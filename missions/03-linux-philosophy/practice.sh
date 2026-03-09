#!/bin/bash
# =============================================================================
#  Mission 03 — Linux Philosophy
# =============================================================================
set -uo pipefail
COURSE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"

init_mission "03" "Linux Philosophy" 10

# =============================================================================
step "Do one thing well"
set_hint "Try: wc --help   or   man wc  — notice how focused the tool is"

explain "The Unix philosophy starts with one rule:
each program does exactly one thing, and does it well.

wc counts. grep searches. sort sorts. cut extracts.
None of them try to do everything."

demo 'wc -l /etc/passwd' \
     "wc -l counts lines — that is its one job:"

demo 'wc -w /etc/passwd' \
     "wc -w counts words:"

demo 'wc -c /etc/passwd' \
     "wc -c counts bytes:"

try "Count the lines in /etc/group" \
    "wc -l /etc/group"

checkpoint \
  "Why not have one tool that counts lines AND searches text AND sorts?" \
  "Small, focused tools compose. A 'super-tool' is harder to combine with others,
harder to test, and harder to trust. Unix power comes from composition, not
from any single program being powerful."

# =============================================================================
step "Text streams — the universal interface"
set_hint "The pipe | passes stdout of one command to stdin of the next.
Try: cat /etc/passwd | wc -l"

explain "Every Unix tool reads text from stdin and writes text to stdout.
This makes them composable with |  (the pipe operator).

  command1 | command2 | command3

stdout of command1 becomes stdin of command2.
No files needed. No shared state. Just a stream of text."

demo 'cat /etc/passwd | wc -l' \
     "Pipe cat output into wc — counts lines in /etc/passwd:"

demo 'cat /etc/passwd | grep root' \
     "Pipe into grep — filter only lines containing 'root':"

try "Count how many lines in /etc/passwd contain the word 'bash'" \
    "grep bash /etc/passwd | wc -l"

# =============================================================================
step "cut — extract fields from text"
set_hint "Syntax: cut -d<delimiter> -f<field-number>
Example: cut -d: -f1 /etc/passwd   extracts the username column"

explain "/etc/passwd is a colon-delimited file with 7 fields per line:
  username : password : UID : GID : comment : home : shell

cut -d: -f1  extracts field 1 (username)
cut -d: -f7  extracts field 7 (login shell)"

demo 'head -3 /etc/passwd' \
     "Raw format of /etc/passwd:"

demo 'cut -d: -f1 /etc/passwd' \
     "Extract just the usernames (field 1):"

demo 'cut -d: -f7 /etc/passwd' \
     "Extract just the login shells (field 7):"

try "Extract the home directories (field 6) from /etc/passwd" \
    "cut -d: -f6 /etc/passwd"

# =============================================================================
step "sort and uniq — clean up output"
set_hint "sort orders lines. uniq removes consecutive duplicates.
Always sort before uniq — uniq only removes adjacent duplicates."

explain "sort alphabetically orders lines.
uniq removes consecutive duplicate lines.

Combine them to get a unique sorted list:
  sort file | uniq

Or count occurrences:
  sort file | uniq -c | sort -rn"

demo 'cut -d: -f7 /etc/passwd | sort' \
     "List all login shells, sorted:"

demo 'cut -d: -f7 /etc/passwd | sort | uniq' \
     "Unique shells only:"

demo 'cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn' \
     "Count how many users use each shell, most common first:"

try "List unique login shells used on this system" \
    "cut -d: -f7 /etc/passwd | sort | uniq"

# =============================================================================
step "Everything is a file — /dev"
set_hint "Try: ls -lh /dev/null /dev/zero /dev/random
These are device files — they look like files but are kernel interfaces."

explain "In Linux, almost everything is exposed through the file interface.
/dev contains device files — not real data, but gateways to the kernel.

  /dev/null   discards anything written to it (a black hole)
  /dev/zero   produces infinite null bytes when read
  /dev/random reads real random bytes
  /dev/stdin  your terminal's input
  /dev/stdout your terminal's output"

demo 'ls -lh /dev/null /dev/zero /dev/random' \
     "These look like files — notice the 'c' in permissions (character device):"

