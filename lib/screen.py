#!/usr/bin/env python3
"""
lib/screen.py — Minimal VT100 screen buffer (drop-in replacement for pyte).

Implements exactly what lib/tui.py uses from pyte:

  screen = ScreenBuffer(cols, rows)
  stream = ByteStream(screen)
  stream.feed(data: bytes)          # update screen from raw PTY output
  screen.resize(rows, cols)
  screen.lines                      # row count
  screen.columns                    # col count
  screen.cursor.x / .y
  screen.buffer[row][col]           # Cell with .data .fg .bg .bold .italics
                                    #             .underscore .reverse
"""

from collections import defaultdict
from dataclasses import dataclass


# Standard ANSI color index → name (matches NAMED_COLORS in tui.py)
_ANSI_FG = ['black', 'red', 'green', 'yellow', 'blue', 'magenta', 'cyan', 'white']

# Bright ANSI colors (indices 8-15)
_ANSI_BRIGHT = [
    'brightblack', 'brightred', 'brightgreen', 'brightyellow',
    'brightblue', 'brightmagenta', 'brightcyan', 'brightwhite',
]

def _color_256(n: int) -> str:
    """Convert a 256-color index to a hex color string."""
    if n < 8:
        return _ANSI_FG[n]
    if n < 16:
        return _ANSI_BRIGHT[n - 8]
    if n < 232:
        # 6×6×6 color cube: 16 + 36*r + 6*g + b
        n -= 16
        r, g, b = n // 36, (n % 36) // 6, n % 6
        # 0-5 → 0, 95, 135, 175, 215, 255
        levels = [0, 95, 135, 175, 215, 255]
        return f'{levels[r]:02x}{levels[g]:02x}{levels[b]:02x}'
    # 24-level grayscale: 232-255
    v = 8 + (n - 232) * 10
    return f'{v:02x}{v:02x}{v:02x}'


# ─── Data types ────────────────────────────────────────────────────────────────

@dataclass
class Cell:
    data:       str  = ' '
    fg:         str  = 'default'
    bg:         str  = 'default'
    bold:       bool = False
    italics:    bool = False
    underscore: bool = False
    reverse:    bool = False


class _Cursor:
    __slots__ = ('x', 'y')

    def __init__(self):
        self.x = 0
        self.y = 0


# ─── Screen buffer ─────────────────────────────────────────────────────────────

class ScreenBuffer:
    """
    Two-dimensional buffer of Cell objects.

    Rows and columns are both 0-indexed.
    Unwritten cells return a blank default Cell.
    """

    def __init__(self, cols: int, rows: int):
        self.columns: int  = max(1, cols)
        self.lines:   int  = max(1, rows)
        self.cursor         = _Cursor()
        self.buffer         = defaultdict(lambda: defaultdict(Cell))
        self.scroll_top:    int = 0        # DECSTBM top (inclusive)
        self.scroll_bottom: int = rows - 1  # DECSTBM bottom (inclusive)
        self.autowrap:      bool = True    # DECAWM: wrap at right margin
        self.using_alt_buf: bool = False   # alternate screen active
        self._saved_buf     = None         # saved main buffer
        self._saved_cursor  = None         # saved cursor for alt screen swap
        self._saved_scroll  = None         # saved scroll region for alt screen swap

    def resize(self, rows: int, cols: int):
        self.columns    = max(1, cols)
        self.lines      = max(1, rows)
        self.cursor.x   = min(self.cursor.x, self.columns - 1)
        self.cursor.y   = min(self.cursor.y, self.lines   - 1)
        self.scroll_top    = 0
        self.scroll_bottom  = self.lines - 1


# ─── Byte stream parser ────────────────────────────────────────────────────────

