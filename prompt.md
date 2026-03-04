# prompt.md — How to Build an Interactive CLI Course

Use this as a starting point when creating a new terminal-based interactive course from any source material (notes, a book, a video series, etc.).

---

## The Prompt

> I have [source material — notes / book / video series] about **[topic]**.
> Build a terminal-driven interactive course from it with the following structure:
>
> - A `Makefile` as the navigation engine (`make start`, `make practice N=XX`, `make status`, etc.)
> - One directory per mission under `missions/`, each with `README.md`, `exercises.md`, `solution.md`, and `practice.sh`
> - A shared `lib/course.sh` library that handles: step rendering, demo/try/checkpoint functions, save/resume state, and an in-session command system (`hint`, `skip`, `goto`, `restart`, `quit`)
> - A `projects/` directory for larger hands-on tasks that combine multiple skills
> - A `lab/` sandbox directory for free experimentation
> - A `progress.md` file to log completed missions with timestamps
> - A `.gitignore` that excludes session state, source material, and editor noise
>
> Each `practice.sh` must:
> - Set `_PRACTICE_PATH="${BASH_SOURCE[0]}"` before sourcing `lib/course.sh` (enables restart/goto)
> - Call `set_hint "..."` after each `step()` so the `hint` command is useful
> - Use `set -uo pipefail` (not `-e`) so user command failures don't kill the session
>
> Split the source material into **N missions**, one topic per mission. Write mission 01 and 02 in full. Stub the rest with a "coming soon" message.

---

## Structure to Generate

```
course-name/
├── Makefile
├── README.md
├── progress.md
├── .gitignore
├── lib/
│   └── course.sh          # shared library — copy from terminal-gym
├── missions/
│   ├── 01-topic-name/
│   │   ├── README.md      # concept brief + learning goals
│   │   ├── exercises.md   # step-by-step tasks with hints and self-checks
│   │   ├── solution.md    # reference answers
│   │   └── practice.sh   # interactive session
│   └── NN-.../ (repeat)
├── projects/
│   └── p1-name/
│       └── README.md
└── lab/
    └── .gitkeep
```

---

## lib/course.sh — Public API

| Function | Purpose |
|----------|---------|
| `init_mission "01" "Title" N` | Start a mission, load saved state |
| `step "title"` | New step — clears screen, draws progress dots |
| `set_hint "text"` | Set hint text for the current step |
| `explain "text"` | Show a concept explanation |
| `demo 'cmd' "label"` | Run a command, show output, pause |
| `show 'cmd' "label"` | Run a command, show output, no pause |
| `try "prompt" "hint"` | Let user type and run any command |
| `try_match "prompt" "hint" "expected"` | Like try, but validates output contains expected string |
| `checkpoint "question" "answer"` | Think pause, then reveal answer |
| `tip / note / warn "text"` | Inline callout |
| `section "title"` | Lightweight sub-heading within a step |
| `mission_complete` | Clear state, show completion screen |

---

## In-Session Commands (built into lib/course.sh)

Available at every prompt during a practice session:

| Command | Action |
|---------|--------|
| `?` / `help` | Show command reference |
| `hint` | Show hint for current step |
| `status` | Progress bar + error count |
| `skip` | Skip the current exercise |
| `restart` | Repeat the current step |
| `goto N` | Jump to step N |
| `q` / `quit` / `exit` | Save position and exit |

---

## Principles

**One concept per step.** Each `step()` should teach exactly one thing. If you find yourself writing two `explain` blocks before a `try`, split it into two steps.

**Show before ask.** Use `demo` or `show` to demonstrate a command before asking the user to run it themselves with `try`. Never ask someone to do something they haven't seen first.

**Fail safely.** Use `set -uo pipefail`, not `set -euo pipefail`. Users will type wrong commands — that is the point. The session should survive and show the error, not crash.

**Always set a hint.** Call `set_hint` on every step. A blank hint is a broken experience when someone types `hint` and gets nothing.

**Keep screens clean.** Each `demo`, `show`, and `try` clears the screen before rendering. One command, one screen. Never let output stack from previous steps.

**Save state on every step.** `step()` calls `_save_state` automatically. Users can quit at any time and resume exactly where they left off.

**Stub first, fill later.** Write mission 01 and 02 in full. Give missions 03–N a single-step "coming soon" stub. A working skeleton is more useful than a perfect but incomplete course.

**The Makefile is the interface.** All navigation — starting, jumping, reviewing, marking done — happens through `make`. Users should never need to run scripts directly.

---

## Reusing lib/course.sh

`lib/course.sh` is self-contained and reusable across courses. Copy it into any new project. No external dependencies — pure bash.

The only requirement: each `practice.sh` must set `_PRACTICE_PATH` before sourcing:

```bash
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"
```
