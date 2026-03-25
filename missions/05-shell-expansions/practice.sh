#!/bin/bash
# =============================================================================
#  Mission 05 — Shell Expansions
# =============================================================================
set -uo pipefail
COURSE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"

SCRATCH="/tmp/mission05"
mkdir -p "$SCRATCH"

init_mission "05" "Shell Expansions" 9

# =============================================================================
step "Expansion — bash rewrites your command before running it"
set_hint "Try: echo *.txt in a directory with .txt files — bash expands the glob before echo sees it"

explain "Before bash runs your command, it transforms it.
This transformation is called expansion.

  echo *.txt

bash finds all matching files and replaces *.txt with their names.
echo never sees the glob — it sees a list of filenames.

Understanding this prevents confusion about why certain things work
or don't work the way you expect."

demo 'touch /tmp/mission05/{a,b,c}.txt && ls /tmp/mission05/' \
     "Create some .txt files to work with:"

demo 'echo /tmp/mission05/*.txt' \
     "bash expands *.txt — echo sees actual filenames:"

demo 'echo "/tmp/mission05/*.txt"' \
     "In quotes, the glob is NOT expanded — echo sees the literal string:"

try "Run: echo /tmp/mission05/*.txt  (without quotes)" \
    "echo /tmp/mission05/*.txt"

checkpoint \
  "What is the difference between: echo *.txt  and  echo '*.txt' ?" \
  "Without quotes, bash expands *.txt to matching filenames before echo runs.
With quotes, the shell treats * as a literal character — echo prints '*.txt'."

