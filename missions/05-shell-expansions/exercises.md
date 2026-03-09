# Exercises — Mission 05: Shell Expansions

---

## Exercise 1: Glob Patterns

**Goal:** Match files with `*`, `?`, and `[...]`.

**Setup:**
```bash
mkdir -p /tmp/m05 && cd /tmp/m05
touch file1.txt file2.txt file3.log report.txt README.md .hidden
```

**Steps:**
1. List all `.txt` files: `ls *.txt`
2. List files starting with `file`: `ls file*`
3. List files with exactly one character before `.txt`: `ls ?.txt`
4. List files whose name starts with a letter a–r: `ls [a-r]*`
5. List all files including hidden ones: `ls -a`
6. List only dotfiles: `ls .??*` (? ensures at least 2 chars after the dot)

**Hint:** Globs match files in the current directory. They don't match hidden files unless the pattern starts with `.`.

**Self-check:** `ls *.txt` should show `file1.txt file2.txt report.txt`. `ls ?.txt` should show nothing (no single-character basenames).

---

## Exercise 2: Brace Expansion

**Goal:** Generate words and create file structures with brace expansion.

**Steps:**
1. Generate a list: `echo {a,b,c,d}`
2. Generate numbered names: `echo item{1..5}.txt`
3. Create a directory tree:
   ```bash
   mkdir -p /tmp/m05/project/{src,tests,docs,scripts}
   ls /tmp/m05/project/
   ```
4. Create multiple files at once:
   ```bash
   touch /tmp/m05/project/src/{main.sh,utils.sh,config.sh}
   ls /tmp/m05/project/src/
   ```
5. Create zero-padded sequences: `echo log{001..005}.txt`

**Hint:** Brace expansion happens before globs — the results don't need to exist as files. You can generate names that will be created.

**Self-check:** `ls /tmp/m05/project/` should show 4 directories.

---

## Exercise 3: Command Substitution

**Goal:** Use `$()` to embed command output inside another command.

**Steps:**
1. Echo a sentence using command substitution:
   ```bash
   echo "I am $(whoami) on $(hostname)"
   ```
2. Count files in /etc:
   ```bash
   echo "There are $(ls /etc | wc -l) entries in /etc"
   ```
3. Build a timestamped filename:
   ```bash
   BACKUP="backup-$(date +%Y%m%d).tar.gz"
   echo $BACKUP
   ```
4. Use it in a path:
   ```bash
   echo "My home is $(echo ~)"
   echo "Shell is $(basename $SHELL)"
   ```

**Hint:** `$()` nests cleanly: `$(echo $(whoami))` works. Backticks `` `cmd` `` don't nest well — prefer `$()`.

**Self-check:** `BACKUP="backup-$(date +%Y%m%d).tar.gz"` — `echo $BACKUP` should show today's date in the filename.

---

## Exercise 4: Arithmetic Expansion

**Goal:** Do integer math in the shell.

**Steps:**
1. Basic math: `echo $((3 + 4)) $((10 - 6)) $((5 * 5)) $((17 / 3))`
2. Modulo: `echo $((17 % 3))`
3. Use variables:
   ```bash
   WIDTH=80
   HEIGHT=24
   echo "Area: $((WIDTH * HEIGHT))"
   ```
4. Count something and double it:
   ```bash
   USERS=$(wc -l < /etc/passwd)
   echo "Users: $USERS, doubled: $((USERS * 2))"
   ```

**Hint:** Division in `$(())` is always integer — it truncates, not rounds. For floating point: `echo "scale=2; 10/3" | bc`

**Self-check:** `echo $((17 / 3))` should print `5`, and `echo $((17 % 3))` should print `2`.

---

## Exercise 5: Variable Expansion Tricks

**Goal:** Use `${VAR}` forms to manipulate strings without external tools.

**Steps:**
1. Strip a suffix:
   ```bash
   FILE="report.txt"
   echo ${FILE%.txt}    # report
   ```
2. Extract an extension:
   ```bash
   FILE="archive.tar.gz"
   echo ${FILE##*.}     # gz
   ```
3. Use a default value:
   ```bash
   NAME=""
   echo ${NAME:-"anonymous"}
   NAME="ahmed"
   echo ${NAME:-"anonymous"}
   ```
4. Get string length:
   ```bash
   STR="hello world"
   echo ${#STR}
   ```
5. Strip a prefix:
   ```bash
   PATH_VAR="/usr/local/bin/python3"
   echo ${PATH_VAR##*/}    # just the filename: python3
   ```

**Hint:**
- `%pattern` strips from the end (shortest match)
- `%%pattern` strips from the end (longest match)
- `#pattern` strips from the start (shortest match)
- `##pattern` strips from the start (longest match)

**Self-check:** Given `FILE="photo.2024.jpg"`, `${FILE%%.*}` should print `photo` and `${FILE##*.}` should print `jpg`.

---

## Exercise 6: Quoting and Expansion

**Goal:** Understand when expansion happens and when quoting stops it.

**Steps:**
1. Unquoted glob:
   ```bash
   ls /etc/*.conf | head -3
   ```
2. Single-quoted — no expansion:
   ```bash
   echo '*.conf means any .conf file'
   echo 'The $HOME variable holds your home directory'
   ```
3. Double-quoted — variable and command substitution work, globs don't:
   ```bash
   echo "My home is $HOME"
   echo "Today: $(date +%F)"
   echo "Pattern: *.conf"   # glob not expanded inside quotes
   ```
4. When tilde fails inside quotes:
   ```bash
   echo "~"          # prints literal ~
   echo ~            # prints /home/yourname
   ```

**Hint:** Single quotes prevent ALL expansion. Double quotes allow `$VAR`, `$()`, and `$(()), but suppress glob and brace expansion.

**Self-check:** `echo '$HOME'` should print `$HOME`. `echo "$HOME"` should print your actual home path.

---

When done, mark this mission complete:

```bash
make done N=05
make next
```
