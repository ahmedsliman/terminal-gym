# terminal-gym

A hands-on Linux CLI course. 17 missions, interactive practice sessions, all from your terminal.

## Start

```bash
git clone https://github.com/ahmedsliman/terminal-gym.git
cd terminal-gym
make start
```

## Commands

```bash
make start              # begin at mission 01
make next               # continue where you left off
make status             # see your progress
make practice  N=03     # interactive session for mission 03
make mission   N=03     # read the brief
make exercises N=03     # open the exercises
make solution  N=03     # reveal the solution
make done      N=03     # mark complete
```

Inside a practice session, type `?` at any prompt to see available commands (hint, skip, goto, quit, ...).

## Missions

| # | Topic |
|---|-------|
| 01 | Basic Commands |
| 02 | Text Files & Vim |
| 03 | Linux Philosophy |
| 04 | Terminal & Shell |
| 05 | Shell Expansions |
| 06 | Pipes & Redirection |
| 07 | Users & Groups |
| 08 | File Management |
| 09 | Filesystem Hierarchy |
| 10 | File Types & Viewing |
| 11 | Finding Files |
| 12 | Archive & Compression |
| 13 | Ownership & Permissions |
| 14 | Process Management |
| 15 | Package Management |
| 16 | Remote Servers & SSH |
| 17 | Shell Scripting |

## Requirements

- Linux (Ubuntu / Debian recommended)
- `make`, `bash`, `vim`
