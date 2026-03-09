# Solution — Mission 03: Linux Philosophy

---

## Exercise 1: wc — Count Things

```bash
wc -l /etc/passwd
wc -w /etc/hostname
wc -c /etc/hosts
wc -l /etc/passwd /etc/group /etc/hosts
```

**Why they match:**
```bash
wc -l /etc/passwd
grep -c '' /etc/passwd
# Both count the number of newline-terminated lines
```

---

## Exercise 2: Pipelines with cut, sort, uniq

```bash
# Usernames
cut -d: -f1 /etc/passwd

# Login shells
cut -d: -f7 /etc/passwd

# Shell usage count
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn

# Unique home directory roots
cut -d: -f6 /etc/passwd | cut -d/ -f2 | sort -u
```

**Why sort before uniq?** `uniq` only removes *adjacent* duplicates. Without sorting first, duplicates that aren't consecutive stay in the output.

---

## Exercise 3: /dev — Device Files

```bash
ls -lh /dev/null /dev/zero /dev/urandom
ls /etc > /dev/null
echo $?           # prints 0

head -c 8 /dev/urandom | od -An -tx1 | tr -d ' \n'; echo
```

**What the permissions mean:**
```
crw-rw-rw- 1 root root 1, 3 ...  /dev/null
^
c = character device (not a regular file)
```

---

## Exercise 4: /proc — The Kernel's Window

```bash
cat /proc/uptime
grep -m1 "model name" /proc/cpuinfo
grep MemTotal /proc/meminfo
grep -c '^processor' /proc/cpuinfo
echo $$
cat /proc/$$/status | head -10
```

**Uptime in hours:**
```bash
awk '{printf "%.1f hours\n", $1/3600}' /proc/uptime
```

**Key insight:** Nothing in `/proc` exists on disk. The kernel synthesizes the content when you read it. Writing to certain files in `/proc` changes kernel behaviour at runtime.

---

## Exercise 5: tr — Translate Characters

```bash
echo "hello world" | tr a-z A-Z
echo "one two three" | tr ' ' '\n'
echo "too    many    spaces" | tr -s ' '
printf "line1\nline2\nline3\n" | tr -d '\n'; echo
cat /etc/hostname | tr a-z A-Z
```

**tr vs sed:**
- `tr` works on individual characters — it's fast and simple
- `sed` works on patterns — more powerful but heavier
- For character-level transforms, always reach for `tr` first

---

## Exercise 6: Build a Pipeline from Scratch

```bash
cut -d: -f1 /etc/passwd | awk '{print length, $0}' | sort -rn | head -5
```

**Breaking it down:**
| Stage | What it does |
|-------|-------------|
| `cut -d: -f1 /etc/passwd` | Extract usernames |
| `awk '{print length, $0}'` | Prefix each line with its length |
| `sort -rn` | Sort numerically, highest first |
| `head -5` | Keep only top 5 |

**The pipeline principle:** Each command is unaware of the others. `awk` doesn't know it's reading usernames. `sort` doesn't know what it's sorting. The *composition* creates meaning.

---

## Exercise 7: /proc — Per-Process

```bash
echo $$
ls /proc/$$
cat /proc/$$/cmdline | tr '\0' ' '
ls -lh /proc/$$/fd
readlink /proc/$$/cwd
```

**File descriptor symlinks:**
```
/proc/$$/fd/0 -> /dev/pts/0   (your terminal — stdin)
/proc/$$/fd/1 -> /dev/pts/0   (your terminal — stdout)
/proc/$$/fd/2 -> /dev/pts/0   (your terminal — stderr)
```

**Why `/proc/$$/cmdline` uses null bytes:** Unix argv arrays are null-terminated C strings. `/proc` exposes them raw. `tr '\0' ' '` makes them readable.

---

## The Unix Philosophy — Summary

| Rule | In practice |
|------|------------|
| One thing well | `wc` counts. `cut` extracts. `sort` sorts. |
| Work together | `\|` passes stdout to stdin |
| Text streams | Every tool reads and writes lines of text |

```
The whole is greater than the sum of its parts —
but only because each part is well-defined and composable.
```
