# Solution — Mission 17: Shell Scripting

---

## Exercise 1: Your First Script

```bash
mkdir -p /tmp/mission17

cat > /tmp/mission17/hello.sh << 'EOF'
#!/bin/bash
echo "Hello from a shell script"
echo "Today is: $(date +%F)"
echo "Running as: $USER on $(hostname)"
EOF

ls -l /tmp/mission17/hello.sh
chmod +x /tmp/mission17/hello.sh
/tmp/mission17/hello.sh
bash /tmp/mission17/hello.sh
```

**Shebang options:**
| Shebang | Interpreter |
|---------|------------|
| `#!/bin/bash` | Bash — use this for bash-specific features |
| `#!/bin/sh` | POSIX sh — portable, but no Bash-isms |
| `#!/usr/bin/env bash` | Finds bash in PATH — more portable across systems |

Without a shebang, the kernel uses `/bin/sh`. `bash script.sh` ignores the shebang and always uses bash.

---

## Exercise 2: Variables

```bash
cat > /tmp/mission17/variables.sh << 'EOF'
#!/bin/bash
NAME="Alice"
AGE=30
TODAY=$(date +%F)
echo "Name: $NAME"
echo "Age: $AGE"
echo "Today: $TODAY"
echo "File: ${NAME}_report.txt"
FILENAME="my file.txt"
echo "Without quotes: $FILENAME"
echo "With quotes: \"$FILENAME\""
EOF
bash /tmp/mission17/variables.sh

X=10; Y=3
echo "Sum: $((X + Y))"
echo "Quotient: $((X / Y))"
echo "Remainder: $((X % Y))"

readonly PI=3.14159
PI=3   # error: PI: readonly variable

TEMP="hello"
unset TEMP
echo "${TEMP:-default}"   # prints: default
```

**Variable substitution forms:**
| Form | Meaning |
|------|---------|
| `$VAR` | Simple substitution |
| `${VAR}` | Explicit boundary (use before letters/digits) |
| `${VAR:-default}` | Use default if VAR is unset or empty |
| `${VAR:=default}` | Assign default if unset |
| `${VAR:?error}` | Error and exit if unset |
| `${#VAR}` | Length of VAR |
| `$(cmd)` | Command substitution |
| `$((expr))` | Arithmetic |

**The quoting rule:** Always write `"$VAR"`, not `$VAR`. Unquoted variables are subject to word splitting and glob expansion.

---

## Exercise 3: Positional Parameters

```bash
cat > /tmp/mission17/greet.sh << 'EOF'
#!/bin/bash
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

bash /tmp/mission17/greet.sh Alice "Good morning"
bash /tmp/mission17/greet.sh Alice   # exits with code 1

cat > /tmp/mission17/listargs.sh << 'EOF'
#!/bin/bash
for arg in "$@"; do
  echo "  Argument: $arg"
done
EOF
bash /tmp/mission17/listargs.sh alpha beta "gamma delta" epsilon
```

**Positional parameter variables:**
| Variable | Value |
|----------|-------|
| `$0` | Script name |
| `$1` … `$9` | First nine arguments |
| `${10}` … | Arguments 10+ (braces required) |
| `$#` | Number of arguments |
| `$@` | All arguments as separate words |
| `$*` | All arguments joined into one string |

`"$@"` always preserves argument boundaries. `"$*"` joins with `$IFS` separator. Use `"$@"` to forward arguments.

---

## Exercise 4: Conditionals — if/then/else

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

bash /tmp/mission17/check-file.sh /etc/hostname
bash /tmp/mission17/check-file.sh /etc
bash /tmp/mission17/check-file.sh /nonexistent

DAY=$(date +%u)
case $DAY in
  1|2|3|4|5) echo "Weekday" ;;
  6|7)       echo "Weekend" ;;
  *)         echo "Unknown" ;;
esac
```

**`[[ ]]` vs `[ ]`:**
- `[[ ]]` is Bash-specific, safer, supports `==`, `!=`, `=~` (regex), `&&`, `||` inside
- `[ ]` is POSIX, works in sh, but has quoting pitfalls
- Always use `[[ ]]` in Bash scripts

**String vs numeric comparison:**
```bash
[[ "$a" == "$b" ]]    # string equality
[[ $n -eq $m ]]       # numeric equality
[[ "$a" < "$b" ]]     # string lexicographic order
[[ $n -lt $m ]]       # numeric less-than
```

---

## Exercise 5: Loops

```bash
# List loop
for COLOR in red green blue; do
  echo "Color: $COLOR"
done

# Range loop
for i in {1..5}; do
  echo "Item $i"
done

