# Mission 10 — File Types & Viewing

## Concept

Linux does not care about file extensions. A file named `data.txt` can be a
PNG image, a shell script, or an ELF binary. The kernel and tools use the
actual bytes inside the file — not its name — to determine what it is.

Understanding how to identify, inspect, and measure files without assumptions
is an essential skill for debugging, reverse engineering, and general system
literacy.

## Learning Goals

- Read the file-type character in `ls -l` output (first column)
- Use `file` to identify content by inspecting bytes, not the name
- Use `stat` to read inode metadata: size, timestamps, permissions, link count
- Inspect binary content with `xxd`, `hexdump -C`, `od`, and `strings`
- Understand magic numbers — the first bytes that identify file formats
- Measure files with `wc`
- Inspect executables with `file` and `ldd`

## Constraints

- Terminal only — no GUI file managers
- Time target: 40 minutes

## Key Commands

| Command | What it does |
|---------|-------------|
| `ls -l` | Long listing — first character is the file type |
| `file path` | Identify file type by content (reads magic bytes) |
| `stat path` | Inode number, size, all three timestamps, permissions |
| `xxd file` | Hex + ASCII dump of binary content |
| `xxd file \| head -4` | Show only the first 4 lines (magic number area) |
| `hexdump -C file` | Canonical hex dump with ASCII sidebar |
| `od -An -tx1 file` | Octal dump in hex byte format, no address column |
| `strings file` | Extract printable ASCII sequences from any file |
| `wc file` | Lines, words, bytes |
| `wc -c file` | Byte count only |
| `ldd /path/to/binary` | List shared libraries an ELF binary depends on |

## Linux File Type Characters (first column of `ls -l`)

| Char | Type | Example |
|------|------|---------|
| `-` | Regular file | `/etc/hostname` |
| `d` | Directory | `/home` |
| `l` | Symbolic link | `/etc/localtime` |
| `b` | Block device | `/dev/sda` |
| `c` | Character device | `/dev/tty` |
| `s` | Socket | `/run/systemd/private/...` |
| `p` | Named pipe (FIFO) | Created with `mkfifo` |

## Common Magic Numbers

| File type | First bytes (hex) | ASCII hint |
|-----------|------------------|-----------|
| ELF binary | `7f 45 4c 46` | `.ELF` |
| PNG image | `89 50 4e 47` | `.PNG` |
| gzip archive | `1f 8b` | (not printable) |
| JPEG image | `ff d8 ff` | (not printable) |
| ZIP/JAR | `50 4b 03 04` | `PK..` |
| Shell script | `23 21` | `#!` |

## Notes

- `stat` shows three timestamps: **atime** (last read), **mtime** (last content
  change), **ctime** (last metadata change including permissions and owner).
- `strings` is not a security tool — an attacker can hide strings. Use it for
  quick recon only.
- `ldd` executes the binary's dynamic linker to resolve libraries. Never run
  `ldd` on untrusted binaries — use `objdump -p` instead.
- `/dev/zero`, `/dev/null`, and `/dev/random` are character devices, not files.
  They have no size on disk.

## Next

Run `make practice N=10` to start the interactive session.
Run `make exercises N=10` to work through the hands-on tasks.
