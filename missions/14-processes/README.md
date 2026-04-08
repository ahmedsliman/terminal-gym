# Mission 14: Process Management

## Concept

Every program running on your system is a **process** — an instance of a program loaded into memory, assigned a **PID** (process ID), and managed by the kernel. Understanding processes is essential for debugging slow systems, killing stuck programs, and writing robust scripts.

## Learning Goals

By the end of this mission you will be able to:

- List all running processes with `ps` and interpret the output
- Monitor system resource usage interactively with `top`
- Understand process states and parent-child relationships (PID, PPID)
- Send signals to processes using `kill`, `killall`, and `pkill`
- Manage foreground/background jobs with `jobs`, `fg`, `bg`
- Read raw process information from the `/proc` virtual filesystem
- Find the top CPU/memory consumers

## Key Concepts

### Process Basics

| Term | Meaning |
|------|---------|
| PID | Process ID — unique integer assigned by the kernel |
| PPID | Parent PID — the process that spawned this one |
| UID/GID | User/group that owns the process |
| TTY | Terminal associated with the process (`?` = no terminal) |

### Process States (STAT column in ps)

| State | Meaning |
|-------|---------|
| `R` | Running or runnable |
| `S` | Sleeping — waiting for I/O or an event (interruptible) |
| `D` | Disk sleep — waiting for I/O (uninterruptible, cannot be killed) |
| `Z` | Zombie — process exited, parent hasn't collected its exit code |
| `T` | Stopped (by SIGSTOP or Ctrl+Z) |
| `s` suffix | Session leader |
| `+` suffix | Foreground process group |

### ps Cheat Sheet

```bash
ps               # your processes in the current terminal
ps aux           # all users, user-oriented format, include no-TTY processes
ps -ef           # all processes in full format (shows PPID)
ps axjf          # process tree (ASCII art)
ps aux --sort=-%cpu | head -6   # top 5 by CPU
ps aux --sort=-%mem | head -6   # top 5 by memory
```

**ps aux columns:** `USER  PID  %CPU  %MEM  VSZ  RSS  TTY  STAT  START  TIME  COMMAND`

- `VSZ` — virtual memory size (all memory the process can access)
- `RSS` — resident set size (actual RAM in use right now)

### Signals

| Signal | Number | Purpose |
|--------|--------|---------|
| SIGTERM | 15 | Graceful shutdown (default for `kill`) — process can catch this |
| SIGKILL | 9 | Immediate kill — cannot be caught or ignored |
| SIGHUP | 1 | Hang up / reload configuration |
| SIGINT | 2 | Interrupt (same as Ctrl+C) |
| SIGSTOP | 19 | Pause process (cannot be caught) |
| SIGCONT | 18 | Resume a stopped process |

```bash
kill PID           # send SIGTERM (graceful)
kill -9 PID        # send SIGKILL (force kill)
kill -HUP PID      # send SIGHUP (reload)
killall sleep      # kill all processes named "sleep"
pkill -9 python    # kill by name pattern (more flexible than killall)
pgrep bash         # list PIDs matching name
pgrep -la bash     # list PIDs + full command line
```

### Job Control

```bash
sleep 300 &        # start in background
jobs -l            # list background jobs (with PIDs)
fg %1              # bring job 1 to foreground
bg %1              # resume stopped job 1 in background
kill %1            # kill job 1 (using job number, not PID)
```

Press **Ctrl+Z** to suspend a foreground process (SIGSTOP).
Press **Ctrl+C** to terminate a foreground process (SIGINT).

### /proc Virtual Filesystem

Every process has a directory `/proc/PID/` with live information:

```bash
cat /proc/$$/status        # detailed process status
cat /proc/$$/cmdline       # command + arguments (null-separated)
ls -la /proc/$$/fd         # open file descriptors
cat /proc/$$/environ | tr '\0' '\n'   # environment variables
```

**Key `/proc` files (not process-specific):**

| File | Content |
|------|---------|
| `/proc/loadavg` | 1/5/15-min load averages, running/total tasks |
| `/proc/meminfo` | System-wide memory statistics |
| `/proc/cpuinfo` | CPU model, cores, features |
| `/proc/uptime` | System uptime in seconds |

## Notes

- **Always try SIGTERM before SIGKILL** — SIGKILL skips cleanup and can leave temp files / locked resources behind.
- **Zombie processes** cannot be killed (they're already dead). Kill their parent to clean them up.
- **Load average > number of CPU cores** means processes are waiting for CPU time — the system is overloaded.
- `kill` takes a PID; `killall` takes a name; `pkill` takes a pattern. Use `pgrep` first to check what you'll hit.
- `nohup command &` runs a command immune to SIGHUP (useful for long-running tasks over SSH).

## Next

Run the hands-on exercises:

```bash
make exercises N=14
```
