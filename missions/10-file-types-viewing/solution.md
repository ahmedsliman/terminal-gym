# Solution — Mission 10: File Types & Viewing

---

## Exercise 1: Reading File Type Characters

```bash
ls -l /etc/hostname /etc
ls -l /etc/localtime
ls -l /dev/null /dev/zero /dev/tty
ls -l /dev/sda 2>/dev/null || ls -l /dev/nvme0n1 2>/dev/null || echo "no block device at standard paths"
mkfifo /tmp/m10-pipe && ls -l /tmp/m10-pipe && rm /tmp/m10-pipe
```

**Seven file type characters:**
| Char | Type | Example |
|------|------|---------|
| `-` | Regular file | `/etc/hostname` |
| `d` | Directory | `/etc` |
| `l` | Symbolic link | `/etc/localtime -> /usr/share/zoneinfo/...` |
| `c` | Character device | `/dev/null`, `/dev/tty` |
| `b` | Block device | `/dev/sda`, `/dev/nvme0n1` |
| `p` | Named pipe (FIFO) | Created with `mkfifo` |
| `s` | Socket | Files in `/run/systemd/...` |

---

## Exercise 2: file — Identify Content, Not Name

```bash
file /usr/bin/ls /usr/bin/bash
file /etc/hostname /etc/os-release
printf '#!/bin/bash\necho hello\n' > /tmp/m10/script.txt
file /tmp/m10/script.txt
printf '\x89PNG\r\n\x1a\n' > /tmp/m10/data.log
file /tmp/m10/data.log
file /etc/localtime
```

**How `file` works:**
1. Reads the first ~512 bytes
2. Compares against `/usr/share/magic` database of magic patterns
3. Falls back to character analysis (ASCII, UTF-8, binary) if no magic matches

Extensions are irrelevant. A file named `data.log` containing PNG bytes will be correctly identified as a PNG.

---

## Exercise 3: stat — Full Inode Metadata

```bash
stat /etc/hostname
touch /tmp/m10/touched.txt && stat /tmp/m10/touched.txt
cat /etc/hostname && stat /etc/hostname
stat -c '%a %n' /etc/hostname /usr/bin/ls /etc/shadow 2>/dev/null
```

**Three timestamps:**
| Timestamp | Updated when |
|-----------|-------------|
| **atime** | File is read |
| **mtime** | File contents change |
| **ctime** | File metadata changes (permissions, owner, link count) |

Note: Modern filesystems use `relatime` — atime is only updated when it's older than mtime, reducing unnecessary writes.

`stat -c '%a %n'` output format: `644 /etc/hostname` (octal permissions then filename).

---

## Exercise 4: xxd and hexdump — Reading Binary Content

```bash
xxd /usr/bin/ls | head -4
hexdump -C /usr/bin/ls | head -4
ls /usr/share/doc/*/*.gz 2>/dev/null | head -1 | xargs -I{} xxd {} | head -2
od -An -tx1 -N4 /usr/bin/ls
```

**Common magic numbers:**
| First bytes (hex) | ASCII | Format |
|------------------|-------|--------|
| `7f 45 4c 46` | `.ELF` | ELF binary |
| `89 50 4e 47` | `.PNG` | PNG image |
| `1f 8b` | — | gzip |
| `50 4b 03 04` | `PK..` | ZIP/JAR |
| `23 21` | `#!` | Script (shebang) |

**Tool comparison:**
| Tool | Output format |
|------|--------------|
| `xxd` | hex + ASCII sidebar, compact |
| `hexdump -C` | hex + ASCII sidebar, canonical |
| `od -An -tx1` | hex bytes only, no address column |

---

## Exercise 5: strings — Extracting Text from Binaries

```bash
strings /usr/bin/ls | head -20
strings /usr/bin/ls | grep -i 'version\|gnu\|coreutils' | head -5
strings /usr/bin/ls | grep -i 'cannot\|error\|failed' | head -10
strings /usr/bin/ls | wc -l
strings /lib/x86_64-linux-gnu/libc.so.6 2>/dev/null | grep -i 'glibc\|version' | head -5
```

