# terminal-gym — Specification

> Learn Linux by doing — hands-on missions in a 3-panel terminal UI.

## Overview

terminal-gym is a self-contained Linux training environment that runs entirely in the user's terminal. It presents a 3-panel TUI with a missions tree, paginated exercises, and an embedded live bash shell. No browser, cloud, or account required — `git clone && make start`.

---

## Architecture

```
terminal-gym/
├── Makefile                 # CLI entry point (start, status, next, done, etc.)
├── requirements.txt         # pyte>=0.8.0 (fallback), aiohttp>=3.9.0 (web)
├── Dockerfile               # Docker deployment (python:3.12-slim)
├── fly.toml                 # Fly.io deployment config
├── render.yaml              # Render.com deployment config
├── progress.md              # DONE:NN timestamps (user progress log)
│
├── core/                    # Shared logic (extracted from lib/tui.py)
│   ├── missions.py          # ExercisePage, Mission, load_missions()
│   ├── grading.py           # load_grades(), save_grades(), matches()
│   ├── content.py           # ANSI colors, style_md(), wrap_visible(), Catppuccin palette
│   └── export.py            # Export missions to JSON for web frontend
│
├── lib/
│   ├── tui.py               # 3-panel TUI — PTY fork, VT100 rendering, input loop (~1160 lines)
│   ├── screen.py            # Minimal VT100 ScreenBuffer (replaces pyte dep, ~472 lines)
│   └── course.sh            # Legacy bash TUI (no longer primary interface)
│
├── web/                     # Web interface (MVP)
│   ├── server.py            # aiohttp: WebSocket PTY bridge + content API
│   └── static/
│       ├── index.html        # 3-panel HTML layout
│       ├── app.js            # Frontend: missions tree, exercises, xterm.js terminal
│       └── style.css         # Catppuccin Mocha themed styles
│
├── missions/                 # 19 mission directories (NN-name/)
│   └── NN-name/
│       ├── README.md         # Concept brief (learning goals, key commands)
│       ├── exercises.md      # Paginated hands-on exercises (--- separator)
│       ├── solution.md       # Worked solutions
│       └── practice.sh       # Interactive bash session (uses course.sh API)
│
├── projects/                 # 4 synthesis projects (pN-name/)
│   └── pN-name/README.md    # Project briefs with tasks and self-checks
│
├── lab/                      # Learner sandbox (safe to modify)
├── docs/                     # GitHub Pages landing site
└── .state/                   # Per-mission state files
```

### Tech Stack

| Layer | Technology |
|---|---|
| Core language | Python 3.13 |
| TUI rendering | Raw ANSI escape codes (no curses dependency) |
| Terminal emulation | Custom `ScreenBuffer` (lib/screen.py) — default; `pyte` — fallback |
| PTY management | `pty.openpty()` + `os.fork()` — forks `/bin/bash --norc -i` |
| Web backend | aiohttp (WebSocket PTY bridge + content JSON API) |
| Web frontend | Vanilla JS + xterm.js 5.5.0 + FitAddon + WebLinksAddon |
| Content format | Markdown with `---` page separators, `**Hint:**` for command extraction |
| Grading | HISTFILE polling every 200ms, lenient match (case-insensitive substring or first-token) |
| Progress | `progress.md` (CLI) + `~/.terminal-gym/grades.json` (TUI/web) |
| Color palette | Catppuccin Mocha (shared between TUI and web) |
| Deployment | Docker, Fly.io, Render.com |

### Data Flow

```
User Input
    │
    ├── NORMAL MODE → Tui._dispatch_input() → panel navigation
    │                                        → exercise pagination
    │                                        → section collapse/expand
    │
    └── SHELL MODE → pty.write(bytes) → bash PTY
                                         │
                                         ▼
                                    bash output → ByteStream → ScreenBuffer
                                                                  │
                                                                  ▼
                                                        _draw_terminal() → ANSI panel


Grading Flow:
    bash → HISTFILE → poll_history() (every 200ms)
                     → evaluate_command() → matches(typed, expected)
                                          → save_grades() → ~/.terminal-gym/grades.json
```

