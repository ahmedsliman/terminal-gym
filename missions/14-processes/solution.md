# Solution — Mission 14: Process Management

---

## Exercise 1: Listing Processes — ps

```bash
ps
ps aux | head -20
ps aux | grep bash
ps axjf 2>/dev/null | head -30
pstree -p | head -20
```

**ps aux column reference:**
| Column | Meaning |
|--------|---------|
| `USER` | Process owner |
| `PID` | Process ID |
| `%CPU` | CPU usage since start |
| `%MEM` | RSS as percentage of total RAM |
| `VSZ` | Virtual memory size (KB) |
| `RSS` | Resident set size — actual RAM in use (KB) |
| `STAT` | Process state |
| `START` | Time process started |
| `TIME` | Total CPU time consumed |
| `COMMAND` | Command name and arguments |

`ps aux | grep $$` finds the current shell. `$$` expands to the current shell's PID.

---

## Exercise 2: Dynamic View — top and htop

```bash
top   # press q to quit, M to sort by memory, P to sort by CPU
```

**top keyboard shortcuts:**
| Key | Action |
|-----|--------|
| `q` | Quit |
| `M` | Sort by memory usage |
| `P` | Sort by CPU usage |
| `k` | Kill a process (prompts for PID) |
| `u` | Filter by user |
| `1` | Toggle per-CPU display |

**Reading load averages:**
```
load average: 0.52, 0.31, 0.18
              ^     ^     ^
           1 min 5 min 15 min
```
Values below the CPU core count = not overloaded. Values at or above = saturated.

---

## Exercise 3: Process States and PID

```bash
echo $$
echo $PPID
ps -p $$ -o pid,ppid,stat,comm
sleep 300 &
SLEEP_PID=$!
ps -p $SLEEP_PID -o pid,ppid,stat,comm
ps -p $SLEEP_PID,$PPID,$$ -o pid,ppid,stat,comm
```

**Process state codes:**
| State | Meaning |
|-------|---------|
| `R` | Running or runnable on the run queue |
| `S` | Sleeping, waiting for an event |
| `D` | Uninterruptible sleep (usually disk I/O) |
| `Z` | Zombie — process exited but parent hasn't called wait() |
| `T` | Stopped by a signal (Ctrl+Z) |
| `+` | In the foreground process group |
| `s` | Session leader |

The sleep process is `S` (sleeping). Your shell is `Ss` (sleeping, session leader).

**Shell special variables:**
- `$$` — PID of the current shell
- `$PPID` — PID of the parent process
- `$!` — PID of the most recently backgrounded process

---

## Exercise 4: Signals — kill and killall

```bash
sleep 300 &
SLEEP_PID=$!
kill $SLEEP_PID          # SIGTERM (15)
sleep 0.5
ps -p $SLEEP_PID 2>&1

sleep 300 &
SLEEP_PID=$!
kill -9 $SLEEP_PID       # SIGKILL
sleep 0.5
ps -p $SLEEP_PID 2>&1

sleep 300 & sleep 300 & sleep 300 &
ps aux | grep sleep | grep -v grep
killall sleep
ps aux | grep sleep | grep -v grep
```

**Common signals:**
| Signal | Number | Sent by | Can be caught? |
|--------|--------|---------|---------------|
| SIGTERM | 15 | `kill PID` | Yes — allows cleanup |
| SIGKILL | 9 | `kill -9 PID` | No — kernel forces immediate termination |
| SIGHUP | 1 | `kill -HUP PID` | Yes — daemons use it to reload config |
| SIGINT | 2 | Ctrl+C | Yes |
| SIGQUIT | 3 | Ctrl+\ | Yes — also creates core dump |
| SIGSTOP | 19 | Ctrl+Z / `kill -STOP` | No — kernel pauses the process |
| SIGCONT | 18 | `kill -CONT PID` | Yes — resumes stopped process |

**Prefer SIGTERM over SIGKILL:** Give the process a chance to clean up, close files, and flush buffers. Only use SIGKILL when SIGTERM is ignored.

---

## Exercise 5: Job Control — fg, bg, jobs

```bash
sleep 300      # then Ctrl+Z to suspend
jobs -l        # list jobs with PIDs
bg %1          # resume job 1 in background
jobs -l        # confirm it is running
fg %1          # bring to foreground
               # then Ctrl+C to terminate

sleep 100 &
sleep 200 &
jobs -l
kill %1 %2
jobs
```

**Job control summary:**
| Command | Effect |
|---------|--------|
| `cmd &` | Start command in background |
| Ctrl+Z | Suspend (stop) foreground process |
| `jobs` | List background/stopped jobs |
| `bg %N` | Resume job N in background |
| `fg %N` | Bring job N to foreground |
| `kill %N` | Send SIGTERM to job N |

Job numbers (`%1`, `%2`) are shell-local — they reset when you open a new shell. PIDs are system-global.

---

## Exercise 6: /proc — Process Information

```bash
ls /proc | grep '^[0-9]' | head -10
cat /proc/$$/status | head -10
cat /proc/$$/cmdline | tr '\0' ' '; echo
ls -la /proc/$$/fd | head -10
cat /proc/$$/environ | tr '\0' '\n' | head -10
grep -E '^(VmRSS|VmSize)' /proc/$$/status
```

**Key /proc/PID/ files:**
| File | Contents |
|------|---------|
| `cmdline` | Command + arguments (null-byte separated) |
| `status` | Human-readable process status (name, PID, state, memory) |
| `environ` | Environment variables (null-byte separated) |
| `fd/` | Directory of open file descriptors |
| `maps` | Memory map |
| `exe` | Symlink to the executable |
| `cwd` | Symlink to the current working directory |

Standard file descriptors: `fd/0` = stdin, `fd/1` = stdout, `fd/2` = stderr. All three are symlinks to the terminal device.

---

## Exercise 7: Finding Resource-Heavy Processes

```bash
ps aux --sort=-%cpu | head -6
ps aux --sort=-%mem | head -6
pgrep -la bash
ps aux | awk '$1 == "root" {print $2, $11}' | head -10
lsof -p $$ 2>/dev/null | head -10
```

**Useful process-finding tools:**
```bash
ps aux --sort=-%cpu    sort by CPU descending
ps aux --sort=-%mem    sort by memory descending
pgrep name             find PIDs by name (regex supported)
pgrep -la name         PIDs + full command line
pkill name             send SIGTERM to all matching processes
lsof -p PID            files open by a specific process
lsof -u user           files open by a specific user
```

**Quick triage pattern:**
```bash
# 1. Who is using the most CPU?
ps aux --sort=-%cpu | head -5

# 2. What files do they have open?
lsof -p PID 2>/dev/null | head -20

# 3. What network connections?
ss -tp | grep PID
```

---

## Quick Reference

```bash
ps aux              list all processes
ps aux --sort=-%cpu top CPU consumers
ps -p PID -o pid,stat,comm  process details by PID
$$                  current shell PID
$!                  last backgrounded process PID
$PPID               parent shell PID
top                 interactive process viewer (q to quit)
kill PID            send SIGTERM
kill -9 PID         send SIGKILL (force)
kill -HUP PID       send SIGHUP (reload)
killall name        kill all processes with this name
pgrep name          find PIDs by name
pgrep -la name      PIDs + full command
jobs                list shell jobs
bg %N               resume job N in background
fg %N               bring job N to foreground
Ctrl+Z              suspend current foreground process
Ctrl+C              send SIGINT to current foreground process
cat /proc/PID/status  process status from kernel
```