demo 'echo "this disappears" > /dev/null && echo "exit: $?"' \
     "Write to /dev/null — the data vanishes silently:"

demo 'head -c 16 /dev/urandom | od -An -tx1 | tr -d " \n"; echo' \
     "Read 16 random bytes from /dev/urandom, show as hex:"

try "Discard the output of ls /etc by redirecting to /dev/null" \
    "ls /etc > /dev/null"

tip "/dev/null is useful in scripts to silence output you do not care about:
  command > /dev/null 2>&1   # discard both stdout and stderr"

# =============================================================================
step "Everything is a file — /proc"
set_hint "Try: cat /proc/cpuinfo   or   cat /proc/meminfo
Nothing in /proc is stored on disk — the kernel generates it on demand."

explain "/proc is a virtual filesystem.
The kernel creates its content in memory when you read it.
It is the kernel's window into its own state.

  /proc/cpuinfo      CPU model and flags
  /proc/meminfo      RAM and swap usage
  /proc/uptime       seconds since boot
  /proc/<PID>/       info about a specific process"

demo 'cat /proc/uptime' \
     "/proc/uptime — seconds since boot (first number):"

demo 'grep -m1 "model name" /proc/cpuinfo' \
     "Your CPU model from /proc/cpuinfo:"

demo 'grep MemTotal /proc/meminfo' \
     "Total RAM from /proc/meminfo:"

try "Find out how many CPU cores this system has (count 'processor' lines)" \
    "grep -c '^processor' /proc/cpuinfo"

# =============================================================================
step "Everything is a file — /proc per-process"
set_hint "Try: ls /proc/$$ — \$\$ is the PID of the current shell"

explain "Every running process has its own directory in /proc/<PID>/.
Inside you can read its command line, environment, file descriptors, and more.

  \$\$  is a special variable — the PID of the current shell"

demo 'echo "My shell PID is $$"'

demo 'ls /proc/$$/' \
     "Your shell's entry in /proc:"

demo 'cat /proc/$$/cmdline | tr "\0" " "' \
     "The command that started this shell (null-separated, so we use tr):"

try "Read your shell's working directory from /proc" \
    "readlink /proc/$$/cwd"

note "Normally you would use pwd. But readlink /proc/\$\$/cwd gives the same
answer — showing how deeply the filesystem model runs in Linux."

# =============================================================================
step "Composing a pipeline"
set_hint "Build it one step at a time — add | and the next command when each step looks right."

explain "A pipeline is just Unix tools connected by pipes.
Build them incrementally — one command at a time.

Goal: find the 3 most common login shells on this system."

show 'cut -d: -f7 /etc/passwd' \
     "Step 1 — extract login shells:"

show 'cut -d: -f7 /etc/passwd | sort' \
     "Step 2 — sort so duplicates are adjacent:"

show 'cut -d: -f7 /etc/passwd | sort | uniq -c' \
     "Step 3 — count each unique shell:"

show 'cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn' \
     "Step 4 — sort by count, highest first:"

demo 'cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn | head -3' \
     "Step 5 — take just the top 3:"

try "Build the same pipeline yourself" \
    "cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn | head -3"

# =============================================================================
step "tr — translate characters"
set_hint "Syntax: tr 'from-set' 'to-set'
Example: echo 'hello' | tr a-z A-Z   converts to uppercase"

explain "tr translates (maps) characters in a stream.
It only reads from stdin — you always pipe into it.

  tr a-z A-Z       lowercase to uppercase
  tr -d '\\n'       delete newlines
  tr ' ' '\\n'      replace spaces with newlines (one word per line)
  tr -s ' '        squeeze multiple spaces into one"

demo "echo 'hello world' | tr a-z A-Z" \
     "Uppercase:"

demo "echo 'hello   world' | tr -s ' '" \
     "Squeeze multiple spaces into one:"

demo "echo 'one two three' | tr ' ' '\n'" \
     "One word per line:"

try "Convert the contents of /etc/hostname to uppercase" \
    "cat /etc/hostname | tr a-z A-Z"

checkpoint \
  "In one sentence: what is the Unix philosophy?" \
  "Small tools that do one thing well, work on text streams, and compose
through pipes — so users can build powerful workflows from simple parts."

# =============================================================================
mission_complete
