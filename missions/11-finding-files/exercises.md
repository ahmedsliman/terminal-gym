# Exercises — Mission 11: Finding Files

---

## Exercise 1: find by Name

**Goal:** Use `-name` and `-iname` to locate files.

**Setup:**
```bash
mkdir -p /tmp/m11/docs/notes
touch /tmp/m11/readme.txt /tmp/m11/README.md /tmp/m11/docs/report.txt /tmp/m11/docs/notes/todo.txt
```

**Steps:**
1. Find files named exactly `readme.txt` (case-sensitive):
   ```bash
   find /tmp/m11 -name "readme.txt"
   ```
2. Find case-insensitively (matches `readme.txt` and `README.md`):
   ```bash
   find /tmp/m11 -iname "readme*"
   ```
3. Find all `.txt` files under /tmp/m11:
   ```bash
   find /tmp/m11 -name "*.txt"
   ```
4. Find all `.conf` files under /etc (suppress permission errors):
   ```bash
   find /etc -name "*.conf" 2>/dev/null | head -10
   ```
5. Find files that do NOT match `*.txt`:
   ```bash
   find /tmp/m11 ! -name "*.txt"
   ```

**Hint:** Always quote glob patterns in `find` — without quotes, the shell expands `*.txt` before `find` sees it, which breaks the search.

**Self-check:** Step 3 should find exactly 3 `.txt` files under `/tmp/m11`.

---

## Exercise 2: find by Type

**Goal:** Filter results to specific file types.

**Steps:**
1. Find only directories under /tmp/m11:
   ```bash
   find /tmp/m11 -type d
   ```
2. Find only regular files:
   ```bash
   find /tmp/m11 -type f
   ```
3. Find symbolic links under /usr/bin:
   ```bash
   find /usr/bin -type l | head -10
   ```
4. Count symlinks vs regular files in /usr/bin:
   ```bash
   echo "symlinks: $(find /usr/bin -type l | wc -l)"
   echo "regular:  $(find /usr/bin -type f | wc -l)"
   ```
5. Find all directories under /etc:
   ```bash
   find /etc -type d 2>/dev/null | wc -l
   ```

**Hint:** `-type f` is "regular file" — it excludes symlinks, directories, devices. `-type l` finds only symlinks. Combining `-type f -name "*.sh"` finds only real shell script files, not symlinks to them.

**Self-check:** Step 1 should show at least 3 directories: `/tmp/m11`, `/tmp/m11/docs`, `/tmp/m11/docs/notes`.

---

## Exercise 3: find by Size

**Goal:** Locate files by size using +/- prefixes.

**Setup:**
```bash
dd if=/dev/zero of=/tmp/m11/large.bin bs=1M count=2 2>/dev/null
dd if=/dev/zero of=/tmp/m11/small.bin bs=1k count=5 2>/dev/null
```

**Steps:**
1. Find files larger than 1 MB under /tmp/m11:
   ```bash
   find /tmp/m11 -type f -size +1M
   ```
2. Find files smaller than 100 KB:
   ```bash
   find /tmp/m11 -type f -size -100k
   ```
3. Find files in /var/log larger than 10 MB:
   ```bash
   find /var/log -type f -size +10M 2>/dev/null
   ```
4. Find files between 1k and 100k:
   ```bash
   find /tmp/m11 -type f -size +1k -size -100k
   ```
5. Find the largest file in /usr/bin:
   ```bash
   find /usr/bin -type f -printf '%s %p\n' | sort -n | tail -5
   ```

**Hint:** Size suffixes: `c` = bytes, `k` = kilobytes (1024 bytes), `M` = megabytes, `G` = gigabytes. `+` means "strictly greater than", `-` means "strictly less than".

**Self-check:** Step 1 should find `large.bin` (2 MB). Step 2 should find `small.bin` and the `.txt` files, but not `large.bin`.

---

## Exercise 4: find by Time

**Goal:** Locate files by modification, access, or change time.

**Steps:**
1. Find files modified in the last day:
   ```bash
   find /tmp/m11 -type f -mtime -1
   ```
2. Find log files not modified in the last 7 days:
   ```bash
   find /var/log -type f -mtime +7 2>/dev/null | head -5
   ```
3. Find files modified within the last 60 minutes:
   ```bash
   find /tmp -type f -mmin -60 2>/dev/null | head -10
   ```
4. Create a reference file and find newer files:
   ```bash
   touch /tmp/m11/reference.mark
   sleep 1
   touch /tmp/m11/newer-than-mark.txt
   find /tmp/m11 -newer /tmp/m11/reference.mark
   ```
5. Find files in /etc changed in the last 24 hours:
   ```bash
   find /etc -ctime -1 2>/dev/null | head -10
   ```

**Hint:** `-mtime -1` = modified within the last 24 hours. `-mtime +7` = last modified more than 7 days ago. `-mmin -60` = modified within the last 60 minutes.