---

## Core Components

### core/missions.py

- `ExercisePage` — parses one `---`-separated chunk from `exercises.md`
  - `.title` — first `## ` or `# ` heading, defaults to "Intro"
  - `.expected` — list of commands extracted from `**Hint:** backticked` lines
  - `.raw`, `.lines` — original text and split lines
- `Mission` — wraps a `missions/NN-name/` directory
  - `.num` — mission number (e.g., "06")
  - `.name` — human-readable name (e.g., "Pipes Redirection")
  - `.pages()` — lazily loads and caches `ExercisePage` list
- `load_missions(missions_dir)` — returns sorted list of `Mission` objects

### core/grading.py

- `load_grades()` — reads `~/.terminal-gym/grades.json`, returns dict or `{}`
- `save_grades(grades)` — atomic write (tmp + rename) to grades.json
- `matches(typed, expected)` — lenient matching:
  - Exact case-insensitive match
  - Substring match (`expected in typed`, case-insensitive)
  - First-token match (first word matches)

### core/content.py

- Catppuccin Mocha color constants (24-bit ANSI)
- `style_md(line)` — inline markdown renderer: `#` headings, `**bold**`, `` `code` ``, lists, `---` rules
- `visible_len(s)` — character count excluding ANSI escape sequences
- `wrap_visible(s, max_w)` — word-wrap respecting ANSI sequences
- `truncate_visible(s, max_w)` — truncate with `…` respecting ANSI sequences

### core/export.py

- `SECTIONS` — defines the 5 section groupings and their mission numbers
- `export_content(missions_dir)` — builds JSON-serialisable dict of all missions/pages
- `export_json(missions_dir, output_path)` — dumps to file or stdout

### lib/tui.py (~1160 lines)

The main TUI application. Key design:

- **Two modes**: NORMAL (navigate panels) and SHELL (type into PTY)
- **Rendering pipeline**: `_draw_borders()` → `_draw_missions()` → `_draw_exercises()` → `_draw_terminal()` → `_draw_status()`
- **PTY lifecycle**: fork bash on startup, respawn on exit, stream output through `ScreenBuffer`
- **Input handling**: `Ctrl-X`/`Esc` to enter NORMAL mode, any other key in SHELL mode goes to PTY
- **Grading**: `poll_history()` every 200ms, `evaluate_command()` against current page's `expected`

### lib/screen.py (~472 lines)

Drop-in replacement for `pyte.Screen` + `pyte.ByteStream`. Handles:
- `\r`, `\n`, `\b` (cursor movement)
- CSI sequences: `A/B/C/D` (cursor), `H` (home), `2J` (clear), `K` (erase line)
- SGR sequences: `Nm` (colors — passed through as-is)
- Handles `ChatData` (alternate charset) and scroll regions
- Used by default; `pyte` is only a fallback if `screen.py` fails

### Web Interface (web/)

- `server.py` — aiohttp application with:
  - `PtySession` class — manages bash PTY per WebSocket connection
  - `/` — serves `index.html`
  - `/api/content` — returns mission data as JSON (cached)
  - `/ws/terminal` — WebSocket: streams PTY output, receives input + resize events
  - `/healthz` — health check for deployment
- `static/index.html` — 3-panel layout matching TUI
- `static/app.js` (~517 lines) — frontend logic: missions tree, exercise rendering, xterm.js integration
- `static/style.css` (~330 lines) — Catppuccin Mocha theme

---

## Content Specification

### Mission Format

Each mission lives in `missions/NN-name/` and must contain:

| File | Purpose | Required |
|---|---|---|
| `README.md` | Concept brief: learning goals, key commands, context | Yes |
| `exercises.md` | Paginated exercises with `---` page separators | Yes |
| `solution.md` | Worked solutions for each exercise | Recommended |
| `practice.sh` | Interactive bash session for guided practice | Recommended |

### Exercise Page Format

Exercises use `---` on its own line to separate pages. Each page:

1. Starts with a `## Title` heading (used as page title and navigation label)
2. Contains instructional text with markdown formatting
3. Includes `**Hint:** \`command\`` lines for automated grading
4. Ends before the next `---` separator

Example:

```markdown
## List Running Processes

Use `ps` to see what's running on your system.

**Hint:** `ps aux`

---

## Filter with grep

Combine `ps` and `grep` to find specific processes.

**Hint:** `ps aux | grep bash`
```

### Sections

| Section | Missions | Topics |
|---|---|---|
| Foundations | 01–04 | Basic commands, Text files & Vim, Linux philosophy, Terminal & shell |
| Shell Power | 05–07 | Shell expansions, Pipes & redirection, Users & groups |
| Filesystem | 08–11 | File management, Filesystem hierarchy, File types, Finding files |
| System | 12–14 | Archive & compression, Permissions, Process management |
| Advanced | 15–19 | Packages, SSH, Shell scripting, awk, jq |

### Projects

| # | Name | Description |
|---|---|---|
| p1 | Log Analyzer | Parse and summarise web server access logs |
| p2 | Backup Script | Incremental backups with rotation and logging |
| p3 | User Audit | Scan system accounts and report anomalies |
| p4 | Dotfiles | Manage and version-control shell configuration |

---

## TUI Specification

### Layout

```
┌─ MISSIONS ──────┬─ EXERCISES ──────────────────────────────┐
│ ▼ Foundations   │  Mission 06 · Pipes & Redirection  p 2/4  │
│   ✓ 01 basics   │                                           │
│   ✓ 02 vim      │  ## Exercise 3: Chaining Pipes            │
│   ✓ 03 philos.. │                                           │
│   ✓ 04 shell    │  Combine ps, grep, and awk to list only   │
│ ▼ Shell Power   │  running processes owned by your user.     │
│   ✓ 05 expand.. │                                           │
│   ● 06 pipes    ├───────────────────────────────────────────┤
│   · 07 users    │  TERMINAL                                 │
│ ▶ Filesystem    │  $ ps aux | grep $USER | awk '{print $11}'│
│ ▶ System        │  /bin/bash                                 │
│ ▶ Advanced      │  /usr/bin/python3                          │
└─────────────────┴───────────────────────────────────────────┘
 [NORMAL MODE]  ← 3 / Ctrl-X  for shell  · ↑↓/jk: navigate    4/19
```

### Keyboard Bindings

| Mode | Key | Action |
|---|---|---|
| NORMAL | `j` / `↓` | Move down in current panel |
| NORMAL | `k` / `↑` | Move up in current panel |
| NORMAL | `h` / `←` | Collapse section / move left |
| NORMAL | `l` / `→` | Expand section / move right |
| NORMAL | `Enter` | Switch to SHELL mode (focus terminal) |
| NORMAL | `Tab` | Cycle panel focus |
| NORMAL | `]**` / `PgDn` | Next exercise page |
| NORMAL | `[` / `PgUp` | Previous exercise page |
| NORMAL | `Ctrl-Q` / `Ctrl-C` | Arm quit confirmation |
| NORMAL | `Y` (after quit arm) | Confirm quit |
| NORMAL | `N` (after quit arm) | Cancel quit |
| SHELL | `Ctrl-X` / `Esc` | Return to NORMAL mode |
| SHELL | `Alt+1` | Switch to missions panel |
| SHELL | `Alt+2` | Switch to exercises panel |
| SHELL | All other keys | Forwarded to bash PTY |

### Panel Colors

| Panel | Accent Color | Catppuccin Name |
|---|---|---|
| Missions tree | Mauve `#CBB6F5` | `C_MAUVE` |
| Exercises | Sapphire `#74C7EC` | `C_SAPPH` |
| Terminal | Green `#A6E3A1` | `C_GREEN` |

### Progress Indicators

| Symbol | Meaning |
|---|---|
| `✓` | Mission completed (`make done` or all exercises graded) |
| `~` | Mission in progress (some exercises completed) |
| `·` | Mission not started |

Status bar shows overall progress: `██░░░░ 4/19`

### Grading System

