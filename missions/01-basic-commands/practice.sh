#!/bin/bash
# =============================================================================
#  Mission 01 — Basic Commands
# =============================================================================
set -uo pipefail
COURSE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"

init_mission "01" "Basic Commands" 12

# =============================================================================
step "whoami — who are you?"
set_hint "Just type: whoami"

explain "The first thing to know in any Linux session is who you are.
whoami prints the current user's login name."

demo 'whoami'

try_match "Now type it yourself" \
          "whoami" \
          "$USER"

# =============================================================================
step "hostname — what machine are you on?"
set_hint "Just type: hostname"

explain "hostname prints the name of the machine you're logged into.
Useful when you have multiple servers and need to confirm where you are."

demo 'hostname'

try "Try it yourself" \
    "hostname"

# =============================================================================
step "pwd — where are you in the filesystem?"
set_hint "Type: pwd — output will always start with /"

explain "pwd stands for Print Working Directory.
It prints the full path to the directory you are currently in.
Every terminal session starts somewhere — usually your home directory."

demo 'pwd'

try_match "Print your current directory" \
          "pwd" \
          "/"

note "The output always starts with / — that's the root of the filesystem.
Every path in Linux starts from /."

# =============================================================================
step "ip a — what is your IP address?"
set_hint "Type: ip a  — look for lines starting with 'inet' to find your IP"

explain "ip a (short for ip address) lists all network interfaces and
their IP addresses. Look for lines starting with 'inet' — those show
your actual IP address on each interface."

demo 'ip a'

try "Run ip a yourself — find and read the inet lines" \
    "ip a"

section "Quick shortcut"

show 'hostname -I' "hostname -I prints only the IPs, no extra noise:"

try_match "Run hostname -I to get just the IPs" \
          "hostname -I" \
          "."

tip "hostname -I (capital i) is faster when you only need the address."

# =============================================================================
step "ls — listing files (basic)"
set_hint "Type: ls ~   (the ~ means your home directory)"

explain "ls lists the contents of a directory.
With no arguments it shows the current directory."

show 'ls ~' "What ls looks like on your home directory:"

try "Run ls on your home directory" \
    "ls ~"

note "Directories and files look the same here. Flags will fix that."

# =============================================================================
step "ls flags — reading the details"
set_hint "Try: ls -l ~   or   ls -a ~   or   ls -h ~   or   ls -F ~"

explain "The real power of ls is in its flags.
Add them one at a time and watch how the output changes."

demo 'ls -l ~' "-l gives the long format: permissions, owner, size, date"

demo 'ls -a ~' "-a shows hidden files (dotfiles start with .)"

demo 'ls -h ~' "-h makes sizes human-readable (KB, MB, GB)"

demo 'ls -F ~' "-F adds a symbol to classify each entry:
   /  = directory     *  = executable     @  = symlink"

# =============================================================================
step "ls combined — the one to memorise"
set_hint "Type: ls -alhF ~   — combines all flags at once"

explain "You can combine flags into one: -alhF
This is the version you will type every day."

show 'ls -alhF ~' "All flags together:"

try "Run ls -alhF on your home directory" \
    "ls -alhF ~"

try "Now list /etc the same way" \
    "ls -alhF /etc"

checkpoint \
  "What flag makes ls show hidden files?" \
  "-a   Hidden files start with a dot: .bashrc  .profile  .ssh/"

# =============================================================================
step "type -a — built-in or external?"
set_hint "Type: type -a grep   — it shows whether a command is external or built-in"

explain "Not all commands work the same way.
Some are external programs on disk. Others are shell built-ins.

  type -a <command>  shows where the shell finds a command

This matters because built-in commands do not have man pages."

demo 'type -a ls'

demo 'type -a cd'

try_match "Check where 'grep' comes from" \
          "type -a grep" \
          "/"

try "Check a few more yourself: type -a echo, type -a pwd, type -a which"

checkpoint \
  "Why does 'man cd' return no entry?" \
  "cd is a shell built-in.
man only covers external programs on disk.
Use 'help cd' instead to read built-in documentation."

# =============================================================================
step "touch and cat — creating and reading files"
set_hint "Type: touch /tmp/myfile.txt && cat /tmp/myfile.txt   (empty output is expected)"

explain "touch creates an empty file.
  If the file already exists, it only updates its timestamp.

cat reads a file and prints its contents to the terminal."

demo 'touch /tmp/practice01.txt && ls -lh /tmp/practice01.txt'

demo 'cat /etc/hostname' "cat reads any text file:"

try "Create your own file in /tmp then read it back" \
    "touch /tmp/myfile.txt && cat /tmp/myfile.txt"

note "The file is empty so cat shows nothing — that's expected."

# =============================================================================
step "echo and redirection — writing into files"
set_hint "Try: echo 'hello' > /tmp/mine.txt && cat /tmp/mine.txt
Use > to overwrite, >> to append."

explain "echo prints text to the terminal.
The > operator redirects that output into a file instead.

  >   overwrites the file (replaces all existing content)
  >>  appends to the file (adds to the end)"

demo 'echo "hello from mission 01" > /tmp/practice01.txt && cat /tmp/practice01.txt'

demo 'echo "second line" >> /tmp/practice01.txt && cat /tmp/practice01.txt'

try "Write your own line into a file and read it back" \
    "echo 'I wrote this' > /tmp/mine.txt && cat /tmp/mine.txt"

tip "> is like aiming at the file with a hose — it replaces everything.
>> is like adding a drop to a bucket."

# =============================================================================
step "echo \$? — reading the exit code"
set_hint "Run any command, then immediately type: echo \$?
  0 = success,  non-zero = something went wrong"

explain "Every command exits with a number:
  0       = success
  1–255   = something went wrong

\$? holds the exit code of the last command.
You must read it immediately — it gets overwritten by the next command."

demo 'ls /etc > /dev/null; echo "exit code: $?"'

demo 'ls /doesnotexist 2>/dev/null; echo "exit code: $?"'

try "Run any command, then immediately check its exit code with echo \$?" \
    "whoami; echo \$?"

# =============================================================================
step "&& and || — chaining on success or failure"
set_hint "Try: true && echo 'success'   or   false || echo 'failed'
&& runs next on success, || runs next on failure."

explain "You can chain commands based on exit codes:

  cmd1 && cmd2   run cmd2 only if cmd1 succeeded (exit 0)
  cmd1 || cmd2   run cmd2 only if cmd1 failed (non-zero)"

demo 'ls /tmp && echo "ls succeeded"'

demo 'ls /fake 2>/dev/null || echo "ls failed — running fallback"'

try "Write a chain yourself: run true then echo 'all good'" \
    "true && echo 'all good'"

checkpoint \
  "What is the difference between && and ||?" \
  "&&  runs the next command only on SUCCESS (exit 0)
||  runs the next command only on FAILURE (non-zero exit)"

# =============================================================================
mission_complete
