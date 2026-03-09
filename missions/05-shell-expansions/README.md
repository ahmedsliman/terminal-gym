# Mission 05 — Shell Expansions

## Learning Goals

- Understand that bash transforms your command *before* running it
- Use glob patterns to match files (`*`, `?`, `[...]`)
- Use brace expansion for generating lists `{a,b}` and sequences `{1..5}`
- Use tilde `~` and `~username` expansion
- Use command substitution `$()` to embed command output in a command
- Use arithmetic expansion `$((...))` for integer math
- Use variable expansion safely with `${VAR}`, `${VAR:-default}`

---

## How Expansion Works

Before bash runs a command, it expands it. The order is:

1. **Brace expansion** — `{a,b}` → `a b`
2. **Tilde expansion** — `~` → `/home/user`
3. **Parameter expansion** — `$VAR`, `${VAR}`
4. **Command substitution** — `$(cmd)`
5. **Arithmetic expansion** — `$((expr))`
6. **Word splitting** — results split on whitespace
7. **Glob expansion** — `*.txt` → matching filenames

Understanding the order prevents bugs.

---

## Glob Patterns

Globs match filenames in the current directory (or a given path):

| Pattern | Matches |
|---------|---------|
| `*` | Any string, including empty |
| `?` | Exactly one character |
| `[abc]` | One character: a, b, or c |
| `[a-z]` | One character in range a–z |
| `[!abc]` | One character NOT a, b, or c |

```bash
ls *.txt          # all .txt files
ls file?.txt      # file1.txt, fileA.txt, ...
ls [0-9]*.log     # files starting with a digit
```

**Globs do not match hidden files** (starting with `.`) unless the pattern itself starts with `.`.

---

## Brace Expansion

Brace expansion generates multiple words from a single pattern. It happens *before* glob expansion — so the results don't need to exist as files.

```bash
echo {a,b,c}            # a b c
echo file{1,2,3}.txt    # file1.txt file2.txt file3.txt
echo {1..5}             # 1 2 3 4 5
echo {a..e}             # a b c d e
echo {01..05}           # 01 02 03 04 05 (zero-padded)
mkdir -p project/{src,tests,docs}
touch file{1..10}.txt
```

---

## Command Substitution

`$(command)` runs the command and replaces itself with the output:

```bash
echo "Today is $(date)"
echo "You are in $(pwd)"
files=$(ls /etc/*.conf | wc -l)
echo "There are $files config files in /etc"
```

The older backtick syntax `` `command` `` does the same but doesn't nest well. Prefer `$()`.

---

## Arithmetic Expansion

`$((expression))` evaluates integer arithmetic:

```bash
echo $((2 + 3))         # 5
echo $((10 / 3))        # 3 (integer division)
echo $((10 % 3))        # 1 (remainder)
x=5; echo $((x * x))   # 25
```

For floating point, use `bc` or `awk`.

---

## Variable Expansion

| Syntax | Meaning |
|--------|---------|
| `$VAR` | Value of VAR |
| `${VAR}` | Same, but unambiguous |
| `${VAR:-default}` | Value of VAR, or "default" if unset/empty |
| `${VAR:=default}` | Value of VAR, or set it to "default" if unset/empty |
| `${#VAR}` | Length of VAR |
| `${VAR%pattern}` | Remove shortest match from end |
| `${VAR##pattern}` | Remove longest match from start |

```bash
FILE="report.2024.txt"
echo ${FILE%.txt}       # report.2024
echo ${FILE##*.}        # txt
echo ${FILE%.*}         # report.2024
echo ${FILE%%.*}        # report
```

---

## What's Next

Mission 06 covers Pipes & Redirection — stdin, stdout, stderr, and building pipelines.

```bash
make practice N=05
```
