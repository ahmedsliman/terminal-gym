# Mission 09 — Filesystem Hierarchy

## Learning Goals

- Understand the Filesystem Hierarchy Standard (FHS) and why it exists
- Know what belongs in each top-level directory and why
- Distinguish virtual filesystems (`/proc`, `/sys`) from real ones
- Use `ls`, `cat`, `find`, and `du` to explore the hierarchy confidently
- Recognize the modern symlink consolidation (`/bin` → `/usr/bin`)

---

## The Filesystem Hierarchy Standard

Linux does not organize files randomly. The FHS defines where each type of file
lives so that software, administrators, and users all agree on the map. Every
distribution follows the same layout, so skills you build on one system transfer
directly to any other.

```
/
├── bin  →  usr/bin      (user commands — symlink on modern systems)
├── sbin →  usr/sbin     (admin commands — symlink on modern systems)
├── lib  →  usr/lib      (shared libraries — symlink on modern systems)
├── etc/                 (host-specific configuration)
├── var/                 (variable data: logs, spool, cache)
├── home/                (user home directories)
├── root/                (root user's home)
├── tmp/                 (temporary files, cleared on reboot)
├── usr/                 (read-only user programs and data)
│   ├── bin/             (most user commands)
│   ├── sbin/            (most admin commands)
│   ├── lib/             (shared libraries)
│   └── local/           (locally-installed software)
├── dev/                 (device files)
├── proc/                (kernel virtual filesystem — process info)
├── sys/                 (kernel virtual filesystem — hardware info)
├── mnt/                 (manual mount points)
├── media/               (removable media mount points)
└── opt/                 (optional third-party software)
```

---

## / — Root

Everything in Linux hangs under `/`. There is only one root — no drive letters,
no separate trees. Mounting attaches additional storage *into* this single tree.

```bash
ls /          # the top-level layout
ls -la /      # note symlinks: bin -> usr/bin, etc.
```

---

## /bin, /sbin and the Modern Symlink

Historically, `/bin` held commands needed before `/usr` was mounted (e.g. in
early boot), and `/usr/bin` held everything else. Modern systems have merged
them: `/bin` is now a symlink to `/usr/bin`, and `/sbin` is a symlink to
`/usr/sbin`. The distinction is gone in practice, but the paths still work.

```bash
ls -la /bin       # symlink to usr/bin on most modern distros
ls /usr/bin | wc -l   # hundreds of commands live here
```

---

## /etc — Configuration

`/etc` holds host-specific, system-wide configuration files. Nearly everything
is a plain text file you can read with `cat`. No binaries live here.

```bash
cat /etc/hostname     # machine name
cat /etc/os-release   # distribution info
cat /etc/shells       # valid login shells
ls /etc/*.conf | head -10   # config files
```

---

## /var — Variable Data

`/var` holds data that changes while the system runs: logs, mail spools, package
databases, lock files, and caches. Its subdirectories are the most active part
of the filesystem during normal operation.

| Path | Contents |
|------|----------|
| `/var/log` | System and application log files |
| `/var/cache` | Application cache data |
| `/var/spool` | Queued data (print jobs, mail, cron) |
| `/var/run` or `/run` | Runtime data (PID files, sockets) |
| `/var/tmp` | Temporary files preserved across reboots |

```bash
ls /var/log
du -sh /var/log/* 2>/dev/null | sort -rh | head -5
```

---

## /home and /root

`/home` contains one directory per regular user. `/root` is the root user's home
— kept separate from `/home` so the superuser's environment survives even when
`/home` is on a different partition.

```bash
ls /home          # one entry per user account
ls -la /root      # root's dotfiles (permission denied unless you're root)
echo $HOME        # your own home path
```

---

## /tmp — Temporary Space

`/tmp` is world-writable. Any user or process can create files there. On most
systems it is a `tmpfs` mount — stored in RAM/swap and wiped on every reboot.
Never store anything important here.

```bash
ls -la /tmp       # world-writable, sticky bit set
df -h /tmp        # often a tmpfs (RAM-backed)
stat /tmp         # note the sticky bit (permissions end in 't')
```

---

## /usr — Read-Only Programs and Data

`/usr` is the largest branch. It holds the bulk of installed programs, libraries,
header files, documentation, and shared data. In theory `/usr` should be
read-only and shareable across machines on a network.

| Path | Contents |
|------|----------|
| `/usr/bin` | User commands |
| `/usr/sbin` | Admin commands |
| `/usr/lib` | Shared libraries |
| `/usr/local` | Locally compiled/installed software |
| `/usr/share` | Architecture-independent data (man pages, icons) |
| `/usr/include` | C header files |

```bash
du -sh /usr/*/  2>/dev/null | sort -rh | head -8
ls /usr/share | head -20
```

---

## /lib and Shared Libraries

Shared libraries (`.so` files) are the Linux equivalent of Windows DLLs. They
let multiple programs share a single copy of common code in memory. `/lib` is
symlinked to `/usr/lib` on modern systems.

```bash
ls /usr/lib | head -20
ldconfig -p | wc -l        # number of cached shared libraries
ldd /usr/bin/ls            # libraries that ls depends on
```

---

## /dev — Device Files

The kernel exposes hardware as files in `/dev`. Reading or writing these files
talks directly to the device driver. This is the "everything is a file" model
in action.

```bash
ls /dev | head -30
ls -lh /dev/null /dev/zero /dev/random   # classic pseudo-devices
ls /dev/sd* /dev/nvme* 2>/dev/null       # disk devices
```

---

## /proc and /sys — Virtual Filesystems

Neither `/proc` nor `/sys` exists on disk. The kernel generates their content
on demand when you read from them. They are a window into the running kernel.

```bash
cat /proc/uptime          # seconds since boot (two numbers)
cat /proc/cpuinfo         # per-core CPU details
cat /proc/meminfo         # memory breakdown
ls /proc | grep '^[0-9]' | wc -l   # one dir per running process
cat /sys/class/net/*/operstate 2>/dev/null  # network interface states
```

---

## /mnt, /media, /opt

- `/mnt` — traditional location for manually-mounted filesystems (USB, NFS, etc.)
- `/media` — automounted removable media (USB drives, CDs) on desktop systems
- `/opt` — self-contained optional software packages that don't follow `/usr/bin` layout

```bash
ls /mnt    # usually empty unless something is manually mounted
ls /media  # populated by the automounter when a USB is inserted
ls /opt    # third-party software like Google Chrome, JetBrains IDEs
```

---

## Key Commands

| Command | What it does |
|---------|-------------|
| `ls -la /` | List root with symlink arrows |
| `du -sh /var/log/* 2>/dev/null \| sort -rh` | Largest log files |
| `cat /etc/os-release` | Distro and version info |
| `ldd /usr/bin/ls` | Shared libraries used by `ls` |
| `stat /tmp` | Show inode info including sticky bit |
| `df -h` | Disk usage per mounted filesystem |
| `findmnt` | Tree of all current mount points |
| `cat /proc/meminfo` | Live memory stats from the kernel |

---

## What's Next

Mission 10 covers file types and viewing — `file`, `od`, `hexdump`, `less`,
and how Linux identifies content without relying on file extensions.

```bash
make practice N=09
```
