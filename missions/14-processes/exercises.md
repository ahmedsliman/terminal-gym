# Exercises — Mission 14: Process Management

---

## Exercise 1: Listing Processes — ps

**Goal:** Use `ps` to inspect running processes.

**Steps:**
1. Show your own processes:
   ```bash
   ps
   ```
2. Show every process on the system:
   ```bash
   ps aux | head -20
   ```
3. Understand the columns:
   - `USER` — who owns the process
   - `PID` — process ID
   - `%CPU` — CPU usage
   - `%MEM` — memory usage
   - `STAT` — process state
   - `COMMAND` — the command that launched it
4. Find a specific process by name:
   ```bash
   ps aux | grep bash
   ```
5. Show processes as a tree:
   ```bash
   ps axjf 2>/dev/null | head -30
   # or
   pstree -p | head -20
   ```

**Hint:** `ps aux` is the most common form. `a` = all users, `u` = user-oriented format, `x` = include processes without a terminal. The combination shows everything running on the system.

**Self-check:** `ps aux | grep $$` should show the current shell process (`$$` is the current shell's PID).

---

## Exercise 2: Dynamic View — top and htop

**Goal:** Use `top` to observe CPU and memory in real time.

**Steps:**
1. Open top:
   ```bash
   top
   ```
2. While in top, note:
   - The first line: uptime and load averages
   - `Tasks:` line: how many processes are running vs sleeping
   - `%Cpu(s):` line: user, system, idle percentages
   - `MiB Mem:` line: total, free, used, buffer/cache
3. Sort by memory usage: press `M` inside top
4. Sort by CPU usage: press `P` inside top
5. Quit top: press `q`

**Alternative (if installed):**
```bash
htop   # more readable interactive view
```

**Hint:** Load average shows 1/5/15-minute averages. A value equal to the number of CPU cores means 100% utilization. Above that means processes are waiting.

**Self-check:** The `%Cpu(s)` idle value should be high on a lightly loaded system (above 80% idle).

---

## Exercise 3: Process States and PID

**Goal:** Understand process states and the process hierarchy.

**Steps:**
1. Find the PID of the current shell:
   ```bash
   echo $$
   ```
2. Find the parent PID:
   ```bash
   echo $PPID
   ```
3. Check process state of the current shell:
   ```bash
   ps -p $$ -o pid,ppid,stat,comm
   ```
4. Start a background sleep and observe it:
   ```bash
   sleep 300 &
   SLEEP_PID=$!
   ps -p $SLEEP_PID -o pid,ppid,stat,comm
   ```
5. Show the process hierarchy from the sleep process up to init:
   ```bash
   ps -p $SLEEP_PID,$PPID,$$ -o pid,ppid,stat,comm
   ```

**Process states (STAT column):**
| State | Meaning |
|-------|---------|
| `R` | Running or runnable |
| `S` | Sleeping (interruptible) |
| `D` | Disk sleep (uninterruptible) |
| `Z` | Zombie (finished, parent hasn't collected exit code) |
| `T` | Stopped (by signal or debugger) |
| `+` suffix | Foreground process group |
| `s` suffix | Session leader |

**Self-check:** The sleep process should show state `S` (sleeping). Your shell should show `Ss` (sleeping, session leader).

---

## Exercise 4: Signals — kill and killall

**Goal:** Send signals to processes to control them.

**Steps:**
1. Create a background process to work with:
   ```bash
   sleep 300 &
   SLEEP_PID=$!
   echo "sleep PID: $SLEEP_PID"
   ```
2. Send SIGTERM (graceful termination — the default):
   ```bash
   kill $SLEEP_PID
   sleep 0.5
   ps -p $SLEEP_PID 2>&1   # should say "no process found"
   ```
3. Create another background process and send SIGKILL (force kill):
   ```bash
   sleep 300 &
   SLEEP_PID=$!
   kill -9 $SLEEP_PID
   sleep 0.5
   ps -p $SLEEP_PID 2>&1
   ```
4. Kill by name (kills all matching processes):
   ```bash
   sleep 300 & sleep 300 & sleep 300 &
   ps aux | grep sleep | grep -v grep
   killall sleep
   ps aux | grep sleep | grep -v grep
   ```
5. Send SIGHUP (reload configuration — signal 1):
   ```bash
   # SIGHUP is commonly sent to daemons to reload config without restarting
   # Demonstration only — we won't reload a daemon here
   kill -HUP $$    # sends SIGHUP to the current shell (may or may not react)
   ```

**Common signals:**
| Signal | Number | Meaning |
|--------|--------|---------|
| SIGTERM | 15 | Graceful termination (default) |
| SIGKILL | 9 | Immediate kill (cannot be caught) |
| SIGHUP | 1 | Hang up / reload configuration |
| SIGINT | 2 | Interrupt (Ctrl+C) |
| SIGSTOP | 19 | Stop (pause) process |
| SIGCONT | 18 | Continue a stopped process |

**Self-check:** After step 2, `ps -p $SLEEP_PID` should print an error — the process no longer exists.

---

## Exercise 5: Job Control — fg, bg, jobs

**Goal:** Manage foreground and background jobs in the shell.

**Steps:**
1. Start a long-running command and suspend it:
   ```bash
   sleep 300
   ```
   Press `Ctrl+Z` to suspend it.

2. Check the job list:
   ```bash
   jobs -l
   ```
   (The `[1]+  Stopped  sleep 300` line shows the job number, state, and command)

3. Resume it in the background:
   ```bash
   bg %1
   jobs -l
   ```

4. Bring it back to the foreground:
   ```bash
   fg %1
   ```
   Press `Ctrl+C` to terminate it.

5. Start a command directly in the background with `&`:
   ```bash
   sleep 100 &
   sleep 200 &
   jobs -l
   kill %1 %2
   jobs
   ```

**Hint:** `%1`, `%2` refer to job numbers (not PIDs). `%+` means the current (most recent) job. `bg` resumes in background, `fg` brings to foreground. Ctrl+Z sends SIGSTOP, Ctrl+C sends SIGINT.

**Self-check:** `jobs -l` shows both the job number (`[1]`) and the PID. `kill %1` uses the job number, not the PID.

---

## Exercise 6: /proc — Process Information

**Goal:** Read process information directly from the /proc virtual filesystem.

**Steps:**
1. List the PID directories:
   ```bash
   ls /proc | grep '^[0-9]' | head -10
   ```
2. Inspect the current shell process:
   ```bash
   cat /proc/$$/status | head -10
   cat /proc/$$/cmdline | tr '\0' ' '; echo
   ```
3. Read what files a process has open:
   ```bash
   ls -la /proc/$$/fd | head -10
   ```
   (fd/0 = stdin, fd/1 = stdout, fd/2 = stderr)
4. Check environment variables of a process:
   ```bash
   cat /proc/$$/environ | tr '\0' '\n' | head -10
   ```
5. Find memory usage from /proc:
   ```bash
   grep -E '^(VmRSS|VmSize)' /proc/$$/status
   ```

**Hint:** Every running process has a directory `/proc/PID/` containing files that describe it. `cmdline` is the command + arguments, null-byte separated. `fd/` shows all open file descriptors.

**Self-check:** `/proc/$$/fd/0`, `/proc/$$/fd/1`, and `/proc/$$/fd/2` should all be symlinks to `/dev/pts/N` (your terminal).

---

## Exercise 7: Finding Resource-Heavy Processes

**Goal:** Identify processes consuming the most CPU and memory.

**Steps:**
1. Top 5 processes by CPU:
   ```bash
   ps aux --sort=-%cpu | head -6
   ```
2. Top 5 processes by memory:
   ```bash
   ps aux --sort=-%mem | head -6
   ```
3. Find a process by partial name:
   ```bash
   pgrep -la bash
   ```
4. Find all processes owned by root:
   ```bash
   ps aux | awk '$1 == "root" {print $2, $11}' | head -10
   ```
5. Show open files for a specific process (requires lsof):
   ```bash
   lsof -p $$ 2>/dev/null | head -10
   ```

**Hint:** `ps aux --sort=-%cpu` sorts by CPU descending (the `-` prefix means descending). `pgrep name` returns PIDs matching the name. `pgrep -l` also prints the name. `pgrep -la` includes the full command line.

**Self-check:** `pgrep -la bash` should include the PID of your current shell. Compare with `echo $$`.

---

Cleanup:
```bash
# Kill any background jobs still running
kill $(jobs -p) 2>/dev/null
```

Mark complete:
```bash
make done N=14
make next
```
