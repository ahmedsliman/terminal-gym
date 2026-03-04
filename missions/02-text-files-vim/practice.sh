#!/bin/bash
# =============================================================================
#  Mission 02 — Text Files & Vim
# =============================================================================
set -uo pipefail
COURSE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"

SCRATCH="/tmp/mission02"
mkdir -p "$SCRATCH"

init_mission "02" "Text Files & Vim" 10

# =============================================================================
step "cp — copying a file"
set_hint "Syntax: cp <source> <destination>
Example: cp /etc/hostname /tmp/hostname-backup"

explain "cp copies a file from source to destination.
The original is left unchanged."

demo "cp /etc/hosts ${SCRATCH}/hosts-backup" \
     "Copy /etc/hosts:"

demo "ls -lh ${SCRATCH}/" \
     "The copy now exists alongside the original:"

try "Copy /etc/hostname into ${SCRATCH}/ yourself" \
    "cp /etc/hostname ${SCRATCH}/"

# =============================================================================
step "cp — copying into a directory"
set_hint "mkdir -p /tmp/mission02/mydir && cp /etc/hostname /tmp/mission02/mydir/
When destination is a directory, cp keeps the original filename."

explain "If the destination is a directory, cp places the file inside it
using the original filename.

If the destination is a new name, cp renames the copy."

demo "mkdir -p ${SCRATCH}/subdir && cp /etc/hosts ${SCRATCH}/subdir/" \
     "Copy into a subdirectory — filename is kept:"

demo "ls -lh ${SCRATCH}/subdir/" \
     "The file landed there with its original name:"

try "Create your own subdirectory in ${SCRATCH} and copy a file into it" \
    "mkdir -p ${SCRATCH}/mydir && cp /etc/hostname ${SCRATCH}/mydir/"

# =============================================================================
step "mv — moving and renaming"
set_hint "Syntax: mv <old-name> <new-name>
Example: mv /tmp/mission02/hostname /tmp/mission02/my-hostname"

explain "mv moves a file to a new location — or renames it in place.
The original is gone after mv."

demo "cp /etc/hosts ${SCRATCH}/will-be-renamed" \
     "First create a file to rename:"

demo "mv ${SCRATCH}/will-be-renamed ${SCRATCH}/was-renamed && ls -lh ${SCRATCH}/" \
     "Rename it — original name is gone:"

try "Rename the file you copied earlier (${SCRATCH}/hostname) to my-hostname" \
    "mv ${SCRATCH}/hostname ${SCRATCH}/my-hostname"

checkpoint \
  "What is the difference between cp and mv?" \
  "cp leaves the original — you end up with two copies.
mv removes the original — it's a rename or move, not a copy."

# =============================================================================
step "diff — comparing two files"
set_hint "Try: echo 'v1' > /tmp/v1.txt && echo 'v2' > /tmp/v2.txt && diff /tmp/v1.txt /tmp/v2.txt
< = only in first file,  > = only in second file"

explain "diff shows the lines that differ between two files.
No output means the files are identical.

  < line  means the line only exists in the first file
  > line  means the line only exists in the second file

-u gives a 'unified diff' — easier to read, used by git."

demo "diff ${SCRATCH}/hosts-backup /etc/hosts" \
     "Compare our backup to the live file (should be identical):"

eval "echo 'extra line' >> ${SCRATCH}/hosts-backup"

demo "diff ${SCRATCH}/hosts-backup /etc/hosts" \
     "Now they differ — diff shows what changed:"

demo "diff -u ${SCRATCH}/hosts-backup /etc/hosts" \
     "-u unified format — the format git uses:"

try "Create two files with different content and diff them" \
    "echo 'version 1' > /tmp/v1.txt && echo 'version 2' > /tmp/v2.txt && diff /tmp/v1.txt /tmp/v2.txt"

tip "-u output: lines starting with - are removed, + are added, no symbol = unchanged."

# =============================================================================
step "head and tail — reading parts of a file"
set_hint "Try: head -n 3 /etc/hosts   or   tail -n 2 /etc/hosts
-n N controls how many lines to show."

explain "cat shows the whole file.
head and tail show just the beginning or end.

  head -n 5 file   first 5 lines
  tail -n 5 file   last 5 lines
  tail -f file     follow a live file (updates in real time)"

demo "head -n 5 /etc/passwd" \
     "First 5 lines of /etc/passwd:"

demo "tail -n 5 /etc/passwd" \
     "Last 5 lines:"

try "Show only the first 3 lines of /etc/hosts" \
    "head -n 3 /etc/hosts"

try "Show only the last 2 lines of /etc/hosts" \
    "tail -n 2 /etc/hosts"

tip "tail -f /var/log/syslog follows a live log file as new lines appear.
Press Ctrl+C to stop following."

# =============================================================================
step "more and less — reading large files"
set_hint "Type: less /etc/passwd   — use Space to page, /word to search, q to quit"

explain "cat dumps a whole file at once.
For large files use less — it shows one screen at a time.

  Space      next page
  b          previous page
  /word      search for 'word'
  n          jump to next search match
  q          quit

less is better than more — it lets you scroll backwards."

demo "wc -l /etc/passwd" \
     "How many lines does /etc/passwd have?"

try "Open /etc/passwd in less — scroll around then press q to quit" \
    "less /etc/passwd"

note "man pages use less internally — now you know how to navigate them."

# =============================================================================
step "Vim — opening and modes"
set_hint "If you are stuck in Vim: press Esc, then type :q! and press Enter to quit without saving.
To save and quit: Esc → :wq → Enter"

