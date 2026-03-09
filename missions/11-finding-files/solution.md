# Solution — Mission 11: Finding Files

---

## Exercise 1: find by Name

```bash
mkdir -p /tmp/m11/docs/notes
touch /tmp/m11/readme.txt /tmp/m11/README.md /tmp/m11/docs/report.txt /tmp/m11/docs/notes/todo.txt

find /tmp/m11 -name "readme.txt"
find /tmp/m11 -iname "readme*"
find /tmp/m11 -name "*.txt"
find /etc -name "*.conf" 2>/dev/null | head -10
find /tmp/m11 ! -name "*.txt"
```

**Quoting rule:** Always quote glob patterns when passing them to `find`:
```bash
find /etc -name "*.conf"   # correct — shell does not expand
find /etc -name *.conf     # wrong  — shell expands before find sees it
```

---

## Exercise 2: find by Type

```bash
find /tmp/m11 -type d
find /tmp/m11 -type f
find /usr/bin -type l | head -10
echo "symlinks: $(find /usr/bin -type l | wc -l)"
echo "regular:  $(find /usr/bin -type f | wc -l)"
find /etc -type d 2>/dev/null | wc -l
```

**Type values:**
| Flag | Type |
|------|------|
| `-type f` | Regular file |
| `-type d` | Directory |
| `-type l` | Symbolic link |
| `-type b` | Block device |
| `-type c` | Character device |
| `-type p` | Named pipe (FIFO) |
| `-type s` | Socket |

---

## Exercise 3: find by Size

```bash
dd if=/dev/zero of=/tmp/m11/large.bin bs=1M count=2 2>/dev/null
dd if=/dev/zero of=/tmp/m11/small.bin bs=1k count=5 2>/dev/null

find /tmp/m11 -type f -size +1M
find /tmp/m11 -type f -size -100k
find /var/log -type f -size +10M 2>/dev/null
find /tmp/m11 -type f -size +1k -size -100k
find /usr/bin -type f -printf '%s %p\n' | sort -n | tail -5
```

**Size prefixes:**
| Prefix | Meaning |
|--------|---------|
| `+N` | Greater than N |
| `-N` | Less than N |
| `N` | Exactly N (rare in practice) |

**Size suffixes:** `c` = bytes, `k` = 1024 bytes, `M` = 1024k, `G` = 1024M

---

## Exercise 4: find by Time

```bash
find /tmp/m11 -type f -mtime -1
find /var/log -type f -mtime +7 2>/dev/null | head -5
find /tmp -type f -mmin -60 2>/dev/null | head -10
touch /tmp/m11/reference.mark
sleep 1
touch /tmp/m11/newer-than-mark.txt
find /tmp/m11 -newer /tmp/m11/reference.mark
find /etc -ctime -1 2>/dev/null | head -10
```

**Time flags:**
| Flag | Meaning |
|------|---------|
| `-mtime -1` | Modified within the last 24 hours |
| `-mtime +7` | Modified more than 7 days ago |
| `-mtime 0` | Modified today (within the last 24h window) |
| `-mmin -60` | Modified within the last 60 minutes |
| `-newer file` | Modified more recently than `file` |
| `-atime` | Last accessed |
| `-ctime` | Last status change (metadata) |

---

## Exercise 5: find by Permissions

```bash
find /tmp -maxdepth 1 -perm -o+w -type f 2>/dev/null | head -5
find /usr/bin -perm -4000 2>/dev/null
find /usr/bin /usr/sbin -perm -2000 2>/dev/null
find /tmp/m11 -perm 644
find /usr/bin -user root -perm /u+x -type f | head -5
```

**Permission prefix meaning:**
| Prefix | Meaning |
|--------|---------|
| `-perm NNN` | Exactly mode NNN |
| `-perm -NNN` | All bits in NNN must be set (AND) |
| `-perm /NNN` | Any bit in NNN must be set (OR) |

Special bits in octal: setuid = `4000`, setgid = `2000`, sticky = `1000`

`find /usr/bin -perm -4000` — real security audit for setuid binaries.

---

## Exercise 6: Combining Criteria and Actions

```bash
find /tmp/m11 -name "*.txt" -type f -size +0c
find /tmp/m11 -name "*.txt" -exec ls -lh {} \;
find /tmp/m11 -name "*.txt" -exec ls -lh {} +
find /tmp/m11 -name "*.bin" -delete
find /tmp/m11 -name "*.txt" -exec wc -l {} +
```

**-exec vs -exec ... +:**
```bash
# Runs ls once per file (N processes):
find . -name "*.txt" -exec ls -lh {} \;

# Runs ls once for all files (1 process):
find . -name "*.txt" -exec ls -lh {} +
```

The `{}` is a placeholder — `find` substitutes each filename there. The `\;` terminates the `-exec` expression (must be escaped from the shell). `+` instead of `\;` batches all results into one command invocation.

---

## Exercise 7: locate and which

```bash
locate passwd | head -10
locate -i readme | head -5
locate -c "*.conf"
which grep
which -a python3 2>/dev/null || which -a python 2>/dev/null
whereis grep
whereis -b grep
whereis -m grep
```

**locate vs find:**
| | `locate` | `find` |
|--|----------|--------|
| Speed | Instant (database) | Slower (real-time) |
| Up to date | Lagged (nightly `updatedb`) | Always current |
| Search by | Name only | Name, type, size, time, permissions |
| Actions | None | `-delete`, `-exec`, ... |

`which` searches `$PATH` in order and stops at the first match.
`whereis` searches fixed standard directories, independent of your `$PATH`.

---

## Exercise 8: Real-world Find Challenges

```bash
find /tmp -maxdepth 1 -type f -empty 2>/dev/null | head -5
find /etc -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -5 | awk '{print $2}'
find /usr/bin -type f -exec file {} + | grep -i 'shell script' | head -10
find /etc -type f 2>/dev/null | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -10
find / -type d -perm -o+w 2>/dev/null | grep -v '/proc\|/sys\|/tmp\|/dev' | head -10
```

**Useful -printf format strings:**
| Format | Meaning |
|--------|---------|
| `%p` | File path |
| `%s` | File size in bytes |
| `%T@` | Modification time as Unix timestamp |
| `%m` | Permissions in octal |
| `%u` | Owner username |

**Real-world patterns:**
```bash
# Find recently changed config files
find /etc -type f -mmin -60 2>/dev/null

# Find large files consuming disk space
find / -type f -size +100M 2>/dev/null | head -10

# Find all cron scripts
find /etc/cron* /var/spool/cron -type f 2>/dev/null
```

---

## Quick Reference

```bash
find path -name "*.txt"         by name (glob, always quote)
find path -iname "*.txt"        case-insensitive name
find path -type f|d|l           by type
find path -size +1M             larger than 1 MB
find path -size -100k           smaller than 100 KB
find path -mtime -1             modified in last 24 hours
find path -mmin -60             modified in last 60 minutes
find path -newer ref.file       newer than reference file
find path -perm -4000           setuid bit set
find path -user username        owned by user
find path -exec cmd {} \;       run cmd once per match
find path -exec cmd {} +        run cmd once for all matches
find path -delete               delete all matches
find path -maxdepth 1           do not recurse deeper than 1 level
find path -empty                empty files or directories
locate pattern                  fast name search (database)
which cmd                       find command on PATH
whereis cmd                     binary + man pages location
```
