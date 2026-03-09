# Solution — Mission 08: File Management

---

## Exercise 1: mkdir -p — Building Directory Trees

```bash
mkdir -p /tmp/m08
mkdir -p /tmp/m08/project/src/components
find /tmp/m08/project -type d | sort
mkdir -p /tmp/m08/project/src/components   # exit code 0, no error
echo "exit code: $?"
mkdir -p /tmp/m08/webapp/{frontend,backend}/{src,tests,docs}
find /tmp/m08/webapp -type d | sort
find /tmp/m08/webapp -type d | wc -l
```

**Why -p:**
- Without `-p`: fails if any parent directory is missing
- With `-p`: creates the entire path, idempotent (safe to run twice)

Step 5 count: `webapp` (1) + `frontend` (1) + `backend` (1) + 3 subdirs × 2 = **9 directories total**.

---

## Exercise 2: cp — Copying Files and Directories

```bash
echo "server config" > /tmp/m08/server.conf
echo "app config"    > /tmp/m08/app.conf
echo "readme text"   > /tmp/m08/README.md

cp /tmp/m08/server.conf /tmp/m08/server.conf.bak
ls /tmp/m08/*.conf*

mkdir -p /tmp/m08/backup
cp /tmp/m08/server.conf /tmp/m08/app.conf /tmp/m08/backup/
ls /tmp/m08/backup/

cp -r /tmp/m08/webapp/frontend /tmp/m08/webapp/frontend-v1
find /tmp/m08/webapp -type d | sort

cp -v /tmp/m08/README.md /tmp/m08/backup/README.md

cp -p /tmp/m08/server.conf /tmp/m08/server.preserved.conf
ls -l /tmp/m08/server.conf /tmp/m08/server.preserved.conf
```

**Key flags:**
| Flag | Effect |
|------|--------|
| `-r` | Recursive — required for directories |
| `-v` | Verbose — print each file copied |
| `-p` | Preserve timestamps, permissions, owner |
| `-i` | Prompt before overwriting |

---

## Exercise 3: mv — Move and Rename

```bash
mv /tmp/m08/server.conf.bak /tmp/m08/server.conf.old
ls /tmp/m08/*.conf*

mv /tmp/m08/server.conf.old /tmp/m08/backup/
ls /tmp/m08/backup/

mv /tmp/m08/webapp/frontend-v1/src /tmp/m08/webapp/frontend-v1/source
ls /tmp/m08/webapp/frontend-v1/

mv /tmp/m08/webapp/backend /tmp/m08/webapp/api
ls /tmp/m08/webapp/

echo "original"    > /tmp/m08/target.txt
echo "replacement" > /tmp/m08/source.txt
mv /tmp/m08/source.txt /tmp/m08/target.txt
cat /tmp/m08/target.txt    # prints: replacement
```

**Key points:**
- `mv` overwrites the destination silently — use `-i` to prompt
- `mv` does not need `-r` for directories (unlike `cp`)
- Renaming and moving are the same operation

---

## Exercise 4: rm — Deleting Files and Directories

```bash
echo "junk" > /tmp/m08/junk.txt
rm /tmp/m08/junk.txt
ls /tmp/m08/junk.txt 2>&1    # No such file or directory

touch /tmp/m08/a.tmp /tmp/m08/b.tmp /tmp/m08/c.tmp
rm /tmp/m08/a.tmp /tmp/m08/b.tmp /tmp/m08/c.tmp
ls /tmp/m08/*.tmp 2>&1       # No such file or directory

echo "test" > /tmp/m08/careful.txt
rm -i /tmp/m08/careful.txt   # type y or n

mkdir -p /tmp/m08/deleteme/sub1/sub2
touch /tmp/m08/deleteme/file1.txt /tmp/m08/deleteme/sub1/file2.txt
ls -R /tmp/m08/deleteme
rm -r /tmp/m08/deleteme
ls /tmp/m08/deleteme 2>&1    # No such file or directory
```

**Safe rm habits:**
```bash
rm -i file          # interactive: prompt before each delete
rm -ri directory/   # interactive recursive delete
# Never do this with a variable:
rm -rf "$VAR"       # if VAR is empty, this becomes: rm -rf /
```

---

## Exercise 5: Hard Links — ln

```bash
echo "shared data" > /tmp/m08/original.txt
ln /tmp/m08/original.txt /tmp/m08/link-a.txt
ls -li /tmp/m08/original.txt /tmp/m08/link-a.txt
# Both show the same inode number and link count 2

echo "updated via link" >> /tmp/m08/link-a.txt
cat /tmp/m08/original.txt    # shows the appended line

rm /tmp/m08/original.txt
cat /tmp/m08/link-a.txt      # data survives
ls -li /tmp/m08/link-a.txt   # link count drops to 1

ln /tmp/m08/link-a.txt /run/crossfs-test 2>&1 || echo "expected: cross-device link error"

ln /tmp/m08/backup /tmp/m08/backup-hard 2>&1 || echo "expected: cannot hard-link a directory"
```

