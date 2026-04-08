#!/usr/bin/env python3
"""
lib/tui.py — Real 3-panel TUI for terminal-gym.

Layout
──────
  ┌──────────────┬──────────────────────────────────┐
  │   MISSIONS   │  EXERCISES  (paginated)          │
  │  ▼ Section   │                                  │
  │    ● 01 ..   ├──────────────────────────────────┤
  │      02 ..   │  TERMINAL / SHELL MODE  (PTY)    │
  │  ▶ Section   │                                  │
  └──────────────┴──────────────────────────────────┘
                         [ status bar ]

Panels
──────
  MISSIONS   — collapsible sections + mission list (left)
  EXERCISES  — paginated markdown content (top-right)
  TERMINAL   — real bash on a PTY, rendered via pyte (bottom-right)

Modes
─────
  NORMAL MODE  — navigating the TUI panels (missions / exercises)
  SHELL MODE   — typing directly into the embedded bash terminal

Key bindings
────────────
  Esc / Ctrl-X       leave SHELL MODE → return to NORMAL MODE
  3 / Ctrl-X         enter SHELL MODE from NORMAL MODE
  Alt+1 / Alt+2      jump to MISSIONS / EXERCISES without leaving SHELL MODE
  1 / 2              jump to MISSIONS / EXERCISES (NORMAL MODE only)
  Tab / Shift-Tab    cycle panel focus (NORMAL MODE only)
  ↑↓ / jk            navigate missions list  ·  scroll exercises page
  ←                  collapse section (MISSIONS)  ·  prev page (EXERCISES)
  →                  expand section  (MISSIONS)  ·  next page (EXERCISES)
  Enter              open mission  ·  toggle section expand/collapse
  exit               exit shell session (shell restarts automatically)
  Ctrl-Q             quit the entire TUI application
"""

import argparse
import errno
import fcntl
import json
import os
import pty
import re
import select
import signal
import struct
import sys
import tempfile
import termios
import time
import tty
from pathlib import Path

import pyte


# ─── Catppuccin Mocha palette (true-color) ────────────────────────────────────
RESET    = '\x1b[0m'
BOLD     = '\x1b[1m'
DIM      = '\x1b[2m'

# Foreground
C_TEXT   = '\x1b[38;2;205;214;244m'  # lavender — main text
C_SUB    = '\x1b[38;2;166;173;200m'  # subtext1 — secondary
C_DIM    = '\x1b[38;2;108;112;134m'  # overlay0 — dimmed
C_GREEN  = '\x1b[38;2;166;227;161m'  # green
C_YELLOW = '\x1b[38;2;249;226;175m'  # yellow
C_PEACH  = '\x1b[38;2;250;179;135m'  # peach
C_RED    = '\x1b[38;2;243;139;168m'  # red
C_BLUE   = '\x1b[38;2;137;180;250m'  # blue
C_SAPPH  = '\x1b[38;2;116;199;236m'  # sapphire
C_TEAL   = '\x1b[38;2;148;226;213m'  # teal
C_MAUVE  = '\x1b[38;2;203;166;247m'  # mauve

# Backgrounds
BG_BASE   = '\x1b[48;2;30;30;46m'    # #1e1e2e  base
BG_MANTLE = '\x1b[48;2;24;24;37m'    # #181825  mantle — status bar + inactive headers
BG_SURF0  = '\x1b[48;2;49;50;68m'    # #313244  surface0 — active panel header
BG_SURF1  = '\x1b[48;2;69;71;90m'    # #45475a  surface1 — cursor row highlight

# Per-panel accent colors
PANEL_COLORS = {
    'tree':      C_MAUVE,
    'exercises': C_SAPPH,
    'terminal':  C_GREEN,
}

# Mission section groupings for the collapsible tree
SECTIONS = [
    ("Foundations",  ["01", "02", "03", "04"]),
    ("Shell Power",  ["05", "06", "07"]),
    ("Filesystem",   ["08", "09", "10", "11"]),
    ("System",       ["12", "13", "14"]),
    ("Advanced",     ["15", "16", "17"]),
]

# ─── Low-level output ─────────────────────────────────────────────────────────
OUT = sys.stdout.buffer  # raw bytes — fast, no codec overhead


def w(s):
    if isinstance(s, str):
        s = s.encode('utf-8', errors='replace')
    OUT.write(s)


def flush():
    OUT.flush()


def goto(row, col):       w(f'\x1b[{row};{col}H')
def clear_screen():       w('\x1b[2J\x1b[H')
def hide_cursor():        w('\x1b[?25l')
def show_cursor():        w('\x1b[?25h')
def alt_screen_on():      w('\x1b[?1049h')
def alt_screen_off():     w('\x1b[?1049l')


def get_term_size():
    sz = os.get_terminal_size(sys.stdout.fileno())
    return sz.lines, sz.columns


def set_pty_size(fd, rows, cols):
    try:
        fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack('HHHH', rows, cols, 0, 0))
    except OSError:
        pass


# ─── Mission data model ───────────────────────────────────────────────────────
PAGE_SEP_RE = re.compile(r'\n-{3,}\n')
ANSI_RE     = re.compile(r'\x1b\[[0-9;]*m')


class ExercisePage:
    """One '---' separated chunk of exercises.md."""

    def __init__(self, raw_text):
        self.raw   = raw_text.strip()
        self.lines = self.raw.splitlines()
        self.title    = self._derive_title()
        self.expected = self._derive_expected()

    def _derive_title(self):
        for line in self.lines:
            line = line.strip()
            if line.startswith('## '):
                return line[3:].strip()
            if line.startswith('# '):
                return line[2:].strip()
        return 'Intro'

    def _derive_expected(self):
        """Pull `backticked` snippets from a **Hint:** line."""
        for line in self.lines:
            m = re.search(r'\*\*Hint:\*\*\s*(.+)', line, re.IGNORECASE)
            if m:
                return [c.strip() for c in re.findall(r'`([^`]+)`', m.group(1))]
        return []