1. Each exercise page may contain `**Hint:** \`command\`` lines
2. The TUI extracts backticked commands as `expected` commands
3. Every 200ms, `poll_history()` reads new lines from bash's `HISTFILE`
4. `evaluate_command()` compares typed commands against expected using `matches()`
5. Matched exercises are recorded with timestamp in `~/.terminal-gym/grades.json`
6. Missions panel updates progress marks in real-time

---

## CLI Specification (Makefile)

| Command | Description |
|---|---|
| `make start` | Launch the 3-panel TUI |
| `make status` | Show visual progress board |
| `make next` | Jump to next unfinished mission |
| `make done N=06` | Mark mission NN as complete |
| `make mission N=06` | Read the concept brief |
| `make exercises N=06` | Open exercises in pager |
| `make solution N=06` | View worked solutions (prompts confirmation) |
| `make practice N=06` | Run interactive practice session |
| `make review N=06` | Open brief + exercises + solution in pager |
| `make hint N=06` | Show all hint lines from exercises |
| `make check N=06` | Show all self-check lines from exercises |
| `make project N=1` | Open a synthesis project |
| `make lab` | Show lab sandbox contents |
| `make web` | Launch the web server (default port 8080) |
| `make help` | Show all available commands |

---

## Web Specification

### Endpoints

| Method | Path | Description |
|---|---|---|
| GET | `/` | Serve `index.html` |
| GET | `/api/content` | Return all missions/pages as JSON |
| GET | `/ws/terminal` | WebSocket: bidirectional PTY bridge |
| GET | `/healthz` | Health check (returns "ok") |

### WebSocket Protocol

- **Server → Client**: Raw PTY output bytes (binary frames)
- **Client → Server**:
  - Binary frames: raw keyboard input forwarded to bash
  - Text frames (JSON): `{"type": "resize", "rows": N, "cols": N}`

### Frontend Architecture

- 3-panel layout: missions tree (left), exercises (top-right), xterm.js terminal (bottom-right)
- Draggable resize handle between exercises and terminal panels
- LocalStorage persistence for grades
- Catppuccin Mocha theme matching the TUI

---

## Deployment

### Docker

```bash
docker build -t terminal-gym .
docker run -p 8080:8080 terminal-gym
```

The Docker image:
- Based on `python:3.12-slim`
- Installs `bash` and `make`
- Runs `web/server.py` as non-root user `gym`
- Exposes port 8080

### Fly.io / Render.com

Configuration files `fly.toml` and `render.yaml` are provided for managed deployment. Both use the health check endpoint at `/healthz`.

---

## Constraints & Design Decisions

1. **Zero-dependency local use**: `screen.py` replaces `pyte` as the default VT100 emulator. Pure `git clone && make start` works with only Python stdlib.
2. **No curses dependency**: All rendering uses raw ANSI escape codes via `sys.stdout.buffer`.
3. **Catppuccin Mocha throughout**: Consistent 24-bit color palette across TUI, web, and CLI.
4. **Lenient grading**: Case-insensitive substring matching reduces frustration for learners.
5. **Atomic progress writes**: `save_grades()` writes to a temp file then renames, preventing corruption.
6. **PTY isolation**: Each session forks a fresh bash with `--norc -i`, ensuring a clean environment.
7. **Content-first**: All learning content lives in plain markdown — no database, no CMS.

---

## Known Limitations

1. **Linux-only**: PTY management (`pty.openpty()`, `os.fork()`) requires Linux. No macOS or Windows support.
2. **Single user**: No authentication or multi-user support for the web interface.
3. **Web security**: Each WebSocket session gets an unrestricted bash shell. The Docker setup runs as non-root, but container isolation is recommended for public deployments.
4. **Missing solution files**: Missions 07 (users-groups), 08 (file-management), and 09 (filesystem-hierarchy) lack `solution.md`.
5. **Legacy code**: `lib/course.sh` (1500 lines) is a legacy bash TUI that is no longer the primary interface.
6. **No undo**: Once a mission is marked done via `make done`, there is no built-in way to unmark it (requires manual edit of `progress.md`).

---

