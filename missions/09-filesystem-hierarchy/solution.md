# Solution — Mission 09: Filesystem Hierarchy

---

## Exercise 1: Map the Root

```bash
ls -la /
ls -la /bin /sbin /lib 2>/dev/null | grep '\->'
ls / | wc -l
ls -F /
```

On modern Debian/Ubuntu:
- `/bin -> usr/bin`
- `/sbin -> usr/sbin`
- `/lib -> usr/lib`
- `/lib64 -> usr/lib64`

`ls -F` markers: `/` = directory, `@` = symlink, `*` = executable file, no marker = regular file.

---

## Exercise 2: /etc — Configuration

```bash
cat /etc/hostname
cat /etc/os-release
cat /etc/shells
ls /etc/*.conf | wc -l
ls -lt /etc | head -6
```

**Key /etc files:**
| File | Contents |
|------|----------|
| `/etc/hostname` | Machine name |
| `/etc/os-release` | Distribution ID, version, pretty name |
| `/etc/shells` | List of valid login shells |
| `/etc/fstab` | Filesystem mount table |
| `/etc/hosts` | Static hostname-to-IP mappings |

---

## Exercise 3: /var — Variable Data

```bash
ls /var
du -sh /var/log/* 2>/dev/null | sort -rh | head -5
find /var/log -type f | wc -l
ls /run | head -10
df -h /run
du -sh /var 2>/dev/null
```

**Key /var subdirectories:**
| Path | Purpose |
|------|---------|
| `/var/log` | Log files (syslog, auth.log, journald) |
| `/var/cache` | Package manager caches |
| `/var/spool` | Print queues, mail, cron jobs |
| `/var/run` → `/run` | Runtime PID files and sockets |
| `/var/tmp` | Temp files preserved across reboots |

`/run` is a `tmpfs` — it lives entirely in RAM. All content is lost on reboot.

---

## Exercise 4: /proc and /sys — Virtual Filesystems

```bash
cat /proc/uptime
ls /proc | grep '^[0-9]' | wc -l
grep -E '^(MemTotal|MemFree|MemAvailable)' /proc/meminfo
grep 'model name' /proc/cpuinfo | head -1
cat /sys/class/net/*/operstate 2>/dev/null
```

**Key /proc files:**
| File | Contains |
|------|---------|
| `/proc/uptime` | Seconds since boot |
| `/proc/meminfo` | Memory statistics |
| `/proc/cpuinfo` | Per-CPU details |
| `/proc/loadavg` | 1/5/15 minute load averages |
| `/proc/PID/` | Directory for each running process |

Nothing in `/proc` or `/sys` is stored on disk. The kernel synthesises these files on every read.

---

## Exercise 5: /dev — Device Files

```bash
ls -lh /dev/null /dev/zero /dev/random /dev/urandom
ls -l /dev/sda 2>/dev/null || ls -l /dev/nvme0n1 2>/dev/null || echo "no disk device found at these paths"
echo "this disappears" > /dev/null
wc -c /dev/null
head -c 16 /dev/urandom | xxd
ls /dev | wc -l
```

**Classic pseudo-devices:**
| Device | Purpose |
|--------|---------|
| `/dev/null` | Discard everything written; reads return EOF immediately |
| `/dev/zero` | Produces an infinite stream of zero bytes |
| `/dev/random` | Cryptographically random bytes (may block) |
| `/dev/urandom` | Cryptographically random bytes (non-blocking) |

`c` as the first character in `ls -l` = character device. `b` = block device.

---

## Exercise 6: /usr — Program and Data Layout

```bash
du -sh /usr/*/ 2>/dev/null | sort -rh | head -8
ls /usr/bin | wc -l
du -sh /usr/lib/*/ 2>/dev/null | sort -rh | head -5
ls /usr/share/man | head -10
ls /usr/local/bin 2>/dev/null || echo "(empty — no locally compiled software)"
```

**Key /usr subdirectories:**
| Path | Contents |
|------|----------|
| `/usr/bin` | User commands (most of them) |
| `/usr/sbin` | Admin commands |
| `/usr/lib` | Shared libraries |
| `/usr/share` | Architecture-independent data (man pages, icons, locale) |
| `/usr/include` | C/C++ header files |
| `/usr/local` | Locally compiled/installed software (outside package manager) |

---

## Exercise 7: /tmp — Temporary Space

```bash
ls -ld /tmp
stat /tmp | grep Access
df -hT /tmp
echo "session note" > /tmp/my-note.txt
cat /tmp/my-note.txt
touch /tmp/my-file.txt
```

**Key /tmp properties:**
- Permissions: `drwxrwxrwt` — world-writable with sticky bit (`t`)
- Sticky bit: prevents users from deleting files they don't own
- Usually a `tmpfs` — stored in RAM, cleared on reboot
- Never use `/tmp` for anything that must survive a reboot

The `t` at the end of `drwxrwxrwt` is the sticky bit. A capital `T` would mean sticky is set but the directory execute bit is not (misconfiguration).

---

## Exercise 8: findmnt — Mount Point Explorer

```bash
findmnt
findmnt -t ext4,xfs,btrfs,vfat 2>/dev/null || findmnt | grep -v 'tmpfs\|devtmpfs\|proc\|sys\|cgroup'
findmnt /home
findmnt /var
df -hT
findmnt | wc -l
```

**Reading findmnt output:**
```
TARGET     SOURCE    FSTYPE  OPTIONS
/          /dev/sda1 ext4    rw,relatime
├─/proc    proc      proc    rw,nosuid,nodev,...
├─/sys     sysfs     sysfs   rw,nosuid,nodev,...
├─/run     tmpfs     tmpfs   rw,nosuid,...
└─/home    /dev/sdb1 ext4    rw,relatime
```

`findmnt /path` finds which filesystem contains a given path — useful when diagnosing "disk full" errors that affect only one subtree.

---

## Quick Reference

```bash
ls -la /          top-level directory listing with symlink arrows
ls -F /           classify entries with type suffixes
findmnt           mount tree with filesystem types
findmnt /path     which filesystem owns this path
cat /proc/uptime  seconds since boot
cat /proc/meminfo memory breakdown (live from kernel)
ls /proc | grep '^[0-9]'   one directory per running process
df -hT            disk usage per filesystem with type
du -sh /var/log/* 2>/dev/null | sort -rh   largest log files
stat /tmp         inode info including sticky bit in octal
```
