# Exercises — Mission 17: Shell Scripting

---

## Exercise 1: Your First Script

**Goal:** Write, make executable, and run a minimal shell script.

**Setup:**
```bash
mkdir -p /tmp/mission17
```

**Steps:**
1. Create the script file:
   ```bash
   cat > /tmp/mission17/hello.sh << 'EOF'
   #!/bin/bash
   echo "Hello from a shell script"
   echo "Today is: $(date +%F)"
   echo "Running as: $USER on $(hostname)"
   EOF
   ```
2. Check that it is not yet executable:
   ```bash
   ls -l /tmp/mission17/hello.sh
   ```
3. Make it executable:
   ```bash
   chmod +x /tmp/mission17/hello.sh
   ```
4. Run it:
   ```bash
   /tmp/mission17/hello.sh
   ```
5. Run it explicitly with bash (no execute bit needed):
   ```bash
   bash /tmp/mission17/hello.sh
   ```

**Hint:** The shebang (`#!/bin/bash`) on line 1 tells the kernel which interpreter to use. Without it, the script runs in `/bin/sh`, which may behave differently. Always include it.

**Self-check:** Running the script should print three lines: the greeting, today's date, and your username and hostname.

---

## Exercise 2: Variables

**Goal:** Declare, use, and safely quote variables.

**Steps:**
1. Create a script with variables:
   ```bash
   cat > /tmp/mission17/variables.sh << 'EOF'
   #!/bin/bash

   # Variable declaration (no spaces around =)
   NAME="Alice"
   AGE=30
   TODAY=$(date +%F)

   # Safe usage: always quote variables
   echo "Name: $NAME"
   echo "Age: $AGE"
   echo "Today: $TODAY"

   # Variable in a string (braces for clarity)
   echo "File: ${NAME}_report.txt"

   # Unquoted variable: dangerous with spaces
   FILENAME="my file.txt"
   echo "Without quotes: $FILENAME"    # may be split by shell
   echo "With quotes: \"$FILENAME\""  # safe
   EOF
   chmod +x /tmp/mission17/variables.sh
   bash /tmp/mission17/variables.sh
   ```
2. Understand the substitution forms:
   - `$VAR` — use variable value
   - `${VAR}` — unambiguous boundaries (e.g., `${VAR}suffix`)
   - `$(command)` — command substitution
   - `$((math))` — arithmetic
3. Demonstrate arithmetic:
   ```bash
   X=10; Y=3
   echo "Sum: $((X + Y))"
   echo "Quotient: $((X / Y))"
   echo "Remainder: $((X % Y))"
   ```
4. Read-only variables:
   ```bash
   readonly PI=3.14159
   PI=3   # should fail
   ```
5. Unset a variable:
   ```bash
   TEMP="hello"
   echo $TEMP
   unset TEMP
   echo "${TEMP:-default}"   # prints "default" when TEMP is unset
   ```

**Hint:** Never put spaces around `=` when assigning variables. `VAR=value` is correct; `VAR = value` is wrong (it tries to run `VAR` as a command with arguments). Always quote `"$VAR"` to prevent word splitting and glob expansion.

**Self-check:** The `readonly PI=3.14159` followed by `PI=3` should print an error like "PI: readonly variable".

---

## Exercise 3: Positional Parameters

**Goal:** Write a script that uses command-line arguments.

**Steps:**
1. Create a script using positional parameters:
   ```bash
   cat > /tmp/mission17/greet.sh << 'EOF'
   #!/bin/bash
   # Usage: ./greet.sh NAME GREETING

   echo "Script name: $0"
   echo "First argument: $1"
   echo "Second argument: $2"
   echo "All arguments: $@"
   echo "Number of arguments: $#"

   if [[ $# -lt 2 ]]; then
     echo "Error: need at least 2 arguments"
     exit 1
   fi

   echo "$2, $1!"
   EOF
   chmod +x /tmp/mission17/greet.sh
   ```
2. Run with arguments:
   ```bash
   bash /tmp/mission17/greet.sh Alice "Good morning"
   ```
3. Run with too few arguments:
   ```bash
   bash /tmp/mission17/greet.sh Alice
   echo "Exit code: $?"
   ```
4. Iterate over all arguments:
   ```bash
   cat > /tmp/mission17/listargs.sh << 'EOF'
   #!/bin/bash
   for arg in "$@"; do
     echo "  Argument: $arg"
   done
   EOF
   bash /tmp/mission17/listargs.sh alpha beta "gamma delta" epsilon
   ```
5. Shift arguments:
   ```bash
   bash -c '
   echo "Before shift: $1 $2 $3"
   shift
   echo "After shift:  $1 $2"
   ' -- first second third
   ```

**Hint:** Always use `"$@"` (quoted) to pass all arguments safely. `$*` joins all arguments into one string — which breaks arguments containing spaces. `"$@"` preserves each argument as a separate word.

**Self-check:** Step 4 with `"gamma delta"` as one argument should print it on a single line: `Argument: gamma delta`.

---

## Exercise 4: Conditionals — if/then/else

**Goal:** Use `[[ ]]` to test conditions and branch.

