#!/bin/bash
# =============================================================================
#  Mission 10 — File Types & Viewing
# =============================================================================
set -uo pipefail
COURSE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"

SCRATCH="/tmp/mission10"
mkdir -p "$SCRATCH"

init_mission "10" "File Types & Viewing" 10

# =============================================================================
step "ls -l — reading the file type character"
set_hint "The very first character of each ls -l line tells you the file type.
Try: ls -l /etc/hostname /etc /dev/sda /dev/tty"

explain "ls -l starts every line with a 10-character permission string.
The FIRST character is the file type:

  -   regular file      (text, binary, anything stored on disk)
  d   directory         (a folder containing other entries)
  l   symbolic link     (a pointer to another path)
  b   block device      (e.g. a hard disk: /dev/sda)
  c   character device  (e.g. a terminal: /dev/tty)
  s   socket            (IPC endpoint)
  p   named pipe/FIFO   (inter-process stream)

The remaining 9 characters are three groups of rwx: owner, group, others."

demo 'ls -l /etc/hostname' \
     "A regular file — starts with -:"

demo 'ls -ld /etc' \
     "A directory — starts with d  (-d shows the dir entry itself):"

demo 'ls -l /etc/localtime' \
     "A symbolic link — starts with l:"

demo 'ls -l /dev/sda 2>/dev/null || ls -l /dev/vda 2>/dev/null || ls -l /dev/xvda 2>/dev/null || echo "(no block device found — try: ls -l /dev/loop0)"' \
     "A block device — starts with b:"

demo 'ls -l /dev/tty' \
     "A character device — starts with c:"

try_match "Run: ls -l /dev/null — what type is it?" \
          "ls -l /dev/null" \
          "^c"

checkpoint \
  "You see this in ls -l output:  lrwxrwxrwx 1 root root 7 /etc/localtime -> ...
What is the file type, and what does the -> mean?" \
  "l = symbolic link.
The -> shows the target path the symlink points to.
Reading or running the symlink transparently uses the target file."

# =============================================================================
step "file — identify by content, not by name"
set_hint "Usage: file <path>
file reads the first few bytes and compares them to a database of signatures."

explain "file reads the content of a file (not its name) to identify what it is.
A file named 'data.txt' could be a PNG, a script, or an ELF binary.
file always tells the truth — extensions can lie.

  file /etc/hostname      → ASCII text
  file /bin/ls            → ELF 64-bit LSB pie executable
  file /etc/localtime     → timezone data
  file /dev/null          → character special"

demo 'file /etc/hostname /etc/passwd /etc/fstab' \
     "Text files — file identifies encoding and line endings:"

demo 'file /bin/ls /bin/bash' \
     "ELF executables — architecture, linking type, ABI:"

demo 'file /etc/localtime' \
     "Binary data that is NOT an executable:"

# Create some test files in SCRATCH
printf '#!/bin/bash\necho hello\n' > "${SCRATCH}/script.sh"
printf 'name = example\nport = 8080\n' > "${SCRATCH}/config.ini"
cp /bin/ls "${SCRATCH}/totally_not_a_binary.txt" 2>/dev/null || cp /usr/bin/ls "${SCRATCH}/totally_not_a_binary.txt"
gzip -k /etc/hostname -c > "${SCRATCH}/archive.gz" 2>/dev/null || gzip < /etc/hostname > "${SCRATCH}/archive.gz"

demo "file ${SCRATCH}/script.sh ${SCRATCH}/config.ini ${SCRATCH}/totally_not_a_binary.txt ${SCRATCH}/archive.gz" \
     "file sees through misleading names — .txt is actually an ELF:"

try_match "Run file on /usr/bin/file itself" \
          "file /usr/bin/file" \
          "ELF"

note "file uses a database called 'magic' stored in /usr/share/misc/magic.
It tests byte patterns, strings, and offsets — not file extensions."

# =============================================================================
step "stat — inode, size, and three timestamps"
set_hint "Usage: stat <path>
Look for: Inode, Size, Blocks, Links, Access (atime), Modify (mtime), Change (ctime)"

explain "stat shows low-level metadata from the filesystem inode:

  Inode     unique number identifying this file on the filesystem
  Size      bytes (exact, not rounded)
  Blocks    512-byte blocks allocated on disk
  Links     hard link count (1 for most files)
  Access    atime — when was the file last READ
  Modify    mtime — when was the content last CHANGED
  Change    ctime — when was the metadata last changed (perms, owner, links)

Note: there is no 'creation time' in standard Linux filesystems (ext4, xfs)."

demo 'stat /etc/hostname' \
     "stat on a simple text file:"

demo 'stat /bin/ls' \
     "stat on an executable — note the Blocks vs Size ratio:"

demo 'stat /etc/localtime' \
     "stat on a symlink — stat follows the link and shows the target:"

demo 'stat -L /etc/localtime' \
     "stat -L follows the link explicitly (same result here):"

try "Run stat on your home directory (~)" \
    "stat ~"

checkpoint \
  "A file has mtime from last week but ctime from today.
What could have happened to it?" \
  "The content was not changed (mtime is old) but the metadata was.
