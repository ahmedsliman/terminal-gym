#!/bin/bash
# =============================================================================
#  Mission 06 — Pipes & Redirection
# =============================================================================
set -uo pipefail
COURSE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"

SCRATCH="/tmp/mission06"
mkdir -p "$SCRATCH"

init_mission "06" "Pipes & Redirection" 9

# =============================================================================
step "stdin, stdout, stderr — three streams"
set_hint "Every process has FD 0 (stdin), 1 (stdout), 2 (stderr).
Try: ls /etc /doesnotexist   — stderr and stdout mixed on screen"

explain "Every process starts with three open streams:

  0   stdin   input  (keyboard by default)
  1   stdout  output (terminal by default)
  2   stderr  errors (terminal by default)

Both stdout and stderr go to your terminal screen.
Redirection separates them."

demo 'ls /etc /doesnotexist 2>/dev/null' \
     "Suppress stderr — only stdout is shown:"

demo 'ls /etc /doesnotexist 1>/dev/null' \
     "Suppress stdout — only stderr is shown:"

demo 'ls /etc /doesnotexist > /dev/null 2>&1' \
     "Suppress both — nothing shown:"

try "Run ls /etc /doesnotexist and suppress only the errors" \
    "ls /etc /doesnotexist 2>/dev/null | head -5"

checkpoint \
  "What is the difference between stdout (FD 1) and stderr (FD 2)?" \
  "stdout carries normal output — the results of a command.
stderr carries diagnostic messages — errors and warnings.
Both print to the terminal by default, which is why they look the same.
Separating them lets you redirect errors to a log while processing output."

# =============================================================================
step "> and >> — redirecting output to a file"
set_hint "> overwrites the file.
>> appends to the file.
Try: echo 'hello' > /tmp/mission06/out.txt && cat /tmp/mission06/out.txt"

explain "> redirects stdout to a file, replacing any existing content.
>> appends to the file (adds to the end without overwriting).

  command > file    overwrite
  command >> file   append"

demo "echo 'first line' > ${SCRATCH}/out.txt && cat ${SCRATCH}/out.txt" \
     "> creates/overwrites the file:"

demo "echo 'second line' >> ${SCRATCH}/out.txt && cat ${SCRATCH}/out.txt" \
     ">> appends without removing existing content:"

demo "echo 'overwrote it' > ${SCRATCH}/out.txt && cat ${SCRATCH}/out.txt" \
     "> again — the previous two lines are gone:"

try "Write a line to a file, append another, then read it back" \
    "echo 'line one' > ${SCRATCH}/mine.txt && echo 'line two' >> ${SCRATCH}/mine.txt && cat ${SCRATCH}/mine.txt"

warn "Using > on a file that already has important content destroys it.
Always check if a file exists before using > to write to it."

# =============================================================================
step "2> — redirecting stderr"
set_hint "2> redirects file descriptor 2 (stderr).
Try: ls /doesnotexist 2> /tmp/mission06/errors.txt && cat /tmp/mission06/errors.txt"

explain "2> redirects stderr (error output) to a file.
stdout still goes to the terminal.

  command 2> errors.txt     errors to file, output to screen
  command 2>> errors.log    append errors to log
  command 2> /dev/null      discard all errors silently"

demo "ls /doesnotexist 2> ${SCRATCH}/errors.txt; cat ${SCRATCH}/errors.txt" \
     "Capture stderr to a file:"

demo "ls /etc 2> ${SCRATCH}/errors.txt | wc -l" \
     "No error — stderr file stays empty, stdout is piped:"

try "Run ls on a nonexistent path and redirect the error to a file, then read that file" \
    "ls /nope 2> ${SCRATCH}/err.txt; cat ${SCRATCH}/err.txt"

# =============================================================================
step "2>&1 — merging stderr into stdout"
set_hint "2>&1 means 'send FD 2 to wherever FD 1 is going'.
It must come AFTER any > redirection.
Right: > file 2>&1    Wrong: 2>&1 > file"

explain "2>&1 redirects stderr to the same place as stdout.

  command > file 2>&1   both stdout and stderr go to file
  command 2>&1 | grep   stderr enters the pipe too

Order matters:
  > file 2>&1   first send stdout to file, then send stderr there too
  2>&1 > file   send stderr to OLD stdout (screen!), then stdout to file
                — common mistake — stderr still appears on screen"

demo "ls /etc /doesnotexist > ${SCRATCH}/combined.txt 2>&1 && cat ${SCRATCH}/combined.txt" \
     "Both stdout and stderr captured in one file:"

demo "ls /etc /doesnotexist 2>&1 | grep 'cannot'" \
     "Both streams enter the pipe — grep can filter errors:"

try "Redirect both stdout and stderr of 'ls /etc /fake' to a file" \
    "ls /etc /fake > ${SCRATCH}/all.txt 2>&1 && cat ${SCRATCH}/all.txt"

tip "Bash shorthand: &> is equivalent to > file 2>&1
  command &> file   captures everything"

# =============================================================================
step "| — the pipe"
set_hint "The pipe | passes stdout of one command to stdin of the next.
Build pipelines one step at a time — check each step before adding the next."