class ByteStream:
    """
    Consume raw PTY bytes and update a ScreenBuffer.

    Handles the subset of VT100/VT220/xterm sequences used by common terminal
    programs (bash, vim, htop, less, man, git).
    """

    # Parser states
    _NORMAL = 0
    _ESC    = 1
    _CSI    = 2
    _OSC    = 3
    _SS2    = 4   # single-shift 2 — consume one char
    _SS3    = 5   # single-shift 3 — consume one char

    def __init__(self, screen: ScreenBuffer):
        self._scr   = screen
        self._state = self._NORMAL
        self._buf:  list = []   # accumulate CSI / OSC parameter bytes
        # Current SGR attributes
        self._fg  = 'default'
        self._bg  = 'default'
        self._bold  = False
        self._ital  = False
        self._und   = False
        self._rev   = False
        # Saved cursor (ESC 7 / CSI s)
        self._saved_x = 0
        self._saved_y = 0

    # ── Public API ────────────────────────────────────────────────────────

    def feed(self, data: bytes):
        scr = self._scr
        i = 0
        n = len(data)
        while i < n:
            byte = data[i]
            i   += 1

            if self._state == self._NORMAL:
                if byte == 0x1b:                    # ESC
                    self._state = self._ESC
                elif byte == 0x0d:                  # CR
                    scr.cursor.x = 0
                elif byte in (0x0a, 0x0b, 0x0c):   # LF / VT / FF
                    self._lf()
                elif byte == 0x08:                  # BS
                    scr.cursor.x = max(0, scr.cursor.x - 1)
                elif byte == 0x09:                  # HT — advance to next 8-col tab stop
                    scr.cursor.x = min(scr.columns - 1,
                                       (scr.cursor.x // 8 + 1) * 8)
                elif byte == 0x07:                  # BEL — ignore
                    pass
                elif 0x20 <= byte <= 0x7e or byte >= 0xa0:
                    self._write(chr(byte))
                # other C0/C1 — ignore

            elif self._state == self._ESC:
                if   byte == 0x5b:                  # '[' → CSI
                    self._buf   = []
                    self._state = self._CSI
                elif byte == 0x5d:                  # ']' → OSC
                    self._buf   = []
                    self._state = self._OSC
                elif byte == 0x4e:                  # 'N' → SS2
                    self._state = self._SS2
                elif byte == 0x4f:                  # 'O' → SS3 (used for Fkeys/arrows)
                    self._state = self._SS3
                elif byte == 0x37:                  # '7' — save cursor
                    self._saved_x = scr.cursor.x
                    self._saved_y = scr.cursor.y
                    self._state   = self._NORMAL
                elif byte == 0x38:                  # '8' — restore cursor
                    scr.cursor.x  = self._saved_x
                    scr.cursor.y  = self._saved_y
                    self._state   = self._NORMAL
                elif byte == 0x44:                  # 'D' — IND (line feed)
                    self._lf()
                    self._state = self._NORMAL
                elif byte == 0x4d:                  # 'M' — RI (reverse index)
                    if scr.cursor.y == scr.scroll_top:
                        self._scroll_down()
                    else:
                        scr.cursor.y = max(0, scr.cursor.y - 1)
                    self._state  = self._NORMAL
                elif byte == 0x63:                  # 'c' — RIS full reset
                    self._hard_reset()
                elif byte == 0x28 or byte == 0x29:  # '(' / ')' — charset designate, consume next
                    self._state = self._NORMAL      # we ignore the charset byte
                    if i < n: i += 1                # consume the charset indicator byte
                else:
                    self._state = self._NORMAL      # unknown two-char sequence

            elif self._state == self._CSI:
                if 0x40 <= byte <= 0x7e:            # final byte
                    self._csi_dispatch(bytes(self._buf), byte)
                    self._state = self._NORMAL
                else:
                    self._buf.append(byte)

            elif self._state == self._OSC:
                # OSC terminated by BEL (0x07), ST (0x9c), or ESC \
                if byte == 0x07 or byte == 0x9c:
                    self._state = self._NORMAL
                elif byte == 0x1b:
                    self._state = self._ESC         # may be ESC \ (ST)
                # else: accumulate and ignore

            elif self._state in (self._SS2, self._SS3):
                # consume one character and discard
                self._state = self._NORMAL

    # ── Low-level helpers ─────────────────────────────────────────────────

    def _write(self, ch: str):
        scr = self._scr
        cx, cy = scr.cursor.x, scr.cursor.y

        # DECAWM: wrap at right margin only when enabled
        if cx >= scr.columns:
            if scr.autowrap:
                cx = 0
                cy += 1
            else:
                cx = scr.columns - 1

        # Scroll when past bottom of scroll region
        if cy > scr.scroll_bottom:
            cy = scr.scroll_bottom
            self._scroll_up()
        elif cy < 0:
            cy = 0

        scr.buffer[cy][cx] = Cell(
            data       = ch,
            fg         = self._fg,
            bg         = self._bg,
            bold       = self._bold,
            italics    = self._ital,
            underscore = self._und,
            reverse    = self._rev,
        )
        scr.cursor.x = cx + 1
        scr.cursor.y = cy

    def _lf(self):
        scr = self._scr
        if scr.cursor.y == scr.scroll_bottom:
            self._scroll_up()
        elif scr.cursor.y < scr.lines - 1:
            scr.cursor.y += 1

    def _scroll_up(self):
        """Scroll the scroll region up one line (content moves up, top line lost)."""
        scr     = self._scr
        top     = scr.scroll_top
        bottom  = scr.scroll_bottom
        new_buf = defaultdict(lambda: defaultdict(Cell))
        for r, row in scr.buffer.items():
            if r < top or r > bottom:
                new_buf[r] = row          # outside region: pass through
            elif r > top:
                new_buf[r - 1] = row      # shift up within region
            # row == top: discarded by the scroll
        scr.buffer.clear()
        scr.buffer.update(new_buf)

    def _scroll_down(self):
        """Scroll the scroll region down one line (content moves down, bottom line lost)."""
        scr     = self._scr
        top     = scr.scroll_top
        bottom  = scr.scroll_bottom
        new_buf = defaultdict(lambda: defaultdict(Cell))
        for r, row in scr.buffer.items():
            if r < top or r > bottom:
                new_buf[r] = row          # outside region: pass through
            elif r < bottom:
                new_buf[r + 1] = row      # shift down within region
            # row == bottom: discarded by the scroll
        scr.buffer.clear()
        scr.buffer.update(new_buf)

    def _hard_reset(self):
        scr = self._scr
        if scr.using_alt_buf:
            self._switch_from_alt_screen()
        scr.buffer.clear()
        scr.cursor.x = scr.cursor.y = 0
        scr.scroll_top = 0
        scr.scroll_bottom = scr.lines - 1
        scr.autowrap = True
        self._reset_attrs()
        self._state = self._NORMAL

    def _switch_to_alt_screen(self):
        scr = self._scr
        if scr.using_alt_buf:
            return
        scr._saved_buf = scr.buffer
        scr._saved_cursor = (scr.cursor.x, scr.cursor.y)
        scr._saved_scroll = (scr.scroll_top, scr.scroll_bottom)
        scr.buffer = defaultdict(lambda: defaultdict(Cell))
        scr.cursor.x = scr.cursor.y = 0
        scr.scroll_top = 0
        scr.scroll_bottom = scr.lines - 1
        scr.using_alt_buf = True
        self._reset_attrs()

    def _switch_from_alt_screen(self):
        scr = self._scr
        if not scr.using_alt_buf:
            return
        scr.buffer = scr._saved_buf if scr._saved_buf is not None else defaultdict(lambda: defaultdict(Cell))
        scr.cursor.x, scr.cursor.y = scr._saved_cursor if scr._saved_cursor is not None else (0, 0)
        scr.scroll_top, scr.scroll_bottom = scr._saved_scroll if scr._saved_scroll is not None else (0, scr.lines - 1)
        scr._saved_buf = None
        scr._saved_cursor = None
        scr._saved_scroll = None
        scr.using_alt_buf = False
        self._reset_attrs()

    def _reset_attrs(self):
        self._fg   = 'default'
        self._bg   = 'default'
        self._bold = False
        self._ital = False
        self._und  = False
        self._rev  = False

    # ── CSI dispatcher ────────────────────────────────────────────────────

    def _csi_dispatch(self, params: bytes, final: int):
        scr = self._scr
        ps  = params.decode('ascii', errors='ignore')

        # Strip private-mode marker '?' (or '>' or '!')
        private = ps[:1] in ('?', '>', '!')
        if private:
            ps = ps[1:]

        def p1(default: int = 1) -> int:
            """First parameter, falling back to default."""
            parts = ps.split(';')
            try:
                return int(parts[0]) if parts[0] else default
            except (ValueError, IndexError):
                return default

        def ints(default: int = 0) -> list:
            """All parameters as a list of ints."""
            parts = ps.split(';') if ps else ['']
            out = []
            for x in parts:
                try:
                    out.append(int(x) if x else default)
                except ValueError:
                    out.append(default)
            return out

        f = chr(final)

        if f == 'm':                        # SGR
            self._sgr(ints(0))

        elif f in ('H', 'f'):              # CUP / HVP — cursor position
            v   = ints(1)
            row = max(1, v[0] if v else 1) - 1
            col = max(1, v[1] if len(v) > 1 else 1) - 1
            scr.cursor.y = min(scr.lines   - 1, row)
            scr.cursor.x = min(scr.columns - 1, col)

        elif f == 'A':                      # CUU — cursor up
            scr.cursor.y = max(0, scr.cursor.y - p1())

        elif f in ('B', 'e'):              # CUD — cursor down
            scr.cursor.y = min(scr.lines - 1, scr.cursor.y + p1())

        elif f in ('C', 'a'):              # CUF — cursor right
            scr.cursor.x = min(scr.columns - 1, scr.cursor.x + p1())

        elif f == 'D':                      # CUB — cursor left
            scr.cursor.x = max(0, scr.cursor.x - p1())

        elif f == 'E':                      # CNL — cursor next line
            scr.cursor.y = min(scr.lines - 1, scr.cursor.y + p1())
            scr.cursor.x = 0

        elif f == 'F':                      # CPL — cursor previous line
            scr.cursor.y = max(0, scr.cursor.y - p1())
            scr.cursor.x = 0

        elif f in ('G', '`'):              # CHA — cursor column absolute
            scr.cursor.x = max(0, min(scr.columns - 1, p1(1) - 1))

        elif f == 'd':                      # VPA — cursor row absolute
            scr.cursor.y = max(0, min(scr.lines - 1, p1(1) - 1))

        elif f == 'J':                      # ED — erase display
            v = p1(0)
            if v in (2, 3):
                scr.buffer.clear()
                scr.cursor.x = scr.cursor.y = 0
            elif v == 0:                    # cursor to end
                for r in list(scr.buffer.keys()):
                    if r > scr.cursor.y:
                        del scr.buffer[r]
                row = scr.buffer.get(scr.cursor.y)
                if row:
                    for c in [k for k in row if k >= scr.cursor.x]:
                        del row[c]
            elif v == 1:                    # start to cursor
                for r in list(scr.buffer.keys()):
                    if r < scr.cursor.y:
                        del scr.buffer[r]
                row = scr.buffer.get(scr.cursor.y)
                if row:
                    for c in [k for k in row if k <= scr.cursor.x]:
                        del row[c]

        elif f == 'K':                      # EL — erase line
            v   = p1(0)
            row = scr.buffer.get(scr.cursor.y)
            if row is None:
                return
            if v == 0:   # cursor to end
                for c in [k for k in row if k >= scr.cursor.x]: del row[c]
            elif v == 1: # start to cursor
                for c in [k for k in row if k <= scr.cursor.x]: del row[c]
            elif v == 2: # entire line
                if scr.cursor.y in scr.buffer: del scr.buffer[scr.cursor.y]

        elif f == 'L':                      # IL — insert lines within scroll region
            count   = p1()
            top     = scr.cursor.y
            bottom  = scr.scroll_bottom
            new_buf = defaultdict(lambda: defaultdict(Cell))
            for r, row in scr.buffer.items():
                if r < top or r > bottom:
                    new_buf[r] = row
                elif r + count <= bottom:
                    new_buf[r + count] = row
            scr.buffer.clear()
            scr.buffer.update(new_buf)

        elif f == 'M':                      # DL — delete lines within scroll region
            count   = p1()
            top     = scr.cursor.y
            bottom  = scr.scroll_bottom
            new_buf = defaultdict(lambda: defaultdict(Cell))
            for r, row in scr.buffer.items():
                if r < top or r > bottom:
                    new_buf[r] = row
                elif r >= top + count:
                    new_buf[r - count] = row
            scr.buffer.clear()
            scr.buffer.update(new_buf)

        elif f == 'P':                      # DCH — delete characters
            count = p1()
            cx    = scr.cursor.x
            row   = scr.buffer.get(scr.cursor.y)
            if row:
                new_row: dict = defaultdict(Cell)
                for c, cell in row.items():
                    if c < cx:
                        new_row[c] = cell
                    elif c >= cx + count:
                        new_row[c - count] = cell
                scr.buffer[scr.cursor.y] = new_row

        elif f == '@':                      # ICH — insert characters (shift right)
            count = p1()
            cx    = scr.cursor.x
            row   = scr.buffer.get(scr.cursor.y)
            if row:
                new_row: dict = defaultdict(Cell)
                for c, cell in row.items():
                    if c < cx:
                        new_row[c] = cell
                    elif c + count < scr.columns:
                        new_row[c + count] = cell
                scr.buffer[scr.cursor.y] = new_row

        elif f == 'S':                      # SU — scroll up N lines
            for _ in range(p1()):
                self._scroll_up()

        elif f == 'T':                      # SD — scroll down N lines within scroll region
            count = p1()
            for _ in range(count):
                self._scroll_down()

        elif f == 's':                      # SCP — save cursor
            self._saved_x = scr.cursor.x
            self._saved_y = scr.cursor.y

        elif f == 'u':                      # RCP — restore cursor
            scr.cursor.x = self._saved_x
            scr.cursor.y = self._saved_y

        elif f == 'r':                      # DECSTBM — set scrolling region
            if private:
                return                      # ?r is not standard
            v = ints(0)
            top = (v[0] if v and v[0] else 1) - 1
            bottom = (v[1] if len(v) > 1 and v[1] else scr.lines) - 1
            if top < 0: top = 0
            if bottom >= scr.lines: bottom = scr.lines - 1
            if top < bottom:
                scr.scroll_top = top
                scr.scroll_bottom = bottom
            scr.cursor.x = 0
            scr.cursor.y = 0

        elif f == 'h' and private:          # DECSET — set mode
            v = ints()
            for mode in v:
                if mode == 7:               # DECAWM — auto-wrap mode
                    scr.autowrap = True
                elif mode == 1049:         # Switch to alternate screen buffer
                    self._switch_to_alt_screen()
                # modes 1, 3, 4, 5, 6, 12, 25, 40, etc. — ignored

        elif f == 'l' and private:          # DECRST — reset mode
            v = ints()
            for mode in v:
                if mode == 7:               # DECAWM — auto-wrap off
                    scr.autowrap = False
                elif mode == 1049:         # Switch back to main screen buffer
                    self._switch_from_alt_screen()

        elif f in ('h', 'l') and not private:
            # Non-private mode set/reset — ignored (line wrap, etc.)
            pass

        elif f in ('c', 'n', 'q', 'x', 'y', 'z', '{', '}', '~'):
            pass    # other sequences — ignored

    # ── SGR attribute parser ──────────────────────────────────────────────

    def _sgr(self, params: list):
        if not params:
            self._reset_attrs()
            return
        i = 0
        while i < len(params):
            p = params[i]
            if   p == 0:                    self._reset_attrs()
            elif p == 1:                    self._bold = True
            elif p == 2:                    pass        # faint
            elif p == 3:                    self._ital = True
            elif p == 4:                    self._und  = True
            elif p in (5, 6):               pass        # blink
            elif p == 7:                    self._rev  = True
            elif p == 8:                    pass        # conceal
            elif p == 22:                   self._bold = False
            elif p == 23:                   self._ital = False
            elif p == 24:                   self._und  = False
            elif p == 25:                   pass        # blink off
            elif p == 27:                   self._rev  = False
            elif p == 28:                   pass        # reveal
            elif 30 <= p <= 37:             self._fg = _ANSI_FG[p - 30]
            elif p == 38:
                i, color = self._parse_extended_color(params, i)
                if color: self._fg = color
            elif p == 39:                   self._fg = 'default'
            elif 40 <= p <= 47:             self._bg = _ANSI_FG[p - 40]
            elif p == 48:
                i, color = self._parse_extended_color(params, i)
                if color: self._bg = color
            elif p == 49:                   self._bg = 'default'
            elif 90 <= p <= 97:             self._fg = _ANSI_BRIGHT[p - 90]
            elif 100 <= p <= 107:           self._bg = _ANSI_BRIGHT[p - 100]
            i += 1

    @staticmethod
    def _parse_extended_color(params: list, i: int):
        """
        Parse 38;2;r;g;b (true-color) or 38;5;n (256-color) starting at index i.
        Returns (new_i, color_string) where color_string is a 6-char hex or named color.
        """
        if i + 1 >= len(params):
            return i, None
        kind = params[i + 1]
        if kind == 2 and i + 4 < len(params):     # true-color
            r, g, b = params[i+2], params[i+3], params[i+4]
            return i + 4, f'{r:02x}{g:02x}{b:02x}'
        if kind == 5 and i + 2 < len(params):     # 256-color
            n = params[i + 2]
            color = _color_256(n)
            return i + 2, color
        return i, None
