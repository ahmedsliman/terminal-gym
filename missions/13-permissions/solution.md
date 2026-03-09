# Solution — Mission 13: Ownership & Permissions

---

## Exercise 1: Decoding Permission Strings

```bash
ls -l /etc/hostname /usr/bin/ls /usr/bin/passwd /tmp
ls -l /usr/bin/passwd
ls -ld /tmp
find /usr/bin -perm -4000 -ls 2>/dev/null
```

**Anatomy of `-rwsr-xr-x`:**
```
- rwx r-x r-x
│ │   │   └── other: read + execute
│ │   └────── group: read + execute
│ └────────── user:  read + write + execute
└──────────── type: regular file

For /usr/bin/passwd:
- rws r-x r-x
      ^
      's' = setuid bit set AND execute set
```

**Special bit display:**
| Display | Meaning |
|---------|---------|
| `s` (user execute) | setuid set, execute set |
| `S` (user execute) | setuid set, execute NOT set (misconfiguration) |
| `s` (group execute) | setgid set, execute set |
| `t` (other execute) | sticky set, execute set |

---

## Exercise 2: Octal Notation — Decoding

```bash
stat -c '%a %n' /etc/hostname /usr/bin/ls /usr/bin/passwd ~/.bashrc 2>/dev/null
```

**Conversion table:**
```
r = 4   w = 2   x = 1

644:  6=rw-  4=r--  4=r--   ->  -rw-r--r--
755:  7=rwx  5=r-x  5=r-x   ->  -rwxr-xr-x
600:  6=rw-  0=---  0=---   ->  -rw-------
700:  7=rwx  0=---  0=---   ->  -rwx------
664:  6=rw-  6=rw-  4=r--   ->  -rw-rw-r--
750:  7=rwx  5=r-x  0=---   ->  -rwxr-x---
640:  6=rw-  4=r--  0=---   ->  -rw-r-----
```

For `rwxr-x---`: u=rwx=7, g=r-x=5, o=---=0 → **750**
For `640`: 6=rw-, 4=r--, 0=--- → **rw-r-----**

---

## Exercise 3: chmod — Changing Permissions

```bash
mkdir -p /tmp/m13
echo "content" > /tmp/m13/file.txt
cp /tmp/m13/file.txt /tmp/m13/script.sh

chmod u+x /tmp/m13/script.sh
ls -l /tmp/m13/script.sh

chmod go-w /tmp/m13/file.txt
ls -l /tmp/m13/file.txt

chmod 644 /tmp/m13/file.txt
chmod 755 /tmp/m13/script.sh
ls -l /tmp/m13/

chmod u=rw,go=r /tmp/m13/file.txt
ls -l /tmp/m13/file.txt

chmod o= /tmp/m13/file.txt
ls -l /tmp/m13/file.txt
stat -c '%a' /tmp/m13/file.txt   # 640
```

**Symbolic mode operators:**
| Operator | Effect |
|----------|--------|
| `+` | Add the bits |
| `-` | Remove the bits |
| `=` | Set exactly (clears all others for that class) |

`chmod o=` removes all permissions from other (equivalent to `chmod o-rwx`).

---

## Exercise 4: chmod -R — Recursive Permissions

```bash
mkdir -p /tmp/m13/project/{src,docs}
touch /tmp/m13/project/src/main.sh /tmp/m13/project/docs/README.md

# Wrong approach — sets execute on data files:
chmod -R 755 /tmp/m13/project/

# Correct approach — different rules for files vs directories:
find /tmp/m13/project -type d -exec chmod 755 {} +
find /tmp/m13/project -type f -exec chmod 644 {} +

# Make only shell scripts executable:
find /tmp/m13/project -name "*.sh" -exec chmod 755 {} +

stat -c '%a %n' /tmp/m13/project/src/main.sh /tmp/m13/project/docs/README.md
```

**The correct recursive permission pattern:**
```bash
find /path -type d -exec chmod 755 {} +   # directories: traversable
find /path -type f -exec chmod 644 {} +   # files: readable, not executable
find /path -name "*.sh" -exec chmod +x {} +  # scripts: executable
```

Never use `chmod -R 755` on a directory containing data files.

---

## Exercise 5: umask — Default Permissions