class Mission:
    def __init__(self, dir_path):
        self.dir  = Path(dir_path)
        m = re.match(r'^(\d+)-(.+)$', self.dir.name)
        self.num  = m.group(1) if m else '00'
        raw       = m.group(2) if m else self.dir.name
        self.name = raw.replace('-', ' ').title()
        self.exercises_md = self.dir / 'exercises.md'
        self._pages = None

    def pages(self):
        if self._pages is None:
            if self.exercises_md.exists():
                text = self.exercises_md.read_text(encoding='utf-8', errors='replace')
                chunks = PAGE_SEP_RE.split(text)
                self._pages = [ExercisePage(c) for c in chunks if c.strip()]
            else:
                self._pages = [ExercisePage(
                    '# No Exercises Yet\n'
                    'This mission does not have an exercises file yet.\n\n'
                    'Check back later or run `make exercises` for this mission.'
                )]
        return self._pages


def load_missions(missions_dir):
    out = []
    for d in sorted(Path(missions_dir).iterdir()):
        if d.is_dir() and re.match(r'^\d+-', d.name):
            out.append(Mission(d))
    return out


# ─── Markdown renderer ────────────────────────────────────────────────────────
def visible_len(s):
    """Character count ignoring ANSI escape sequences."""
    return len(ANSI_RE.sub('', s))


def style_md(line):
    """Apply basic Markdown formatting to a single line."""
    s = line.rstrip()
    if not s:
        return ''
    if s.startswith('# '):
        return f'{BOLD}{C_MAUVE}{s[2:]}{RESET}'
    if s.startswith('## '):
        return f'{BOLD}{C_SAPPH}{s[3:]}{RESET}'
    if s.startswith('### '):
        return f'{BOLD}{C_TEAL}{s[4:]}{RESET}'
    if s.startswith('#### '):
        return f'{BOLD}{C_TEXT}{s[5:]}{RESET}'
    if s.lstrip().startswith(('- ', '* ')):
        indent = len(s) - len(s.lstrip())
        rest   = s.lstrip()[2:]
        s = ' ' * indent + f'{C_BLUE}•{RESET} {C_TEXT}' + rest + RESET
    out = re.sub(r'\*\*([^*]+)\*\*', f'{BOLD}{C_TEXT}\\1{RESET}', s)
    out = re.sub(r'`([^`]+)`', f'{C_GREEN}\\1{RESET}', out)
    if out == s:           # no markdown matched — plain text
        out = f'{C_SUB}{out}{RESET}'
    return out


def truncate_visible(s, max_w):
    """Truncate ANSI string to ≤ max_w visible columns, preserving sequences."""
    if visible_len(s) <= max_w:
        return s
    out  = []
    seen = 0
    i    = 0
    while i < len(s) and seen < max_w - 1:
        if s[i] == '\x1b':
            j = s.find('m', i)
            if j == -1:
                break
            out.append(s[i:j + 1])
            i = j + 1
            continue
        out.append(s[i])
        seen += 1
        i    += 1
    out.append('…')
    out.append(RESET)
    return ''.join(out)


def wrap_visible(s, max_w):
    """Wrap a line at word boundaries to fit ≤ max_w visible columns."""
    if visible_len(s) <= max_w:
        return [s]
    segments = []
    current  = []
    seen     = 0
    i        = 0
    last_break      = -1
    last_break_seen = 0
    while i < len(s):
        if s[i] == '\x1b':
            j = s.find('m', i)
            if j == -1:
                break
            current.append(s[i:j + 1])
            i = j + 1
            continue
        ch = s[i]
        if ch == ' ':
            last_break      = len(current)
            last_break_seen = seen
        current.append(ch)
        seen += 1
        i    += 1
        if seen >= max_w:
            if last_break > 0:
                segments.append(''.join(current[:last_break]) + RESET)
                current  = current[last_break + 1:]
                seen     = seen - last_break_seen - 1
                last_break = -1
            else:
                segments.append(''.join(current) + RESET)
                current = []
                seen    = 0
    if current:
        segments.append(''.join(current))
    return segments


# ─── Pyte color → ANSI SGR ────────────────────────────────────────────────────
NAMED_COLORS = {
    'black': 0, 'red': 1, 'green': 2, 'brown': 3, 'yellow': 3,
    'blue': 4, 'magenta': 5, 'cyan': 6, 'white': 7,
}


def sgr_for_color(color, is_bg):
    base  = 48 if is_bg else 38
    short = 40 if is_bg else 30
    if color is None or color == 'default':
        return None
    if color in NAMED_COLORS:
        return str(short + NAMED_COLORS[color])
    if isinstance(color, str) and len(color) == 6:
        try:
            r = int(color[0:2], 16)
            g = int(color[2:4], 16)
            b = int(color[4:6], 16)
            return f'{base};2;{r};{g};{b}'
        except ValueError:
            return None
    return None


# ─── Grades store ─────────────────────────────────────────────────────────────
GRADES_PATH = Path.home() / '.terminal-gym' / 'grades.json'


def load_grades():
    if GRADES_PATH.exists():
        try:
            return json.loads(GRADES_PATH.read_text())
        except (json.JSONDecodeError, OSError):
            return {}
    return {}


