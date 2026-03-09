# Exercises — Mission 03: Linux Philosophy

Work through each exercise in your terminal. The goal is not just to run the commands — it's to understand *why* they work.

---

## Exercise 1: wc — Count Things

**Goal:** Use `wc` to measure files.

**Steps:**
1. Count lines in `/etc/passwd`: `wc -l /etc/passwd`
2. Count words in `/etc/hostname`: `wc -w /etc/hostname`
3. Count bytes in `/etc/hosts`: `wc -c /etc/hosts`
4. Count lines in three files at once: `wc -l /etc/passwd /etc/group /etc/hosts`

**Hint:** `wc` with multiple files prints a total line at the end.

**Self-check:** `wc -l /etc/passwd` and `grep -c '' /etc/passwd` should give the same number.

---

## Exercise 2: Pipelines with cut, sort, uniq

**Goal:** Extract structured data from `/etc/passwd` using a pipeline.

**Steps:**
1. Extract all usernames (field 1): `cut -d: -f1 /etc/passwd`
2. Extract all login shells (field 7): `cut -d: -f7 /etc/passwd`
3. Count how many users use each shell:
   ```bash
   cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn
   ```
4. Find unique home directory roots:
   ```bash
   cut -d: -f6 /etc/passwd | cut -d/ -f2 | sort -u
   ```

**Hint:** `sort -u` is shorthand for `sort | uniq`. `-rn` means reverse numeric sort (highest first).

**Self-check:** Does any shell appear more than once? Which is most common?

---

## Exercise 3: /dev — Device Files

**Goal:** Interact with virtual device files.

**Steps:**
1. List device files: `ls -lh /dev/null /dev/zero /dev/urandom`
2. Discard output silently: `ls /etc > /dev/null`
3. Check the exit code: `echo $?` (should be 0 — the command succeeded)
4. Generate random hex bytes:
   ```bash
   head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n'; echo
   ```

**Hint:** The first character in `ls -l` output for device files is `c` (character device) or `b` (block device), not `-` or `d`.

**Self-check:** `echo "anything" > /dev/null; echo $?` should print `0`.

---

## Exercise 4: /proc — The Kernel's Window

**Goal:** Read live system information directly from the kernel.

**Steps:**
1. See how long the system has been running: `cat /proc/uptime`
2. Find your CPU model: `grep -m1 "model name" /proc/cpuinfo`
3. Check RAM: `grep MemTotal /proc/meminfo`
4. Count CPU cores: `grep -c '^processor' /proc/cpuinfo`
5. See your shell's PID: `echo $$`
6. Read info about the current shell process: `cat /proc/$$/status | head -10`

**Hint:** The first number in `/proc/uptime` is seconds since boot. Divide by 3600 for hours.

**Self-check:** Does `grep -c '^processor' /proc/cpuinfo` match what you know about your CPU?

---

## Exercise 5: tr — Translate Characters

**Goal:** Use `tr` to transform text streams.

**Steps:**
1. Uppercase a string: `echo "hello world" | tr a-z A-Z`
2. Replace spaces with newlines: `echo "one two three" | tr ' ' '\n'`
3. Squeeze repeated spaces: `echo "too    many    spaces" | tr -s ' '`
4. Delete newlines: `printf "line1\nline2\nline3\n" | tr -d '\n'; echo`
5. Convert hostname to uppercase: `cat /etc/hostname | tr a-z A-Z`

**Hint:** `tr` only reads from stdin — you always pipe into it or use `< file`.

**Self-check:** `echo "abc" | tr a-z A-Z` should print `ABC`.

---

## Exercise 6: Build a Pipeline from Scratch

**Goal:** Answer a question about the system by composing tools.

**Question:** What are the 5 longest usernames in `/etc/passwd`?

**Build it step by step:**
```bash
# Step 1: extract usernames
cut -d: -f1 /etc/passwd

# Step 2: measure the length of each username
cut -d: -f1 /etc/passwd | awk '{print length, $0}'

# Step 3: sort by length (numeric, reverse)
cut -d: -f1 /etc/passwd | awk '{print length, $0}' | sort -rn

# Step 4: show just the top 5
cut -d: -f1 /etc/passwd | awk '{print length, $0}' | sort -rn | head -5
```

**Hint:** Build one stage at a time. Make sure each step looks right before adding the next `|`.

**Self-check:** The first column should show the character count of each username.

---

## Exercise 7: /proc — Per-Process (Stretch)

**Goal:** Inspect a running process through `/proc`.

**Steps:**
1. Find the PID of your shell: `echo $$`
2. List everything in your shell's `/proc` entry: `ls /proc/$$`
3. Read the command line: `cat /proc/$$/cmdline | tr '\0' ' '`
4. See open file descriptors: `ls -lh /proc/$$/fd`
5. Find your shell's working directory: `readlink /proc/$$/cwd`

**Hint:** File descriptor 0 = stdin, 1 = stdout, 2 = stderr. These show up as symlinks in `/proc/$$/fd/`.

**Self-check:** `readlink /proc/$$/cwd` should match `pwd`.

---

When done, mark this mission complete:

```bash
make done N=03
make next
```
