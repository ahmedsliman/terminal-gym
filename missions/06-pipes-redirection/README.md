# Mission 06 — Pipes & Redirection

## Learning Goals

- Understand stdin, stdout, and stderr as numbered file descriptors
- Redirect output to files with `>` and `>>`
- Redirect stderr separately from stdout
- Discard output with `/dev/null`
- Connect commands with `|` (pipe)
- Split a stream to a file AND the screen with `tee`
- Write multi-line input with here-docs `<<EOF`

---

## File Descriptors

Every process has three standard streams open by default:

| FD | Name | Direction | Default |
|----|------|-----------|---------|
| 0 | stdin | input | keyboard |
| 1 | stdout | output | terminal |
| 2 | stderr | error output | terminal |

When you type a command, its output goes to stdout (FD 1). Error messages go to stderr (FD 2). Both appear on your screen unless you redirect them.

---

## Output Redirection

```bash
command > file      # redirect stdout to file (overwrite)
command >> file     # redirect stdout to file (append)
command 2> file     # redirect stderr to file
command 2>&1        # redirect stderr into stdout (merge them)
command > file 2>&1 # redirect both stdout and stderr to file
command &> file     # shorthand for > file 2>&1 (bash only)
```

**Order matters:** `> file 2>&1` is correct. `2>&1 > file` is wrong — it sends stderr to the old stdout (screen), then redirects the new stdout to file.

---

## Input Redirection

```bash
command < file        # feed file as stdin
command << 'EOF'      # here-doc: type multi-line input until EOF
line 1
line 2
EOF
command <<< "string"  # here-string: feed a single string as stdin
```

---

## Pipes

The pipe `|` connects stdout of one command to stdin of the next:

```bash
command1 | command2 | command3
```

Each command runs in its own process simultaneously. Data flows left-to-right as a stream. No temporary files needed.

**stderr is NOT piped.** To pipe stderr too:
```bash
command 2>&1 | next-command
```

---

## tee — Split a Stream

`tee` reads from stdin, writes to both stdout AND a file:

```bash
command | tee output.txt          # see output AND save it
command | tee -a output.txt       # append to file
command | tee file1 file2         # write to multiple files
```

Useful for logging while still seeing output in the terminal.

---

## /dev/null — The Black Hole

```bash
command > /dev/null       # discard stdout
command 2> /dev/null      # discard stderr
command > /dev/null 2>&1  # discard everything
```

---

## Key Commands This Mission

| Command | Purpose |
|---------|---------|
| `tee file` | Split stdout to screen and file |
| `wc -l` | Count lines from stdin |
| `grep pattern` | Filter lines from stdin |
| `head -n N` | First N lines |
| `tail -n N` | Last N lines |
| `sort` | Sort lines |
| `uniq -c` | Count duplicates |

---

## What's Next

Mission 07 covers Users & Groups — UIDs, GIDs, sudo, and permission models.

```bash
make practice N=06
```
