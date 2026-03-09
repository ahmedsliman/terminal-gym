# Exercises — Mission 09: Filesystem Hierarchy

---

## Exercise 1: Map the Root

**Goal:** Survey the top-level directories and identify symlinks.

**Steps:**
1. List root with full details:
   ```bash
   ls -la /
   ```
2. Identify which entries are symlinks (they show `->` and have `l` as the first character).
3. Confirm the modern symlink consolidation:
   ```bash
   ls -la /bin /sbin /lib 2>/dev/null | grep '\->'
   ```
4. Count how many top-level entries exist:
   ```bash
   ls / | wc -l
   ```
5. List root with classification characters:
   ```bash
   ls -F /
   ```
   (`/` = directory, `@` = symlink, `*` = executable, nothing = regular file)

**Hint:** On modern Ubuntu/Debian, `/bin`, `/sbin`, `/lib`, and `/lib64` are all symlinks pointing into `/usr/`.

**Self-check:** `ls -la /bin` should end with `-> usr/bin` (or similar). If it shows a real directory, you are on an older distribution.

---

## Exercise 2: /etc — Configuration

**Goal:** Explore the configuration directory and read system identity files.

**Steps:**
1. Display the machine's hostname:
   ```bash
   cat /etc/hostname
   ```
2. Display OS information:
   ```bash
   cat /etc/os-release
   ```
3. List all valid login shells:
   ```bash
   cat /etc/shells
   ```
4. Count `.conf` files in /etc:
   ```bash
   ls /etc/*.conf | wc -l
   ```
5. Find the five most recently modified files in /etc:
   ```bash
   ls -lt /etc | head -6
   ```

**Hint:** Every file in `/etc` is a plain text file. No binaries belong here. When you change configuration, you edit a file in `/etc`.

**Self-check:** `cat /etc/os-release` should display your distribution name and version.

---

## Exercise 3: /var — Variable Data

**Goal:** Explore the dynamic data directory and find the largest log files.

**Steps:**
1. List the first level of /var:
   ```bash
   ls /var
   ```
2. Find the five largest log files:
   ```bash
   du -sh /var/log/* 2>/dev/null | sort -rh | head -5
   ```
3. Count files in /var/log:
   ```bash
   find /var/log -type f | wc -l
   ```
4. Check /run (runtime data):
   ```bash
   ls /run | head -10
   df -h /run
   ```
5. Show total size of /var:
   ```bash
   du -sh /var 2>/dev/null
   ```

**Hint:** `/var/log` contains logs that grow over time. `/run` is a `tmpfs` — it lives in RAM and is wiped on every reboot. PID files and sockets live there.

**Self-check:** Step 4 — `df -h /run` should show `tmpfs` as the filesystem type and a size much smaller than your main disk.

---

## Exercise 4: /proc and /sys — Virtual Filesystems

**Goal:** Read live kernel data without any special tools.

**Steps:**
1. Show system uptime in seconds:
   ```bash
   cat /proc/uptime
   ```
2. Count running processes:
   ```bash
   ls /proc | grep '^[0-9]' | wc -l
   ```
3. Show memory breakdown:
   ```bash
   grep -E '^(MemTotal|MemFree|MemAvailable)' /proc/meminfo
   ```
4. Show CPU model:
   ```bash
   grep 'model name' /proc/cpuinfo | head -1
   ```
5. Check network interface states:
   ```bash
   cat /sys/class/net/*/operstate 2>/dev/null
   ```

**Hint:** `/proc` and `/sys` do not exist on disk. The kernel generates their content on the fly when you `cat` them. No data is ever written to disk.

**Self-check:** Step 2 count should match roughly the number of lines `ps aux` produces (minus one for the header).

---

## Exercise 5: /dev — Device Files

**Goal:** Identify the three classic pseudo-devices and understand device types.

**Steps:**
1. List common device files:
   ```bash
   ls -lh /dev/null /dev/zero /dev/random /dev/urandom
   ```
2. Identify block vs character devices (first character of permissions):
   ```bash
   ls -l /dev/sda 2>/dev/null || ls -l /dev/nvme0n1 2>/dev/null || echo "no disk device found at these paths"
   ```