Possible causes: chmod, chown, adding/removing a hard link, or renaming.
ctime updates whenever the inode changes — content or metadata."

# =============================================================================
step "xxd — hex dump to read binary files"
set_hint "Usage: xxd file | head -N
Left column = offset, middle = hex bytes, right = ASCII representation."

explain "xxd prints the raw bytes of any file as hex pairs.
The right column shows printable ASCII, dots for non-printable bytes.

  xxd file              full dump
  xxd file | head -4    first 32 bytes — enough to see the magic number
  xxd -l 16 file        only the first 16 bytes (limit flag)
  xxd -s 100 file       start at byte offset 100

Magic numbers live in the first few bytes.
Knowing them lets you identify files without relying on extensions."

demo 'xxd /etc/hostname' \
     "A small text file — all printable, no surprises:"

demo 'xxd -l 16 /bin/ls' \
     "First 16 bytes of an ELF binary — magic number 7f 45 4c 46 = .ELF:"

demo "xxd -l 16 ${SCRATCH}/archive.gz" \
     "gzip magic: 1f 8b at the start:"

# Create a minimal PNG header in SCRATCH for demonstration
printf '\x89PNG\r\n\x1a\n\x00\x00\x00\rIHDR' > "${SCRATCH}/fake.png"
demo "xxd -l 16 ${SCRATCH}/fake.png" \
     "PNG magic: 89 50 4e 47 = .PNG:"

try_match "Show the first 16 bytes of /bin/bash with xxd" \
          "xxd -l 16 /bin/bash" \
          "7f45 4c46"

note "The offset column on the left is in hex. 0x00000010 = 16 bytes in."

# =============================================================================
step "hexdump -C and od — alternative binary viewers"
set_hint "hexdump -C is like xxd but the ASCII column is always on the right.
od -An -tx1 prints only hex bytes with no address column — good for piping."

explain "Several tools dump binary content — each has a different format:

  xxd file          hex + ASCII, offset on left (widely available)
  hexdump -C file   canonical hex dump — same layout as xxd, BSD default
  od -An -tx1 file  octal dump in hex mode, no address (-An), one byte per cell
  od -c file        character representation — \\n, \\t, \\0 shown literally

Choose based on what you need:
  xxd / hexdump -C   for human reading
  od -An -tx1        for piping into awk or scripts (consistent spacing)"

demo 'hexdump -C /etc/hostname' \
     "hexdump -C — same information as xxd, slightly different column layout:"

demo 'od -An -tx1 /etc/hostname' \
     "od -An -tx1 — raw hex bytes, no offsets, easy to parse:"

demo 'od -c /etc/hostname' \
     "od -c — shows escape sequences (\\n at end of line):"

try "Run hexdump -C on /etc/passwd | head -3" \
    "hexdump -C /etc/passwd | head -3"

tip "On systems without xxd (some minimal containers), hexdump -C is your fallback.
od is always available — it is a POSIX standard tool."

# =============================================================================
step "strings — extract printable text from any file"
set_hint "Usage: strings file
strings prints any sequence of 4+ printable ASCII characters it finds."

explain "strings scans a file for runs of printable ASCII characters (4+ long)
and prints each one on its own line.

Useful for:
  - Quickly reading embedded messages in binaries
  - Finding hardcoded paths, version strings, error messages
  - Initial triage of an unknown binary

Limitations:
  - Only finds ASCII (not UTF-16 or other encodings without -e flag)
  - A malicious binary can intentionally hide or obfuscate strings
  - Not a substitute for a proper disassembler"

demo 'strings /bin/ls | head -20' \
     "Strings embedded in /bin/ls — paths, error messages, option names:"

demo 'strings /bin/ls | grep "^/" | head -10' \
     "Filter for paths only (lines starting with /):"

demo 'strings /bin/ls | grep -i "version\|copyright\|author" | head -5' \
     "Look for version or copyright strings:"

demo "strings ${SCRATCH}/archive.gz" \
     "Even compressed files may have readable strings:"

try_match "Extract strings from /bin/cat and find any that contain 'usage' or 'Usage'" \
          "strings /bin/cat | grep -i usage | head -3" \
          "."

warn "Never run 'ldd' on untrusted binaries — ldd executes code.
Use 'strings' or 'objdump -p' for safe recon on unknown files."

# =============================================================================
step "wc — measuring files"
set_hint "wc file → lines words bytes filename
wc -l = lines only, wc -c = bytes only, wc -w = words only."

explain "wc (word count) measures text files along three dimensions:

  wc file       print lines, words, bytes, and filename
  wc -l file    count lines only
  wc -w file    count words only (whitespace-delimited tokens)
  wc -c file    count bytes
  wc -m file    count characters (differs from bytes for multi-byte encodings)

Multiple files: wc prints a total row at the bottom.
stdin: pipe into wc to count pipeline output."

demo 'wc /etc/passwd' \
     "Lines, words, bytes in /etc/passwd:"

demo 'wc -l /etc/passwd /etc/group /etc/hosts' \
     "Multiple files — total row is appended:"