# Roadmap

## Phase 1 — Polish & Robustness (Current Sprint)

| # | Item | Status | Notes |
|---|---|---|---|
| 1.1 | Inline search in exercises | ⏳ | `/` to search, `n`/`N` to navigate hits |
| 1.2 | Missing solution files | ⏳ | Missions 07, 08, 09 need `solution.md` |
| 1.3 | Resize handling | ⏳ | Graceful terminal resize without layout corruption |
| 1.4 | Error boundaries | ⏳ | Better error messages when missions dir is missing or malformed |
| 1.5 | Unit tests for core/ | ⏳ | Test missions.py, grading.py, content.py in isolation |

## Phase 2 — Content Expansion (1–2 weeks)

| # | Item | Status | Notes |
|---|---|---|---|
| 2.1 | Mission 20 — sed | ⏳ | Stream editor basics: substitution, addresses, ranges |
| 2.2 | Mission 21 — regex | ⏳ | Regular expressions: BRE, ERE, practical patterns |
| 2.3 | Mission 22 — git basics | ⏳ | init, add, commit, log, diff, branch, merge |
| 2.4 | Difficulty tags | ⏳ | Per-exercise-page difficulty (beginner/intermediate/advanced) |
| 2.5 | Additional projects | ⏳ | p5+: CI/CD pipeline, system monitoring, network debugging |

## Phase 3 — Learning Enhancements (2–4 weeks)

| # | Item | Status | Notes |
|---|---|---|---|
| 3.1 | Spaced-repetition review | ⏳ | Resurface commands not recently used |
| 3.2 | Command history replay | ⏳ | Replay a session's commands for review |
| 3.3 | Session export | ⏳ | Export session transcript as markdown/HTML |
| 3.4 | Streak tracking | ⏳ | Daily streak counter, time-played stats |
| 3.5 | Progress reset | ⏳ | `make reset` or undo `make done` |
| 3.6 | nohup/tmux integration | ⏳ | Handle long-running exercises that background processes |

## Phase 4 — Web Interface Improvements (3–5 weeks)

| # | Item | Status | Notes |
|---|---|---|---|
| 4.1 | Container sandboxing | ⏳ | Docker or bubblewrap per WebSocket session |
| 4.2 | Session timeout | ⏳ | Auto-cleanup idle PTY sessions |
| 4.3 | Server-side grading | ⏳ | Port grading logic from TUI to web backend |
| 4.4 | Responsive redesign | ⏳ | Mobile-friendly layout, collapsible panels |
| 4.5 | Persistent grades (web) | ⏳ | Server-side grade storage (SQLite or Redis) |
| 4.6 | Multiple session support | ⏳ | Handle concurrent users safely |

## Phase 5 — Codebase Refactor (1–2 weeks)

| # | Item | Status | Notes |
|---|---|---|---|
| 5.1 | Split lib/tui.py | ⏳ | Extract into `interfaces/tui/app.py`, `interfaces/tui/pty.py`, `interfaces/tui/render.py` |
| 5.2 | Remove lib/course.sh | ⏳ | Delete legacy bash TUI if no longer referenced |
| 5.3 | Type annotations | ⏳ | Add full type hints to core/ and lib/ |
| 5.4 | Lint/format setup | ⏳ | ruff + black configuration, CI integration |
| 5.5 | Remove pyte fallback | ⏳ | Once screen.py is battle-tested, drop pyte from requirements.txt |

## Phase 6 — Future Considerations

| # | Item | Status | Notes |
|---|---|---|---|
| 6.1 | Config file | ⏳ | `~/.terminal-gym/config.toml` for theme, keybindings, shell preference |
| 6.2 | Plugin system | ⏳ | Allow community-contributed missions |
| 6.3 | Leaderboard | ⏳ | Optional public stats for completed missions |
| 6.4 | Localization | ⏳ | i18n support for mission content |
| 6.5 | Go/Rust port | ⏳ | Single static binary, zero runtime deps — only if Python becomes limiting |
| 6.6 | macOS support | ⏳ | Abstract PTY management for cross-platform |