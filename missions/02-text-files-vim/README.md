# Mission 02 — Text Files & Vim

## Concept
In Linux, text files are the universal interface. `cp` and `mv` move data; Vim
edits it with keyboard efficiency that scales to any file size.

## Learning Goals
- Copy and rename files with `cp`
- Edit files efficiently in Vim (modes, movement, yank/paste)
- Run shell commands from inside Vim
- Diff two files with `diff`

## Key Commands
| Command | What it does |
|---------|-------------|
| `cp src dst` | Copy file |
| `cp src dir/` | Copy into directory (keeps filename) |
| `diff -u file1 file2` | Unified diff between two files |
| `vim file` | Open file in Vim |

## Vim Cheat Sheet
| Key | Action |
|-----|--------|
| `i` | Enter insert mode |
| `Esc` | Return to command mode |
| `w` / `b` | Move word forward / backward |
| `0` / `$` | Start / end of line |
| `dd` | Delete line |
| `dw` | Delete word |
| `yy` / `p` | Yank (copy) line / paste |
| `u` | Undo |
| `:.! ls` | Insert shell command output |
| `:sh` | Drop to shell (exit to return) |
| `:wq` | Save and quit |
| `:q!` | Quit without saving |

## Next
Run `make exercises N=02` to start the hands-on tasks.
