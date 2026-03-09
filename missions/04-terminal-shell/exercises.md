# Exercises — Mission 04: Terminal & Shell

---

## Exercise 1: Identify Your Environment

**Goal:** Know what terminal and shell you are running.

**Steps:**
1. Print your shell: `echo $SHELL`
2. Print your terminal type: `echo $TERM`
3. Show the running shell process: `ps -p $$`
4. List all shells installed: `cat /etc/shells`

**Hint:** `$$` is the PID of the current shell.

**Self-check:** Does `echo $SHELL` match the process name shown by `ps -p $$`?

---

## Exercise 2: Explore Environment Variables

**Goal:** Read and understand the variables in your environment.

**Steps:**
1. List all variables: `env`
2. Count them: `env | wc -l`
3. Print specific ones: `printenv HOME USER SHELL EDITOR`
4. Find variables containing "path" (case-insensitive): `env | grep -i path`

**Hint:** `env` and `printenv` both show the environment. `env` can also run a command with a modified environment.

**Self-check:** `printenv HOME` and `echo $HOME` should print the same thing.

---

## Exercise 3: Set and Export Variables

**Goal:** Understand the difference between local and exported variables.

**Steps:**
1. Set a local variable: `MYCOLOR="blue"`
2. Try to read it in a child shell: `bash -c "echo $MYCOLOR"` (should print nothing)
3. Export it: `export MYCOLOR`
4. Try again: `bash -c "echo $MYCOLOR"` (should now print "blue")
5. Set and export in one step: `export EDITOR="vim"`

**Hint:** Exported variables are inherited by child processes. Local variables die with the shell that set them.

**Self-check:** `bash -c "printenv MYCOLOR"` should print "blue" only after exporting.

---

## Exercise 4: PATH — Command Resolution

**Goal:** Understand how the shell finds commands and how to extend PATH.

**Steps:**
1. Show PATH directories, one per line:
   ```bash
   echo $PATH | tr ':' '\n'
   ```
2. Find where commands live: `which ls bash grep`
3. See all forms of `echo`: `type -a echo`
4. Create a personal bin directory and add it to PATH:
   ```bash
   mkdir -p ~/bin
   export PATH="$HOME/bin:$PATH"
   echo $PATH | tr ':' '\n' | head -5
   ```
5. Create a command in it:
   ```bash
   echo '#!/bin/bash' > ~/bin/greet
   echo 'echo "Hello, $USER!"' >> ~/bin/greet
   chmod +x ~/bin/greet
   greet
   ```

**Hint:** The shell searches PATH left-to-right and runs the first match. Prepending `~/bin` means your scripts take priority over system commands.

**Self-check:** `type -a greet` should show the full path to your script in `~/bin/`.

---

## Exercise 5: Customize Your Prompt

**Goal:** Change your PS1 prompt and understand its escape sequences.

**Steps:**
1. See your current prompt: `echo $PS1`
2. Save it: `OLD_PS1="$PS1"`
3. Try a minimal prompt: `PS1='\$ '`
4. Try a more informative one: `PS1='\u@\h:\w\$ '`
5. Add the time: `PS1='[\t] \u@\h:\W\$ '`
6. Restore: `PS1="$OLD_PS1"`

**Hint:** Changes to PS1 last only for the current session. To make it permanent, add `PS1='...'` to `~/.bashrc`.

**Self-check:** After restoring, `echo $PS1` should match what it was at the start.

---

## Exercise 6: Shell History

**Goal:** Navigate and search your command history efficiently.

**Steps:**
1. Show all history: `history`
2. Show last 10 entries: `history 10`
3. Count total entries: `history | wc -l`
4. Search for a command containing "grep": `history | grep grep | tail -5`
5. Press `Ctrl+R` and type a partial command to search interactively

**Hint:** `HISTSIZE` controls how many commands are kept in memory during a session. Check it with `echo $HISTSIZE`.

**Self-check:** Try pressing `Up` arrow several times — you should scroll through recent commands.

---

## Exercise 7: Readline Navigation (Stretch)

**Goal:** Move and edit command lines without touching the mouse.

**Practice these shortcuts at the prompt:**

| Shortcut | What to do |
|----------|-----------|
| `Ctrl+A` | Type a long command, press Ctrl+A to jump to start |
| `Ctrl+E` | From start, press Ctrl+E to jump to end |
| `Ctrl+W` | Type 3 words, press Ctrl+W three times |
| `Ctrl+U` | Start typing, press Ctrl+U to erase the whole line |
| `Alt+F` | Move forward one word at a time |
| `Alt+B` | Move backward one word at a time |

**Hint:** These shortcuts come from GNU Readline. They also work in Python REPL, `psql`, `irb`, and many other interactive programs.

**Self-check:** Can you position the cursor in the middle of a word without using arrow keys?

---

When done, mark this mission complete:

```bash
make done N=04
make next
```
