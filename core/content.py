"""core/content.py — ANSI color constants, markdown renderer, text utilities."""

import re

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

# ─── Text utilities ───────────────────────────────────────────────────────────
ANSI_RE = re.compile(r'\x1b\[[0-9;]*m')


def visible_len(s):
    """Character count ignoring ANSI escape sequences."""
    return len(ANSI_RE.sub('', s))


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


# ─── Markdown renderer ────────────────────────────────────────────────────────
def style_md(line):
    """Apply basic Markdown formatting to a single line."""
    s = line.rstrip()
    if not s:
        return ''
    # Code fence markers — hide them, keep the spacing
    if s.lstrip().startswith('```'):
        return ''
    # Horizontal rule — render as a dim line
    if s.strip() == '---':
        return f'{C_DIM}{"─" * len(s.rstrip())}{RESET}'
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
        s = ' ' * indent + f'{C_PEACH}•{RESET} {C_TEXT}' + rest + RESET
    out = re.sub(r'\*\*([^*]+)\*\*', f'{BOLD}{C_YELLOW}\\1{RESET}', s)
    out = re.sub(r'`([^`]+)`', f'{C_GREEN}\\1{RESET}', out)
    if out == s:           # no markdown matched — plain text
        out = f'{C_TEXT}{out}{RESET}'
    return out