# =============================================================================
step "Glob — * matches anything"
set_hint "* matches any string including empty string.
Try: ls /etc/*.conf  or  ls /etc/ssh/*"

explain "The * glob matches any sequence of characters (including none).

  *.txt        any file ending in .txt
  log*         any file starting with 'log'
  /etc/*.conf  all .conf files in /etc"

demo 'ls /etc/*.conf 2>/dev/null | head -10' \
     "All .conf files in /etc:"

demo 'ls /usr/bin/py*' \
     "All binaries starting with 'py' in /usr/bin:"

try_match "List all files in /etc that end in .conf" \
          "ls /etc/*.conf 2>/dev/null | wc -l" \
          "^[0-9]"

note "* does not match hidden files (dotfiles).
To include them: ls -A .*  or use dotglob shell option."

# =============================================================================
step "Glob — ? and [...]"
set_hint "? matches exactly ONE character.
[abc] matches one character from the set.
Try: ls /dev/sd?  or  ls /dev/tty[0-9]"

explain "Beyond *, globs have two more patterns:

  ?         exactly one character
  [abc]     one character: a, b, or c
  [a-z]     one character in range a–z
  [!abc]    one character NOT in the set"

demo 'ls /dev/sd? 2>/dev/null || echo "(no /dev/sd? found)"' \
     "/dev/sd? — block devices with single-char suffix:"

demo 'ls /dev/tty[0-9] 2>/dev/null | head -5' \
     "/dev/tty followed by one digit:"

demo 'ls /tmp/mission05/[ab].txt' \
     "Files named a.txt or b.txt:"

try "List files in /tmp/mission05/ that are named exactly one letter + .txt" \
    "ls /tmp/mission05/?.txt"

# =============================================================================
step "Brace expansion — generating lists"
set_hint "Brace expansion generates words before any file matching happens.
Try: echo {a,b,c}   or   echo {1..5}"

explain "Brace expansion generates a list of words.
It happens BEFORE glob expansion — so the results don't need to exist.

  {a,b,c}       → a b c
  file{1,2,3}   → file1 file2 file3
  {1..5}        → 1 2 3 4 5
  {a..e}        → a b c d e
  {01..05}      → 01 02 03 04 05   (zero-padded)"

demo 'echo {a,b,c}' \
     "Simple list:"

demo 'echo file{1,2,3}.txt' \
     "Filename pattern:"

demo 'echo {1..10}' \
     "Numeric sequence:"

demo 'echo {a..f}' \
     "Letter sequence:"

try "Use brace expansion to create 5 numbered files at once" \
    "touch /tmp/mission05/report{1..5}.txt && ls /tmp/mission05/report*.txt"

# =============================================================================
step "Brace expansion — creating directory trees"
set_hint "mkdir -p project/{src,tests,docs}   creates all three dirs at once.
The -p flag prevents errors if they already exist."

explain "Brace expansion makes directory and file creation concise:

  mkdir -p project/{src,tests,docs}
  touch project/src/{main.sh,utils.sh}

Without brace expansion you would need three mkdir commands."

demo 'mkdir -p /tmp/mission05/project/{src,tests,docs} && find /tmp/mission05/project -type d' \
     "Create a directory tree in one command:"

demo 'touch /tmp/mission05/project/src/{main.sh,utils.sh,config.sh} && ls /tmp/mission05/project/src/' \
     "Create multiple files at once:"

try "Create a project layout with frontend/ and backend/ subdirectories, each with a README.md" \
    "mkdir -p /tmp/mission05/app/{frontend,backend} && touch /tmp/mission05/app/{frontend,backend}/README.md && find /tmp/mission05/app"

# =============================================================================
step "Command substitution — \$()"
set_hint "Syntax: \$(command)
The output of the command replaces the \$() in the line.
Try: echo \"Today is \$(date +%F)\""

explain "Command substitution runs a command and inserts its output
into the current command.

  \$(command)    preferred — nests cleanly
  \`command\`    older syntax — avoid, it doesn't nest well

Examples:
  echo \"Hello, \$(whoami)\"
  LOG=\"backup-\$(date +%Y%m%d).tar.gz\"
  echo \"There are \$(wc -l < /etc/passwd) users\""

demo 'echo "Hello, $(whoami)! Today is $(date +%F)."' \
     "Two substitutions in one string:"

demo 'echo "There are $(wc -l < /etc/passwd) lines in /etc/passwd"' \
     "Embed a count:"

demo 'STAMP=$(date +%Y%m%d_%H%M%S) && echo "Backup: backup-${STAMP}.tar.gz"' \
     "Use substitution to build a timestamped filename:"

try "Print a sentence: 'I am <username> on <hostname>'" \
    "echo \"I am \$(whoami) on \$(hostname)\""

# =============================================================================
step "Arithmetic expansion — \$(())"
set_hint "Syntax: \$((expression))
Try: echo \$((2 + 3))  or  echo \$((10 % 3))"

explain "Arithmetic expansion evaluates integer math.

  echo \$((2 + 3))      # 5
  echo \$((10 / 3))     # 3  (integer division — no fractions)
  echo \$((10 % 3))     # 1  (remainder / modulo)
  x=5; echo \$((x * x)) # 25

Variables inside \$(()) don't need a \$ prefix."

demo 'echo $((2 + 3))' \
     "Addition:"

demo 'echo $((10 / 3))' \
     "Integer division (result is 3, not 3.33):"

demo 'echo $((10 % 3))' \
     "Modulo (remainder):"

demo 'x=7; echo $((x * x))' \
     "Use a variable:"

demo 'echo "Lines in /etc/passwd: $(wc -l < /etc/passwd) — times 2: $(( $(wc -l < /etc/passwd) * 2 ))"' \
     "Combine command substitution and arithmetic:"

try "Calculate 100 divided by 7 and show the remainder" \
    "echo \$((100 / 7)) remainder \$((100 % 7))"

# =============================================================================
step "Variable expansion — \${VAR} and safe patterns"
set_hint "Always use \${VAR} when the variable name is followed by more text.
\${VAR:-default} gives a fallback when VAR is unset or empty."

explain "Beyond simple \$VAR, bash has powerful expansion forms:

  \${VAR}          unambiguous variable reference
  \${VAR:-default} use 'default' if VAR is unset or empty
  \${#VAR}         length of VAR's value
  \${VAR%pattern}  strip shortest match from end
  \${VAR##pattern} strip longest match from start"

demo 'FILE="report.2024.txt" && echo ${FILE%.txt}' \
     "Strip .txt suffix (shortest match from end):"

demo 'FILE="report.2024.txt" && echo ${FILE##*.}' \
     "Extract extension (strip everything up to last dot):"

demo 'NAME="" && echo ${NAME:-anonymous}' \
     "Fallback when variable is empty:"

demo 'MSG="hello" && echo ${#MSG}' \
     "Length of a variable:"

try "Given FILE='backup-2024-01-15.tar.gz', print just the date part (strip 'backup-' and '.tar.gz')" \
    'FILE="backup-2024-01-15.tar.gz" && echo ${FILE#backup-} | sed "s/.tar.gz//"'

# =============================================================================
step "Tilde expansion — ~ and ~user"
set_hint "~ always expands to your home directory.
~username expands to that user's home directory."

explain "~ expands to the current user's home directory.
~username expands to that user's home directory.

  echo ~           → /home/yourname
  echo ~root       → /root
  ls ~/Documents   → list your Documents folder

Tilde expansion only works at the start of a word or after :.
  PATH=~/bin:\$PATH   works
  PATH=\"~/bin\"       does NOT work (quotes prevent expansion)"

demo 'echo ~' \
     "Your home directory:"

demo 'echo ~root' \
     "Root's home directory:"

demo 'ls ~/.' \
     "List your home directory via tilde:"

try_match "Print your home directory using tilde expansion" \
          "echo ~" \
          "/home"

tip "Tilde inside double quotes is treated as a literal ~.
Always use ~ outside quotes: cd ~/Documents   not   cd \"~/Documents\""

checkpoint \
  "What happens when you write PATH=\"~/bin:\$PATH\"?" \
  "The tilde is inside double quotes, so bash treats it as a literal ~.
PATH ends up with '~/bin' as a string, not '/home/yourname/bin'.
The shell cannot find commands there. Always write: PATH=~/bin:\$PATH"

# =============================================================================
# Cleanup
rm -rf "$SCRATCH"

mission_complete