def save_grades(grades):
    try:
        GRADES_PATH.parent.mkdir(parents=True, exist_ok=True)
        tmp = GRADES_PATH.with_suffix('.tmp')
        tmp.write_text(json.dumps(grades, indent=2, sort_keys=True))
        tmp.replace(GRADES_PATH)
    except OSError:
        pass


# ─── Box-drawing characters ───────────────────────────────────────────────────
BX = {
    'tl': '┌', 'tr': '┐', 'bl': '└', 'br': '┘',
    'h':  '─', 'v':  '│',
    'tt': '┬', 'tb': '┴', 'tl_split': '├', 'tr_split': '┤', 'cross': '┼',
}


# ─── TUI ──────────────────────────────────────────────────────────────────────
class Tui:
    LEFT_W = 26   # width of the missions column including borders

    # ── Initialisation ────────────────────────────────────────────────────
    def __init__(self, missions, start_num):
        self.missions    = missions
        self.mission_idx = 0
        for i, m in enumerate(missions):
            if m.num == start_num:
                self.mission_idx = i
                break

        self.section_expanded  = {name: True for name, _ in SECTIONS}
        self._tree_flat_cache  = None          # invalidated by _invalidate_tree()

        self.tree_cursor = self._mission_flat_idx(self.mission_idx)
        self.tree_scroll = 0
        self.page_idx    = 0    # current exercise page within the active mission
        self.page_scroll = 0    # vertical scroll within a single page

        self.focus          = 'terminal'
        self.last_nav_focus = 'exercises'

        # Shell / PTY state
        self.master_fd = None
        self.shell_pid = None
        self.screen    = None
        self.stream    = None

        # Render state
        self.dirty      = True
        self.term_rows  = 0
        self.term_cols  = 0
        self.mid_h      = 0
        self.tp_row     = 0
        self.tp_col     = 0
        self.tp_rows    = 0
        self.tp_cols    = 0

        # Flash message (overlays footer hints for a short duration)
        self.message       = ''
        self.message_until = 0.0

        # Command grading
        self.histfile     = None
        self.histfile_pos = 0
        self.grades       = load_grades()

        # Wrapped-page cache: (mission_idx, page_idx, max_w) → list[str]
        self._page_cache: dict = {}

    # ── Layout ────────────────────────────────────────────────────────────
    def calculate_layout(self):
        self.term_rows, self.term_cols = get_term_size()
        usable        = self.term_rows - 1          # rows 1…term_rows-1 are panels
        self.mid_h    = max(8, usable // 2 + 1)    # row where the horizontal divider sits
        self.tp_row   = self.mid_h + 1              # first content row of terminal panel
        self.tp_col   = self.LEFT_W + 1             # left border column of terminal panel
        self.tp_rows  = max(3, (self.term_rows - 2) - self.tp_row + 1)
        self.tp_cols  = max(20, (self.term_cols - 1) - self.tp_col)
        self._page_cache.clear()

    # ── Shell management ──────────────────────────────────────────────────
    def start_shell(self):
        """Fork a bash process on a new PTY and wire it up."""
        if self.histfile is None:
            fd, path = tempfile.mkstemp(prefix='tgym_hist_', suffix='.log')
            os.close(fd)
            self.histfile     = path
            self.histfile_pos = 0

        master, slave = pty.openpty()
        set_pty_size(slave, self.tp_rows, self.tp_cols)
        pid = os.fork()
        if pid == 0:
            # ── child ──
            os.close(master)
            os.setsid()
            try:
                fcntl.ioctl(slave, termios.TIOCSCTTY, 0)
            except OSError:
                pass
            set_pty_size(slave, self.tp_rows, self.tp_cols)
            os.dup2(slave, 0); os.dup2(slave, 1); os.dup2(slave, 2)
            if slave > 2:
                os.close(slave)
            env = os.environ.copy()
            env.update({
                'LINES':          str(self.tp_rows),
                'COLUMNS':        str(self.tp_cols),
                'TERM':           'xterm-256color',
                'HISTFILE':       self.histfile,
                'HISTSIZE':       '10000',
                'HISTFILESIZE':   '10000',
                'PROMPT_COMMAND': 'history -a',
                'PS1': (
                    r'\[\033[1;32m\]\u\[\033[0m\]'
                    r':\[\033[1;34m\]\W\[\033[0m\]'
                    r'\[\033[1;33m\]$ \[\033[0m\]'
                ),
            })
            os.execvpe('/bin/bash', ['/bin/bash', '--norc', '+h', '-i'], env)
            os._exit(127)

        # ── parent ──
        os.close(slave)
        self.master_fd = master
        self.shell_pid = pid
        fl = fcntl.fcntl(master, fcntl.F_GETFL)
        fcntl.fcntl(master, fcntl.F_SETFL, fl | os.O_NONBLOCK)
        try:
            os.write(master, b'set -o history; clear\n')
        except OSError:
            pass
        self.screen = pyte.Screen(self.tp_cols, self.tp_rows)
        self.stream = pyte.ByteStream(self.screen)

    def resize_shell(self):
        if self.master_fd is None:
            return
        set_pty_size(self.master_fd, self.tp_rows, self.tp_cols)
        try:
            self.screen.resize(self.tp_rows, self.tp_cols)
        except Exception:
            pass
        try:
            os.kill(self.shell_pid, signal.SIGWINCH)
        except (OSError, ProcessLookupError):
            pass

    def stop_shell(self):
        if self.shell_pid:
            try:
                os.kill(self.shell_pid, signal.SIGHUP)
            except (OSError, ProcessLookupError):
                pass
        if self.master_fd is not None:
            try:
                os.close(self.master_fd)
            except OSError:
                pass
        if self.histfile and os.path.exists(self.histfile):
            try:
                os.unlink(self.histfile)
            except OSError:
                pass

    def read_pty(self):
        try:
            data = os.read(self.master_fd, 8192)
        except OSError as e:
            if e.errno in (errno.EAGAIN, errno.EWOULDBLOCK):
                return False
            return False
        if not data:
            return False
        self.stream.feed(data)
        return True

    # ── Command grading ───────────────────────────────────────────────────
    def poll_history(self):
        """Read new lines appended to bash's HISTFILE and evaluate them."""
        if not self.histfile:
            return
        try:
            sz = os.path.getsize(self.histfile)
        except OSError:
            return
        if sz <= self.histfile_pos:
            return
        try:
            with open(self.histfile, 'rb') as f:
                f.seek(self.histfile_pos)
                chunk = f.read(sz - self.histfile_pos)
            self.histfile_pos = sz
        except OSError:
            return
        for line in chunk.decode('utf-8', errors='replace').splitlines():
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            self.evaluate_command(line)

    def evaluate_command(self, cmd):
        """Match cmd against the current mission's expected commands."""
        m     = self.missions[self.mission_idx]
        pages = m.pages()
        if not pages:
            return
        matched = False
        for pi, page in enumerate(pages):
            for exp in page.expected:
                if self._matches(cmd, exp):
                    self._mark_done(m.num, pi, page, exp)
                    matched = True
        if matched:
            self.dirty = True

    @staticmethod
    def _matches(typed, expected):
        """Lenient match: case-insensitive substring or shared first token."""
        t = typed.strip().lower()
        e = expected.strip().lower()
        if not e:
            return False
        if e == t or e in t:
            return True
        et, tt = e.split(), t.split()
        return bool(et and tt and et[0] == tt[0])

    def _mark_done(self, mnum, page_idx, page, cmd):
        m_grades   = self.grades.setdefault(mnum, {})
        key        = f'page_{page_idx}'
        page_grade = m_grades.setdefault(key, {
            'title': page.title, 'expected': page.expected, 'done': [],
        })
        page_grade['title']    = page.title
        page_grade['expected'] = page.expected
        if cmd not in page_grade['done']:
            page_grade['done'].append(cmd)
            save_grades(self.grades)
            self._page_cache.clear()   # ← grade ticks must update immediately
            self.flash(
                f'✓  {page.title}  —  '
                f'{len(page_grade["done"])}/{len(page.expected)} done'
            )

    def page_progress(self, mnum, page_idx, page):
        g    = self.grades.get(mnum, {}).get(f'page_{page_idx}', {})
        done = len(g.get('done', []))
        return done, len(page.expected)

    def mission_progress(self, m):
        done = total = 0
        for pi, page in enumerate(m.pages()):
            d, t = self.page_progress(m.num, pi, page)
            done += d; total += t
        return done, total

    # ── State helpers ─────────────────────────────────────────────────────
    def flash(self, msg, secs=2.5):
        self.message       = msg
        self.message_until = time.time() + secs

    def _set_focus(self, panel):
        """Switch focus and keep last_nav_focus consistent."""
        self.focus = panel
        if panel != 'terminal':
            self.last_nav_focus = panel
        self.dirty = True

    def _invalidate_tree(self):
        self._tree_flat_cache = None

    # ── Input handling ────────────────────────────────────────────────────
    def _handle_shell_mode(self, data):
        """Dispatch a raw byte string received while in SHELL MODE."""
        if data == b'\x11':                       # Ctrl-Q — quit TUI
            raise KeyboardInterrupt
        if data in (b'\x18', b'\x1b'):            # Ctrl-X / Esc — leave shell
            self._set_focus(self.last_nav_focus)
            return
        if data == b'\x1b1':                      # Alt+1 — jump to MISSIONS
            self._set_focus('tree'); return
        if data == b'\x1b2':                      # Alt+2 — jump to EXERCISES
            self._set_focus('exercises'); return
        if data == b'\x1b3':                      # Alt+3 — already in terminal
            return
        try:
            os.write(self.master_fd, data)
        except OSError:
            pass

    def _handle_nav_mode(self, data):
        """Dispatch a byte string received while in NORMAL MODE."""
        # ── Global ───────────────────────────────────────────────────────
        if data in (b'\x11', b'\x03'):            # Ctrl-Q / Ctrl-C — quit
            raise KeyboardInterrupt
        if data == b'\x18':                       # Ctrl-X — enter shell
            self._set_focus('terminal'); return
        if data == b'1':
            self._set_focus('tree'); return
        if data == b'2':
            self._set_focus('exercises'); return
        if data == b'3':
            self._set_focus('terminal'); return
        if data == b'\t':
            self._cycle_focus(reverse=False); self.dirty = True; return
        if data == b'\x1b[Z':                     # Shift-Tab
            self._cycle_focus(reverse=True);  self.dirty = True; return

        # ── Navigation: up / down ─────────────────────────────────────────
        if data in (b'\x1b[A', b'k'):
            self._navigate(-1); self.dirty = True; return
        if data in (b'\x1b[B', b'j'):
            self._navigate(+1); self.dirty = True; return

        # ── Navigation: left / right ──────────────────────────────────────
        if data in (b'\x1b[D', b'h', b'[', b','):
            self._on_left();  self.dirty = True; return
        if data in (b'\x1b[C', b'l', b']', b'.'):
            self._on_right(); self.dirty = True; return

        # ── Page scroll ───────────────────────────────────────────────────
        if data == b'\x1b[5~':                    # PgUp
            self._scroll_page(-5); self.dirty = True; return
        if data == b'\x1b[6~':                    # PgDn
            self._scroll_page(+5); self.dirty = True; return

        # ── Enter ─────────────────────────────────────────────────────────
        if data in (b'\r', b'\n'):
            self._on_enter(); self.dirty = True; return

    def handle_input(self, data):
        if self.focus == 'terminal':
            self._handle_shell_mode(data)
        else:
            self._handle_nav_mode(data)

    # ── Navigation actions ────────────────────────────────────────────────
    def _cycle_focus(self, reverse):
        order = ['tree', 'exercises', 'terminal']
        i     = order.index(self.focus)
        i     = (i + (-1 if reverse else 1)) % len(order)
        self.focus = order[i]
        if self.focus != 'terminal':
            self.last_nav_focus = self.focus

    def _navigate(self, delta):
        if self.focus == 'tree':
            flat = self._tree_flat()
            self.tree_cursor = max(0, min(len(flat) - 1, self.tree_cursor + delta))
        elif self.focus == 'exercises':
            self._scroll_page(delta)

    def _scroll_page(self, delta):
        self.page_scroll = max(0, self.page_scroll + delta)

    def _page(self, delta):
        """Advance the exercise page by delta (for exercises focus only)."""
        if self.focus != 'exercises':
            return
        pages        = self.missions[self.mission_idx].pages()
        self.page_idx    = max(0, min(len(pages) - 1, self.page_idx + delta))
        self.page_scroll = 0

    def _on_left(self):
        if self.focus == 'tree':
            flat = self._tree_flat()
            kind, payload = flat[self.tree_cursor]
            if kind == 'section':
                self.section_expanded[payload] = False
                self._invalidate_tree()
                self.tree_cursor = min(self.tree_cursor, len(self._tree_flat()) - 1)
            else:
                # Jump up to parent section header
                for i in range(self.tree_cursor - 1, -1, -1):
                    if flat[i][0] == 'section':
                        self.tree_cursor = i
                        break
        else:
            self._page(-1)

    def _on_right(self):
        if self.focus == 'tree':
            flat = self._tree_flat()
            kind, payload = flat[self.tree_cursor]
            if kind == 'section' and not self.section_expanded.get(payload, True):
                self.section_expanded[payload] = True
                self._invalidate_tree()
        else:
            self._page(+1)

    def _on_enter(self):
        if self.focus != 'tree':
            return
        flat = self._tree_flat()
        kind, payload = flat[self.tree_cursor]
        if kind == 'section':
            self.section_expanded[payload] = not self.section_expanded.get(payload, True)
            self._invalidate_tree()
            self.tree_cursor = min(self.tree_cursor, len(self._tree_flat()) - 1)
        else:
            m       = payload
            new_idx = self.missions.index(m)
            if new_idx != self.mission_idx:
                self.mission_idx  = new_idx
                self.page_idx     = 0
                self.page_scroll  = 0
                self.flash(f'→  Mission {m.num}  ·  {m.name}')
            self._set_focus('exercises')

    # ── Tree data ─────────────────────────────────────────────────────────
    def _tree_flat(self):
        """Flat list of visible (kind, payload) rows, cached until invalidated.

        kind='section' → payload = section name (str)
        kind='mission' → payload = Mission object
        """
        if self._tree_flat_cache is None:
            by_num = {m.num: m for m in self.missions}
            flat   = []
            for sec_name, nums in SECTIONS:
                flat.append(('section', sec_name))
                if self.section_expanded.get(sec_name, True):
                    for num in nums:
                        if num in by_num:
                            flat.append(('mission', by_num[num]))
            self._tree_flat_cache = flat
        return self._tree_flat_cache

    def _mission_flat_idx(self, mission_idx):
        """Return the flat tree index for missions[mission_idx]."""
        target = self.missions[mission_idx]
        for i, (kind, payload) in enumerate(self._tree_flat()):
            if kind == 'mission' and payload is target:
                return i
        return 0

    # ── Rendering: layout helpers ─────────────────────────────────────────
    def _hbar(self, row, col, width, left_text, right_text='', panel_name=''):
        """Draw a full-width header bar with panel-specific accent colour."""
        focused = self.focus == panel_name
        accent  = PANEL_COLORS.get(panel_name, C_TEXT)
        bg      = BG_SURF0  if focused else BG_MANTLE
        style   = BOLD + accent if focused else C_DIM
        left    = f' {left_text}'
        right   = f'{right_text} ' if right_text else ''
        # Use visible length so accented characters (◀ ▶) are counted correctly
        gap     = max(1, width - visible_len(left) - visible_len(right))
        content = left + ' ' * gap + right
        goto(row, col)
        w(f'{bg}{style}{content[:width]}{RESET}')

    def _panel_clear(self, r1, c1, nrows, ncols):
        blank = ' ' * ncols
        for r in range(nrows):
            goto(r1 + r, c1)
            w(blank)

    def render(self):
        hide_cursor()
        self._draw_borders()
        self._draw_missions()
        self._draw_exercises()
        self._draw_terminal()
        self._draw_status()
        self._position_cursor()
        flush()

    # ── Rendering: borders ────────────────────────────────────────────────
    def _draw_borders(self):
        rows = self.term_rows
        cols = self.term_cols
        w(C_DIM)
        # Outer box
        goto(1, 1);         w(BX['tl'] + BX['h'] * (cols - 2) + BX['tr'])
        goto(rows - 1, 1);  w(BX['bl'] + BX['h'] * (cols - 2) + BX['br'])
        for r in range(2, rows - 1):
            goto(r, 1);           w(BX['v'])
            goto(r, self.LEFT_W); w(BX['v'])
            goto(r, cols);        w(BX['v'])
        # Horizontal divider between EXERCISES and TERMINAL
        goto(self.mid_h, self.LEFT_W)
        w(BX['tl_split'] + BX['h'] * (cols - self.LEFT_W - 1) + BX['tr_split'])
        w(RESET)

    # ── Rendering: missions tree ──────────────────────────────────────────
    def _draw_missions(self):
        iw      = self.LEFT_W - 2   # interior width: col 2 … LEFT_W-1
        focused = self.focus == 'tree'

        # Header: aggregate progress counter
        done_cnt = sum(
            1 for m in self.missions
            if (p := self.mission_progress(m))[0] >= p[1] > 0
        )
        self._hbar(2, 2, iw, 'MISSIONS', f'{done_cnt}/{len(self.missions)}', 'tree')

        flat        = self._tree_flat()
        blank       = ' ' * iw
        max_visible = self.term_rows - 4   # rows 3 … term_rows-2

        # Auto-scroll viewport to keep cursor visible
        if self.tree_cursor < self.tree_scroll:
            self.tree_scroll = self.tree_cursor
        elif self.tree_cursor >= self.tree_scroll + max_visible:
            self.tree_scroll = self.tree_cursor - max_visible + 1

        # Column layout for mission rows: indent(2) + cur(1) + sp(1) + num(2) + sp(1) + name + sp(1) + mark(1)
        name_w = max(4, iw - 10)

        for i in range(max_visible):
            row      = 3 + i
            flat_idx = self.tree_scroll + i
            goto(row, 2); w(blank)
            if flat_idx >= len(flat):
                continue

            kind, payload = flat[flat_idx]
            is_cursor     = (flat_idx == self.tree_cursor and focused)

            # Row highlight: surface1 background for cursor row
            row_bg = BG_SURF1 if is_cursor else ''
            # Row-aware reset: after any RESET inside a highlighted row,
            # we must restore the background colour.
            rr = (RESET + BG_SURF1) if is_cursor else RESET

            if kind == 'section':
                arrow = '▼' if self.section_expanded.get(payload, True) else '▶'
                style = (BOLD + C_MAUVE) if is_cursor else C_DIM
                label = payload[:iw - 3]
                goto(row, 2)
                w(f'{row_bg} {style}{arrow} {label}{RESET}')

            else:
                # Mission row
                m        = payload
                is_active = (m is self.missions[self.mission_idx])
                done, total = self.mission_progress(m)

                # Mark symbol
                if total > 0 and done >= total:
                    mark = f'{C_GREEN}✓{rr}'
                elif done > 0:
                    mark = f'{C_YELLOW}~{rr}'
                else:
                    mark = f'{C_DIM}·{rr}'

                # Cursor / active indicator
                # When cursor lands on the active mission: green ▶ (merges both states)
                if is_cursor and is_active:
                    cur = f'{BOLD}{C_GREEN}▶{rr}'
                elif is_cursor:
                    cur = f'{BOLD}{C_MAUVE}▶{rr}'
                elif is_active:
                    cur = f'{C_GREEN}●{RESET}'
                else:
                    cur = ' '

                # Name colour
                if is_active:
                    ns, ne = BOLD + C_GREEN, rr
                elif is_cursor:
                    ns, ne = C_MAUVE, rr
                else:
                    ns, ne = C_SUB, RESET

                label = m.name[:name_w]
                goto(row, 2)
                w(f'{row_bg}  {cur} {C_DIM}{m.num}{rr} {ns}{label:<{name_w}}{ne} {mark}{RESET}')

    # ── Rendering: exercises panel ────────────────────────────────────────
    def _draw_exercises(self):
        focused = self.focus == 'exercises'
        m       = self.missions[self.mission_idx]
        pages   = m.pages()
        page    = pages[self.page_idx] if pages else None
        c1      = self.LEFT_W + 1
        iw      = self.term_cols - c1 - 1

        # Panel header
        pg_nav = f'◀ {self.page_idx + 1}/{len(pages)} ▶' if pages else ''
        self._hbar(2, c1 + 1, iw, f'EXERCISES  {m.num} · {m.name}', pg_nav, 'exercises')

        # Sub-header row: progress bar  (or flash message if active)
        self._panel_clear(3, c1 + 1, 1, iw)
        now = time.time()
        if self.message and now < self.message_until:
            goto(3, c1 + 2)
            w(f'{BOLD}{C_YELLOW}  {self.message}{RESET}')
        elif page is not None:
            done, total = self.page_progress(m.num, self.page_idx, page)
            if total > 0:
                bar_len  = min(20, iw - 14)
                filled   = int(round(bar_len * done / total))
                bar      = f'{C_GREEN}{"█" * filled}{C_DIM}{"░" * (bar_len - filled)}{RESET}'
                score_c  = C_GREEN if done == total else C_YELLOW
                progress = (
                    f'  {bar}  {score_c}{done}/{total}{RESET}'
                    if done < total
                    else f'{C_GREEN}  ✓  All exercises complete!{RESET}'
                )
                goto(3, c1 + 2); w(progress)

        # Body
        body_row  = 4
        body_rows = max(1, self.mid_h - 4)
        max_w     = iw - 2
        self._panel_clear(body_row, c1 + 1, body_rows, iw)

        if page is None:
            goto(body_row + body_rows // 2, c1 + 3)
            w(f'{C_DIM}No exercises for this mission yet.{RESET}')
            return

        wrapped    = self._wrapped_page(self.mission_idx, self.page_idx, max_w)
        max_scroll = max(0, len(wrapped) - body_rows)
        if self.page_scroll > max_scroll:
            self.page_scroll = max_scroll

        for i, line in enumerate(wrapped[self.page_scroll:self.page_scroll + body_rows]):
            goto(body_row + i, c1 + 2)
            w(truncate_visible(line, max_w))

        # Scroll indicator (right edge of panel)
        if len(wrapped) > body_rows:
            ind_col = c1 + iw
            ratio   = self.page_scroll / max(1, max_scroll)
            knob    = body_row + int(ratio * (body_rows - 1))
            for r in range(body_row, body_row + body_rows):
                goto(r, ind_col); w(f'{C_DIM}│{RESET}')
            goto(knob, ind_col); w(f'{BOLD}{C_SAPPH}█{RESET}')

    def _wrapped_page(self, mi, pi, max_w):
        key = (mi, pi, max_w)
        if key not in self._page_cache:
            page = self.missions[mi].pages()[pi]
            out  = []

            # Title banner
            out.append(f'{BOLD}{C_SAPPH}{page.title}{RESET}')
            out.append('')

            for raw in page.lines:
                # Skip the raw heading line — already used as title
                if raw.strip() in (f'## {page.title}', f'# {page.title}'):
                    continue
                for seg in wrap_visible(style_md(raw), max_w):
                    out.append(seg)

            # Expected commands footer with grade ticks
            if page.expected:
                out.append('')
                out.append(f'{C_DIM}{"─" * max_w}{RESET}')
                out.append(f'{BOLD}{C_TEXT}Expected commands:{RESET}')
                grade    = self.grades.get(self.missions[mi].num, {}).get(f'page_{pi}', {})
                done_set = set(grade.get('done', []))
                for exp in page.expected:
                    hit  = any(self._matches(d, exp) for d in done_set)
                    tick = f'{C_GREEN}✓{RESET}' if hit else f'{C_DIM}○{RESET}'
                    out.append(f'  {tick} {C_TEAL}{exp}{RESET}')

            self._page_cache[key] = out
        return self._page_cache[key]

    # ── Rendering: terminal panel ─────────────────────────────────────────
    def _draw_terminal(self):
        c1 = self.LEFT_W + 1
        iw = self.term_cols - c1 - 1

        # Header bar sits on the horizontal divider row
        m             = self.missions[self.mission_idx]
        done, total   = self.mission_progress(m)
        grade_str     = f'{done}/{total} tasks' if total else ''
        in_shell      = self.focus == 'terminal'
        title         = 'SHELL MODE' if in_shell else 'TERMINAL'
        self._hbar(self.mid_h, c1 + 1, iw, title, grade_str, 'terminal')

        # PTY content
        self._panel_clear(self.tp_row, self.tp_col + 1, self.tp_rows, self.tp_cols)
        if self.screen is None:
            # Shell is still starting — show a loading message
            mid = self.tp_rows // 2
            goto(self.tp_row + mid, self.tp_col + 3)
            w(f'{C_DIM}Starting shell…{RESET}')
            return
        for r in range(min(self.tp_rows, self.screen.lines)):
            self._draw_pyte_row(r)

    def _draw_pyte_row(self, r):
        line  = self.screen.buffer[r]
        max_c = min(self.tp_cols, self.screen.columns)
        goto(self.tp_row + r, self.tp_col + 1)
        last_attrs = None
        chunks     = []
        _default   = ('default', 'default', False, False, False, False)
        for c in range(max_c):
            ch    = line[c]
            attrs = (ch.fg, ch.bg, ch.bold, ch.italics, ch.underscore, ch.reverse)
            if attrs != last_attrs:
                if chunks:
                    if last_attrs and last_attrs != _default:
                        w(self._sgr(last_attrs)); w(''.join(chunks)); w(RESET)
                    else:
                        w(''.join(chunks))
                    chunks = []
                last_attrs = attrs
            chunks.append(ch.data if ch.data else ' ')
        if chunks:
            if last_attrs and last_attrs != _default:
                w(self._sgr(last_attrs)); w(''.join(chunks)); w(RESET)
            else:
                w(''.join(chunks))

    @staticmethod
    def _sgr(attrs):
        fg, bg, bold, italic, underscore, reverse = attrs
        codes = []
        if bold:       codes.append('1')
        if italic:     codes.append('3')
        if underscore: codes.append('4')
        if reverse:    codes.append('7')
        c = sgr_for_color(fg, False)
        if c: codes.append(c)
        c = sgr_for_color(bg, True)
        if c: codes.append(c)
        return f'\x1b[{";".join(codes)}m' if codes else ''

    # ── Rendering: status bar ─────────────────────────────────────────────
    def _draw_status(self):
        rows = self.term_rows
        cols = self.term_cols
        # Clear the whole row with mantle background
        goto(rows, 1)
        w(f'{BG_MANTLE}{" " * cols}{RESET}')
        goto(rows, 2)

        # Mode badge
        if self.focus == 'terminal':
            mode_label = 'SHELL MODE'
            mode_color = C_GREEN
        else:
            mode_label = 'NORMAL MODE'
            mode_color = C_MAUVE

        # Hint text — panel-specific in NORMAL MODE, fixed in SHELL MODE
        now = time.time()
        if self.message and now < self.message_until:
            hint = f'  {BOLD}{C_YELLOW}{self.message}{RESET}{BG_MANTLE}'
        else:
            self.message = ''
            if self.focus == 'terminal':
                hint = (
                    f'{C_DIM}  Esc/Ctrl-X: leave shell'
                    f'  ·  Ctrl-Q: quit'
                    f'  ·  exit: end shell session{RESET}'
                )
            elif self.focus == 'tree':
                hint = (
                    f'{C_DIM}  ↑↓/jk: navigate'
                    f'  ·  Enter: open / toggle'
                    f'  ·  ←→: collapse/expand'
                    f'  ·  Ctrl-X/3: shell'
                    f'  ·  Ctrl-Q: quit{RESET}'
                )
            else:   # exercises
                hint = (
                    f'{C_DIM}  ←→/[]: page'
                    f'  ·  ↑↓/jk: scroll'
                    f'  ·  1: missions'
                    f'  ·  Ctrl-X/3: shell'
                    f'  ·  Ctrl-Q: quit{RESET}'
                )

        badge = f'{BG_MANTLE}{BOLD}{mode_color} [{mode_label}]{RESET}{BG_MANTLE}'
        w(f'{badge}{hint}')

    # ── Rendering: cursor placement ───────────────────────────────────────
    def _position_cursor(self):
        if self.focus == 'terminal' and self.screen is not None:
            row = self.tp_row + self.screen.cursor.y
            col = self.tp_col + 1 + self.screen.cursor.x
            if row < self.term_rows - 1 and col < self.term_cols:
                goto(row, col)
                show_cursor()
                return
        hide_cursor()

    # ── Main loop ─────────────────────────────────────────────────────────
    def run(self):
        self.calculate_layout()
        self.start_shell()
        alt_screen_on(); clear_screen(); hide_cursor()

        stdin_fd = sys.stdin.fileno()
        old      = termios.tcgetattr(stdin_fd)
        tty.setraw(stdin_fd)
        fl       = fcntl.fcntl(stdin_fd, fcntl.F_GETFL)
        fcntl.fcntl(stdin_fd, fcntl.F_SETFL, fl | os.O_NONBLOCK)

        def on_resize(sig, frame):
            self.calculate_layout()
            self.resize_shell()
            self.dirty = True
        signal.signal(signal.SIGWINCH, on_resize)

        try:
            self.render()
            self.dirty      = False
            last_render     = 0.0
            last_hist_poll  = 0.0

            while True:
                # Reap zombie shell and restart automatically
                try:
                    pid, _ = os.waitpid(self.shell_pid, os.WNOHANG)
                    if pid != 0:
                        try:
                            os.close(self.master_fd)
                        except OSError:
                            pass
                        self.start_shell()
                        self.flash('Shell session ended — new session started')
                        self.dirty = True
                except ChildProcessError:
                    pass

                r, _, _ = select.select([stdin_fd, self.master_fd], [], [], 0.03)

                if self.master_fd in r:
                    while self.read_pty():
                        pass
                    self.dirty = True

                if stdin_fd in r:
                    try:
                        data = os.read(stdin_fd, 4096)
                    except OSError:
                        data = b''
                    if data:
                        self._dispatch_input(data)

                now = time.time()
                if now - last_hist_poll > 0.2:
                    self.poll_history()
                    last_hist_poll = now

                if (self.dirty and now - last_render > 0.03) or (
                        self.message and now < self.message_until
                        and now - last_render > 0.1):
                    self.render()
                    self.dirty      = False
                    last_render     = now

        except KeyboardInterrupt:
            pass
        finally:
            self.stop_shell()
            termios.tcsetattr(stdin_fd, termios.TCSADRAIN, old)
            fcntl.fcntl(stdin_fd, fcntl.F_SETFL, fl)
            show_cursor()
            alt_screen_off()
            flush()

    def _dispatch_input(self, data):
        """Parse raw stdin bytes and deliver complete sequences to handle_input."""
        if self.focus == 'terminal':
            # In SHELL MODE: pass the entire buffer as-is; handle_input inspects it.
            self.handle_input(data)
            return

        # NORMAL MODE: parse escape sequences so arrow keys etc. work correctly.
        i = 0
        while i < len(data):
            b = data[i:i + 1]
            if b == b'\x1b' and i + 1 < len(data):
                nxt = data[i + 1:i + 2]
                if nxt == b'[':
                    # CSI sequence: \x1b[ … final-byte (0x40-0x7E)
                    j = i + 2
                    while j < len(data) and not (0x40 <= data[j] <= 0x7E):
                        j += 1
                    self.handle_input(data[i:j + 1])
                    i = j + 1
                elif nxt == b'O':
                    # SS3 sequence: \x1bO<char>  (used by some terminals for arrows/Fkeys)
                    if i + 2 < len(data):
                        _ss3 = {b'A': b'\x1b[A', b'B': b'\x1b[B',
                                b'C': b'\x1b[C', b'D': b'\x1b[D'}
                        key  = data[i + 2:i + 3]
                        self.handle_input(_ss3.get(key, data[i:i + 3]))
                        i += 3
                    else:
                        self.handle_input(b)
                        i += 1
                else:
                    # Alt+key or bare Esc followed by something
                    if i + 1 < len(data):
                        self.handle_input(data[i:i + 2])
                        i += 2
                    else:
                        self.handle_input(b'\x1b')
                        i += 1
            else:
                self.handle_input(b)
                i += 1


def main():
    p = argparse.ArgumentParser(description='terminal-gym — 3-panel TUI')
    p.add_argument('--missions-dir', default=None,
                   help='path to missions/ directory (auto-detected if omitted)')
    p.add_argument('--start', default='01',
                   help='starting mission number, e.g. 03')
    args = p.parse_args()

    missions_dir = args.missions_dir
    if not missions_dir:
        missions_dir = Path(__file__).resolve().parent.parent / 'missions'

    missions = load_missions(missions_dir)
    if not missions:
        print(f'No missions found in {missions_dir}', file=sys.stderr)
        return 1

    Tui(missions, args.start).run()
    return 0


if __name__ == '__main__':
    sys.exit(main())
