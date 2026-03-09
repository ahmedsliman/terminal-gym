#!/bin/bash
# =============================================================================
#  Mission 04 — Terminal & Shell
# =============================================================================
set -uo pipefail
COURSE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"

init_mission "04" "Terminal & Shell" 9

# =============================================================================
step "Terminal vs Shell — what is the difference?"
set_hint "echo \$SHELL shows your shell. echo \$TERM shows your terminal type."

explain "Two separate programs are always involved when you type a command:

  Terminal   draws the window, handles keyboard and display
  Shell      reads your input and runs commands

Your terminal could be GNOME Terminal, xterm, Alacritty, or tmux.
Your shell is almost certainly bash — or possibly zsh or fish.

The terminal and shell are independent. You can run any shell
in any terminal."

demo 'echo $SHELL' \
     "Your default shell:"

demo 'echo $TERM' \
     "Your terminal type (set by the terminal emulator):"

demo 'ps -p $$' \
     "The actual process running as your shell right now:"

try "Print your shell and terminal type" \
    "echo \$SHELL && echo \$TERM"

checkpoint \
  "If you change the shell inside a terminal, does the terminal change?" \
  "No. The terminal emulator keeps running unchanged. Only the shell
(the process interpreting commands) is replaced. You can start bash
inside zsh, or zsh inside bash, without affecting the terminal."

# =============================================================================
step "Environment variables — what they are"
set_hint "env or printenv shows all variables.
echo \$VARNAME prints one variable."

explain "Environment variables are key-value pairs that the shell and
programs use to communicate settings.

  env           list all environment variables
  printenv VAR  print one variable
  echo \$VAR     also prints one variable

Variables set without export are local to the shell.
Variables set with export are passed to child processes."

demo 'env | head -20' \
     "All environment variables (truncated):"

demo 'printenv HOME USER SHELL PATH' \
     "Some key variables:"

try "Print your HOME directory using printenv" \
    "printenv HOME"

try "Print PATH — the directories searched for commands" \
    "echo \$PATH"

# =============================================================================
step "Setting and exporting variables"
set_hint "MYVAR='value'   sets a local variable.
export MYVAR   makes it available to child processes."

explain "Variables are local by default — child processes cannot see them.
export makes a variable part of the environment.

  GREETING='hello'       local — bash only
  export GREETING        now exported to children
  export GREETING='hi'   set and export in one step"

demo 'MYVAR="test value" && echo $MYVAR' \
     "Set and read a variable:"

demo 'MYVAR="test value" && bash -c "echo \$MYVAR"' \
     "A child bash cannot see it (not exported):"

demo 'export MYVAR="test value" && bash -c "echo \$MYVAR"' \
     "Now the child can see it (exported):"

try "Set your own variable and export it, then verify in a child shell" \
    "export MYNAME='$(whoami)' && bash -c 'echo \$MYNAME'"

note "Variables exported in a session only last for that session.
To make them permanent, add them to ~/.bashrc."

# =============================================================================
step "PATH — how the shell finds commands"
set_hint "echo \$PATH  shows the search path.
which <command>   shows which file will run when you type the command."

explain "When you type a command, bash searches each directory in PATH
from left to right and runs the first match it finds.

  echo \$PATH          show current PATH
  which <command>     show the full path to a command
  type -a <command>   show all locations (built-ins + external)"

demo 'echo $PATH | tr ":" "\n"' \
     "PATH directories, one per line:"

demo 'which ls grep sort' \
     "Where these commands live on disk:"

demo 'type -a echo' \
     "echo is both built-in and an external program:"

try_match "Show where the 'bash' command lives" \
          "which bash" \
          "/bash"

tip "Prepend to PATH to make your own scripts take priority:
  export PATH=\"\$HOME/bin:\$PATH\"
Add that line to ~/.bashrc to make it permanent."

# =============================================================================
step "Shell startup files"
set_hint "cat ~/.bashrc   shows your interactive shell config.
source ~/.bashrc  reloads it without opening a new terminal."

explain "bash reads config files when it starts.
For most terminal windows (interactive, non-login shell), it reads:

  /etc/bash.bashrc   system-wide config
  ~/.bashrc          your personal config

Changes to ~/.bashrc only take effect for new shells.
To apply changes to the current shell:  source ~/.bashrc"

demo 'wc -l ~/.bashrc 2>/dev/null || echo "~/.bashrc does not exist yet"' \
     "How long is your .bashrc?"

demo 'grep -v "^#" ~/.bashrc 2>/dev/null | grep -v "^$" | head -20 || echo "(nothing to show)"' \
     "Non-comment lines in ~/.bashrc:"

try "Show the last 10 lines of your ~/.bashrc" \
    "tail -10 ~/.bashrc"

