"""core/grading.py — Grade storage and command matching."""

import json
import re
from pathlib import Path

GRADES_PATH = Path.home() / '.terminal-gym' / 'grades.json'


def load_grades():
    if GRADES_PATH.exists():
        try:
            return json.loads(GRADES_PATH.read_text(encoding='utf-8', errors='replace'))
        except (json.JSONDecodeError, OSError):
            return {}
    return {}


def save_grades(grades):
    try:
        GRADES_PATH.parent.mkdir(parents=True, exist_ok=True)
        tmp = GRADES_PATH.parent / (GRADES_PATH.name + '.tmp')
        tmp.write_text(json.dumps(grades, indent=2, sort_keys=True))
        tmp.replace(GRADES_PATH)
    except OSError:
        pass


def matches(typed, expected):
    """Lenient match: case-insensitive, word-boundary substring or shared first token.

    Matches if:
    1. Exact case-insensitive match  ("ls -la" matches "ls")
    2. Expected is a word-boundary substring of typed  ("ls" matches "ls -la" but not "false")
    3. First token matches  ("ls" matches "ls /tmp", "cat" matches "cat file.txt")
    """
    t = typed.strip().lower()
    e = expected.strip().lower()
    if not e:
        return False
    if e == t:
        return True
    if re.search(r'\b' + re.escape(e) + r'\b', t):
        return True
    et, tt = e.split(), t.split()
    return bool(et and tt and et[0] == tt[0])