```bash
umask
umask -S

touch /tmp/m13/default-file.txt
mkdir /tmp/m13/default-dir
ls -l /tmp/m13/default-file.txt
ls -ld /tmp/m13/default-dir
stat -c '%a %n' /tmp/m13/default-file.txt /tmp/m13/default-dir

umask 077
touch /tmp/m13/private-file.txt
mkdir /tmp/m13/private-dir
stat -c '%a %n' /tmp/m13/private-file.txt /tmp/m13/private-dir

umask 022
```

**umask calculation:**
```
Files base:       666  (never executable by default)
Directories base: 777

umask 022:  remove w from group and other
  Files:       666 & ~022 = 644  (rw-r--r--)
  Directories: 777 & ~022 = 755  (rwxr-xr-x)

umask 027:  remove w from group, all from other
  Files:       666 & ~027 = 640  (rw-r-----)
  Directories: 777 & ~027 = 750  (rwxr-x---)

umask 077:  remove everything from group and other
  Files:       666 & ~077 = 600  (rw-------)
  Directories: 777 & ~077 = 700  (rwx------)
```

---

## Exercise 6: Special Bits — setuid, setgid, sticky

```bash
ls -l /usr/bin/passwd
stat -c '%a %n' /usr/bin/passwd   # 4755

find /var /run -type d -perm -2000 2>/dev/null | head -5

ls -ld /tmp
stat -c '%a' /tmp   # 1777

stat /usr/bin/passwd | grep Access
```

**Special bit encoding:**
| Bit | Octal | Displayed as |
|-----|-------|-------------|
| setuid | 4000 | `s` or `S` in user execute position |
| setgid | 2000 | `s` or `S` in group execute position |
| sticky | 1000 | `t` or `T` in other execute position |

```
4755 = setuid(4) + user-rwx(7) + group-r-x(5) + other-r-x(5)
2775 = setgid(2) + user-rwx(7) + group-rwx(7) + other-r-x(5)
1777 = sticky(1) + all-rwx(777)
```

---

## Exercise 7: chown — Changing Ownership

```bash
ls -l /tmp/m13/file.txt
stat -c '%U %G %n' /tmp/m13/file.txt

chown :$(id -gn) /tmp/m13/file.txt
ls -l /tmp/m13/file.txt

chown root /tmp/m13/file.txt 2>&1   # Operation not permitted (expected)

ls -la /var/www/html 2>/dev/null || echo "Apache web root not installed"
```

**chown syntax:**
```bash
chown user file            # change owner only
chown user:group file      # change owner and group
chown :group file          # change group only (same as chgrp group file)
chown -R user:group dir/   # recursive
```

**Who can change what:**
| Operation | Who can do it |
|-----------|--------------|
| Change owner to self | root only |
| Change owner to another user | root only |
| Change group to any group you belong to | File owner |
| Change group to a group you don't belong to | root only |

---

## Exercise 8: Real-world Permission Scenarios

```bash
echo "-----BEGIN PRIVATE KEY-----" > /tmp/m13/id_rsa_fake
chmod 600 /tmp/m13/id_rsa_fake
stat -c '%a %n' /tmp/m13/id_rsa_fake

mkdir -p /tmp/m13/shared
chmod 775 /tmp/m13/shared
ls -ld /tmp/m13/shared

mkdir -p /tmp/m13/shared-sticky
chmod 1777 /tmp/m13/shared-sticky
ls -ld /tmp/m13/shared-sticky

chmod 700 /tmp/m13/script.sh
ls -l /tmp/m13/script.sh

find ~ -type f -perm /o+w 2>/dev/null | head -10
```

**Common permission patterns:**
| Scenario | Permissions |
|----------|------------|
| SSH private key | `600` |
| SSH authorized_keys | `600` |
| `~/.ssh` directory | `700` |
| Web server files | `644` (files), `755` (directories) |
| Shared group directory | `775` or `2775` (setgid) |
| World-shared temp area | `1777` (sticky) |
| Admin script | `750` (owner runs, group reads, others excluded) |

---

## Quick Reference

```bash
ls -l path          show permission string
ls -ld dir/         show the directory entry itself
stat -c '%a %n' f   print octal permissions + filename
chmod 644 file      numeric: rw-r--r--
chmod u+x file      symbolic: add execute for owner
chmod go-w file     remove write from group and other
chmod u=rw,go=r f   set exactly: owner rw, group+other r
chmod -R ... dir/   recursive (use with find for safety)
chown user:grp f    change owner and group
chown :group file   change group only
umask               show current default mask
umask 022           set mask for this session
find / -perm -4000  find setuid files (security audit)
find ~ -perm /o+w   find world-writable files in home
```
