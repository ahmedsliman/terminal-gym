# Solution — Mission 04: Terminal & Shell

---

## Exercise 1: Identify Your Environment

```bash
echo $SHELL          # e.g. /bin/bash
echo $TERM           # e.g. xterm-256color
ps -p $$             # shows bash (or your shell) with its PID
cat /etc/shells      # all valid login shells on the system
```

**Terminal vs shell:** The terminal emulator sets `$TERM` to tell programs how to draw on screen. The shell is the process shown by `ps -p $$`. They are independent.

---

## Exercise 2: Explore Environment Variables

```bash
env
env | wc -l
printenv HOME USER SHELL EDITOR
env | grep -i path
```

**Common key variables:**
| Variable | Typical value |
|----------|--------------|
| `HOME` | `/home/yourname` |
| `USER` | `yourname` |
| `SHELL` | `/bin/bash` |
| `PATH` | `/usr/local/bin:/usr/bin:/bin:...` |
| `EDITOR` | `vim` or `nano` |

---

## Exercise 3: Set and Export Variables

```bash
MYCOLOR="blue"
bash -c "echo $MYCOLOR"   # prints nothing — not exported

export MYCOLOR
bash -c "echo $MYCOLOR"   # prints "blue"

# Or in one step:
export MYCOLOR="blue"
bash -c "echo $MYCOLOR"

export EDITOR="vim"
```

**Why this matters:** When you run a script, it starts a new bash process (a child). Only exported variables reach it. This is why `EDITOR`, `PATH`, `HOME`, etc. are all exported — they need to reach every child process.

---

## Exercise 4: PATH — Command Resolution

```bash
echo $PATH | tr ':' '\n'
which ls bash grep
type -a echo

mkdir -p ~/bin
export PATH="$HOME/bin:$PATH"
echo $PATH | tr ':' '\n' | head -5

cat > ~/bin/greet << 'EOF'
#!/bin/bash
echo "Hello, $USER!"
EOF
chmod +x ~/bin/greet
greet
```

**Making PATH permanent — add to `~/.bashrc`:**
```bash
export PATH="$HOME/bin:$PATH"
```

**Why prepend?** Prepending means your custom commands in `~/bin` override system commands with the same name. Appending means system commands win.

---

## Exercise 5: Customize Your Prompt

```bash
echo $PS1
OLD_PS1="$PS1"

PS1='\$ '                    # minimal
PS1='\u@\h:\w\$ '           # user@host:full-path$
PS1='[\t] \u@\h:\W\$ '      # [time] user@host:dirname$

PS1="$OLD_PS1"               # restore
```

**PS1 cheat sheet:**
| Sequence | Meaning |
|----------|---------|
| `\u` | username |
| `\h` | short hostname |
| `\H` | full hostname |
| `\w` | full working directory |
| `\W` | working directory basename only |
| `\$` | `$` (or `#` for root) |
| `\t` | time HH:MM:SS |
| `\n` | newline |

**To add color:**
```bash
PS1='\[\e[32m\]\u@\h\[\e[0m\]:\[\e[34m\]\w\[\e[0m\]\$ '
```
`\[\e[32m\]` starts green. `\[\e[0m\]` resets. Wrap color codes in `\[...\]` so bash doesn't count them as visible characters.

---

## Exercise 6: Shell History

```bash
history
history 10
history | wc -l
history | grep grep | tail -5
# Then Ctrl+R for interactive search
```

**Useful history settings for `~/.bashrc`:**
```bash
HISTSIZE=5000           # commands kept in memory
HISTFILESIZE=10000      # commands saved to disk
HISTCONTROL=ignoredups  # don't record duplicate consecutive commands
HISTTIMEFORMAT="%F %T " # record timestamps
```

---

## Exercise 7: Readline Navigation

There's no single command — practice until the shortcuts feel automatic.

**Quick reference card:**
```
Ctrl+A   ←  start of line
Ctrl+E   →  end of line
Ctrl+F   →  forward one char  (same as Right arrow)
Ctrl+B   ←  backward one char (same as Left arrow)
Alt+F    →→ forward one word
Alt+B    ←← backward one word
Ctrl+W      delete word to the left
Alt+D       delete word to the right
Ctrl+U      delete to start of line
Ctrl+K      delete to end of line
Ctrl+Y      paste (yank) what you just deleted
Ctrl+L      clear screen
Ctrl+R      reverse search history
```

**Pro tip:** `Ctrl+Y` (yank) pastes the text last deleted by `Ctrl+U`, `Ctrl+K`, or `Ctrl+W`. Delete and yank work as a cut/paste system.