explain "The pipe | connects commands:
  command1 | command2

stdout of command1 becomes stdin of command2.
Both run simultaneously — it is not sequential.

stderr is NOT piped by default."

demo 'cat /etc/passwd | grep bash' \
     "Filter lines containing 'bash':"

demo 'cat /etc/passwd | cut -d: -f1 | sort' \
     "Extract usernames and sort them:"

demo 'cat /etc/passwd | wc -l' \
     "Count lines:"

show 'cat /etc/passwd | cut -d: -f7 | sort | uniq -c | sort -rn' \
     "Full pipeline — most common shells:"

try "Count unique login shells in /etc/passwd using a pipeline" \
    "cut -d: -f7 /etc/passwd | sort | uniq | wc -l"

# =============================================================================
step "tee — split a stream"
set_hint "tee reads stdin and writes to both stdout AND a file simultaneously.
Try: ls /etc | tee /tmp/mission06/listing.txt | wc -l"

explain "tee splits a stream: it writes to a file AND passes the
stream along to the next pipe stage.

  command | tee file | next-command

Without tee you have to choose: save to file OR pipe to next command.
With tee you can do both at once.

  tee -a file   appends to the file instead of overwriting"

demo "ls /etc | tee ${SCRATCH}/listing.txt | wc -l" \
     "Count /etc entries AND save the list to a file at the same time:"

demo "cat ${SCRATCH}/listing.txt | head -5" \
     "The file was saved while the count appeared in the terminal:"

demo "echo 'log entry' | tee -a ${SCRATCH}/app.log && echo 'another entry' | tee -a ${SCRATCH}/app.log && cat ${SCRATCH}/app.log" \
     "tee -a to build a log file:"

try "List /usr/bin entries, save them with tee, and count them" \
    "ls /usr/bin | tee ${SCRATCH}/binlist.txt | wc -l"

# =============================================================================
step "< — input redirection"
set_hint "< feeds a file as stdin.
Try: wc -l < /etc/passwd  — same as cat /etc/passwd | wc -l but cleaner"

explain "< redirects a file to stdin.

  command < file    use file as stdin instead of keyboard

This is cleaner than using cat as a pipe source:
  wc -l < /etc/passwd        (preferred — no unnecessary cat)
  cat /etc/passwd | wc -l    (works but wastes a process)"

demo 'wc -l < /etc/passwd' \
     "Count lines without cat:"

demo 'sort < /etc/hosts' \
     "Sort the file without cat:"

demo 'grep bash < /etc/passwd' \
     "grep using < instead of giving it the filename:"

try "Count words in /etc/hostname using < instead of cat" \
    "wc -w < /etc/hostname"

# =============================================================================
step "here-doc <<EOF"
set_hint "A here-doc lets you write multi-line text inline.
Syntax: command << 'EOF'
lines...
EOF
The quotes around EOF prevent variable expansion inside."

explain "A here-doc feeds multi-line text to a command's stdin
without needing a separate file.

  cat << 'EOF'
  line one
  line two
  EOF

Single-quoting the delimiter prevents expansion inside the here-doc.
Without quotes, \$VAR and \$(cmd) expand."

eval "cat << 'DEMO'
line one: static text
line two: static text
DEMO"

printf "  ${D}(above: single-quoted delimiter — no expansion)${R}\n\n"
_read_pause

eval "MYDATE=\$(date +%F)
cat << DEMO
today is: \$MYDATE
shell is: \$SHELL
DEMO"

printf "  ${D}(above: unquoted delimiter — variables expanded)${R}\n\n"
_read_pause

try "Use a here-doc to write a 3-line file to ${SCRATCH}/heredoc.txt, then read it" \
    "cat > ${SCRATCH}/heredoc.txt << 'EOF'
line one
line two
line three
EOF
cat ${SCRATCH}/heredoc.txt"

# =============================================================================
step "<<< here-string and building real pipelines"
set_hint "<<< feeds a single string as stdin: wc -w <<< 'hello world'"

explain "A here-string feeds a single string as stdin:

  command <<< 'string'

Equivalent to:  echo 'string' | command
But no subshell needed — slightly more efficient in scripts."

demo "wc -w <<< 'hello world from here-string'" \
     "Count words in a string:"

demo 'grep "root" <<< "root:x:0:0:root:/root:/bin/bash"' \
     "grep on a string:"

show "ls -lhS /var/log 2>/dev/null | awk 'NR>1 {print \$5, \$9}' | head -5" \
     "Real pipeline — 5 largest files in /var/log by size:"

demo "ls -lhS /var/log 2>/dev/null | awk 'NR>1 {print \$5, \$9}' | head -5" \
     "Running it:"

try "Count the characters in 'terminal-gym' using wc -c and a here-string" \
    "wc -c <<< 'terminal-gym'"

checkpoint \
  "You need to capture both stdout and stderr into a file,
but also see the output in real time. How?" \
  "Use tee combined with 2>&1:
  command 2>&1 | tee output.log
2>&1 merges stderr into stdout, then tee sends both
to the terminal AND the file simultaneously."

# =============================================================================
# Cleanup
rm -rf "$SCRATCH"

mission_complete