demo 'ls /usr/bin | wc -l' \
     "Count entries in /usr/bin by piping ls through wc:"

demo 'wc -c /bin/ls' \
     "Byte count of /bin/ls (exact file size in bytes):"

show 'printf "hello world\n" | wc' \
     "Counting a string: 1 line, 2 words, 12 bytes (includes the newline):"

try_match "Count the number of lines in /etc/group" \
          "wc -l /etc/group" \
          "/etc/group"

checkpoint \
  "wc -c reports the size in bytes. stat also shows size.
Why might they ever disagree for a symlink?" \
  "stat on a symlink (without -L) reports the length of the symlink path itself,
not the size of the file it points to.
wc -c follows the symlink and counts the target file's bytes.
Use stat -L to make stat follow the link and report the real file size."

# =============================================================================
step "Inspecting executables: file and ldd"
set_hint "file /bin/ls → identifies the binary format and architecture.
ldd /bin/ls → lists shared libraries the binary needs at runtime."

explain "Every ELF executable on Linux has two things worth knowing:

1. Its format — shown by file:
     ELF 64-bit LSB pie executable, x86-64
     Statically linked (no runtime dependencies) vs dynamically linked

2. Its runtime dependencies — shown by ldd:
     ldd lists every shared library (.so file) the binary needs.
     Each entry shows: library name => resolved path => load address

Why it matters:
  - Debugging 'command not found' or 'library not found' at runtime
  - Understanding what a binary does before running it
  - Packaging: know which libraries must ship with a program"

demo 'file /bin/ls /bin/bash /usr/bin/python3 2>/dev/null || file /bin/ls /bin/bash' \
     "file on several executables — note the link type differences:"

demo 'ldd /bin/ls' \
     "ldd on ls — the shared libraries it needs at runtime:"

demo 'ldd /bin/bash' \
     "bash has more dependencies — libreadline, libdl, libc:"

# Check if a static binary exists to demonstrate the contrast
demo 'file /bin/busybox 2>/dev/null && ldd /bin/busybox 2>/dev/null || echo "(busybox not installed — try: ldd /sbin/ldconfig)"' \
     "A statically linked binary reports 'not a dynamic executable':"

demo 'ldd /bin/ls | wc -l' \
     "How many shared libraries does ls depend on?"

try_match "Run ldd on /usr/bin/find and count how many .so files it uses" \
          "ldd /usr/bin/find | grep -c '\.so'" \
          "[0-9]"

section "Checking a binary safely"

show 'readelf -d /bin/ls | grep NEEDED' \
     "readelf -d reads ELF metadata without executing — safer than ldd:"

note "readelf and objdump are safe for untrusted binaries.
ldd executes the dynamic linker — safe only on trusted system binaries."

# =============================================================================
step "Magic numbers — file identity in the first bytes"
set_hint "Read the first 4-8 bytes with: xxd -l 8 <file>
Compare against known signatures: ELF=7f454c46, PNG=89504e47, gzip=1f8b"

explain "Magic numbers are fixed byte sequences at the start (or specific offsets)
of a file that identify its format. Tools like file use them.

Common magic numbers:
  7f 45 4c 46   ELF executable or shared library    (.ELF)
  89 50 4e 47   PNG image                            (.PNG)
  1f 8b         gzip compressed data
  50 4b 03 04   ZIP archive / JAR / APK / docx      (PK..)
  25 50 44 46   PDF document                         (%PDF)
  23 21         Shell script / interpreted file      (#!)
  ff d8 ff      JPEG image

When file cannot identify a file, hex-dump the first 16 bytes yourself
and compare against known signatures."

# Build a set of test files
printf '#!/bin/bash\necho test\n' > "${SCRATCH}/mystery_a"
gzip < /etc/hostname > "${SCRATCH}/mystery_b"
cp /bin/ls "${SCRATCH}/mystery_c"
printf 'just plain text\n' > "${SCRATCH}/mystery_d"

demo "for f in ${SCRATCH}/mystery_a ${SCRATCH}/mystery_b ${SCRATCH}/mystery_c ${SCRATCH}/mystery_d; do
  printf '%s\\n' \"\$f\"
  xxd -l 8 \"\$f\"
  echo
done" \
     "Four mystery files — identify each by their first 8 bytes:"

demo "file ${SCRATCH}/mystery_a ${SCRATCH}/mystery_b ${SCRATCH}/mystery_c ${SCRATCH}/mystery_d" \
     "Confirm with file — does it match what you read in the hex?"

try_match "Show the first 8 bytes of /usr/bin/zip or /usr/bin/gzip — find the magic number" \
          "xxd -l 8 /usr/bin/zip 2>/dev/null || xxd -l 8 /usr/bin/gzip" \
          "7f45 4c46"

checkpoint \
  "You find a file with no extension. xxd -l 4 shows: 25 50 44 46
What format is it, and how would you confirm?" \
  "25 50 44 46 = %PDF — this is a PDF document.
The ASCII column in xxd would show '%PDF' on the right.
Confirm with: file <path>  — it should say 'PDF document'."

# =============================================================================
# Cleanup
rm -rf "$SCRATCH"

mission_complete