3. Write to /dev/null and confirm nothing is saved:
   ```bash
   echo "this disappears" > /dev/null
   wc -c /dev/null
   ```
4. Read a few bytes of /dev/urandom as hex:
   ```bash
   head -c 16 /dev/urandom | xxd
   ```
5. Count total entries in /dev:
   ```bash
   ls /dev | wc -l
   ```

**Hint:** `c` in the first character means character device (byte-at-a-time). `b` means block device (read/write in fixed-size blocks, like disks). `/dev/null` is always empty — anything written to it is discarded.

**Self-check:** `wc -c /dev/null` always returns `0 /dev/null`.

---

## Exercise 6: /usr — Program and Data Layout

**Goal:** Understand the internal structure of /usr.

**Steps:**
1. Show sizes of top-level /usr subdirectories:
   ```bash
   du -sh /usr/*/ 2>/dev/null | sort -rh | head -8
   ```
2. Count commands in /usr/bin:
   ```bash
   ls /usr/bin | wc -l
   ```
3. Examine the largest shared libraries:
   ```bash
   du -sh /usr/lib/*/ 2>/dev/null | sort -rh | head -5
   ```
4. Sample the man pages directory:
   ```bash
   ls /usr/share/man | head -10
   ```
5. Look at locally-installed software:
   ```bash
   ls /usr/local/bin 2>/dev/null || echo "(empty — no locally compiled software)"
   ```

**Hint:** `/usr/local` is where software compiled from source or installed outside the package manager goes. It is intentionally kept separate so package upgrades do not overwrite it.

**Self-check:** `/usr/lib` or `/usr/lib64` should be the largest subdirectory in step 1.

---

## Exercise 7: /tmp — Temporary Space

**Goal:** Verify /tmp properties: world-writable, sticky bit, and tmpfs.

**Steps:**
1. Show /tmp permissions:
   ```bash
   ls -ld /tmp
   ```
2. Identify the sticky bit (the `t` at the end of the permission string):
   ```bash
   stat /tmp | grep Access
   ```
3. Check if /tmp is a tmpfs (RAM-backed):
   ```bash
   df -hT /tmp
   ```
4. Write a file, verify it exists, then observe it is gone after reboot:
   ```bash
   echo "session note" > /tmp/my-note.txt
   cat /tmp/my-note.txt
   ```
5. Confirm the world-writable + sticky combination:
   ```bash
   # Create a file as yourself
   touch /tmp/my-file.txt
   # Try to delete a file you do not own (should fail):
   ls /tmp | grep -v my-file | head -3
   ```

**Hint:** The sticky bit on a directory means you can only delete files *you own*, even if you have write permission on the directory. This prevents users from deleting each other's files in shared `/tmp`.

**Self-check:** `ls -ld /tmp` ends in `t` (e.g., `drwxrwxrwt`). `df -hT /tmp` shows `tmpfs` as the type.

---

## Exercise 8: findmnt — Mount Point Explorer

**Goal:** List and interpret the current mount table.

**Steps:**
1. Show the full mount tree:
   ```bash
   findmnt
   ```
2. Show only real (non-virtual) filesystems:
   ```bash
   findmnt -t ext4,xfs,btrfs,vfat 2>/dev/null || findmnt | grep -v 'tmpfs\|devtmpfs\|proc\|sys\|cgroup'
   ```
3. Find what filesystem a specific path is on:
   ```bash
   findmnt /home
   findmnt /var
   ```
4. Compare with df:
   ```bash
   df -hT
   ```
5. Count total mount points:
   ```bash
   findmnt | wc -l
   ```

**Hint:** `findmnt` shows the mount table as a tree, making parent-child relationships between filesystems clear. `df` shows the same data in a flat table with usage information added.

**Self-check:** `/proc`, `/sys`, and `/run` should show as `tmpfs` or `proc`/`sysfs` in the TYPE column — these are virtual, not on your disk.

---

Cleanup (no scratch files used this mission):
```bash
rm -f /tmp/my-note.txt /tmp/my-file.txt
```

Mark complete:
```bash
make done N=09
make next
```
