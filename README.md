# terminal-gym

> Learn Linux by doing — hands-on missions in a 3-panel terminal UI.

```
┌─ MISSIONS ──────┬─ EXERCISES ──────────────────────────────────┐
│ ▼ Foundations   │  Mission 06 · Pipes & Redirection  page 2/4  │
│   ✓ 01 basics   │                                               │
│   ✓ 02 vim      │  ## Exercise 3: Chaining Pipes               │
│   ✓ 03 philos.. │                                               │
│   ✓ 04 shell    │  Combine ps, grep, and awk to list only       │
│ ▼ Shell Power   │  running processes owned by your user.        │
│   ✓ 05 expand.. │                                               │
│   ● 06 pipes    ├───────────────────────────────────────────────┤
│   · 07 users    │  TERMINAL                                     │
│ ▶ Filesystem    │  $ ps aux | grep $USER | awk '{print $11}'   │
│ ▶ System        │  /bin/bash                                    │
│ ▶ Advanced      │  /usr/bin/python3                             │
└─────────────────┴───────────────────────────────────────────────┘
 [NORMAL MODE]  ← 3 / Ctrl-X  for shell  · ↑↓/jk: navigate    4/19
```

---

## What is this?

terminal-gym is a self-contained Linux training environment that runs entirely in your terminal. Each mission teaches a real skill through a concept brief, paginated exercises, and a live bash shell — all in one view. No browser, no cloud, no account required.

---

## Quick Start

```bash
git clone https://github.com/ahmedsliman/terminal-gym
cd terminal-gym
make start
```

**Requires:** Linux · bash · make · python3

---

## Missions

19 missions across 5 sections, each with a concept brief, hands-on exercises, worked solutions, and an interactive practice session.

| # | Section | Topics |
|---|---------|--------|
| 01–04 | **Foundations** | Basic commands · Text files & Vim · Linux philosophy · Terminal & shell |
| 05–07 | **Shell Power** | Shell expansions · Pipes & redirection · Users & groups |
| 08–11 | **Filesystem** | File management · Filesystem hierarchy · File types · Finding files |
| 12–14 | **System** | Archive & compression · Permissions · Process management |
| 15–19 | **Advanced** | Package management · SSH · Shell scripting · awk · jq |

---

## Projects

Four real-world projects to apply what you've learned end-to-end:

| # | Project |
|---|---------|
| 1 | **Log Analyzer** — parse and summarise web server access logs |
| 2 | **Backup Script** — incremental backups with rotation and logging |
| 3 | **User Audit** — scan system accounts and report anomalies |
| 4 | **Dotfiles** — manage and version-control your shell config |

```bash
make project N=1   # open a project
```

---

## Commands

```bash
make start             # launch the TUI
make status            # visual progress board in the terminal
make next              # jump to the next unfinished mission
make done   N=06       # mark mission 06 complete
make mission    N=06   # read the concept brief
make exercises  N=06   # open the exercises
make solution   N=06   # view worked solutions
make practice   N=06   # run the interactive practice session
```