# File glob loop
for FILE in /etc/*.conf; do
  echo "Config: $FILE ($(wc -l < "$FILE") lines)"
done | head -5

# While read loop
cat > /tmp/mission17/servers.txt << 'EOF'
web01
web02
db01
EOF

while IFS= read -r SERVER; do
  echo "Checking: $SERVER"
done < /tmp/mission17/servers.txt

# While with counter
COUNT=0
while [[ $COUNT -lt 3 ]]; do
  echo "Count: $COUNT"
  COUNT=$((COUNT + 1))
done
```

**Loop patterns:**
```bash
# Iterate over files safely (handles spaces in names)
for f in /path/*.txt; do
  [[ -f "$f" ]] || continue   # skip if no match
  process "$f"
done

# Read file line by line
while IFS= read -r line; do
  echo "Line: $line"
done < input.txt

# Process command output
while IFS= read -r line; do
  echo "PID: $line"
done < <(ps aux | awk '{print $2}' | tail -n +2)
```

**Never do:** `for line in $(cat file)` — breaks on whitespace and triggers globbing.

---

## Exercise 6: Functions

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
  echo "$RESULT"
}

log "Script started"
greet "Alice"
greet
SUM=$(add 5 3)
log "5 + 3 = $SUM"
EOF
bash /tmp/mission17/functions.sh

# Exit code pattern
is_even() {
  [[ $(( $1 % 2 )) -eq 0 ]]
}
is_even 4 && echo "4 is even"
is_even 7 || echo "7 is odd"

# die() pattern
die() {
  echo "ERROR: $*" >&2
  exit 1
}
[[ -f /etc/hostname ]] || die "hostname file missing"
```

**Function rules:**
| Rule | Detail |
|------|--------|
| `local VAR` | Scope variable to function — always use inside functions |
| `echo "$result"` | Return a value — capture with `$(func)` |
| `return N` | Set exit code (0=success, 1-255=error) |
| `$*` in function | All arguments passed to the function |

Functions must be defined before they are called (Bash reads top to bottom).

---

## Exercise 7: Error Handling — set -euo pipefail and trap

```bash
# Unsafe (default):
bash -c '
echo "before"
ls /nonexistent
echo "after"   # still runs — dangerous
'

# Safe (strict mode):
bash -c '
set -euo pipefail
echo "before"
ls /nonexistent   # exits here
echo "after"      # never runs
'

# trap for cleanup:
cat > /tmp/mission17/trap-demo.sh << 'EOF'
#!/bin/bash
set -euo pipefail
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"; echo "cleanup done"' EXIT
echo "Working with: $TMPFILE"
echo "data" > "$TMPFILE"
cat "$TMPFILE"
EOF
bash /tmp/mission17/trap-demo.sh

# || fallback:
mkdir /tmp/mission17/newdir || { echo "Error: could not create directory" >&2; exit 1; }
```

**Strict mode flags:**
| Flag | Effect |
|------|--------|
| `set -e` | Exit immediately when a command fails |
| `set -u` | Treat unset variables as errors |
| `set -o pipefail` | Fail if any command in a pipeline fails |
| `set -euo pipefail` | All three together |

**trap signals:**
```bash
trap 'cleanup_code' EXIT    # on any exit (normal or error)
trap 'cleanup_code' ERR     # on error only
trap 'cleanup_code' INT     # on Ctrl+C (SIGINT)
trap '' SIGPIPE             # ignore SIGPIPE
```

**`set -e` exceptions:** Commands in `if` conditions, `||`, `&&` chains, and `while`/`until` conditions are not subject to `set -e` — they are allowed to fail.

---

## Exercise 8: The Complete Backup Script

```bash
cat > /tmp/mission17/backup.sh << 'SCRIPT'
#!/bin/bash
set -euo pipefail

log() { echo "[$(date +%T)] $*"; }
die() { echo "ERROR: $*" >&2; exit 1; }

[[ $# -eq 2 ]] || die "Usage: $0 SOURCE BACKUP_DIR"

SOURCE="$1"
BACKUP_DIR="$2"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
ARCHIVE="${BACKUP_DIR}/backup-${TIMESTAMP}.tar.gz"
LOGFILE="${BACKUP_DIR}/backup.log"

[[ -d "$SOURCE" ]] || die "Source directory not found: $SOURCE"

mkdir -p "$BACKUP_DIR"

trap 'log "Script finished (exit code: $?)"' EXIT

log "Starting backup of $SOURCE"
tar -czf "$ARCHIVE" "$SOURCE" 2>/dev/null
SIZE=$(du -sh "$ARCHIVE" | cut -f1)
log "Created $ARCHIVE ($SIZE)"
echo "$(date +%F) $ARCHIVE $SIZE" >> "$LOGFILE"
log "Done"
SCRIPT

chmod +x /tmp/mission17/backup.sh
bash /tmp/mission17/backup.sh /etc/apt /tmp/mission17/backups
ls -lh /tmp/mission17/backups/
cat /tmp/mission17/backups/backup.log
bash /tmp/mission17/backup.sh /nonexistent /tmp/mission17/backups   # error
bash /tmp/mission17/backup.sh                                        # error
```

**Script structure checklist:**
```bash
#!/bin/bash              # 1. Shebang
set -euo pipefail        # 2. Strict mode
                         # 3. Helper functions (log, die)
                         # 4. Argument validation
                         # 5. Variable setup
                         # 6. Input validation
                         # 7. trap for cleanup
                         # 8. Main logic
```

---

## Quick Reference

```bash
#!/bin/bash                   shebang (always line 1)
set -euo pipefail             enable strict error handling
NAME="value"                  variable (no spaces around =)
"$NAME"                       always quote variables
${NAME:-default}              use default if unset
$(command)                    command substitution
$(( x + y ))                  arithmetic
$1 $2 ... $# $@ $0            positional parameters
[[ -f file ]]                 test: file is regular file
[[ -d dir ]]                  test: is directory
[[ -z "$str" ]]               test: string is empty
[[ $n -gt $m ]]               test: numeric greater than
if [[ ]]; then ... fi         conditional
for x in list; do ... done    for loop
while IFS= read -r line; do   read file line by line
  ...
done < file
local VAR                     scope variable to function
trap 'cleanup' EXIT           run cleanup on any exit
die() { echo "$*" >&2; exit 1; }   error and exit pattern
```
