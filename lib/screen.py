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

    def resize(self, rows: int, cols: int):
        self.columns    = max(1, cols)
        self.lines      = max(1, rows)
        self.cursor.x   = min(self.cursor.x, self.columns - 1)
        self.cursor.y   = min(self.cursor.y, self.lines   - 1)


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

        # Auto-wrap at right margin
        if cx >= scr.columns:
            cx = 0
            cy += 1

        # Scroll when past bottom
        if cy >= scr.lines:
            cy = scr.lines - 1
            self._scroll_up()

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
        if scr.cursor.y >= scr.lines - 1:
            self._scroll_up()
        else:
            scr.cursor.y += 1

    def _scroll_up(self):
        """Scroll the entire buffer up one line, discarding row 0."""
        scr     = self._scr
        new_buf = defaultdict(lambda: defaultdict(Cell))
        for r in range(1, scr.lines):
            if r in scr.buffer:
                new_buf[r - 1] = scr.buffer[r]
        scr.buffer.clear()
        scr.buffer.update(new_buf)

    def _hard_reset(self):
        scr = self._scr
        scr.buffer.clear()
        scr.cursor.x = scr.cursor.y = 0
        self._reset_attrs()
        self._state = self._NORMAL

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

        elif f == 'L':                      # IL — insert lines
            count   = p1()
            new_buf = defaultdict(lambda: defaultdict(Cell))
            cy      = scr.cursor.y
            for r, row in scr.buffer.items():
                if r < cy:
                    new_buf[r] = row
                elif r + count < scr.lines:
                    new_buf[r + count] = row
            scr.buffer.clear()
            scr.buffer.update(new_buf)

        elif f == 'M':                      # DL — delete lines
            count   = p1()
            new_buf = defaultdict(lambda: defaultdict(Cell))
            cy      = scr.cursor.y
            for r, row in scr.buffer.items():
                if r < cy:
                    new_buf[r] = row
                elif r >= cy + count:
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

        elif f == 'T':                      # SD — scroll down N lines (reverse scroll)
            count   = p1()
            new_buf = defaultdict(lambda: defaultdict(Cell))
            for r, row in scr.buffer.items():
                if r + count < scr.lines:
                    new_buf[r + count] = row
            scr.buffer.clear()
            scr.buffer.update(new_buf)

        elif f == 's':                      # SCP — save cursor
            self._saved_x = scr.cursor.x
            self._saved_y = scr.cursor.y

        elif f == 'u':                      # RCP — restore cursor
            scr.cursor.x = self._saved_x
            scr.cursor.y = self._saved_y

        elif f in ('h', 'l', 'r', 'c', 'n', 'q', 'x', 'y', 'z', '{', '}', '~'):
            pass    # mode set/reset and other sequences — ignored

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
            elif 90 <= p <= 97:             self._fg = _ANSI_FG[p - 90]   # bright → same name
            elif 100 <= p <= 107:           self._bg = _ANSI_FG[p - 100]
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
            color = _ANSI_FG[n % 8] if n < 8 else 'default'
            return i + 2, color
        return i, None
