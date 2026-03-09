#!/bin/bash
# =============================================================================
#  Mission 09 — Filesystem Hierarchy
# =============================================================================
set -uo pipefail
COURSE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"

init_mission "09" "Filesystem Hierarchy" 10

# =============================================================================
step "/ — the root: one tree to hold them all"
set_hint "ls / shows the top-level layout.
ls -la / reveals the symlinks: bin -> usr/bin, lib -> usr/lib, etc."

explain "Everything in Linux lives under /. There are no drive letters —
just one tree rooted at /.

Adding storage means mounting it into a subdirectory of this tree.
The Filesystem Hierarchy Standard (FHS) defines what belongs where
so every Linux system shares the same map."

demo 'ls /' \
     "The top-level layout:"

demo 'ls -la / | grep "^l"' \
     "Symlinks at / — the modern consolidation (bin -> usr/bin, etc.):"

try "List / with the -la flags to see symlinks and hidden entries" \
    "ls -la /"

checkpoint \
  "Why is /bin a symlink to usr/bin on modern systems?" \
  "Historically /bin held commands needed before /usr was mounted
(during early boot from a separate partition). Modern systems use
an initramfs that already has /usr, so the split is unnecessary.
Merging them into /usr/bin simplifies maintenance while keeping
/bin working via the symlink for compatibility."

# =============================================================================
step "/etc — host-specific configuration"
set_hint "Everything in /etc is a plain text file. cat, less, and grep
are your tools. Try: cat /etc/os-release"

explain "/etc holds system-wide configuration for this specific machine.
Rules:
  - All files are plain text (no compiled configs)
  - No binaries live here
  - Changes here affect every user on the system

Key files you will visit again and again:"

show 'printf "%-30s %s\n" /etc/hostname    "machine name"
printf "%-30s %s\n" /etc/os-release  "distro and version"
printf "%-30s %s\n" /etc/shells      "valid login shells"
printf "%-30s %s\n" /etc/passwd      "user account database"
printf "%-30s %s\n" /etc/fstab       "filesystems to mount at boot"
printf "%-30s %s\n" /etc/hosts       "static hostname -> IP mappings"' \
     "Key /etc files:"

demo 'cat /etc/os-release' \
     "Distro info — structured key=value text:"

demo 'cat /etc/shells' \
     "Valid login shells registered on this system:"

demo 'ls /etc/*.conf 2>/dev/null | head -12' \
     "A sample of .conf files in /etc:"

try_match \
  "Show the contents of /etc/hostname" \
  "cat /etc/hostname" \
  "."

note "/etc originally stood for 'etcetera' — a catch-all for admin files.
Today it means 'editable text configuration'."

# =============================================================================
step "/var — data that changes while the system runs"
set_hint "du -sh /var/log/* 2>/dev/null | sort -rh | head -5
shows which log files are largest."

explain "/var holds variable data — files that grow, shrink, or change
during normal operation. The system writes here constantly.

  /var/log    application and system logs
  /var/cache  cached data (can be regenerated if lost)
  /var/spool  queued jobs (print, mail, cron)
  /var/run    runtime state (PID files, sockets)  -- often /run
  /var/tmp    temp files preserved across reboots"

demo 'ls /var' \
     "Top-level of /var:"

demo 'ls /var/log | head -20' \
     "Log files in /var/log:"

demo 'du -sh /var/log/* 2>/dev/null | sort -rh | head -8' \
     "Largest log files (sorted by size):"

try "Show disk usage of /var subdirectories, human-readable, sorted largest first" \
    "du -sh /var/*/ 2>/dev/null | sort -rh | head -8"

tip "Log files rotate — old logs get compressed (.gz) or deleted automatically.
Tool: logrotate. Config: /etc/logrotate.conf and /etc/logrotate.d/"

# =============================================================================
step "/home and /root — user homes"
set_hint "ls /home shows regular user accounts.
echo \$HOME shows your own home path."

explain "/home contains one directory per regular user.

  /home/alice    alice's personal files and config
  /home/bob      bob's personal files and config

/root is kept separate — it is the root account's home.
Keeping root's home outside /home ensures the superuser can log in
even when /home lives on a different (possibly broken) partition."

demo 'ls -la /home' \
     "User home directories:"

demo 'echo "Your home: $HOME"' \
     "Your own home path from the environment:"

demo 'ls -la "$HOME" | head -20' \
     "Your home directory contents (dotfiles included):"

demo 'stat /root' \
     "Metadata for /root — note the permissions (750):"

try "Count how many entries are in your home directory including hidden ones" \
    "ls -a ~ | wc -l"

