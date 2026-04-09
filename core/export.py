"""core/export.py — Export missions to JSON for the web frontend."""

import json
import sys
from pathlib import Path

from .missions import load_missions

SECTIONS = [
    ("Foundations",  ["01", "02", "03", "04"]),
    ("Shell Power",  ["05", "06", "07"]),
    ("Filesystem",   ["08", "09", "10", "11"]),
    ("System",       ["12", "13", "14"]),
    ("Advanced",     ["15", "16", "17", "18", "19"]),
]


def export_content(missions_dir):
    """Build a JSON-serialisable dict of all missions and their exercises."""
    missions = load_missions(missions_dir)

    section_for = {}
    for name, nums in SECTIONS:
        for num in nums:
            section_for[num] = name

    return {
        "sections": [
            {"name": name, "missions": nums}
            for name, nums in SECTIONS
        ],
        "missions": [
            {
                "num": m.num,
                "name": m.name,
                "section": section_for.get(m.num, "Other"),
                "pages": [
                    {
                        "title": p.title,
                        "lines": p.lines,
                        "expected": p.expected,
                    }
                    for p in m.pages()
                ],
            }
            for m in missions
        ],
    }


def export_json(missions_dir, output_path=None):
    content = export_content(missions_dir)
    text = json.dumps(content, indent=2, ensure_ascii=False)
    if output_path:
        Path(output_path).write_text(text)
    return text


if __name__ == "__main__":
    missions_dir = sys.argv[1] if len(sys.argv) > 1 else "missions"
    output = sys.argv[2] if len(sys.argv) > 2 else None
    result = export_json(missions_dir, output)
    if not output:
        print(result)
