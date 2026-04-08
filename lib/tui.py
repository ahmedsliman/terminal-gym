#!/usr/bin/env python3
"""
lib/tui.py — Real 3-panel TUI for terminal-gym.

Layout:
  ┌──────────┬───────────────────────────────┐
  │ MISSIONS │ EXERCISES (paginated)         │
  │          │                               │
  │          ├───────────────────────────────┤
  │          │ TERMINAL  (real bash on PTY)  │
  └──────────┴───────────────────────────────┘
                       [ status bar ]

Three independent panels. Real bash on a PTY in the bottom-right panel —
output flows through `pyte` (a VT100 emulator) so colors/cursor/vim/htop
all work. The TUI captures every command the user runs in the shell and
matches them against the expected commands of the current exercise page;
grades are stored in ~/.terminal-gym/grades.json.

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
  ↑↓ / jk            navigate missions list or scroll exercises page
  ← →                collapse/expand section (MISSIONS) · prev/next page (EXERCISES)
  Enter              open mission · toggle section expand/collapse
  exit               exit the shell session (shell restarts automatically)
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


# ─── Catppuccin Mocha palette (true-color) ───────────────────────────────────
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
BG_MANTLE = '\x1b[48;2;24;24;37m'    # #181825  mantle — status + inactive headers
BG_SURF0  = '\x1b[48;2;49;50;68m'    # #313244  surface0 — active header
BG_SURF1  = '\x1b[48;2;69;71;90m'    # #45475a  surface1 — selection

# Per-panel accent colors used in header bars
PANEL_COLORS = {
    'tree':      C_MAUVE,
    'exercises': C_SAPPH,
    'terminal':  C_GREEN,
}

# Mission section groupings for collapsible tree
SECTIONS = [
    ("Foundations",  ["01", "02", "03", "04"]),
    ("Shell Power",  ["05", "06", "07"]),
    ("Filesystem",   ["08", "09", "10", "11"]),
    ("System",       ["12", "13", "14"]),
    ("Advanced",     ["15", "16", "17"]),
]

# Legacy aliases so old references in _sgr / status still work
GREEN        = C_GREEN
YELLOW       = C_YELLOW
CYAN         = C_SAPPH
WHITE        = C_TEXT
BRIGHT_WHITE = C_TEXT
BG_STATUS    = BG_MANTLE

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


# ─── Mission discovery + page parsing ────────────────────────────────────────
PAGE_SEP_RE = re.compile(r'\n-{3,}\n')
ANSI_RE     = re.compile(r'\x1b\[[0-9;]*m')


class ExercisePage:
    """One '---' chunk of exercises.md."""
    def __init__(self, raw_text):
        self.raw = raw_text.strip()
        self.lines = self.raw.splitlines()
        self.title = self._derive_title()
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
        # Fallback: any backticks in the **Steps:** block
        return []


class Mission:
    def __init__(self, dir_path):
        self.dir = Path(dir_path)
        m = re.match(r'^(\d+)-(.+)$', self.dir.name)
        self.num = m.group(1) if m else '00'
        raw = m.group(2) if m else self.dir.name
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
                self._pages = [ExercisePage('# (no exercises.md)\nThis mission has no exercises file.')]
        return self._pages


def load_missions(missions_dir):
    out = []
    for d in sorted(Path(missions_dir).iterdir()):
        if d.is_dir() and re.match(r'^\d+-', d.name):
            out.append(Mission(d))
    return out


# ─── Markdown styling for the EXERCISES panel ────────────────────────────────
def visible_len(s):
    return len(ANSI_RE.sub('', s))


def style_md(line):
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
        rest = s.lstrip()[2:]
        s = ' ' * indent + f'{C_BLUE}•{RESET} {C_TEXT}' + rest + RESET
    out = re.sub(r'\*\*([^*]+)\*\*', f'{BOLD}{C_TEXT}\\1{RESET}', s)
    out = re.sub(r'`([^`]+)`', f'{C_GREEN}\\1{RESET}', out)
    if out == s:  # no markdown applied — plain text
        out = f'{C_SUB}{out}{RESET}'
    return out


def truncate_visible(s, max_w):
    """Truncate ANSI string to <= max_w visible cols, preserving sequences."""
    if visible_len(s) <= max_w:
        return s
    out = []
    seen = 0
    i = 0
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
        i += 1
    out.append('…')
    out.append(RESET)
    return ''.join(out)


def wrap_visible(s, max_w):
    """Wrap one line at most max_w visible columns. Returns list of segments."""
    if visible_len(s) <= max_w:
        return [s]
    # Naive wrapping: track ANSI state, break on whitespace
    segments = []
    current = []
    seen = 0
    i = 0
    last_break = -1
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
            last_break = len(current)
            last_break_seen = seen
        current.append(ch)
        seen += 1
        i += 1
        if seen >= max_w:
            if last_break > 0:
                seg = ''.join(current[:last_break])
                segments.append(seg + RESET)
                current = current[last_break + 1:]
                seen = seen - last_break_seen - 1
                last_break = -1
            else:
                segments.append(''.join(current) + RESET)
                current = []
                seen = 0
    if current:
        segments.append(''.join(current))
    return segments


# ─── Pyte color → SGR ────────────────────────────────────────────────────────
NAMED_COLORS = {
    'black': 0, 'red': 1, 'green': 2, 'brown': 3, 'yellow': 3,
    'blue': 4, 'magenta': 5, 'cyan': 6, 'white': 7,
}


def sgr_for_color(color, is_bg):
    base = 48 if is_bg else 38
    short = 40 if is_bg else 30
    if color is None or color == 'default':
        return None
    if color in NAMED_COLORS:
        return str(short + NAMED_COLORS[color])
    if isinstance(color, str) and len(color) == 6:
        try:
            r = int(color[0:2], 16); g = int(color[2:4], 16); b = int(color[4:6], 16)
            return f'{base};2;{r};{g};{b}'
        except ValueError:
            return None
    return None


# ─── Grades store ────────────────────────────────────────────────────────────
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


# ─── Box-drawing characters ──────────────────────────────────────────────────
BX = {
    'tl': '┌', 'tr': '┐', 'bl': '└', 'br': '┘',
    'h':  '─', 'v':  '│',
    'tt': '┬', 'tb': '┴', 'tl_split': '├', 'tr_split': '┤', 'cross': '┼',
}


# ─── TUI ─────────────────────────────────────────────────────────────────────
class Tui:
    LEFT_W = 26

    def __init__(self, missions, start_num):
        self.missions = missions
        self.mission_idx = 0
        for i, m in enumerate(missions):
            if m.num == start_num:
                self.mission_idx = i
                break
        self.section_expanded = {name: True for name, _ in SECTIONS}
        self.tree_cursor = self._mission_flat_idx(self.mission_idx)
        self.tree_scroll = 0
        self.page_idx = 0          # current exercise page within the mission
        self.page_scroll = 0       # vertical scroll within a single page
        self.focus = 'terminal'
        self.last_nav_focus = 'exercises'
        self.master_fd = None
        self.shell_pid = None
        self.screen = None
        self.stream = None
        self.dirty = True
        self.term_rows = 0
        self.term_cols = 0
        self.mid_h = 0
        self.tp_row = 0
        self.tp_col = 0
        self.tp_rows = 0
        self.tp_cols = 0
        self.message = ''
        self.message_until = 0
        # ── Command capture / grading state ────────────────────────────
        self.histfile = None
        self.histfile_pos = 0
        self.grades = load_grades()
        # ── Cached wrapped page lines ──────────────────────────────────
        self._page_cache = {}     # (mission_idx, page_idx, max_w) → wrapped lines

    # ── Layout ────────────────────────────────────────────────────────────
    def calculate_layout(self):
        self.term_rows, self.term_cols = get_term_size()
        # rows 1..term_rows-1 are panels (with row 1 = top border, row term_rows-1 = bottom border)
        # row term_rows = status bar
        usable = self.term_rows - 1
        self.mid_h = max(8, usable // 2 + 1)
        # Terminal panel inner area: rows mid_h+1 .. term_rows-2, cols LEFT_W+2 .. term_cols-1
        self.tp_row = self.mid_h + 1
        self.tp_col = self.LEFT_W + 1
        self.tp_rows = max(3, (self.term_rows - 2) - self.tp_row + 1)
        self.tp_cols = max(20, (self.term_cols - 1) - self.tp_col)
        self._page_cache.clear()

    # ── Shell management ──────────────────────────────────────────────────
    def start_shell(self):
        # Create unique history file for this session — used to capture commands
        if self.histfile is None:
            fd, path = tempfile.mkstemp(prefix='tgym_hist_', suffix='.log')
            os.close(fd)
            self.histfile = path
            self.histfile_pos = 0

        master, slave = pty.openpty()
        set_pty_size(slave, self.tp_rows, self.tp_cols)
        pid = os.fork()
        if pid == 0:
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
            env['LINES'] = str(self.tp_rows)
            env['COLUMNS'] = str(self.tp_cols)
            env['TERM'] = 'xterm-256color'
            env['HISTFILE'] = self.histfile
            env['HISTSIZE'] = '10000'
            env['HISTFILESIZE'] = '10000'
            env['PROMPT_COMMAND'] = 'history -a'
            env['PS1'] = (
                r'\[\033[1;32m\]\u\[\033[0m\]'
                r':\[\033[1;34m\]\W\[\033[0m\]'
                r'\[\033[1;33m\]$ \[\033[0m\]'
            )
            os.execvpe('/bin/bash', ['/bin/bash', '--norc', '+h', '-i'], env)
            os._exit(127)
        os.close(slave)
        self.master_fd = master
        self.shell_pid = pid
        fl = fcntl.fcntl(master, fcntl.F_GETFL)
        fcntl.fcntl(master, fcntl.F_SETFL, fl | os.O_NONBLOCK)
        # Re-enable history (we passed +h to disable it during init, then turn it back on
        # via the very first command sent to the shell)
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
        # Clean up histfile
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

    # ── Command capture + grading ────────────────────────────────────────
    def poll_history(self):
        """Read any new lines appended to bash's HISTFILE and grade them."""
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
        """Match the command against the current page's expected and update grades."""
        m = self.missions[self.mission_idx]
        pages = m.pages()
        if not pages:
            return
        # Check ALL pages of the current mission, not just the current one — the
        # user might be working ahead.
        any_match = False
        for pi, page in enumerate(pages):
            for exp in page.expected:
                if self._matches(cmd, exp):
                    self._mark_done(m.num, pi, page, exp)
                    any_match = True
        if any_match:
            self.dirty = True

    @staticmethod
    def _matches(typed, expected):
        """Lenient: case-insensitive substring match on the trimmed strings."""
        t = typed.strip().lower()
        e = expected.strip().lower()
        if not e:
            return False
        # Exact or contains
        if e == t or e in t:
            return True
        # Tokenize and require expected's first token equals typed's first token
        et = e.split()
        tt = t.split()
        if et and tt and et[0] == tt[0]:
            return True
        return False

    def _mark_done(self, mnum, page_idx, page, cmd):
        m_grades = self.grades.setdefault(mnum, {})
        key = f'page_{page_idx}'
        page_grade = m_grades.setdefault(key, {
            'title': page.title,
            'expected': page.expected,
            'done': [],
        })
        # Refresh in case the page was edited since last run
        page_grade['title'] = page.title
        page_grade['expected'] = page.expected
        if cmd not in page_grade['done']:
            page_grade['done'].append(cmd)
            save_grades(self.grades)
            self.flash(f'✓ {page.title} — {len(page_grade["done"])}/{len(page.expected)}')

    def page_progress(self, mnum, page_idx, page):
        m_grades = self.grades.get(mnum, {})
        page_grade = m_grades.get(f'page_{page_idx}', {})
        done = len(page_grade.get('done', []))
        total = len(page.expected)
        return done, total

    def mission_progress(self, m):
        done = 0
        total = 0
        for pi, page in enumerate(m.pages()):
            d, t = self.page_progress(m.num, pi, page)
            done += d
            total += t
        return done, total

    # ── Input handling ───────────────────────────────────────────────────
    def handle_input(self, data):
        if self.focus == 'terminal':
            # ── SHELL MODE ────────────────────────────────────────────────
            if data == b'\x11':                  # Ctrl-Q — quit TUI
                raise KeyboardInterrupt
            if data in (b'\x18', b'\x1b'):       # Ctrl-X / Esc — leave SHELL MODE
                # \x1b is bare Esc (1 byte); \x1b1 etc. are multi-byte and won't match here
                self.focus = self.last_nav_focus
                self.dirty = True
                return
            if data == b'\x1b1':                 # Alt+1 — jump to MISSIONS
                self.focus = 'tree'; self.last_nav_focus = 'tree'; self.dirty = True; return
            if data == b'\x1b2':                 # Alt+2 — jump to EXERCISES
                self.focus = 'exercises'; self.last_nav_focus = 'exercises'; self.dirty = True; return
            if data == b'\x1b3':                 # Alt+3 — already in terminal, consume silently
                return
            try:
                os.write(self.master_fd, data)   # pass everything else to the shell
            except OSError:
                pass
            return

        # ── NORMAL MODE (tree | exercises) ───────────────────────────────
        if data == b'\x11':                      # Ctrl-Q — quit TUI
            raise KeyboardInterrupt
        if data == b'\x03':                      # Ctrl-C — quit TUI (nav mode only)
            raise KeyboardInterrupt
        if data == b'\x18':                      # Ctrl-X — back to terminal
            self.focus = 'terminal'; self.dirty = True; return
        if data in (b'1',):
            self.focus = 'tree'; self.last_nav_focus = 'tree'; self.dirty = True; return
        if data in (b'2',):
            self.focus = 'exercises'; self.last_nav_focus = 'exercises'; self.dirty = True; return
        if data in (b'3',):
            self.focus = 'terminal'; self.dirty = True; return
        if data == b'\t':
            self._cycle_focus(False); self.dirty = True; return
        if data == b'\x1b[Z':                    # Shift-Tab
            self._cycle_focus(True); self.dirty = True; return
        if data in (b'\x1b[A', b'k'):
            self._navigate(-1); self.dirty = True; return
        if data in (b'\x1b[B', b'j'):
            self._navigate(1); self.dirty = True; return
        if data in (b'\x1b[D', b'h', b'[', b','):
            if self.focus == 'tree':
                # Left: collapse section or jump to parent section
                flat = self._tree_flat()
                kind, payload = flat[self.tree_cursor]
                if kind == 'section':
                    self.section_expanded[payload] = False
                else:
                    # Jump cursor to parent section
                    for i in range(self.tree_cursor - 1, -1, -1):
                        if flat[i][0] == 'section':
                            self.tree_cursor = i
                            break
                self.tree_cursor = min(self.tree_cursor, len(self._tree_flat()) - 1)
            else:
                self._page(-1)
            self.dirty = True; return
        if data in (b'\x1b[C', b'l', b']', b'.'):
            if self.focus == 'tree':
                # Right: expand section
                flat = self._tree_flat()
                kind, payload = flat[self.tree_cursor]
                if kind == 'section':
                    self.section_expanded[payload] = True
            else:
                self._page(1)
            self.dirty = True; return
        if data == b'\x1b[5~':                   # PgUp
            self._scroll_page(-5); self.dirty = True; return
        if data == b'\x1b[6~':                   # PgDn
            self._scroll_page(5); self.dirty = True; return
        if data in (b'\r', b'\n'):
            if self.focus == 'tree':
                flat = self._tree_flat()
                kind, payload = flat[self.tree_cursor]
                if kind == 'section':
                    # Toggle expand/collapse
                    self.section_expanded[payload] = not self.section_expanded.get(payload, True)
                    self.tree_cursor = min(self.tree_cursor, len(self._tree_flat()) - 1)
                else:
                    # Open mission
                    m = payload
                    new_idx = self.missions.index(m)
                    if new_idx != self.mission_idx:
                        self.mission_idx = new_idx
                        self.page_idx = 0
                        self.page_scroll = 0
                        self.flash(f'opened mission {m.num} · {m.name}')
                    self.focus = 'exercises'
                    self.last_nav_focus = 'exercises'
                self.dirty = True
            return

    def _cycle_focus(self, reverse):
        order = ['tree', 'exercises', 'terminal']
        i = order.index(self.focus)
        i = (i + (-1 if reverse else 1)) % len(order)
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
        if self.focus != 'exercises':
            return
        pages = self.missions[self.mission_idx].pages()
        self.page_idx = max(0, min(len(pages) - 1, self.page_idx + delta))
        self.page_scroll = 0

    def flash(self, msg, secs=2.5):
        self.message = msg
        self.message_until = time.time() + secs

    # ── Rendering ────────────────────────────────────────────────────────
    def _hbar(self, row, col, width, left_text, right_text='', panel_name=''):
        """Draw a full-width header bar with panel-specific accent color."""
        focused = self.focus == panel_name
        accent  = PANEL_COLORS.get(panel_name, C_TEXT)
        if focused:
            bg    = BG_SURF0
            style = BOLD + accent
        else:
            bg    = BG_MANTLE
            style = C_DIM
        left    = f' {left_text}'
        right   = f'{right_text} ' if right_text else ''
        gap     = max(1, width - len(left) - len(right))
        content = (left + ' ' * gap + right)[:width]
        goto(row, col)
        w(f'{bg}{style}{content}{RESET}')

    def render(self):
        hide_cursor()
        self._draw_borders()
        self._draw_missions()
        self._draw_exercises()
        self._draw_terminal()
        self._draw_status()
        self._position_cursor()
        flush()

    def _draw_borders(self):
        rows = self.term_rows
        cols = self.term_cols
        w(C_DIM)
        goto(1, 1); w(BX['tl'] + BX['h'] * (cols - 2) + BX['tr'])
        goto(rows - 1, 1); w(BX['bl'] + BX['h'] * (cols - 2) + BX['br'])
        for r in range(2, rows - 1):
            goto(r, 1);           w(BX['v'])
            goto(r, self.LEFT_W); w(BX['v'])
            goto(r, cols);        w(BX['v'])
        goto(self.mid_h, self.LEFT_W)
        w(BX['tl_split'] + BX['h'] * (cols - self.LEFT_W - 1) + BX['tr_split'])
        w(RESET)

    def _panel_clear(self, r1, c1, rows, cols):
        blank = ' ' * cols
        for r in range(rows):
            goto(r1 + r, c1)
            w(blank)

    def _tree_flat(self):
        """Flat list of (kind, payload) visible tree rows.

        kind = 'section' → payload = section name (str)
        kind = 'mission' → payload = Mission object
        """
        by_num = {m.num: m for m in self.missions}
        flat = []
        for sec_name, nums in SECTIONS:
            flat.append(('section', sec_name))
            if self.section_expanded.get(sec_name, True):
                for num in nums:
                    if num in by_num:
                        flat.append(('mission', by_num[num]))
        return flat

    def _mission_flat_idx(self, mission_idx):
        """Return the flat tree index that corresponds to missions[mission_idx]."""
        target = self.missions[mission_idx]
        for i, (kind, payload) in enumerate(self._tree_flat()):
            if kind == 'mission' and payload is target:
                return i
        # Mission not visible (section collapsed) — return 0
        return 0

    def _draw_missions(self):
        iw = self.LEFT_W - 2   # interior width (col 2 … LEFT_W-1)
        focused = self.focus == 'tree'

        # Aggregate progress for header right text
        done_cnt = sum(1 for m in self.missions
                       if self.mission_progress(m)[0] >= self.mission_progress(m)[1] > 0)
        right = f'{done_cnt}/{len(self.missions)}'
        self._hbar(2, 2, iw, 'MISSIONS', right, 'tree')

        blank = ' ' * iw
        max_visible = self.term_rows - 4   # rows 3 … term_rows-2

        flat = self._tree_flat()
        if self.tree_cursor < self.tree_scroll:
            self.tree_scroll = self.tree_cursor
        elif self.tree_cursor >= self.tree_scroll + max_visible:
            self.tree_scroll = self.tree_cursor - max_visible + 1

        # Layout widths for mission rows: ' IND CUR NN name.... MARK'
        # indent=2, cur=1, sp=1, num=2, sp=1, name, sp=1, mark=1 → name_w = iw-10
        name_w = max(4, iw - 10)

        for i in range(max_visible):
            row = 3 + i
            flat_idx = self.tree_scroll + i
            goto(row, 2); w(blank)
            if flat_idx >= len(flat):
                continue

            kind, payload = flat[flat_idx]
            is_cursor = (flat_idx == self.tree_cursor and focused)

            if kind == 'section':
                # ─── Section header row ──────────────────────────────────
                arrow = '▼' if self.section_expanded.get(payload, True) else '▶'
                if is_cursor:
                    style, rst = BOLD + C_MAUVE, RESET
                else:
                    style, rst = C_SUB, RESET
                label = payload[:iw - 3]
                goto(row, 2)
                w(f' {style}{arrow} {label}{rst}')

            else:
                # ─── Mission row (indented) ───────────────────────────────
                m = payload
                done, total = self.mission_progress(m)
                mark = (f'{C_GREEN}✓{RESET}' if total > 0 and done >= total else
                        f'{C_YELLOW}~{RESET}' if done > 0 else f'{C_DIM}·{RESET}')

                is_active = (m is self.missions[self.mission_idx])
                if is_cursor:
                    cur = f'{BOLD}{C_MAUVE}▶{RESET}'
                elif is_active:
                    cur = f'{C_GREEN}●{RESET}'
                else:
                    cur = ' '

                label = m.name[:name_w]
                if is_active:
                    ns, ne = BOLD + C_GREEN, RESET
                elif is_cursor:
                    ns, ne = C_MAUVE, RESET
                else:
                    ns, ne = C_SUB, RESET

                goto(row, 2)
                w(f'  {cur} {C_DIM}{m.num}{RESET} {ns}{label:<{name_w}}{ne} {mark}')

    def _draw_exercises(self):
        focused = self.focus == 'exercises'
        m   = self.missions[self.mission_idx]
        pages = m.pages()
        page  = pages[self.page_idx] if pages else None
        c1    = self.LEFT_W + 1           # column of left border
        iw    = self.term_cols - c1 - 1   # interior width

        # Header bar ─────────────────────────────────────────────────────
        pg_nav = ''
        if pages:
            pg_nav = f'◀ {self.page_idx + 1}/{len(pages)} ▶'
        self._hbar(2, c1 + 1, iw, f'EXERCISES  {m.num} · {m.name}', pg_nav, 'exercises')

        # Sub-header: progress bar or flash message (row 3) ─────────────────
        self._panel_clear(3, c1 + 1, 1, iw)
        if self.message and time.time() < self.message_until:
            goto(3, c1 + 2); w(f'{BOLD}{C_YELLOW}  {self.message}{RESET}')
        elif page is not None:
            done, total = self.page_progress(m.num, self.page_idx, page)
            if total > 0:
                bar_len  = min(20, iw - 14)
                filled   = int(round(bar_len * done / total))
                bar      = f'{C_GREEN}{"█" * filled}{C_DIM}{"░" * (bar_len - filled)}{RESET}'
                score_c  = C_GREEN if done == total else C_YELLOW
                progress = (f'  {bar}  {score_c}{done}/{total}{RESET}'
                            if done < total else f'{C_GREEN}  ✓  All done!{RESET}')
                goto(3, c1 + 2); w(progress)

        # Body ────────────────────────────────────────────────────────────
        body_first_row = 4
        body_max_rows  = max(1, self.mid_h - 4)
        max_w          = iw - 2
        self._panel_clear(body_first_row, c1 + 1, body_max_rows, iw)

        if page is None:
            return

        wrapped    = self._wrapped_page(self.mission_idx, self.page_idx, max_w)
        max_scroll = max(0, len(wrapped) - body_max_rows)
        if self.page_scroll > max_scroll:
            self.page_scroll = max_scroll

        for i, line in enumerate(wrapped[self.page_scroll:self.page_scroll + body_max_rows]):
            goto(body_first_row + i, c1 + 2)
            w(truncate_visible(line, max_w))

        # Scroll indicator
        if len(wrapped) > body_max_rows:
            indicator_col = c1 + iw
            ratio = self.page_scroll / max(1, max_scroll)
            knob  = body_first_row + int(ratio * (body_max_rows - 1))
            for r in range(body_first_row, body_first_row + body_max_rows):
                goto(r, indicator_col); w(f'{C_DIM}│{RESET}')
            goto(knob, indicator_col); w(f'{BOLD}{C_SAPPH}█{RESET}')

    def _wrapped_page(self, mi, pi, max_w):
        key = (mi, pi, max_w)
        if key in self._page_cache:
            return self._page_cache[key]
        page = self.missions[mi].pages()[pi]
        out = []
        # Add a banner with the title at the top
        out.append(f'{BOLD}{CYAN}{page.title}{RESET}')
        out.append('')
        for raw in page.lines:
            # Skip the title line we already used
            if raw.strip() == f'## {page.title}' or raw.strip() == f'# {page.title}':
                continue
            styled = style_md(raw)
            for seg in wrap_visible(styled, max_w):
                out.append(seg)
        # Append "Expected commands" footer with completion ticks
        if page.expected:
            out.append('')
            out.append(f'{DIM}{"─" * max_w}{RESET}')
            out.append(f'{BOLD}Expected commands:{RESET}')
            done_set = set()
            grade = self.grades.get(self.missions[mi].num, {}).get(f'page_{pi}', {})
            for c in grade.get('done', []):
                done_set.add(c)
            for exp in page.expected:
                # Check if any of the recorded done commands matches this expected
                hit = any(self._matches(d, exp) for d in done_set)
                tick = f'{C_GREEN}✓{RESET}' if hit else f'{C_DIM}○{RESET}'
                out.append(f'  {tick} {C_TEAL}{exp}{RESET}')
        self._page_cache[key] = out
        return out

    def _draw_terminal(self):
        c1 = self.LEFT_W + 1
        iw = self.term_cols - c1 - 1

        # Header bar drawn ON the horizontal divider row (mid_h) ─────────
        m    = self.missions[self.mission_idx]
        done, total = self.mission_progress(m)
        grade_str = f'grade {done}/{total}' if total else ''
        # Title changes to SHELL MODE when the user is actively in the shell
        title = 'SHELL MODE' if self.focus == 'terminal' else 'TERMINAL'
        self._hbar(self.mid_h, c1 + 1, iw, title, grade_str, 'terminal')

        # PTY content ─────────────────────────────────────────────────────
        self._panel_clear(self.tp_row, self.tp_col + 1, self.tp_rows, self.tp_cols)
        if self.screen is None:
            return
        for r in range(min(self.tp_rows, self.screen.lines)):
            self._draw_pyte_row(r)

    def _draw_pyte_row(self, r):
        line = self.screen.buffer[r]
        max_c = min(self.tp_cols, self.screen.columns)
        goto(self.tp_row + r, self.tp_col + 1)
        last_attrs = None
        chunks = []
        for c in range(max_c):
            ch = line[c]
            attrs = (ch.fg, ch.bg, ch.bold, ch.italics, ch.underscore, ch.reverse)
            if attrs != last_attrs:
                if chunks:
                    if last_attrs and last_attrs != ('default', 'default', False, False, False, False):
                        w(self._sgr(last_attrs))
                        w(''.join(chunks))
                        w(RESET)
                    else:
                        w(''.join(chunks))
                    chunks = []
                last_attrs = attrs
            chunks.append(ch.data if ch.data else ' ')
        if chunks:
            if last_attrs and last_attrs != ('default', 'default', False, False, False, False):
                w(self._sgr(last_attrs))
                w(''.join(chunks))
                w(RESET)
            else:
                w(''.join(chunks))

    @staticmethod
    def _sgr(attrs):
        fg, bg, bold, italic, underscore, reverse = attrs
        codes = []
        if bold: codes.append('1')
        if italic: codes.append('3')
        if underscore: codes.append('4')
        if reverse: codes.append('7')
        c = sgr_for_color(fg, False)
        if c: codes.append(c)
        c = sgr_for_color(bg, True)
        if c: codes.append(c)
        if not codes:
            return ''
        return f'\x1b[{";".join(codes)}m'

    def _draw_status(self):
        rows = self.term_rows
        cols = self.term_cols
        goto(rows, 1)
        w(f'{BG_STATUS}{" " * cols}{RESET}')
        goto(rows, 2)

        # ── Mode badge ───────────────────────────────────────────────────
        if self.focus == 'terminal':
            mode_label = 'SHELL MODE'
            mode_color = C_GREEN
        else:
            mode_label = 'NORMAL MODE'
            mode_color = C_MAUVE

        # ── Flash message or persistent hint bar ─────────────────────────
        if self.message and time.time() < self.message_until:
            hint_text = f'  {BOLD}{C_YELLOW}{self.message}{RESET}{BG_STATUS}'
        else:
            self.message = ''
            if self.focus == 'terminal':
                hint_text = (
                    f'{DIM}  Esc/Ctrl-X: leave shell'
                    f'  {C_DIM}|{RESET}{DIM}  Ctrl-Q: quit app'
                    f'  {C_DIM}|{RESET}{DIM}  exit: exit shell{RESET}'
                )
            else:
                hint_text = (
                    f'{DIM}  3/Ctrl-X: enter shell'
                    f'  {C_DIM}|{RESET}{DIM}  ←→ []: pages'
                    f'  {C_DIM}|{RESET}{DIM}  1/2: panels'
                    f'  {C_DIM}|{RESET}{DIM}  Ctrl-Q: quit{RESET}'
                )

        left  = f'{BG_STATUS}{BOLD}{mode_color} [{mode_label}]{RESET}{BG_STATUS}'
        w(f'{left}{hint_text}')

    def _position_cursor(self):
        if self.focus == 'terminal' and self.screen is not None:
            cy = self.screen.cursor.y
            cx = self.screen.cursor.x
            row = self.tp_row + cy
            col = self.tp_col + 1 + cx
            if row < self.term_rows - 1 and col < self.term_cols:
                goto(row, col)
                show_cursor()
        else:
            hide_cursor()

    # ── Main loop ────────────────────────────────────────────────────────
    def run(self):
        self.calculate_layout()
        self.start_shell()
        alt_screen_on(); clear_screen(); hide_cursor()

        stdin_fd = sys.stdin.fileno()
        old = termios.tcgetattr(stdin_fd)
        tty.setraw(stdin_fd)
        fl = fcntl.fcntl(stdin_fd, fcntl.F_GETFL)
        fcntl.fcntl(stdin_fd, fcntl.F_SETFL, fl | os.O_NONBLOCK)

        def on_resize(sig, frame):
            self.calculate_layout()
            self.resize_shell()
            self.dirty = True
        signal.signal(signal.SIGWINCH, on_resize)

        try:
            self.render()
            self.dirty = False
            last_render = 0.0
            last_hist_poll = 0.0
            while True:
                # Reap zombie shell + restart if it died
                try:
                    pid, _ = os.waitpid(self.shell_pid, os.WNOHANG)
                    if pid != 0:
                        try: os.close(self.master_fd)
                        except OSError: pass
                        self.start_shell()
                        self.flash('Shell session ended — new shell started')
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
                # Poll bash history every 200ms
                if now - last_hist_poll > 0.2:
                    self.poll_history()
                    last_hist_poll = now

                if (self.dirty and now - last_render > 0.03) or (
                        self.message and now < self.message_until and now - last_render > 0.1):
                    self.render()
                    self.dirty = False
                    last_render = now
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
        if self.focus == 'terminal':
            self.handle_input(data)
            return
        i = 0
        while i < len(data):
            b = data[i:i + 1]
            if b == b'\x1b' and i + 1 < len(data) and data[i + 1:i + 2] == b'[':
                j = i + 2
                while j < len(data) and not (0x40 <= data[j] <= 0x7e):
                    j += 1
                seq = data[i:j + 1]
                self.handle_input(seq)
                i = j + 1
            else:
                self.handle_input(b)
                i += 1


def main():
    p = argparse.ArgumentParser(description='Real 3-panel TUI for terminal-gym')
    p.add_argument('--missions-dir', default=None,
                   help='path to missions/ directory')
    p.add_argument('--start', default='01',
                   help='starting mission number (e.g. 01)')
    args = p.parse_args()

    missions_dir = args.missions_dir
    if not missions_dir:
        here = Path(__file__).resolve().parent
        missions_dir = here.parent / 'missions'

    missions = load_missions(missions_dir)
    if not missions:
        print(f'No missions found in {missions_dir}', file=sys.stderr)
        return 1

    Tui(missions, args.start).run()
    return 0


if __name__ == '__main__':
    sys.exit(main())
