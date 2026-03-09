# Mission 08 — File Management

## Learning Goals

- Create nested directory trees with `mkdir -p`
- Copy files and directories with `cp` and `cp -r`
- Move and rename with `mv`
- Delete files and directories with `rm`, `rm -r` (and why that's dangerous)
- Understand hard links and symbolic links, and when to use each
- Inspect links with `ls -l`, `readlink`, and `file`
- Measure disk usage with `du -sh` and `df -h`
- Find large files quickly using `du` + `sort`

---

## Creating Directories

`mkdir` creates a directory. The `-p` flag creates **all missing parent directories** in one shot and does not error if the directory already exists:

```bash
mkdir -p projects/web/src/components   # creates every missing level
mkdir -p existing/dir                  # no error — already exists
```

Combine with brace expansion to create entire project skeletons:

```bash
mkdir -p app/{frontend,backend}/{src,tests}
```

---

## Copying — cp

```bash
cp source dest           # copy a file
cp file1 file2 dir/      # copy multiple files into a directory
cp -r srcdir/ destdir/   # recursive copy — required for directories
cp -p file dest          # preserve timestamps and permissions
cp -v file dest          # verbose — print each file as it is copied
```

`cp` never follows the trailing slash rule — `cp src/ dst/` copies the *contents*
of `src` into `dst`. Without `-r`, `cp` refuses to copy a directory.

---

## Moving and Renaming — mv

`mv` both **renames** and **moves**. There is no separate rename command:

```bash
mv old.txt new.txt           # rename within same directory
mv file.txt dir/             # move into a directory
mv dir1/ dir2/               # rename a directory (no -r needed)
mv *.log /var/log/archive/   # move multiple files (glob)
```

`mv` is atomic (on the same filesystem) — either the whole move succeeds
or nothing changes. No `-r` flag needed for directories.

---

## Deleting — rm

```bash
rm file.txt            # delete a file
rm file1 file2         # delete multiple files
rm -i file.txt         # interactive — ask before each deletion
rm -r dir/             # recursive — delete directory and all contents
rm -rf dir/            # recursive + force (no prompts, ignores errors)
```

`rm` has **no undo**. There is no Recycle Bin. Deleted files are gone.

**Safe habits:**
- Use `rm -i` when unsure
- Confirm the path before running `rm -rf`
- Never run `rm -rf` as root on a path with a variable that could be empty
  (`rm -rf "$DIR/"` where `$DIR` is empty becomes `rm -rf /`)

---

## Hard Links — ln

A **hard link** is a second directory entry pointing to the **same inode**
(the same data on disk). Both names are equally "real" — there is no original.

```bash
ln original.txt hardlink.txt   # create a hard link
ls -li                         # -i shows inode numbers — they match
```

Properties of hard links:
- Same inode number, same file size, same data
- Deleting one name leaves the other intact
- Cannot span filesystems (different partitions)
- Cannot link directories (on most Linux systems)

---

## Symbolic Links — ln -s

A **symbolic link** (symlink, soft link) is a file that holds a **path** to
another file. It is a pointer, not a copy.

```bash
ln -s /etc/hosts hosts-link   # create a symlink
ls -l hosts-link              # shows:  hosts-link -> /etc/hosts
readlink hosts-link           # prints: /etc/hosts
file hosts-link               # "symbolic link to /etc/hosts"
```

Properties of symlinks:
- Has its own inode — different from the target
- Can span filesystems
- Can point to directories
- Breaks (becomes a "dangling link") if the target is deleted or moved

---

## Inspecting Links

| Command | What it shows |
|---------|---------------|
| `ls -l` | Arrow `->` indicates symlink; permission string starts with `l` |
| `ls -li` | Inode numbers — hard links share them |
| `readlink linkname` | Print the target path of a symlink |
| `readlink -f linkname` | Resolve the full canonical path (follow chain) |
| `file linkname` | Describes the file type, including symlinks |

---

## Disk Usage — du and df

`df` reports **filesystem-level** free and used space:

```bash
df -h          # all mounted filesystems in human-readable sizes
df -h /        # just the root filesystem
df -h /home    # just the filesystem holding /home
```

`du` reports **directory-level** disk usage:

```bash
du -sh dir/          # total size of a directory, human-readable
du -sh *             # size of every item in the current directory
du -sh /var/log      # how much space the log directory uses
```

---

## Finding Large Files Quickly

Combine `du`, `sort`, and `head` to find what is eating your disk:

```bash
# Top 10 largest items at the top level of / (errors silenced)
du -sh /* 2>/dev/null | sort -rh | head

# Top 10 largest subdirectories inside /var
du -sh /var/*/ 2>/dev/null | sort -rh | head
```

`sort -h` sorts human-readable sizes (1K, 2M, 3G) correctly.
`sort -rh` reverses the order — largest first.

---

## Key Commands This Mission

| Command | Purpose |
|---------|---------|
| `mkdir -p path` | Create nested directories in one step |
| `cp -r src dst` | Copy a directory recursively |
| `mv src dst` | Move or rename (works for files and dirs) |
| `rm -r dir` | Delete a directory and all its contents |
| `ln target link` | Create a hard link |
| `ln -s target link` | Create a symbolic (soft) link |
| `ls -l` | Show file type and symlink arrows |
| `ls -li` | Show inode numbers (useful for hard links) |
| `readlink link` | Print symlink target |
| `file path` | Describe the type of a file |
| `du -sh path` | Size of a directory |
| `df -h` | Filesystem free space |

---

## What's Next

Mission 09 covers the Filesystem Hierarchy Standard (FHS) — understanding
what belongs where in a Linux system (`/etc`, `/var`, `/usr`, `/proc`, ...).

```bash
make practice N=08
```
