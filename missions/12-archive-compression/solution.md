# Solution — Mission 12: Archive & Compression

---

## Exercise 1: Creating tar Archives

```bash
mkdir -p /tmp/m12/project/{src,docs,tests}
echo "main code" > /tmp/m12/project/src/main.sh
echo "helper"   > /tmp/m12/project/src/helper.sh
echo "readme"   > /tmp/m12/project/docs/README.md
echo "test 1"   > /tmp/m12/project/tests/test1.sh

tar -cvf  /tmp/m12/project.tar     /tmp/m12/project/
tar -czf  /tmp/m12/project.tar.gz  /tmp/m12/project/
tar -cjf  /tmp/m12/project.tar.bz2 /tmp/m12/project/
tar -cJf  /tmp/m12/project.tar.xz  /tmp/m12/project/
ls -lh /tmp/m12/*.tar /tmp/m12/*.tar.gz /tmp/m12/*.tar.bz2 /tmp/m12/*.tar.xz
```

**tar flag reference:**
| Flag | Meaning |
|------|---------|
| `-c` | Create a new archive |
| `-x` | Extract an archive |
| `-t` | List archive contents |
| `-v` | Verbose (show files as they are processed) |
| `-f file` | Use `file` as the archive name |
| `-z` | gzip compression |
| `-j` | bzip2 compression |
| `-J` | xz compression |
| `-C dir` | Change to `dir` before extracting |

---

## Exercise 2: Listing Archive Contents

```bash
tar -tvf  /tmp/m12/project.tar
tar -tzvf /tmp/m12/project.tar.gz
tar -tf   /tmp/m12/project.tar.gz
tar -tf   /tmp/m12/project.tar.gz | wc -l
tar -tf   /tmp/m12/project.tar.gz | grep "README"
```

Modern `tar` auto-detects the compression format when reading — you usually do not need to specify `-z`, `-j`, or `-J` when listing or extracting.

Without `-v`, `-t` shows only filenames. With `-v`, it shows permissions, owner, size, and modification time — the same as `ls -l`.

---

## Exercise 3: Extracting Archives

```bash
mkdir -p /tmp/m12/extract
cd /tmp/m12/extract
tar -xzf /tmp/m12/project.tar.gz
find /tmp/m12/extract -type f | sort

mkdir -p /tmp/m12/extract2
tar -xzf /tmp/m12/project.tar.gz -C /tmp/m12/extract2
find /tmp/m12/extract2 -type f | sort

mkdir -p /tmp/m12/extract3
tar -xzf /tmp/m12/project.tar.gz -C /tmp/m12/extract3 tmp/m12/project/docs/README.md
find /tmp/m12/extract3 -type f

mkdir -p /tmp/m12/extract4
tar -xzvf /tmp/m12/project.tar.gz -C /tmp/m12/extract4

tar -tzf /tmp/m12/project.tar.gz > /dev/null && echo "archive OK" || echo "archive corrupted"
```

**Path stripping:** Archives store paths as they appear at creation time (absolute paths lose the leading `/`). Use `--strip-components=N` to remove N leading path components on extraction:
```bash
tar -xzf archive.tar.gz --strip-components=3   # removes /tmp/m12/project from each path
```

---

## Exercise 4: gzip, bzip2, xz — Compression Algorithms

```bash
cp /tmp/m12/data.txt /tmp/m12/data-gzip.txt
gzip /tmp/m12/data-gzip.txt
ls -lh /tmp/m12/data-gzip.txt.gz
gunzip /tmp/m12/data-gzip.txt.gz
head -c 20 /tmp/m12/data-gzip.txt

cp /tmp/m12/data.txt /tmp/m12/data-bzip2.txt
bzip2 /tmp/m12/data-bzip2.txt
ls -lh /tmp/m12/data-bzip2.txt.bz2

cp /tmp/m12/data.txt /tmp/m12/data-xz.txt
xz /tmp/m12/data-xz.txt
ls -lh /tmp/m12/data-xz.txt.xz

ls -lh /tmp/m12/data-gzip.txt.gz /tmp/m12/data-bzip2.txt.bz2 /tmp/m12/data-xz.txt.xz
```

