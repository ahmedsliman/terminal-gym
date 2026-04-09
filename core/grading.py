"""core/grading.py — Grade storage and command matching."""

import json
from pathlib import Path

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


def matches(typed, expected):
    """Lenient match: case-insensitive substring or shared first token."""
    t = typed.strip().lower()
    e = expected.strip().lower()
    if not e:
        return False
    if e == t or e in t:
        return True
    et, tt = e.split(), t.split()
    return bool(et and tt and et[0] == tt[0])