**Self-check:** Step 4 should show `newer-than-mark.txt` but not `reference.mark`.

---

## Exercise 5: find by Permissions

**Goal:** Find files based on their permission bits.

**Steps:**
1. Find world-writable files in /tmp (excluding /tmp itself):
   ```bash
   find /tmp -maxdepth 1 -perm -o+w -type f 2>/dev/null | head -5
   ```
2. Find setuid executables (security-relevant):
   ```bash
   find /usr/bin -perm -4000 2>/dev/null
   ```
3. Find setgid executables:
   ```bash
   find /usr/bin /usr/sbin -perm -2000 2>/dev/null
   ```
4. Find files with exactly 644 permissions:
   ```bash
   find /tmp/m11 -perm 644
   ```
5. Find executable files owned by root in /usr/bin:
   ```bash
   find /usr/bin -user root -perm /u+x -type f | head -5
   ```

**Hint:** `-perm -4000` means "the setuid bit (4000) must be set" — the `-` prefix means all listed bits must be present. `-perm /4000` means "any of the listed bits" — same result for a single bit, but differs for multiple bits.

**Self-check:** Step 2 should include `/usr/bin/passwd` — it has setuid set so ordinary users can change their own passwords.

---

## Exercise 6: Combining Criteria and Actions

**Goal:** Use multiple criteria and the -exec action.

**Steps:**
1. Find `.txt` files larger than 0 bytes:
   ```bash
   find /tmp/m11 -name "*.txt" -type f -size +0c
   ```
2. Find `.txt` files and display their sizes:
   ```bash
   find /tmp/m11 -name "*.txt" -exec ls -lh {} \;
   ```
3. Find `.txt` files and display their sizes (batch — one `ls` call):
   ```bash
   find /tmp/m11 -name "*.txt" -exec ls -lh {} +
   ```
4. Find `.bin` files and delete them:
   ```bash
   find /tmp/m11 -name "*.bin" -delete
   ls /tmp/m11
   ```
5. Find all `.txt` files and count total lines:
   ```bash
   find /tmp/m11 -name "*.txt" -exec wc -l {} +
   ```

**Hint:** `-exec cmd {} \;` runs `cmd` once per file. `-exec cmd {} +` collects all matches and runs `cmd` once with all files as arguments — more efficient for large result sets. `-delete` is equivalent to `-exec rm {} \;` but faster.

**Self-check:** Steps 2 and 3 produce the same output but step 3 runs `ls` only once.

---

## Exercise 7: locate and which

**Goal:** Use database-backed search and PATH-based command lookup.

**Steps:**
1. Search for files containing "passwd" in the name:
   ```bash
   locate passwd | head -10
   ```
2. Case-insensitive search:
   ```bash
   locate -i readme | head -5
   ```
3. Count how many paths contain "conf":
   ```bash
   locate -c "*.conf"
   ```
4. Find where the `grep` command lives:
   ```bash
   which grep
   which -a python3 2>/dev/null || which -a python 2>/dev/null
   ```
5. Find binary, man page, and source for `grep`:
   ```bash
   whereis grep
   whereis -b grep
   whereis -m grep
   ```

**Hint:** `locate` reads a pre-built database (usually updated nightly by `updatedb`). Files created after the last `updatedb` run will not appear. `which` searches only your `$PATH`. `whereis` searches fixed standard directories regardless of your shell's `$PATH`.

**Self-check:** `which grep` should return `/usr/bin/grep` or `/bin/grep`.

---

## Exercise 8: Real-world Find Challenges

**Goal:** Solve practical administrative tasks with `find`.

**Steps:**
1. Find all empty files in /tmp:
   ```bash
   find /tmp -maxdepth 1 -type f -empty 2>/dev/null | head -5
   ```
2. Find the 5 most recently modified files in /etc:
   ```bash
   find /etc -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -5 | awk '{print $2}'
   ```
3. Find all shell scripts under /usr/bin:
   ```bash
   find /usr/bin -type f -exec file {} + | grep -i 'shell script' | head -10
   ```
4. Count files by extension under /etc:
   ```bash
   find /etc -type f 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -10
   ```
5. Find all directories world-writable (suspicious outside /tmp):
   ```bash
   find / -type d -perm -o+w 2>/dev/null | grep -v '/proc\|/sys\|/tmp\|/dev' | head -10
   ```

**Hint:** `-printf '%T@ %p\n'` prints the modification timestamp as a Unix epoch number followed by the path — sorting numerically on this field sorts by time. Step 5 is a real security audit technique.

**Self-check:** Step 1 — empty files exist if you ran `touch /tmp/m11/readme.txt` earlier without writing content to them.

---

Cleanup:
```bash
rm -rf /tmp/m11
```

Mark complete:
```bash
make done N=11
make next
```
