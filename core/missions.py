"""core/missions.py — Mission data model and loader."""

import re
from pathlib import Path

PAGE_SEP_RE = re.compile(r'\n-{3,}\n')


class ExercisePage:
    """One '---'-separated chunk of exercises.md."""

    def __init__(self, raw_text):
        self.raw      = raw_text.strip()
        self.lines    = self.raw.splitlines()
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
        self.dir = Path(dir_path)
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
