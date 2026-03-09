# Mission 13 — Ownership & Permissions

## Learning Goals

- Read and decode a permission string from `ls -l` (`-rwxr-xr--`)
- Understand the three classes: user (owner), group, other
- Convert between symbolic and octal permission notation
- Use `chmod` with both symbolic (`u+x`, `go-w`) and numeric (`644`, `755`) modes
- Use `chown` to change file owner and group
- Understand `umask` — how it shapes default permissions for new files and directories
- Recognise the three special bits: setuid, setgid, sticky
- Know where each special bit is used in practice (`/usr/bin/passwd`, `/tmp`)
- Use `stat` to inspect full permission details including the raw octal value

---

## Permission Bits — The Basics

Every file and directory on Linux carries a set of **permission bits** that control who can do what to it.

```
-rwxr-xr--
│├─┤├─┤├─┤
│ u   g   o
│
└── file type:  - = regular file, d = directory, l = symlink
```

The ten characters break down as:

| Position | Meaning |
|----------|---------|
| 1 | File type (`-`, `d`, `l`, `c`, `b`, `p`, `s`) |
| 2–4 | **User** (owner) bits: `rwx` |
| 5–7 | **Group** bits: `rwx` |
| 8–10 | **Other** (world) bits: `rwx` |

Each slot is either the letter (`r`, `w`, `x`) or a dash (`-`) meaning the permission is not set.

### What r, w, x mean

| Bit | On a regular file | On a directory |
|-----|-------------------|----------------|
| `r` | Read the file contents | List directory entries (`ls`) |
| `w` | Modify / overwrite the file | Create, delete, rename files inside |
| `x` | Execute the file as a program | Enter the directory (`cd`), traverse it |

A directory without `x` is effectively sealed — you can see its name but cannot enter or access anything inside it.

---

## Octal (Numeric) Notation

Each `rwx` triple maps to a 3-bit number:

```
r = 4   w = 2   x = 1
```

Add the values for each class:

| Symbolic | Octal | Meaning |
|----------|-------|---------|
| `rwx` | 7 | read + write + execute |
| `rw-` | 6 | read + write |
| `r-x` | 5 | read + execute |
| `r--` | 4 | read only |
| `---` | 0 | no permissions |

Common permission combinations:

| Octal | Symbolic | Typical use |
|-------|----------|-------------|
| `644` | `-rw-r--r--` | Normal files (owner edits, others read) |
| `755` | `-rwxr-xr-x` | Executables and public directories |
| `600` | `-rw-------` | Private files (SSH keys, secrets) |
| `700` | `-rwx------` | Private executables or directories |
| `664` | `-rw-rw-r--` | Shared group-editable files |
| `775` | `-rwxrwxr-x` | Shared group-editable directories |

---

## chmod — Change Mode

`chmod` changes permission bits. You can use symbolic or numeric mode.

### Symbolic mode

```bash
chmod WHO OPERATOR PERMISSION file

# WHO:        u (user/owner)  g (group)  o (other)  a (all)
# OPERATOR:   + (add)   - (remove)   = (set exactly)
# PERMISSION: r  w  x
```

Examples:

```bash
chmod u+x script.sh        # add execute for owner
chmod go-w shared.txt      # remove write from group and other
chmod a+r public.txt       # add read for everyone
chmod u=rw,go=r config     # set owner to rw, group and other to r
chmod o= secret.key        # remove ALL permissions from other
```

### Numeric mode

```bash
chmod 644 file.txt         # -rw-r--r--
chmod 755 script.sh        # -rwxr-xr-x
chmod 600 ~/.ssh/id_rsa    # -rw-------
chmod -R 755 mydir/        # recursive: directory and all contents
```

---

## chown — Change Ownership

```bash
chown owner file           # change owner only
chown owner:group file     # change owner and group
chown :group file          # change group only (same as chgrp)
chown -R owner:group dir/  # recursive
```

Examples:

```bash
chown alice report.txt
chown alice:developers project/
chown -R www-data:www-data /var/www/html/
```

Only root can change the owner of a file. A regular user can change the group of a file they own, but only to a group they themselves belong to.

---

## umask — Default Permission Mask

When you create a new file or directory, the kernel starts with a base permission and then **subtracts** the umask bits.

```
Base for files:       666  (rw-rw-rw-)
Base for directories: 777  (rwxrwxrwx)
Typical umask:        022
```

Subtraction in octal (mask bits are zeroed out):

```
Files:       666 - 022 = 644  ->  -rw-r--r--
Directories: 777 - 022 = 755  ->  drwxr-xr-x
```

Common umask values:

| umask | New files | New directories | Typical use |
|-------|-----------|-----------------|-------------|
| `022` | `644` | `755` | Default — others can read |
| `027` | `640` | `750` | Restrict group, block others |
| `077` | `600` | `700` | Private — others see nothing |

```bash
umask           # show current mask (octal)
umask -S        # show symbolic form (u=rwx,g=rx,o=rx)
umask 027       # set mask for this session
```

---

## Special Bits

There are three extra permission bits beyond the standard `rwx` set. They occupy a fourth octal digit prepended to the standard three.

### Setuid (SUID) — bit 4

When set on an **executable**, the program runs with the **file owner's** UID instead of the caller's UID.

```bash
ls -l /usr/bin/passwd
# -rwsr-xr-x 1 root root ...
#    ^--- 's' in owner execute position = setuid + executable
```

`/usr/bin/passwd` is owned by root and has setuid set — so when any user runs it, it temporarily gains root privileges to update `/etc/shadow`. The letter `s` replaces `x` in the display when both setuid and execute are set. An uppercase `S` means setuid is set but the execute bit is *not* — almost always a misconfiguration.

```bash
chmod u+s file         # add setuid (symbolic)
chmod 4755 file        # numeric: 4=setuid, 755=rwxr-xr-x
```

### Setgid (SGID) — bit 2

On an **executable**: the process runs with the file's group GID.
On a **directory**: files created inside inherit the directory's group rather than the creator's primary group. This is essential for shared project directories.

```bash
ls -ld /var/mail
# drwxrwsr-x  ...  mail  ...
#       ^--- 's' in group execute position = setgid

chmod g+s shared_dir/
chmod 2775 shared_dir/
```

### Sticky bit — bit 1

On a **directory**: users can only delete or rename files they *own*, even if they have write permission on the directory itself. The classic use is `/tmp`.

```bash
ls -ld /tmp
# drwxrwxrwt  ...
#          ^--- 't' = sticky bit set AND execute set

chmod +t /tmp
chmod 1777 /tmp
```

A capital `T` means sticky is set but directory execute is not.

---

## stat — Full Permission Details

`ls -l` gives a human-friendly summary. `stat` exposes everything the inode stores:

```bash
stat file.txt
```

```
  File: file.txt
  Size: 1234     Blocks: 8    IO Block: 4096  regular file
Device: fd01h/64769d  Inode: 524319   Links: 1
Access: (0644/-rw-r--r--)  Uid: (1000/alice)   Gid: (1000/alice)
Modify: 2024-01-15 10:23:45.000000000 +0000
```

The `Access:` line shows both the octal value (`0644`) and the symbolic string simultaneously. This is the most reliable way to confirm the exact numeric mode of a file.

---

## Key Commands This Mission

| Command | Purpose |
|---------|---------|
| `ls -l` | Long listing with permission string |
| `ls -ld dir/` | Show the directory entry itself, not its contents |
| `chmod MODE file` | Change permission bits (symbolic or numeric) |
| `chmod -R MODE dir/` | Recursive chmod |
| `chown user:group file` | Change owner and group |
| `umask` | Show or set default permission mask |
| `stat file` | Full inode metadata including octal permissions |

---

## What's Next

Mission 14 covers Process Management — inspecting, signalling, and controlling running processes.

```bash
make practice N=13
```