note "Dotfiles (.bashrc, .profile, .ssh/) store per-user configuration.
They are hidden by default — use ls -a or ls -la to see them."

# =============================================================================
step "/tmp — world-writable scratch space"
set_hint "stat /tmp shows the sticky bit (permissions end in 't').
df -h /tmp shows whether it is a RAM-backed tmpfs."

explain "/tmp is world-writable: every user and process can create files there.
Two protections prevent abuse:

  Sticky bit   only the file's owner can delete it, even though the
               directory is world-writable (permissions show 't')
  tmpfs        on most modern systems /tmp is a RAM-backed filesystem
               and is wiped completely on every reboot

Never store anything important in /tmp."

demo 'ls -la /tmp | head -15' \
     "Contents of /tmp — note the 'd' + sticky 't' in permissions:"

demo 'stat /tmp | grep -E "Access:|File:"' \
     "stat shows the sticky bit in the permission bits:"

demo 'df -h /tmp' \
     "Is /tmp on disk or in RAM (tmpfs)?"

try_match \
  "Show the permissions of /tmp using ls -ld /tmp" \
  "ls -ld /tmp — look for the 't' at the end of the permission string" \
  "tmp"

warn "Scripts that write to /tmp with predictable filenames can be exploited
by other local users (symlink attacks). Use mktemp to create safe temp files."

# =============================================================================
step "/usr — the bulk of installed programs"
set_hint "du -sh /usr/*/ 2>/dev/null | sort -rh | head -8
shows which /usr subdirectories use the most space."

explain "/usr is the largest branch of the tree. It holds the read-only,
shareable portion of the system — programs, libraries, and data that
do not change during normal operation.

  /usr/bin       most user commands (ls, grep, python3, git, ...)
  /usr/sbin      most admin commands (useradd, ip, fdisk, ...)
  /usr/lib       shared libraries
  /usr/local     locally compiled or hand-installed software
  /usr/share     architecture-independent data (man pages, icons, fonts)
  /usr/include   C header files for compiling programs"

demo 'du -sh /usr/*/ 2>/dev/null | sort -rh | head -8' \
     "Space used by each /usr subdirectory:"

demo 'ls /usr/bin | wc -l' \
     "How many commands live in /usr/bin:"

demo 'ls /usr/share | head -20' \
     "A sample of shared data packages in /usr/share:"

demo 'ls /usr/local' \
     "Locally-installed software in /usr/local:"

try_match \
  "Count the files in /usr/bin" \
  "ls /usr/bin | wc -l" \
  ""

section "usr/local — the sysadmin's territory"

explain "/usr/local mirrors the /usr layout but is reserved for software
you install manually (not via the package manager):

  /usr/local/bin     hand-installed commands
  /usr/local/lib     hand-installed libraries
  /usr/local/etc     hand-installed config

Package managers never touch /usr/local, so your custom installs
survive system upgrades."

# =============================================================================
step "/lib and shared libraries"
set_hint "ldd /usr/bin/ls shows which shared libraries ls depends on.
ldconfig -p | wc -l counts all cached shared libraries."

explain "Shared libraries (.so files) are reusable code loaded by multiple
programs at runtime — similar to Windows DLLs.

