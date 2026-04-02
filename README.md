# terminal-gym

Learn Linux by doing. 17 hands-on missions, straight from your terminal.

```bash
git clone https://github.com/ahmedsliman/terminal-gym.git
cd terminal-gym
make start
```

## Three-Panel TUI

The default interface features a modern three-panel layout:

```
┌──────────────┬─────────────────────────────────────────┐
│  MISSIONS    │  EXERCISES — 01 Basic Commands          │
│              │                                         │
│ ▶ 01 Basic   │  Work through each exercise...          │
│   ▸ Concept  │                                         │
│   ▸ Goals    │  ## Exercise 1: Explore Environment     │
│ ▶ 02 Text    │  **Goal:** Know who you are...          │
│ ▶ 03 Linux   │                                         │
│ ▶ 04 Terminal│                                         │
│ ...          │                                         │
├──────────────┴─────────────────────────────────────────┤
│  TERMINAL                                              │
│  Step 1/12 · Basic Commands                            │
│  ▌ whoami — who are you?                               │
│  ● ○ ○ ○ ○ ○ ○ ○ ○ ○ ○ ○                              │
│                                                        │
│  $ whoami                                              │
│  ahmedsoliman                                          │
│  ✓ exit 0 — success                                    │
├────────────────────────────────────────────────────────┤
│ [TERMINAL] │ Tab:switch j/k:nav g/G:top/bot ...       │
└────────────────────────────────────────────────────────┘
```

### Keyboard Shortcuts

**Panel Navigation:**
| Key | Action |
|-----|--------|
| `Tab` / `Shift+Tab` | Cycle focus forward/backward |
| `1` / `2` / `3` | Jump to tree / exercises / terminal |
| `Esc` | Focus terminal panel |

**Tree Panel:**
| Key | Action |
|-----|--------|
| `j` / `k` / `↑` / `↓` | Move cursor down/up |
| `g` / `G` | Jump to top/bottom |
| `Enter` / `Space` | Select / toggle expand |
| `+` / `-` | Expand all / collapse all |
| `→` / `←` | Expand / collapse current node |
| `Ctrl+d` / `Ctrl+u` | Half-page down/up |
| `Ctrl+f` / `Ctrl+b` | Full-page down/up |
| `PgUp` / `PgDn` | Scroll one page |

**Exercises Panel:**
| Key | Action |
|-----|--------|
| `j` / `k` / `↑` / `↓` | Scroll down/up |
| `g` / `G` | Jump to top/bottom |
| `Ctrl+d` / `Ctrl+u` | Half-page scroll |

**Terminal Panel:**
| Key | Action |
|-----|--------|
| `↑` / `↓` | Navigate command history |
| `Ctrl+l` | Clear terminal |

**Global:**
| Key | Action |
|-----|--------|
| `/` | Search tree |
| `n` / `N` | Next/previous search result |
| `r` | Refresh |
| `?` | Show help overlay |
| `q` | Quit session |

> To use classic mode instead: `USE_PANELS=0 make start`

## Commands

```
make start              Begin at mission 01
make next               Continue where you left off
make status             See your progress
make practice  N=03     Interactive session
make mission   N=03     Read the brief
make exercises N=03     Open the exercises
make done      N=03     Mark complete
```

> Inside a session, type `?` for in-session commands (hint · skip · goto · quit).

## Missions

```
01  Basic Commands          10  File Types & Viewing
02  Text Files & Vim        11  Finding Files
03  Linux Philosophy        12  Archive & Compression
04  Terminal & Shell        13  Ownership & Permissions
05  Shell Expansions        14  Process Management
06  Pipes & Redirection     15  Package Management
07  Users & Groups          16  Remote Servers & SSH
08  File Management         17  Shell Scripting
09  Filesystem Hierarchy
```

**Requirements:** Linux · `make` · `bash` · `vim`
