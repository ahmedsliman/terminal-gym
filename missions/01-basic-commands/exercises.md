# Exercises — Mission 01: Basic Commands

Work through each exercise in your terminal. Use `man` or `--help` freely — that's how real Linux users work.

---

## Exercise 1: Explore Your Environment

**Goal:** Know who you are, where you are, and what machine you're on.

**Steps:**
1. Print your username
2. Print your machine's hostname
3. Print the full current working directory path
4. Show your network IP address

**Hint:** `whoami`, `hostname`, `pwd`, `ip a` (look for `inet` lines)

**Self-check:** `echo $USER` should match `whoami`. `hostname -I` gives you a quick IP list.

---

## Exercise 2: List Files Like a Pro

**Goal:** Understand what `ls` flags do and how to read the output.

**Steps:**
1. List your home directory: `ls ~`
2. Add flags one at a time and observe what changes:
   - `-l` (long format)
   - `-a` (show hidden files)
   - `-h` (human-readable sizes)
   - `-F` (classify entries with symbols)
3. Combine them: `ls -alhF ~`

**Hint:** Files starting with `.` are hidden (dotfiles). Entries ending in `/` are directories, `*` are executables, `@` are symlinks.

**Self-check:** How many hidden files are in your home directory? Count entries starting with `.` in `ls -a ~`.

---

## Exercise 3: Binary or Built-in?

**Goal:** Distinguish external commands from shell built-ins.

**Steps:**
1. Run `type -a ls` — note the output
2. Run `type -a cd` — note the output
3. Run `type -a echo` — it may appear in both places
4. Try `man cd` — observe what happens
5. Try `help cd` — this works for built-ins

**Hint:** `type -a <cmd>` tells you every location where the shell can find a command.

**Self-check:** Can you explain why `man cd` has no entry?

---

## Exercise 4: Build a Mini Workspace

**Goal:** Create a structured directory tree using one command.

**Steps:**
1. Create this layout in `lab/`:
   ```
   lab/
   ├── docs/
   │   ├── file1.txt ... file5.txt
   │   └── readme.md
   └── logs/
       └── app.log
   ```
2. Commands:
   ```bash
   mkdir -p lab/{docs,logs}
   touch lab/docs/{file{1..5}.txt,readme.md}
   echo "hello world" > lab/logs/app.log
   ```
3. Verify the structure with `ls -lR lab/`

**Hint:** Brace expansion `{1..5}` expands to `1 2 3 4 5`. Commas separate alternatives.

**Self-check:** `ls lab/docs | wc -l` should print `6` (5 txt files + readme.md).

---

## Exercise 5: Exit Codes & True/False

**Goal:** Understand how commands signal success or failure.

**Steps:**
1. Run `true` then immediately `echo $?` — note the result
2. Run `false` then immediately `echo $?` — note the result
3. Run `ls /nonexistent` then `echo $?`
4. Run `ls /etc` then `echo $?`

**Hint:** `$?` holds the exit code of the **last command only**. It is overwritten every time.

**Self-check:** Exit code `0` = success, anything else = failure. This is how shell scripts make decisions.

---

## Exercise 6: Add a Script to PATH (Stretch)

**Goal:** Make a custom command available system-wide for your session.

**Steps:**
1. Create `lab/bin/hello` with this content:
   ```bash
   #!/bin/bash
   echo "Hello, $(whoami)! You are on $(hostname)."
   ```
2. Make it executable: `chmod +x lab/bin/hello`
3. Add `lab/bin` to PATH: `export PATH="$PWD/lab/bin:$PATH"`
4. Run `hello` from any directory

**Hint:** `$PWD` is your current directory. The PATH change lasts only for this shell session.

**Self-check:** `type -a hello` should now show the full path to your script.

---

When done, mark this mission complete:

```bash
make done N=01
make next
```