**`strings` limitations:**
- Only finds sequences of printable ASCII (4+ characters by default)
- Cannot find encoded or compressed strings
- Does not understand the binary structure — just scans bytes
- Useful for quick recon; not reliable for security analysis

For security analysis, use `objdump`, `readelf`, or a proper disassembler instead.

---

## Exercise 6: wc — Measuring Files

```bash
wc /etc/passwd
wc -l /etc/passwd
wc -c /usr/bin/ls
wc -w <<< "the quick brown fox jumps over the lazy dog"
wc -l /etc/*.conf 2>/dev/null | tail -1
```

**wc flags:**
| Flag | Counts |
|------|--------|
| `-l` | Lines (newline characters) |
| `-w` | Words (whitespace-separated tokens) |
| `-c` | Bytes |
| `-m` | Characters (differs from bytes in multi-byte encodings) |

Output order without flags: `lines words bytes filename`

Step 4 result: `9` — nine words in the sentence.

---

## Exercise 7: ldd — Shared Library Dependencies

```bash
ldd /usr/bin/ls
ldd /usr/bin/bash
ldd /bin/true
ldconfig -p | wc -l
ldconfig -p | grep libc
```

**Reading ldd output:**
```
        linux-vdso.so.1 => (0x00007ffce7de7000)    # kernel virtual DSO
        libselinux.so.1 => /lib/x86_64-linux-gnu/libselinux.so.1
        libc.so.6 => /lib/x86_64-linux-gnu/libc.so.6
        /lib64/ld-linux-x86-64.so.2                # dynamic linker
```

- `=>` shows where the library is resolved on disk
- `linux-vdso` is a virtual shared object injected by the kernel — not on disk
- A binary printing "not a dynamic executable" is statically linked

**Warning:** Never run `ldd` on untrusted binaries — it partially executes the binary (via the dynamic linker). Use `objdump -p binary | grep NEEDED` instead for untrusted files.

---

## Exercise 8: Magic Numbers Lab

```bash
printf '\x89PNG\r\n\x1a\n' > /tmp/m10/fake.png
file /tmp/m10/fake.png
xxd /tmp/m10/fake.png | head -2

printf '#!/bin/bash\n' > /tmp/m10/magic-script
file /tmp/m10/magic-script
xxd /tmp/m10/magic-script | head -2

echo "hello world" > /tmp/m10/text.bin
file /tmp/m10/text.bin

printf '\x1f\x8b' > /tmp/m10/fake.gz
file /tmp/m10/fake.gz
```

**Magic number table:**
| Magic bytes (hex) | ASCII hint | Format |
|------------------|-----------|--------|
| `7f 45 4c 46` | `.ELF` | ELF binary |
| `89 50 4e 47 0d 0a 1a 0a` | `.PNG....` | PNG image |
| `1f 8b` | — | gzip archive |
| `50 4b 03 04` | `PK..` | ZIP / JAR |
| `23 21` | `#!` | Script with shebang |
| `ff d8 ff` | — | JPEG image |

`printf '\xNN'` writes the byte with hex value NN, letting you craft files with exact magic bytes for testing.

---

## Quick Reference

```bash
ls -l path         first character shows file type
file path          identify type by reading content bytes
stat path          full inode: size, 3 timestamps, permissions, inode#
stat -c '%a %n'    print only octal permissions and filename
xxd file | head    hex+ASCII dump, first N lines
hexdump -C file    canonical hex dump with ASCII sidebar
od -An -tx1 -N4    first 4 bytes as hex only
strings file       extract printable text sequences from any file
wc file            lines / words / bytes
wc -l / -w / -c    individual counts
ldd binary         list shared library dependencies
ldconfig -p        list all cached shared libraries
```
