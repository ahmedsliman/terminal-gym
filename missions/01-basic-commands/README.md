# Mission 01 — Basic Commands

## Concept

Linux commands are case-sensitive programs that live on your `PATH`. Some are
external binaries (like `ls`), others are shell built-ins (like `cd`). Knowing
the difference — and knowing how to find information about any command — is your
first Linux superpower.

## Learning Goals

- Navigate the filesystem with `ls`, `cd`, `pwd`
- Identify whether a command is a built-in or external binary
- Use `man`, `--help`, and `type -a` to look up commands
- Create and inspect files with `touch` and `cat`
- Query the system with `whoami`, `hostname`, and `ip`

## Constraints

- Terminal only — no file manager, no GUI
- Time target: 30 minutes

## Key Commands

| Command | What it does |
|---------|-------------|
| `ls -alhF` | Long list, human sizes, all files, classify entries |
| `type -a ls` | Show where `ls` comes from (alias, binary, built-in) |
| `man <cmd>` | Full manual for any command |
| `<cmd> --help` | Quick usage summary |
| `whoami` | Current username |
| `hostname` | Machine name |
| `ip a` | Network interfaces and IP addresses |
| `touch file.txt` | Create empty file (or update timestamp) |
| `cat file.txt` | Print file contents |
| `echo $?` | Exit code of the last command (`0` = success) |

## Notes

- `.` = current directory, `..` = parent directory
- Linux uses `/` (forward slash), not `\` like Windows
- `type -a cd` — `cd` is a shell built-in, so `man cd` has no entry; use `help cd` instead
- `echo $?` after `true` gives `0`, after `false` gives `1`

## Next

Run `make exercises N=01` to start the hands-on tasks.
