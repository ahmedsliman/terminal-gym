# Mission 04 — Terminal & Shell

## Learning Goals

- Distinguish a terminal emulator from the shell running inside it
- Understand bash startup files (`.bashrc`, `.profile`, `.bash_profile`)
- Read and modify environment variables
- Customize the `PS1` prompt
- Use shell history efficiently
- Know the most useful readline keyboard shortcuts

---

## Terminal vs Shell

These two things are often confused:

| | Terminal | Shell |
|-|---------|-------|
| **What it is** | The program that draws the window and handles keyboard/display | The program that interprets your commands |
| **Examples** | GNOME Terminal, Alacritty, xterm, tmux | bash, zsh, fish, sh |
| **Analogy** | A telephone handset | The person speaking |

When you open a terminal window, it starts a shell inside it. The terminal handles rendering; the shell handles logic.

---

## Shell Startup Files

When bash starts, it reads configuration files in order:

**Login shell** (SSH login, `su -`, terminal that sources your profile):
1. `/etc/profile` — system-wide
2. `~/.bash_profile` or `~/.profile` — your personal config

**Interactive non-login shell** (most terminal windows):
1. `/etc/bash.bashrc` — system-wide
2. `~/.bashrc` — your personal config

**Key rule:** Put your customizations in `~/.bashrc`. Source it from `~/.bash_profile` to keep things consistent:

```bash
# In ~/.bash_profile:
[ -f ~/.bashrc ] && source ~/.bashrc
```

---

## Environment Variables

Variables set in the shell are only visible to that shell. To make a variable available to child processes, you `export` it:

```bash
MY_VAR="hello"        # local to this shell
export MY_VAR         # now available to child processes
export PATH="$HOME/bin:$PATH"   # prepend to PATH
```

Key variables:
| Variable | What it holds |
|----------|--------------|
| `PATH` | Colon-separated directories to search for commands |
| `HOME` | Your home directory |
| `USER` | Your username |
| `SHELL` | Path to your default shell |
| `PS1` | Your command prompt string |
| `EDITOR` | Default text editor |
| `LANG` | Your locale |

---

## PS1 — Your Prompt

`PS1` controls what your prompt looks like. Special escape sequences:

| Sequence | Expands to |
|----------|-----------|
| `\u` | username |
| `\h` | hostname (short) |
| `\H` | hostname (full) |
| `\w` | current directory (full path) |
| `\W` | current directory (basename only) |
| `\$` | `$` for regular users, `#` for root |
| `\t` | current time (HH:MM:SS) |
| `\n` | newline |

Example:
```bash
PS1='\u@\h:\w\$ '   # user@host:/path$
```

---

## Shell History

bash records every command you type in `~/.bash_history`.

| Key / Command | Action |
|--------------|--------|
| `Up arrow` | Previous command |
| `Down arrow` | Next command |
| `Ctrl+R` | Search history interactively |
| `!!` | Repeat last command |
| `!string` | Repeat last command starting with `string` |
| `history` | List recent commands |
| `history N` | List last N commands |
| `history -c` | Clear history for this session |

---

## Readline Shortcuts

These work at any bash prompt (and in most programs that use readline):

| Shortcut | Action |
|----------|--------|
| `Ctrl+A` | Jump to start of line |
| `Ctrl+E` | Jump to end of line |
| `Ctrl+U` | Delete from cursor to line start |
| `Ctrl+K` | Delete from cursor to line end |
| `Ctrl+W` | Delete previous word |
| `Alt+F` | Move forward one word |
| `Alt+B` | Move backward one word |
| `Ctrl+L` | Clear screen (like `clear`) |
| `Ctrl+C` | Cancel current command |
| `Ctrl+D` | EOF / logout |

---

## What's Next

Mission 05 covers Shell Expansions — glob patterns, brace expansion, command substitution, and arithmetic.

```bash
make practice N=04
```