**Steps:**
1. Basic if/else:
   ```bash
   cat > /tmp/mission17/check-file.sh << 'EOF'
   #!/bin/bash
   FILE="$1"

   if [[ -z "$FILE" ]]; then
     echo "Error: no filename given"
     exit 1
   fi

   if [[ -f "$FILE" ]]; then
     echo "$FILE exists and is a regular file"
     echo "Size: $(wc -c < "$FILE") bytes"
   elif [[ -d "$FILE" ]]; then
     echo "$FILE is a directory"
     echo "Contains: $(ls "$FILE" | wc -l) entries"
   else
     echo "$FILE does not exist"
     exit 1
   fi
   EOF
   chmod +x /tmp/mission17/check-file.sh
   bash /tmp/mission17/check-file.sh /etc/hostname
   bash /tmp/mission17/check-file.sh /etc
   bash /tmp/mission17/check-file.sh /nonexistent
   ```
2. String comparisons:
   ```bash
   A="hello"; B="world"
   [[ "$A" == "$B" ]] && echo "equal" || echo "not equal"
   [[ "$A" != "$B" ]] && echo "different"
   [[ -z "" ]]        && echo "empty string"
   [[ -n "text" ]]    && echo "non-empty string"
   ```
3. Numeric comparisons:
   ```bash
   X=10; Y=5
   [[ $X -gt $Y ]] && echo "$X is greater than $Y"
   [[ $X -ne $Y ]] && echo "$X is not equal to $Y"
   ```
4. Compound conditions:
   ```bash
   [[ -f /etc/hostname && -r /etc/hostname ]] && echo "hostname is readable"
   [[ -f /nonexistent || -f /etc/hostname ]] && echo "at least one exists"
   ```
5. The case statement:
   ```bash
   DAY=$(date +%u)   # 1=Monday ... 7=Sunday
   case $DAY in
     1|2|3|4|5) echo "Weekday" ;;
     6|7)       echo "Weekend" ;;
     *)         echo "Unknown" ;;
   esac
   ```

**Test operators — common list:**
| Test | True when |
|------|-----------|
| `-f file` | file is a regular file |
| `-d file` | file is a directory |
| `-e file` | file exists (any type) |
| `-r file` | file is readable |
| `-x file` | file is executable |
| `-z "$str"` | string is empty |
| `-n "$str"` | string is non-empty |
| `"$a" == "$b"` | strings are equal |
| `$n -gt $m` | n is greater than m |
| `$n -lt $m` | n is less than m |

**Self-check:** Step 1 — running with `/etc/hostname` should print "exists and is a regular file". Running with `/etc` should print "is a directory".

---

## Exercise 5: Loops

**Goal:** Write for loops and while read loops.

**Steps:**
1. For loop over a list:
   ```bash
   for COLOR in red green blue; do
     echo "Color: $COLOR"
   done
   ```
2. For loop over a range:
   ```bash
   for i in {1..5}; do
     echo "Item $i"
   done
   ```
3. For loop over files:
   ```bash
   for FILE in /etc/*.conf; do
     echo "Config: $FILE ($(wc -l < "$FILE") lines)"
   done | head -5
   ```
4. While read loop (process a file line by line):
   ```bash
   cat > /tmp/mission17/servers.txt << 'EOF'
   web01
   web02
   db01
   EOF

   while IFS= read -r SERVER; do
     echo "Checking: $SERVER"
   done < /tmp/mission17/servers.txt
   ```
5. While loop with a counter:
   ```bash
   COUNT=0
   while [[ $COUNT -lt 3 ]]; do
     echo "Count: $COUNT"
     COUNT=$((COUNT + 1))
   done
   ```

**Hint:** Use `while IFS= read -r line` for reading files line by line. `IFS=` prevents leading/trailing whitespace stripping. `-r` prevents backslash interpretation. This is the correct pattern — not `for line in $(cat file)` which breaks on spaces.

**Self-check:** Step 4 should print exactly three "Checking:" lines, one per server name in the file.

---

## Exercise 6: Functions

**Goal:** Define and call reusable functions.

**Steps:**
1. Define and call a function:
   ```bash
   cat > /tmp/mission17/functions.sh << 'EOF'
   #!/bin/bash

   log() {
     echo "[$(date +%T)] $*"
   }

   greet() {
     local NAME="$1"
     if [[ -z "$NAME" ]]; then
       NAME="World"
     fi
     echo "Hello, $NAME!"
   }

   add() {
     local RESULT=$(( $1 + $2 ))
     echo "$RESULT"   # functions return values via echo
   }

   log "Script started"
   greet "Alice"
   greet             # uses default "World"
   SUM=$(add 5 3)
   log "5 + 3 = $SUM"
   EOF
   bash /tmp/mission17/functions.sh
   ```
2. Key function rules:
   - Use `local` for variables inside functions to avoid polluting global scope
   - Functions return an exit code (0–255), not a value
   - Return a value by echoing it and capturing with `$(func_name)`
3. Function exit codes:
   ```bash
   is_even() {
     [[ $(( $1 % 2 )) -eq 0 ]]   # exits 0 if true, 1 if false
   }

   is_even 4 && echo "4 is even"
   is_even 7 || echo "7 is odd"
   ```