**Hard link rules:**
- Hard links share an inode — both names point to the same data
- Cannot cross filesystem boundaries
- Cannot link directories (except by the kernel internally for `.` and `..`)
- Link count in `ls -li` tracks how many names point to the inode

---

## Exercise 6: Symbolic Links — ln -s

```bash
ln -s /tmp/m08/link-a.txt /tmp/m08/soft-link.txt
ls -l /tmp/m08/soft-link.txt     # shows -> /tmp/m08/link-a.txt
readlink /tmp/m08/soft-link.txt  # /tmp/m08/link-a.txt

cat /tmp/m08/soft-link.txt       # reads through to the target

ln -s /tmp/m08/webapp /tmp/m08/current-webapp
ls /tmp/m08/current-webapp/      # lists webapp contents

ln -s /tmp/m08/does-not-exist /tmp/m08/dangling
ls -l /tmp/m08/dangling          # shows arrow to non-existent path
cat /tmp/m08/dangling 2>&1       # No such file or directory
file /tmp/m08/dangling           # broken symbolic link

readlink -f /tmp/m08/soft-link.txt   # absolute resolved path
```

**Symlink vs hard link:**
| | Hard link | Symlink |
|--|-----------|---------|
| Own inode | No (shares) | Yes |
| Cross filesystem | No | Yes |
| Link directories | No | Yes |
| Broken if target deleted | No (data stays) | Yes (dangling) |

---

## Exercise 7: Inspecting Links — ls -li, file, readlink

```bash
echo "data" > /tmp/m08/data.txt
ln      /tmp/m08/data.txt /tmp/m08/hard.txt
ln -s   /tmp/m08/data.txt /tmp/m08/soft.txt
ln -s   /tmp/m08/soft.txt /tmp/m08/chain.txt

ls -li /tmp/m08/data.txt /tmp/m08/hard.txt /tmp/m08/soft.txt /tmp/m08/chain.txt
# data.txt and hard.txt share the same inode number

file /tmp/m08/data.txt /tmp/m08/hard.txt /tmp/m08/soft.txt /tmp/m08/chain.txt
# data.txt, hard.txt: ASCII text
# soft.txt: symbolic link to .../data.txt
# chain.txt: symbolic link to .../soft.txt

readlink /tmp/m08/chain.txt      # /tmp/m08/soft.txt (one step)
readlink -f /tmp/m08/chain.txt   # /tmp/m08/data.txt (fully resolved)

ls -l /tmp/m08/data.txt    # link count 2
rm /tmp/m08/hard.txt
ls -l /tmp/m08/data.txt    # link count drops to 1
```

---

## Exercise 8: du — Measuring Disk Usage

```bash
du -sh /tmp/m08/
du -sh /tmp/m08/*
du -ah --max-depth=1 /tmp/m08/ 2>/dev/null | sort -rh | head -10
du -sh /var/log 2>/dev/null
du -sh /usr/*/ 2>/dev/null | sort -rh | head -5
```

**Flag reference:**
| Flag | Meaning |
|------|---------|
| `-s` | Summary — one total per argument, no recursion |
| `-h` | Human-readable (K, M, G) |
| `-a` | All files, not just directories |
| `--max-depth=1` | Limit recursion to one level |

`sort -h` sorts human-readable sizes correctly: `1K < 10K < 1M`.

---

## Exercise 9: df — Filesystem Free Space and Finding Large Files

```bash
df -h
df -h /var
df -hT
du -sh /* 2>/dev/null | sort -rh | head -10
du -sh /usr/*/ 2>/dev/null | sort -rh | head -5
```

**df vs du:**
| | `df` | `du` |
|-|------|------|
| Unit | Filesystem | Directory tree |
| What it measures | Filesystem capacity and free space | Space used by files |
| Use for | "Is the disk full?" | "What is taking up space?" |

**Disk investigation workflow:**
```bash
df -h                               # 1. which filesystem is full?
du -sh /* 2>/dev/null | sort -rh    # 2. what at the top level is largest?
du -sh /var/* 2>/dev/null | sort -rh  # 3. drill into the culprit
```

---

## Quick Reference

```bash
mkdir -p path/to/dir    create full path, no error if exists
cp -r src dst           recursive copy
cp -p src dst           preserve timestamps and permissions
mv src dst              move or rename (no -r needed)
rm -i file              interactive delete (prompt first)
rm -r dir               recursive delete
ln target link          create hard link
ln -s target link       create symbolic link
readlink -f link        resolve symlink chain to real path
file path               identify file type by content
ls -li path             show inode number and link count
du -sh dir              total disk usage of directory
du -sh dir/* | sort -rh  sorted usage of each item
df -h                   disk free by filesystem
```