Benefits:
  - Programs are smaller (they don't embed common code)
  - A library bug fix benefits every program at once
  - Multiple programs share one copy in RAM

/lib is a symlink to /usr/lib on modern systems."

demo 'ls -la /lib' \
     "/lib — symlink to /usr/lib on modern systems:"

demo 'ls /usr/lib | head -20' \
     "Shared libraries and framework directories in /usr/lib:"

demo 'ldd /usr/bin/ls' \
     "Shared libraries that /usr/bin/ls loads at runtime:"

demo 'ldconfig -p | wc -l' \
     "Total cached shared libraries on this system:"

try "Show which shared libraries /usr/bin/grep depends on" \
    "ldd /usr/bin/grep"

tip "LD_LIBRARY_PATH can add extra search paths for shared libraries at runtime.
The standard search paths are configured in /etc/ld.so.conf.d/"

# =============================================================================
step "/dev, /proc, /sys — virtual and device filesystems"
set_hint "cat /proc/uptime shows seconds since boot.
ls /dev | head -20 lists device files."

explain "/dev — device files
The kernel exposes hardware as files. Reading or writing them
sends data to or from the device driver.

  /dev/sda, /dev/nvme0n1   block devices (disks)
  /dev/tty, /dev/pts/N     terminal devices
  /dev/null                 discards all input (the black hole)
  /dev/zero                 produces infinite null bytes
  /dev/random               cryptographically secure random bytes

/proc — kernel window (virtual, no disk storage)
The kernel generates content on demand when you read /proc.

/sys — hardware info (virtual)
/sys exposes kernel objects: devices, drivers, power management."

demo 'ls -lh /dev/null /dev/zero /dev/random /dev/urandom' \
     "The classic pseudo-devices — note 'c' (character device) type:"

demo 'ls /dev | grep -E "^sd|^nvme|^vd" | head -10' \
     "Disk block devices visible in /dev:"

demo 'cat /proc/uptime' \
     "/proc/uptime — seconds since boot (first number), idle time (second):"

demo 'cat /proc/meminfo | head -10' \
     "/proc/meminfo — live memory stats from the kernel:"

demo 'ls /proc | grep "^[0-9]" | wc -l' \
     "Number of running processes (one directory per PID in /proc):"

show 'cat /sys/class/net/*/operstate 2>/dev/null' \
     "Network interface states from /sys:"

try "Read your CPU model name from /proc/cpuinfo" \
    "grep 'model name' /proc/cpuinfo | head -1"

checkpoint \
  "Both /proc and /sys look like directories full of files.
What makes them fundamentally different from /etc or /var?" \
  "Neither /proc nor /sys exists on disk. They are virtual filesystems
(type: proc and sysfs respectively) that the kernel generates in memory.
When you read a file in /proc/cpuinfo the kernel writes the current
CPU data into a buffer at that moment — nothing is stored anywhere.
This is why you can cat /proc/uptime and always get the current uptime:
the kernel computes the answer fresh each time you read."

# =============================================================================
step "/mnt, /media, /opt — mount points and optional software"
set_hint "findmnt shows the full mount tree.
ls /opt shows any installed optional software packages."

explain "/mnt — manual mount points
Traditional location for temporarily mounting filesystems:
  mount /dev/sdb1 /mnt    attach a USB disk at /mnt

/media — automounted removable media
Desktop systems (with udisks or similar) auto-mount USB drives,
CDs, and SD cards under /media/username/label.

/opt — optional, self-contained software
Software that installs its entire tree in one place rather than
spreading files across /usr/bin, /usr/lib, etc.
Examples: /opt/google/chrome  /opt/JetBrains/clion"

demo 'ls /mnt' \
     "/mnt — usually empty unless something is manually mounted:"

demo 'ls /media 2>/dev/null || echo "(empty or not present)"' \
     "/media — removable media mount points:"

demo 'ls /opt 2>/dev/null || echo "(empty — no optional software installed)"' \
     "/opt — optional software packages:"

demo 'findmnt' \
     "Current mount tree — all mounted filesystems:"

try "Show all currently mounted filesystems with df -h" \
    "df -h"

note "/srv holds data served by this system (web files, FTP files).
/run (or /var/run) holds runtime data like PID files and sockets —
it is always a tmpfs and cleared on every boot."

# =============================================================================
step "Putting it together — finding your way around"
set_hint "find /etc -name '*.conf' -type f | wc -l
counts all .conf files under /etc."

explain "Now that you know the map, you can navigate any Linux system.
A few patterns that always work:

  Configuration lives in   /etc
  Logs live in             /var/log
  User commands live in    /usr/bin
  Libraries live in        /usr/lib
  Your files live in       ~/  (which is /home/yourname)
  Kernel data lives in     /proc and /sys

Use these commands to explore any directory confidently:"

demo 'find /etc -maxdepth 1 -name "*.conf" -type f | wc -l' \
     "How many .conf files are directly in /etc:"

demo 'du -sh /bin /etc /home /tmp /usr /var 2>/dev/null | sort -rh' \
     "Disk usage of major top-level directories:"

demo 'find /usr/bin -type f -newer /etc/passwd | wc -l' \
     "Commands in /usr/bin newer than /etc/passwd (recently installed):"

demo 'df -hT' \
     "All mounted filesystems — type, size, used, available:"

try_match \
  "Find all directories directly under / that are symlinks" \
  "ls -la / | grep '^l'" \
  "usr"

checkpoint \
  "You need to find a config file for a service but you don't know its name.
Where do you start, and what commands do you use?" \
  "Start in /etc — all system configuration lives there.
Use: ls /etc to see top-level files and directories.
Then: find /etc -name '*servicename*' to narrow it down.
Or:   grep -r 'keyword' /etc/ to search by content.
Man pages also list config file paths: man sshd_config shows /etc/ssh/sshd_config."

# =============================================================================
mission_complete
