# Exercises — Mission 12: Archive & Compression

---

## Exercise 1: Creating tar Archives

**Goal:** Create uncompressed and compressed tar archives.

**Setup:**
```bash
mkdir -p /tmp/m12/project/{src,docs,tests}
echo "main code" > /tmp/m12/project/src/main.sh
echo "helper"   > /tmp/m12/project/src/helper.sh
echo "readme"   > /tmp/m12/project/docs/README.md
echo "test 1"   > /tmp/m12/project/tests/test1.sh
```

**Steps:**
1. Create an uncompressed tar archive:
   ```bash
   tar -cvf /tmp/m12/project.tar /tmp/m12/project/
   ```
2. Create a gzip-compressed archive:
   ```bash
   tar -czf /tmp/m12/project.tar.gz /tmp/m12/project/
   ```
3. Create a bzip2-compressed archive:
   ```bash
   tar -cjf /tmp/m12/project.tar.bz2 /tmp/m12/project/
   ```
4. Create an xz-compressed archive:
   ```bash
   tar -cJf /tmp/m12/project.tar.xz /tmp/m12/project/
   ```
5. Compare the sizes of all four archives:
   ```bash
   ls -lh /tmp/m12/*.tar /tmp/m12/*.tar.gz /tmp/m12/*.tar.bz2 /tmp/m12/*.tar.xz
   ```

**Hint:** `-c` = create, `-v` = verbose, `-f` = file (next argument is the archive name), `-z` = gzip, `-j` = bzip2, `-J` = xz. The flag order matters: `-f` must be immediately followed by the archive filename.

**Self-check:** Step 5 should show that `project.tar` is the largest (uncompressed) and `project.tar.xz` is the smallest.

---

## Exercise 2: Listing Archive Contents

**Goal:** Inspect an archive without extracting it.

**Steps:**
1. List contents of the uncompressed archive:
   ```bash
   tar -tvf /tmp/m12/project.tar
   ```
2. List contents of the gzip archive:
   ```bash
   tar -tzvf /tmp/m12/project.tar.gz
   ```
3. List only the file paths (no metadata):
   ```bash
   tar -tf /tmp/m12/project.tar.gz
   ```
4. Count files in the archive:
   ```bash
   tar -tf /tmp/m12/project.tar.gz | wc -l
   ```
5. Check if a specific file is in the archive:
   ```bash
   tar -tf /tmp/m12/project.tar.gz | grep "README"
   ```

**Hint:** `-t` = list (test), `-v` = verbose (show permissions, size, date). Without `-v`, you just get filenames. You do not need to specify the compression flag when listing — `tar` detects it automatically on modern systems.

**Self-check:** Step 3 should show paths starting with `tmp/m12/project/` (absolute paths are stored without the leading `/`).

---

## Exercise 3: Extracting Archives

**Goal:** Extract archives to specific locations.

**Setup:**
```bash
mkdir -p /tmp/m12/extract
```

**Steps:**
1. Extract to the current directory (note: restores original paths):
   ```bash
   cd /tmp/m12/extract
   tar -xzf /tmp/m12/project.tar.gz
   find /tmp/m12/extract -type f | sort
   ```
2. Extract to a specific directory with `-C`:
   ```bash
   mkdir -p /tmp/m12/extract2
   tar -xzf /tmp/m12/project.tar.gz -C /tmp/m12/extract2
   find /tmp/m12/extract2 -type f | sort
   ```
3. Extract only one specific file:
   ```bash
   mkdir -p /tmp/m12/extract3
   tar -xzf /tmp/m12/project.tar.gz -C /tmp/m12/extract3 \
     tmp/m12/project/docs/README.md
   find /tmp/m12/extract3 -type f
   ```
4. Extract with verbose output:
   ```bash
   mkdir -p /tmp/m12/extract4
   tar -xzvf /tmp/m12/project.tar.gz -C /tmp/m12/extract4
   ```
5. Test archive integrity without extracting:
   ```bash
   tar -tzf /tmp/m12/project.tar.gz > /dev/null && echo "archive OK" || echo "archive corrupted"
   ```

**Hint:** `-x` = extract, `-C dir` = change to `dir` before extracting. If you omit `-C`, files are extracted relative to the current working directory, recreating the full path structure stored in the archive.

**Self-check:** After step 2, `find /tmp/m12/extract2 -type f` shows 4 files inside a `tmp/m12/project/` subdirectory tree.

---

## Exercise 4: gzip, bzip2, xz — Compression Algorithms

**Goal:** Compress and decompress individual files; compare algorithms.

**Setup:**
```bash
# Create a compressible test file
python3 -c "print('a' * 10000)" > /tmp/m12/data.txt 2>/dev/null || \
  dd if=/dev/zero bs=10000 count=1 2>/dev/null | tr '\0' 'a' > /tmp/m12/data.txt
```

**Steps:**
1. Compress with gzip and check size:
   ```bash
   cp /tmp/m12/data.txt /tmp/m12/data-gzip.txt
   gzip /tmp/m12/data-gzip.txt
   ls -lh /tmp/m12/data-gzip.txt.gz
   ```
2. Decompress:
   ```bash
   gunzip /tmp/m12/data-gzip.txt.gz
   head -c 20 /tmp/m12/data-gzip.txt
   ```
3. Compress with bzip2:
   ```bash
   cp /tmp/m12/data.txt /tmp/m12/data-bzip2.txt
   bzip2 /tmp/m12/data-bzip2.txt
   ls -lh /tmp/m12/data-bzip2.txt.bz2
   ```