note "Never put secrets or passwords in ~/.bashrc — it is a plain text file
anyone with access to your account can read."

# =============================================================================
step "PS1 — customizing your prompt"
set_hint "PS1 is just a string. \\u = user, \\h = host, \\w = current dir, \\\\$ = prompt char.
Try: PS1='\\u@\\h:\\w\\$ '   (this only changes the current session)"

explain "PS1 is the variable that controls your prompt.
It supports special escape sequences:

  \\u   your username
  \\h   short hostname
  \\w   current directory (full path)
  \\W   current directory (name only)
  \\$   \$ for users,  # for root
  \\t   current time"

demo 'echo "Current PS1: $PS1"'

show 'PS1_BACKUP="$PS1"' \
     "Save the current prompt first so we can restore it:"

printf "  ${YL}▶  Try changing your prompt. Type:${R}\n\n"
printf "       ${B}PS1='\\u@\\h:\\W\\$ '${R}\n\n"
printf "     Then type a few commands to see it in action.\n"
printf "     When done, type: ${B}PS1=\"\$PS1_BACKUP\"${R} to restore.\n\n"

try "Change your PS1 and restore it" \
    'PS1_BACKUP="$PS1" && PS1="\u@\h:\W\$ " && echo "changed!" && PS1="$PS1_BACKUP"'

tip "To make a prompt permanent, add PS1='...' to ~/.bashrc"

# =============================================================================
step "Shell history"
set_hint "Ctrl+R to search. !! to repeat the last command.
history shows your command history."

explain "bash records every command in ~/.bash_history.
Several shortcuts make history navigation fast:

  history          list all recorded commands
  history 20       last 20 commands
  !!               repeat the last command
  !ls              repeat the last command starting with 'ls'
  Ctrl+R           reverse-incremental search through history"

demo 'history | tail -10' \
     "Your 10 most recent commands:"

demo 'history | wc -l' \
     "Total commands recorded:"

try "Show the last 5 history entries" \
    "history 5"

tip "HISTSIZE controls how many commands are kept in memory.
HISTFILESIZE controls how many are saved to disk.
Add to ~/.bashrc:   HISTSIZE=5000  HISTFILESIZE=10000"

# =============================================================================
step "Readline shortcuts — moving faster"
set_hint "Practice Ctrl+A (line start), Ctrl+E (line end), Ctrl+W (delete word), Ctrl+U (delete to start)"

explain "These shortcuts work at any bash prompt:

  Ctrl+A   jump to start of line
  Ctrl+E   jump to end of line
  Ctrl+W   delete word to the left
  Ctrl+U   delete from cursor to line start
  Ctrl+K   delete from cursor to line end
  Ctrl+L   clear the screen
  Alt+F    move forward one word
  Alt+B    move backward one word"

printf "  ${YL}▶  Practice the shortcuts:${R}\n\n"
printf "  1. Type a long command but do not press Enter.\n"
printf "     Use ${B}Ctrl+A${R} to jump to the start.\n"
printf "     Use ${B}Ctrl+E${R} to jump to the end.\n\n"
printf "  2. Type: echo 'hello world goodbye'\n"
printf "     Press ${B}Ctrl+W${R} three times — it deletes one word at a time.\n\n"
printf "  3. Type any partial command and press ${B}Ctrl+U${R} to clear the line.\n\n"

try "Use Ctrl+L to clear the screen, then run any command" \
    "clear && echo 'screen cleared'"

note "These shortcuts work in any program that uses GNU readline:
bash, python REPL, psql, mysql, and many others."

# =============================================================================
step "which, type, command — finding commands"
set_hint "which cmd  finds the external binary.
type -a cmd  finds everything: built-ins, functions, aliases, and externals."

explain "Several tools help you understand where a command comes from:

  which cmd        find the first match in PATH (external only)
  type -a cmd      show all matches: built-ins, aliases, functions, externals
  command -v cmd   like which, but POSIX-portable (use in scripts)

Use type -a when you are debugging unexpected behavior."

demo 'which ls' \
     "which finds the external binary:"

demo 'type -a ls' \
     "type -a shows everything — ls has an alias on many systems:"

demo 'type -a echo' \
     "echo is both built-in and external:"

demo 'type -a cd' \
     "cd is a built-in only — it has no external binary:"

try_match "Check whether 'git' is installed and where it lives" \
          "type -a git 2>&1 || echo 'git not found'" \
          "git"

checkpoint \
  "Why would a command behave differently from what 'which' shows?" \
  "which only shows the external binary in PATH.
It misses aliases, shell functions, and built-ins.
If you have 'alias ls=\"ls --color\"', then typing ls runs the alias,
not the raw binary. Use type -a to see the full picture."

# =============================================================================
mission_complete
