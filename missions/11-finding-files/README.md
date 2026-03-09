# Mission 11 — Finding Files

## Learning Goals

- Use `find` to locate files and directories by name, type, size, time, and permissions
- Combine multiple `find` criteria in a single command
- Execute actions on results with `-delete`, `-exec`, and `-exec ... +`
- Use `locate` for fast filename lookups backed by a pre-built database
- Use `which` and `whereis` to find commands and their related files

---

## find — The Real-Time Search Tool

`find` walks a directory tree and tests every entry against your criteria. It scans the filesystem in real time — no database, no caching, always current.

### Basic Syntax

```bash
find path [criteria] [action]
```

- **path** — where to start (`.` for current directory, `/` for the whole system)
- **criteria** — zero or more tests (`-name`, `-type`, `-size`, etc.)
- **action** — what to do with matches (default: `-print`)

```bash
find /etc -name "*.conf"        # files named *.conf under /etc
find . -name "README.md"        # named exactly README.md, from here
find /tmp -name "*.log"         # all .log files under /tmp
```

---

## Filtering by Type

```bash
find path -type f    # regular files only
find path -type d    # directories only
find path -type l    # symbolic links only
find path -type b    # block devices
find path -type c    # character devices
```

Examples:

```bash
find /etc -type d                   # all directories under /etc
find /usr/bin -type l               # symlinks in /usr/bin
find . -type f -name "*.sh"         # regular files named *.sh
```

---

## Filtering by Size

Size suffixes: `c` (bytes), `k` (kilobytes), `M` (megabytes), `G` (gigabytes).
Prefix with `+` (larger than) or `-` (smaller than):

```bash
find /var -size +10M                    # files larger than 10 MB
find /tmp -size -100k                   # files smaller than 100 KB
find /home -size +1G                    # files larger than 1 GB
find /var/log -size +1M -size -50M      # between 1 MB and 50 MB
```

---

## Filtering by Modification Time

`-mtime N` matches files modified N days ago. Use `+N` (more than N days ago) or `-N` (within the last N days):

```bash
find /var/log -mtime -7      # modified in the last 7 days
find /tmp -mtime +30         # not touched in over 30 days
find /etc -mtime 0           # modified today
find . -newer reference.txt  # newer than a reference file
```

Other time flags:
- `-atime` — last accessed
- `-ctime` — last status change (permissions, ownership)
- `-mmin` / `-amin` — in minutes: `-mmin -60` means "within the last hour"

---

## Filtering by Permissions

```bash
find /etc -perm 644           # exactly mode 644
find /usr/bin -perm /u+x      # user-executable bit set (any bit in set)
find /tmp -perm -o+w          # all listed bits must be set
find . -perm /a+x             # executable by anyone
```

`/` prefix — any of the listed bits are set (OR logic).
`-` prefix — all of the listed bits must be set (AND logic).

---

## Combining Criteria

Criteria are AND-ed by default. Use `-o` for OR, `!` for NOT:

```bash
find /var/log -name "*.log" -size +1M       # .log AND larger than 1 MB
find /tmp -type f -mtime +7                 # files not touched in a week
find . -name "*.bak" -o -name "*.tmp"       # .bak OR .tmp
find /etc ! -name "*.conf"                  # NOT named *.conf
```

Group with `\(` `\)`:

```bash
find . \( -name "*.log" -o -name "*.tmp" \) -mtime +30
```

---

## Actions

By default `find` prints each match (`-print`). Other actions:

```bash
find /tmp -name "*.tmp" -print              # explicit print (default)
find /tmp -name "*.tmp" -delete             # delete each match
find . -name "*.sh" -exec chmod +x {} \;   # run once per file
find . -name "*.log" -exec grep "ERROR" {} +  # batch: one call, all files
```

`-exec cmd {} \;` — `cmd` runs once per match. `{}` is replaced by the filename.
`-exec cmd {} +` — collects all matches and runs `cmd` once. Faster for large result sets.

```bash
# Copy all .conf files to a backup directory
find /etc -name "*.conf" -exec cp {} /tmp/conf-backup/ \;

# Count lines in all .sh files at once
find . -name "*.sh" -exec wc -l {} +
```

---

## locate — Fast Database Search

`locate` searches a pre-built filename database. It is far faster than `find` for simple name lookups, but the database is only refreshed periodically (usually nightly by `updatedb`).

```bash
locate passwd                  # paths containing 'passwd'
locate -i readme               # case-insensitive search
locate "*.conf" | head -20     # glob pattern (must quote it)
locate -c "*.log"              # count matches without printing paths
sudo updatedb                  # rebuild the database manually
```

**locate vs find:**

| | locate | find |
|---|---|---|
| Speed | Very fast | Slower (real-time scan) |
| Up to date | No (database may lag) | Yes |
| Search criteria | Name only | Name, type, size, time, perms, ... |
| Actions | None | -delete, -exec, ... |

---

## which and whereis — Finding Commands

```bash
which ls            # first 'ls' on your PATH
which -a python     # all python executables on PATH
whereis ls          # binary + man pages + source locations
whereis -b grep     # binary location only
whereis -m grep     # manual pages only
```

`which` searches your `$PATH` in order and stops at the first match.
`whereis` searches a fixed set of standard system locations regardless of `$PATH`.

---

## Key Commands This Mission

| Command | Purpose |
|---------|---------|
| `find path -name "*.txt"` | Find by name pattern |
| `find path -type f\|d\|l` | Find by file type |
| `find path -size +1M` | Find larger than 1 MB |
| `find path -mtime -7` | Modified in the last 7 days |
| `find path -newer ref` | Newer than a reference file |
| `find path -perm /u+x` | Executable by the owner |
| `find path -exec cmd {} \;` | Run command once per result |
| `find path -exec cmd {} +` | Run command once for all results |
| `find path -delete` | Delete every match |
| `locate pattern` | Fast database name search |
| `which cmd` | Find command on PATH |
| `whereis cmd` | Find binary, man pages, and source |

---

## What's Next

Mission 12 covers Archive & Compression — creating, inspecting, and extracting tarballs, and comparing gzip, bzip2, and xz.

```bash
make practice N=11
```