4. Compress with xz:
   ```bash
   cp /tmp/m12/data.txt /tmp/m12/data-xz.txt
   xz /tmp/m12/data-xz.txt
   ls -lh /tmp/m12/data-xz.txt.xz
   ```
5. Compare all three compressed sizes:
   ```bash
   ls -lh /tmp/m12/data-gzip.txt.gz /tmp/m12/data-bzip2.txt.bz2 /tmp/m12/data-xz.txt.xz
   ```

**Hint:** `gzip`, `bzip2`, and `xz` compress single files **in place** — the original file is replaced by the compressed version. Use `gzip -k` (keep) to preserve the original. `gunzip` and `bunzip2` decompress in place.

**Self-check:** All three compressed files should be much smaller than the 10 KB original. xz typically achieves the best compression ratio.

---

## Exercise 5: Compression Algorithm Comparison

**Goal:** Understand the trade-offs between speed and compression ratio.

**Setup:**
```bash
# Generate a larger compressible file
python3 -c "import random; random.seed(42); [print('log entry ' + str(i) + ' ' + 'x'*50) for i in range(1000)]" \
  > /tmp/m12/logdata.txt 2>/dev/null || \
  seq 1 1000 | awk '{printf "log entry %s %s\n", $1, "x"*50}' > /tmp/m12/logdata.txt
```

**Steps:**
1. Time gzip compression:
   ```bash
   time gzip -k /tmp/m12/logdata.txt
   ls -lh /tmp/m12/logdata.txt.gz
   ```
2. Time bzip2 compression:
   ```bash
   time bzip2 -k /tmp/m12/logdata.txt
   ls -lh /tmp/m12/logdata.txt.bz2
   ```
3. Time xz compression:
   ```bash
   time xz -k /tmp/m12/logdata.txt
   ls -lh /tmp/m12/logdata.txt.xz
   ```
4. Summarize in a table:

   | Algorithm | Extension | Speed | Ratio | Use case |
   |-----------|-----------|-------|-------|---------|
   | gzip | `.gz` | Fastest | Good | Logs, general purpose |
   | bzip2 | `.bz2` | Medium | Better | Source archives |
   | xz | `.xz` | Slowest | Best | Distribution packages |

5. Clean up:
   ```bash
   rm -f /tmp/m12/logdata.txt.gz /tmp/m12/logdata.txt.bz2 /tmp/m12/logdata.txt.xz
   ```

**Hint:** For interactive use, gzip's speed makes it the practical default. xz is preferred for software distributions where archive size matters more than creation time.

**Self-check:** `time gzip` should be noticeably faster than `time xz` — xz does more computation to achieve better compression.

---

## Exercise 6: zip and unzip

**Goal:** Work with zip archives (common for cross-platform sharing).

**Steps:**
1. Create a zip archive:
   ```bash
   zip /tmp/m12/project.zip -r /tmp/m12/project/
   ```
2. List zip contents:
   ```bash
   unzip -l /tmp/m12/project.zip
   ```
3. Test archive integrity:
   ```bash
   unzip -t /tmp/m12/project.zip
   ```
4. Extract to a specific directory:
   ```bash
   mkdir -p /tmp/m12/unzipped
   unzip /tmp/m12/project.zip -d /tmp/m12/unzipped
   find /tmp/m12/unzipped -type f
   ```
5. Extract a single file from the zip:
   ```bash
   mkdir -p /tmp/m12/single
   unzip /tmp/m12/project.zip 'tmp/m12/project/docs/README.md' -d /tmp/m12/single
   ```

**Hint:** `zip` stores files with their directory structure. The `-r` flag makes it recursive (required for directories). `unzip -l` lists without extracting. `unzip -t` tests integrity.

**Self-check:** `unzip -t` should print "No errors detected" for a valid archive.

---

## Exercise 7: Real-world Archive Patterns

**Goal:** Apply archiving skills to practical scenarios.

**Steps:**
1. Create a timestamped backup archive:
   ```bash
   TIMESTAMP=$(date +%Y%m%d-%H%M%S)
   tar -czf /tmp/m12/backup-${TIMESTAMP}.tar.gz /tmp/m12/project/
   ls -lh /tmp/m12/backup-*.tar.gz
   ```
2. Extract only specific file types from an archive:
   ```bash
   tar -xzf /tmp/m12/project.tar.gz -C /tmp/m12/extract \
     --wildcards '*.sh'
   find /tmp/m12/extract -name "*.sh"
   ```
3. Append files to an existing archive (uncompressed only):
   ```bash
   echo "new file" > /tmp/m12/new-file.txt
   tar -rf /tmp/m12/project.tar /tmp/m12/new-file.txt
   tar -tf /tmp/m12/project.tar | tail -3
   ```
4. Create an archive and pipe it directly (no intermediate file):
   ```bash
   tar -czf - /tmp/m12/project/ | wc -c
   ```
5. View a file inside an archive without extracting:
   ```bash
   tar -xzf /tmp/m12/project.tar.gz -O tmp/m12/project/docs/README.md
   ```

**Hint:** `-O` (uppercase letter O) sends extracted content to stdout rather than creating a file. `-` as the filename means stdin/stdout. Appending (`-r`) only works on uncompressed `.tar` archives — you cannot append to `.tar.gz`.

**Self-check:** Step 5 should print `readme` — the content of README.md — directly to the terminal without creating any files.

---

Cleanup:
```bash
rm -rf /tmp/m12
```

Mark complete:
```bash
make done N=12
make next
```
