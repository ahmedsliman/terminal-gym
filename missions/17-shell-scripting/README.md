# Mission 17 — Shell Scripting

## Concept

A shell script is a plain text file containing the same commands you type
interactively, executed in sequence by the shell. Scripts turn repetitive tasks
into repeatable, shareable, auditable automation. This is the skill that
separates someone who _uses_ Linux from someone who _controls_ it.

This mission builds a real, working backup script from scratch — line by line —
covering every core feature of Bash scripting along the way.

## Learning Goals

- Write and run a script with the correct shebang and permissions
- Declare and use variables safely, including positional parameters
- Make decisions with `if`/`then`/`else`/`fi` and `[[ ]]` test expressions
- Iterate with `for` loops (over lists and globs) and `while read` loops
- Define and call reusable functions
- Understand and use exit codes to signal success or failure
- Handle errors with `set -euo pipefail` and `||` fallback patterns
- Clean up resources automatically with `trap`
- Build a complete, production-style backup script

## Constraints

- Terminal only — no GUI editor
- All file work happens in `/tmp/mission17`
- Time target: 60 minutes

## Key Concepts

| Concept | Syntax |
|---------|--------|
| Shebang | `#!/bin/bash` |
| Make executable | `chmod +x script.sh` |
| Variable | `NAME="value"` — always quote: `"$NAME"` |
| Positional parameters | `$1  $2  $@  $#` |
| If / else | `if [[ condition ]]; then ... else ... fi` |
| String empty? | `[[ -z "$str" ]]` |
| String equal? | `[[ "$a" == "$b" ]]` |
| File exists? | `[[ -f file ]]` |
| Directory exists? | `[[ -d dir ]]` |
| Executable? | `[[ -x file ]]` |
| Numeric compare | `[[ $n -gt 5 ]]` |
| For loop | `for item in list; do ... done` |
| While read | `while read line; do ... done < file` |
| Function | `name() { body; }` |
| Exit code | `exit 0` (success) / `exit 1` (failure) |
| Error guard | `cmd || { echo "error"; exit 1; }` |
| Safe mode | `set -euo pipefail` |
| Cleanup hook | `trap 'rm -f "$tmpfile"' EXIT` |

## Script Built Over This Mission

By the end you will have a working `backup.sh` that:

1. Validates its arguments
2. Checks the source directory exists
3. Creates a timestamped archive with `tar`
4. Logs the result to a log file
5. Cleans up on exit with `trap`
6. Exits with meaningful codes

## Notes

- `[[ ]]` is the modern Bash test operator — always prefer it over `[ ]`
- Never write `$VAR` without quotes in most contexts — write `"$VAR"`
- `$?` is the exit code of the last command
- Functions in Bash return exit codes, not values — use `echo` to return data
- `set -u` catches undefined variables; `set -e` exits on any error;
  `set -o pipefail` catches errors inside pipes

## Next

Run `make practice N=17` to start the interactive session.
Run `make exercises N=17` for the standalone exercises.