explain "Vim is a modal editor.
The same key does different things depending on the current mode.

  Normal mode   navigate and edit — this is where you start
  Insert mode   type text — enter with i, leave with Esc
  Command mode  run commands — enter with : from Normal mode

The most important thing: when lost, press Esc to return to Normal mode."

cat > "${SCRATCH}/vim-intro.txt" << 'EOF'
This is a Vim practice file.

STEP 1: You are in Normal mode right now.
        Press i to enter Insert mode.
        Type your name below, then press Esc.

        Your name: _______________

STEP 2: Navigate with h j k l (left down up right).
        Try moving to different lines without arrow keys.

STEP 3: Go to any line and press dd to delete it.
        Then press u to undo.

STEP 4: Go to the line marked [COPY] and press yy to copy it.
        Move down and press p to paste.
        [COPY] Paste this line below.

STEP 5: When done, press Esc then type :wq and press Enter.
        (:wq = write and quit)
EOF

printf "  ${D}Opening Vim with a practice file.${R}\n"
printf "  ${D}Follow the steps inside. Exit with Esc → :wq → Enter${R}\n\n"
printf "  ${D}Press Enter to open Vim ...${R}  "
local ans; read -r ans
[[ "$ans" =~ ^[Qq]$ ]] && _quit
vim "${SCRATCH}/vim-intro.txt"
printf "\n  ${GR}✓  You exited Vim.${R}\n\n"
printf "  ${D}Press Enter to continue ...${R}  "
read -r ans; [[ "$ans" =~ ^[Qq]$ ]] && _quit
printf "\n"

# =============================================================================
step "Vim — movement and deletion"
set_hint "w = next word, b = back, 0 = line start, \$ = line end
dd = delete line, dw = delete word, x = delete char, u = undo"

explain "In Normal mode, Vim has fast keyboard shortcuts
for movement and editing:

  Movement
    w   jump forward one word
    b   jump backward one word
    0   go to start of line
    \$   go to end of line
    gg  go to top of file
    G   go to bottom of file

  Deletion
    x   delete the character under the cursor
    dw  delete from cursor to end of word
    dd  delete the whole line
    u   undo the last change"

cat > "${SCRATCH}/vim-movement.txt" << 'EOF'
Line one: the quick brown fox jumps over the lazy dog
Line two: delete this entire line with dd
Line three: delete just the word DELETE using dw: DELETE this word
Line four: use x to delete: XXXXX the Xs one by one
Line five: undo (u) brings back deleted text
EOF

printf "  ${D}Practice the movement and deletion shortcuts in this file.${R}\n"
printf "  ${D}Exit with Esc → :wq → Enter when done.${R}\n\n"
printf "  ${D}Press Enter to open Vim ...${R}  "
read -r ans; [[ "$ans" =~ ^[Qq]$ ]] && _quit
vim "${SCRATCH}/vim-movement.txt"
printf "\n  ${GR}✓  Done.${R}\n\n"
printf "  ${D}Press Enter to continue ...${R}  "
read -r ans; [[ "$ans" =~ ^[Qq]$ ]] && _quit
printf "\n"

# =============================================================================
step "Vim — search and replace"
set_hint "In Vim: /word to search, n for next match
:%s/old/new/g to replace all occurrences across the whole file"

explain "Inside Vim, you can search and replace across the whole file:

  /word        search forward for 'word'  (n = next match)
  ?word        search backward
  :%s/old/new/g   replace all occurrences of 'old' with 'new'

  %  = whole file
  s  = substitute
  g  = global (all matches on each line)"

demo "echo 'the cat sat on the mat next to the vat' > ${SCRATCH}/replace.txt && cat ${SCRATCH}/replace.txt" \
     "Create a file with repeated words:"

printf "  ${YL}▶  Open the file in Vim and run:${R}\n\n"
printf "       ${B}:%s/the/THE/g${R}\n\n"
printf "     Then save and quit with ${B}:wq${R}\n\n"
printf "  ${D}Press Enter to open Vim ...${R}  "
local ans; read -r ans
[[ "$ans" =~ ^[Qq]$ ]] && _quit
vim "${SCRATCH}/replace.txt"

demo "cat ${SCRATCH}/replace.txt" \
     "Result after substitution:"

checkpoint \
  "What does :%s/old/new/g do in Vim?" \
  "Replaces every occurrence of 'old' with 'new' in the entire file.
% = whole file, s = substitute, g = all matches per line."

# =============================================================================
step "Vim — shell commands from inside Vim"
set_hint "In Vim: place cursor on a line, then type :.! date  to replace it with command output
:sh opens a real shell — type exit to return to Vim"

explain "You can run shell commands without leaving Vim.

  :.! command   replace the current line with the output of a command
  :sh           suspend Vim and open a real shell (exit to return)

These make Vim an interactive environment, not just an editor."

cat > "${SCRATCH}/vim-shell.txt" << 'EOF'
Put your cursor on the line below and run:  :.! date
REPLACE THIS LINE WITH THE DATE OUTPUT

Put your cursor on this line and run:  :.! whoami
REPLACE THIS LINE WITH YOUR USERNAME
EOF

printf "  ${YL}▶  Open the file and use :.! to replace lines with command output.${R}\n"
printf "     Then exit with Esc → :wq → Enter\n\n"
printf "  ${D}Press Enter to open Vim ...${R}  "
local ans; read -r ans
[[ "$ans" =~ ^[Qq]$ ]] && _quit
vim "${SCRATCH}/vim-shell.txt"

demo "cat ${SCRATCH}/vim-shell.txt" \
     "What ended up in the file:"

# =============================================================================
# Cleanup
rm -rf "$SCRATCH"

mission_complete