4. Error-handling function pattern:
   ```bash
   die() {
     echo "ERROR: $*" >&2
     exit 1
   }

   [[ -f /etc/hostname ]] || die "hostname file missing"
   echo "OK"
   ```

**Hint:** Functions in Bash do not have a `return value` like in other languages. Use `echo` to output data, and capture it with `$(func)`. Use `return N` to set the exit code (0 = success, non-zero = failure).

**Self-check:** Step 3 — `is_even 4` returns exit code 0 (true), `is_even 7` returns 1 (false). The `&&` and `||` operators test these exit codes.

---

## Exercise 7: Error Handling — set -euo pipefail and trap

**Goal:** Make scripts fail safely and clean up after themselves.

**Steps:**
1. Demonstrate unsafe default behavior:
   ```bash
   bash -c '
   echo "before"
   ls /nonexistent    # error — but script continues by default
   echo "after"       # this still runs — dangerous
   '
   ```
2. Enable strict mode:
   ```bash
   bash -c '
   set -euo pipefail
   echo "before"
   ls /nonexistent    # error — script exits here
   echo "after"       # this NEVER runs
   '
   echo "Script exited with code: $?"
   ```
3. Understand each flag:
   - `set -e` — exit on any error
   - `set -u` — treat undefined variables as errors
   - `set -o pipefail` — pipeline fails if any command in it fails
4. Use trap for cleanup:
   ```bash
   cat > /tmp/mission17/trap-demo.sh << 'EOF'
   #!/bin/bash
   set -euo pipefail

   TMPFILE=$(mktemp)
   trap 'rm -f "$TMPFILE"; echo "cleanup done"' EXIT

   echo "Working with: $TMPFILE"
   echo "data" > "$TMPFILE"
   cat "$TMPFILE"
   # TMPFILE is automatically deleted when script exits (even on error)
   EOF
   bash /tmp/mission17/trap-demo.sh
   ```
5. The `||` fallback pattern (safe alternative to `set -e`):
   ```bash
   mkdir /tmp/mission17/newdir || { echo "Error: could not create directory" >&2; exit 1; }
   ```

**Hint:** Always put `set -euo pipefail` at the top of every script. It turns off dangerous silent failures that cause scripts to continue in a broken state. `trap 'cleanup' EXIT` runs on any exit — normal or error.

**Self-check:** Step 2 — the script exits after `ls /nonexistent` with a non-zero code. "after" is never printed.

---

## Exercise 8: Build the Backup Script

**Goal:** Combine everything into a complete, production-style backup script.

**Steps:**
1. Write the full script:
   ```bash
   cat > /tmp/mission17/backup.sh << 'SCRIPT'
   #!/bin/bash
   # backup.sh — create a timestamped tar.gz backup
   # Usage: backup.sh SOURCE_DIR BACKUP_DIR
   set -euo pipefail

   # --- functions ---
   log() { echo "[$(date +%T)] $*"; }
   die() { echo "ERROR: $*" >&2; exit 1; }

   # --- validate arguments ---
   [[ $# -eq 2 ]] || die "Usage: $0 SOURCE BACKUP_DIR"

   SOURCE="$1"
   BACKUP_DIR="$2"
   TIMESTAMP=$(date +%Y%m%d-%H%M%S)
   ARCHIVE="${BACKUP_DIR}/backup-${TIMESTAMP}.tar.gz"
   LOGFILE="${BACKUP_DIR}/backup.log"

   # --- validate source ---
   [[ -d "$SOURCE" ]] || die "Source directory not found: $SOURCE"

   # --- create backup dir if needed ---
   mkdir -p "$BACKUP_DIR"

   # --- cleanup on exit ---
   trap 'log "Script finished (exit code: $?)"' EXIT

   # --- run backup ---
   log "Starting backup of $SOURCE"
   tar -czf "$ARCHIVE" "$SOURCE" 2>/dev/null
   SIZE=$(du -sh "$ARCHIVE" | cut -f1)
   log "Created $ARCHIVE ($SIZE)"
   echo "$(date +%F) $ARCHIVE $SIZE" >> "$LOGFILE"
   log "Done"
   SCRIPT
   chmod +x /tmp/mission17/backup.sh
   ```
2. Run it:
   ```bash
   bash /tmp/mission17/backup.sh /etc/apt /tmp/mission17/backups
   ```
3. Verify the result:
   ```bash
   ls -lh /tmp/mission17/backups/
   cat /tmp/mission17/backups/backup.log
   ```
4. Test error handling — wrong source:
   ```bash
   bash /tmp/mission17/backup.sh /nonexistent /tmp/mission17/backups
   echo "Exit code: $?"
   ```
5. Test error handling — too few arguments:
   ```bash
   bash /tmp/mission17/backup.sh
   echo "Exit code: $?"
   ```

**Self-check:** Steps 4 and 5 should print an error message to stderr and exit with a non-zero code. Step 2 should create a `.tar.gz` file and a `backup.log` entry.

---

Cleanup:
```bash
rm -rf /tmp/mission17
```

Mark complete:
```bash
make done N=17
```
