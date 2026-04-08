# terminal-gym

Learn Linux by doing — 17 hands-on missions in a 3-panel terminal UI.

## Features

- **3-panel TUI**: collapsible missions tree, paginated exercises, live bash terminal
- **17 missions**: basic commands → shell scripting, grouped into 5 sections
- **4 real-world projects** to apply what you've learned
- **Progress tracking** with per-exercise grading
- Vim-style keyboard navigation throughout

## Quick Start

```bash
git clone <repo-url>
cd terminal-gym
make start
```

**Requires:** Linux, bash, make, python3, vim

## Layout

```
┌─────────────┬──────────────────────────────────┐
│  MISSIONS   │  EXERCISES (paginated)            │
│  ▼ Found..  │                                   │
│    ● 01 ..  ├──────────────────────────────────┤
│    02 ..    │  TERMINAL  (real bash on PTY)     │
│  ▶ Shell .. └──────────────────────────────────┘
└─────────────       [ status bar ]
```

## Keyboard Shortcuts

### Global

| Key | Action |
|-----|--------|
| `Ctrl-C` / `Ctrl-Q` | Quit |
| `1` / `2` / `3` | Jump to Missions / Exercises / Terminal |
| `Tab` / `Shift-Tab` | Cycle panel focus |
| `Ctrl-X` | Toggle between terminal and last nav panel |
| `Alt+1` / `Alt+2` | Switch to Missions / Exercises from terminal |

### Missions Panel

| Key | Action |
|-----|--------|
| `↑` / `↓` or `k` / `j` | Move cursor |
| `←` / `→` or `h` / `l` | Collapse / expand section |
| `Enter` | Open mission · toggle section |

### Exercises Panel

| Key | Action |
|-----|--------|
| `←` / `→` or `[` / `]` | Previous / next page |
| `↑` / `↓` or `k` / `j` | Scroll page |
| `PgUp` / `PgDn` | Scroll 5 lines |

## Missions

| Section | Missions |
|---------|---------|
| **Foundations** | 01 Basic Commands · 02 Text Files & Vim · 03 Linux Philosophy · 04 Terminal & Shell |
| **Shell Power** | 05 Shell Expansions · 06 Pipes & Redirection · 07 Users & Groups |
| **Filesystem** | 08 File Management · 09 Filesystem Hierarchy · 10 File Types & Viewing · 11 Finding Files |
| **System** | 12 Archive & Compression · 13 Permissions · 14 Process Management |
| **Advanced** | 15 Package Management · 16 Remote Servers & SSH · 17 Shell Scripting |

## Other Commands

```bash
make status       # visual progress board
make next         # open next unfinished mission
make done N=03    # mark mission 03 complete
make project N=1  # open real-world project
```
