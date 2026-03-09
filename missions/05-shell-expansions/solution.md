# Solution — Mission 05: Shell Expansions

---

## Exercise 1: Glob Patterns

```bash
mkdir -p /tmp/m05
cd /tmp/m05
touch file1.txt file2.txt file3.log report.txt README.md .hidden

ls *.txt          # file1.txt  file2.txt  report.txt
ls file*          # file1.txt  file2.txt  file3.log
ls ?.txt          # (nothing — no single-char basenames)
ls [a-r]*         # file1.txt  file2.txt  file3.log  report.txt
ls -a             # includes .hidden
ls .??*           # .hidden (dot + at least 2 chars)
```

**Glob rules:**
| Pattern | Meaning |
|---------|---------|
| `*` | Any string (including empty) |
| `?` | Exactly one character |
| `[abc]` | One of: a, b, c |
| `[a-z]` | One character in range |
| `[!abc]` | One character NOT in set |

**Gotcha:** Globs do not match hidden files unless the pattern starts with `.`.

---

## Exercise 2: Brace Expansion

```bash
echo {a,b,c,d}
echo item{1..5}.txt
mkdir -p /tmp/m05/project/{src,tests,docs,scripts}
touch /tmp/m05/project/src/{main.sh,utils.sh,config.sh}
echo log{001..005}.txt
```

**Key insight:** Brace expansion is NOT glob expansion. It generates words, not filenames. The generated names don't need to exist yet — that's why it's useful for creating files and directories.

---

## Exercise 3: Command Substitution

```bash
echo "I am $(whoami) on $(hostname)"
echo "There are $(ls /etc | wc -l) entries in /etc"
BACKUP="backup-$(date +%Y%m%d).tar.gz"
echo $BACKUP
echo "My home is $(echo ~)"
echo "Shell is $(basename $SHELL)"
```

**Nesting:** `$(cmd)` nests cleanly:
```bash
echo "PID digits: $(echo $$ | wc -c)"
```

**`wc -l < file` vs `wc -l file`:**
- `wc -l file` prints `N filename`
- `wc -l < file` prints just `N` (no filename) — better for embedding in strings

---

## Exercise 4: Arithmetic Expansion

```bash
echo $((3 + 4)) $((10 - 6)) $((5 * 5)) $((17 / 3))
echo $((17 % 3))    # 2

WIDTH=80; HEIGHT=24
echo "Area: $((WIDTH * HEIGHT))"   # 1920

USERS=$(wc -l < /etc/passwd)
echo "Users: $USERS, doubled: $((USERS * 2))"
```

**For floating point use bc:**
```bash
echo "scale=2; 10/3" | bc    # 3.33
```

**Supported operators:**
`+` `-` `*` `/` `%` (modulo) `**` (power) `<<` `>>` `&` `|` `^`

---

## Exercise 5: Variable Expansion Tricks

```bash
FILE="report.txt"
echo ${FILE%.txt}           # report

FILE="archive.tar.gz"
echo ${FILE##*.}            # gz

NAME=""
echo ${NAME:-"anonymous"}   # anonymous
NAME="ahmed"
echo ${NAME:-"anonymous"}   # ahmed

STR="hello world"
echo ${#STR}                # 11

PATH_VAR="/usr/local/bin/python3"
echo ${PATH_VAR##*/}        # python3
```

**Strip cheat sheet:**
| Syntax | Operation |
|--------|-----------|
| `${VAR%pattern}` | Strip shortest match from **end** |
| `${VAR%%pattern}` | Strip longest match from **end** |
| `${VAR#pattern}` | Strip shortest match from **start** |
| `${VAR##pattern}` | Strip longest match from **start** |

**Example with `photo.2024.jpg`:**
```bash
F="photo.2024.jpg"
echo ${F%%.*}    # photo  (strip everything from first dot)
echo ${F%.*}     # photo.2024  (strip from last dot)
echo ${F##*.}    # jpg  (keep only after last dot)
echo ${F#*.}     # 2024.jpg  (strip up to first dot)
```

---

## Exercise 6: Quoting and Expansion

```bash
ls /etc/*.conf | head -3         # glob expanded
echo '*.conf means any .conf file'   # single quote — literal
echo 'The $HOME variable holds your home directory'  # no expansion

echo "My home is $HOME"          # $HOME expanded
echo "Today: $(date +%F)"        # $() expanded
echo "Pattern: *.conf"           # glob NOT expanded in double quotes

echo "~"          # literal ~ — tilde NOT expanded in double quotes
echo ~            # /home/yourname — expanded
```

**Quoting rules summary:**
| | `$VAR` | `$()` | `$((` | Globs | Brace |
|-|--------|-------|--------|-------|-------|
| No quotes | ✓ | ✓ | ✓ | ✓ | ✓ |
| Double `"` | ✓ | ✓ | ✓ | ✗ | ✗ |
| Single `'` | ✗ | ✗ | ✗ | ✗ | ✗ |

**When to quote:**
- Always quote variables used in commands: `"$file"` not `$file`
- This prevents word splitting on filenames with spaces: `rm "$file"` is safe; `rm $file` breaks on `my file.txt`