**In-place compression:** `gzip file` replaces `file` with `file.gz`. Use `-k` (keep) to preserve the original:
```bash
gzip -k file    # creates file.gz, keeps file
bzip2 -k file   # creates file.bz2, keeps file
xz -k file      # creates file.xz, keeps file
```

---

## Exercise 5: Compression Algorithm Comparison

```bash
time gzip  -k /tmp/m12/logdata.txt && ls -lh /tmp/m12/logdata.txt.gz
time bzip2 -k /tmp/m12/logdata.txt && ls -lh /tmp/m12/logdata.txt.bz2
time xz    -k /tmp/m12/logdata.txt && ls -lh /tmp/m12/logdata.txt.xz
```

**Algorithm trade-offs:**
| Algorithm | Extension | Speed | Ratio | Best for |
|-----------|-----------|-------|-------|---------|
| gzip | `.gz` | Fast | Good | Logs, quick backups, general use |
| bzip2 | `.bz2` | Medium | Better | Source code archives (historical) |
| xz | `.xz` | Slow | Best | Linux distribution packages |
| zstd | `.zst` | Very fast | Good-Best | Modern alternative (Facebook) |

For daily use, `tar -czf` (gzip) is the practical default. For distributing software, `tar -cJf` (xz) maximises compression.

---

## Exercise 6: zip and unzip

```bash
zip /tmp/m12/project.zip -r /tmp/m12/project/
unzip -l /tmp/m12/project.zip
unzip -t /tmp/m12/project.zip
mkdir -p /tmp/m12/unzipped
unzip /tmp/m12/project.zip -d /tmp/m12/unzipped
find /tmp/m12/unzipped -type f
mkdir -p /tmp/m12/single
unzip /tmp/m12/project.zip 'tmp/m12/project/docs/README.md' -d /tmp/m12/single
```

**tar vs zip:**
| | `tar + gzip` | `zip` |
|-|-------------|-------|
| Unix metadata | Preserved (permissions, symlinks) | Partially |
| Cross-platform | Needs software on Windows | Native on Windows/Mac |
| Stream support | Yes (`tar -czf - \| ssh ...`) | No |
| Append files | Possible (uncompressed tar) | Yes |

Prefer `tar.gz` on Unix systems. Use `zip` when sharing with Windows users.

---

## Exercise 7: Real-world Archive Patterns

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
tar -czf /tmp/m12/backup-${TIMESTAMP}.tar.gz /tmp/m12/project/
ls -lh /tmp/m12/backup-*.tar.gz

tar -xzf /tmp/m12/project.tar.gz -C /tmp/m12/extract --wildcards '*.sh'
find /tmp/m12/extract -name "*.sh"

echo "new file" > /tmp/m12/new-file.txt
tar -rf /tmp/m12/project.tar /tmp/m12/new-file.txt
tar -tf /tmp/m12/project.tar | tail -3

tar -czf - /tmp/m12/project/ | wc -c

tar -xzf /tmp/m12/project.tar.gz -O tmp/m12/project/docs/README.md
```

**Useful tar patterns:**
```bash
# Backup with timestamp
tar -czf backup-$(date +%F).tar.gz /path/to/backup/

# Stream archive over SSH (no intermediate file)
tar -czf - /data/ | ssh user@host "cat > /backup/data.tar.gz"

# Extract to stdout for piping
tar -xzf archive.tar.gz -O path/in/archive | grep pattern

# Exclude directories
tar -czf archive.tar.gz /src/ --exclude=/src/.git --exclude='*.pyc'
```

---

## Quick Reference

```bash
tar -czf archive.tar.gz dir/     create gzip-compressed archive
tar -cjf archive.tar.bz2 dir/    create bzip2-compressed archive
tar -cJf archive.tar.xz dir/     create xz-compressed archive
tar -tf  archive.tar.gz          list contents (no extraction)
tar -xzf archive.tar.gz          extract to current directory
tar -xzf archive.tar.gz -C dir/  extract to specific directory
tar -xzf archive.tar.gz -O path  extract file to stdout
tar -rf  archive.tar newfile     append to uncompressed archive
gzip  -k file                    compress (keep original with -k)
gunzip   file.gz                 decompress
bzip2 -k file                    compress with bzip2
xz    -k file                    compress with xz
zip -r archive.zip dir/          create zip archive
unzip -l archive.zip             list zip contents
unzip archive.zip -d dir/        extract zip to directory
```
