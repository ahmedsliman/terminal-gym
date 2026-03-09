# Exercises — Mission 10: File Types & Viewing

---

## Exercise 1: Reading File Type Characters

**Goal:** Identify all seven file type characters from `ls -l` output.

**Steps:**
1. Find a regular file and a directory:
   ```bash
   ls -l /etc/hostname /etc
   ```
2. Find a symbolic link:
   ```bash
   ls -l /etc/localtime
   ```
3. Find character devices:
   ```bash
   ls -l /dev/null /dev/zero /dev/tty
   ```
4. Find a block device (if any):
   ```bash
   ls -l /dev/sda 2>/dev/null || ls -l /dev/nvme0n1 2>/dev/null || echo "no block device at standard paths"
   ```
5. Create and inspect a named pipe:
   ```bash
   mkfifo /tmp/m10-pipe
   ls -l /tmp/m10-pipe
   rm /tmp/m10-pipe
   ```

**Hint:** The file type is always the very first character: `-` regular, `d` directory, `l` symlink, `c` character device, `b` block device, `p` named pipe, `s` socket.

**Self-check:** `ls -l /etc/localtime` should start with `l` and show `-> /usr/share/zoneinfo/...`.

---

## Exercise 2: file — Identify Content, Not Name

**Goal:** Prove that file extensions mean nothing — content determines type.

**Setup:**
```bash
mkdir -p /tmp/m10
```

**Steps:**
1. Identify system binaries:
   ```bash
   file /usr/bin/ls /usr/bin/bash
   ```
2. Identify text files:
   ```bash
   file /etc/hostname /etc/os-release
   ```
3. Create a shell script disguised as a `.txt` file and identify it:
   ```bash
   printf '#!/bin/bash\necho hello\n' > /tmp/m10/script.txt
   file /tmp/m10/script.txt
   ```
4. Create a PNG disguised as a `.log` file:
   ```bash
   # Copy a real PNG (first few bytes are the magic number)
   cp /usr/share/pixmaps/*.png /tmp/m10/data.log 2>/dev/null || \
     printf '\x89PNG\r\n\x1a\n' > /tmp/m10/data.log
   file /tmp/m10/data.log
   ```
5. Identify a symlink and its target:
   ```bash
   file /etc/localtime
   ```

**Hint:** `file` reads the first few bytes (the "magic number") to determine type. Extensions are purely cosmetic in Linux.

**Self-check:** Step 3 should report "Bourne-Again shell script" or similar, even though the extension is `.txt`.

---

## Exercise 3: stat — Full Inode Metadata

**Goal:** Read all three timestamps and the full permission details from an inode.

**Steps:**
1. Run stat on a file:
   ```bash
   stat /etc/hostname
   ```
2. Identify the three timestamps in the output:
   - **Access** — last time the file was read
   - **Modify** — last time the file contents changed
   - **Change** — last time the inode metadata changed (permissions, owner)
3. Touch a file and observe which timestamp changes:
   ```bash
   touch /tmp/m10/touched.txt
   stat /tmp/m10/touched.txt
   ```
4. Read a file and check if atime updates:
   ```bash
   cat /etc/hostname
   stat /etc/hostname
   ```
   (atime may not update if the filesystem is mounted with `relatime`)
5. View the raw octal permission value:
   ```bash
   stat -c '%a %n' /etc/hostname /usr/bin/ls /etc/shadow 2>/dev/null
   ```

**Hint:** `stat -c '%a %n'` prints only the octal permission and filename — useful in scripts. Modern filesystems use `relatime` which only updates atime when it is older than mtime, to reduce disk I/O.

**Self-check:** `stat -c '%a' /usr/bin/ls` should print `755`.

---

## Exercise 4: xxd and hexdump — Reading Binary Content

**Goal:** Inspect the raw bytes of files and identify magic numbers.

**Steps:**
1. Show the first 32 bytes of the `ls` binary as hex:
   ```bash
   xxd /usr/bin/ls | head -4
   ```
2. Identify the ELF magic number (bytes 0–3):
   - Should be: `7f 45 4c 46` which is `.ELF` in ASCII
3. Read the same bytes with hexdump:
   ```bash
   hexdump -C /usr/bin/ls | head -4
   ```
4. Find the magic number of a gzip file:
   ```bash
   ls /usr/share/doc/*/*.gz 2>/dev/null | head -1 | xargs -I{} xxd {} | head -2
   ```
5. Show just the first 4 bytes of a file in hex (no addresses):
   ```bash
   od -An -tx1 -N4 /usr/bin/ls
   ```

**Hint:** `xxd file | head -N` is enough for identifying most formats — the magic number is always in the first few bytes. The `7f 45 4c 46` ELF header is universal across all Linux executables.

**Self-check:** The first four bytes of any ELF binary are always `7f 45 4c 46`.

---

## Exercise 5: strings — Extracting Text from Binaries

**Goal:** Extract readable strings from a binary executable.

**Steps:**
1. Extract all readable strings from `ls`:
   ```bash
   strings /usr/bin/ls | head -20
   ```
2. Find version-related strings:
   ```bash
   strings /usr/bin/ls | grep -i 'version\|gnu\|coreutils' | head -5
   ```
3. Find error messages embedded in a binary:
   ```bash
   strings /usr/bin/ls | grep -i 'cannot\|error\|failed' | head -10
   ```
4. Count printable strings found:
   ```bash
   strings /usr/bin/ls | wc -l
   ```
5. Find strings in a system library:
   ```bash
   strings /lib/x86_64-linux-gnu/libc.so.6 2>/dev/null | grep -i 'glibc\|version' | head -5
   ```

**Hint:** `strings` by default extracts sequences of 4+ printable ASCII characters. It is useful for quick recon but not reliable as a security tool — strings can be obfuscated or encoded.

**Self-check:** Step 2 should show something containing "GNU coreutils" or the `ls` version number.

---

## Exercise 6: wc — Measuring Files

**Goal:** Count lines, words, and bytes in various files.

**Steps:**
1. Count lines, words, and bytes in /etc/passwd:
   ```bash
   wc /etc/passwd
   ```
2. Count only lines:
   ```bash
   wc -l /etc/passwd
   ```
3. Count only bytes:
   ```bash
   wc -c /usr/bin/ls
   ```
4. Count words in a sentence using a here-string:
   ```bash
   wc -w <<< "the quick brown fox jumps over the lazy dog"
   ```
5. Count total lines across all files in /etc:
   ```bash
   wc -l /etc/*.conf 2>/dev/null | tail -1
   ```

**Hint:** `wc` output order is always: lines words bytes filename. Use `-l`, `-w`, or `-c` to request only one count.

**Self-check:** Step 4 should output `9` (nine words).

---

## Exercise 7: ldd — Shared Library Dependencies

**Goal:** Inspect what shared libraries an ELF binary requires at runtime.

**Steps:**
1. List libraries that `ls` depends on:
   ```bash
   ldd /usr/bin/ls
   ```
2. List libraries that `bash` depends on:
   ```bash
   ldd /usr/bin/bash
   ```
3. Find a statically linked binary (no dynamic dependencies):
   ```bash
   ldd /usr/bin/busybox 2>/dev/null || echo "busybox not installed — try: ldd /bin/true"
   ldd /bin/true
   ```
4. Count how many shared libraries are cached system-wide:
   ```bash
   ldconfig -p | wc -l
   ```
5. Find the library that provides `printf`:
   ```bash
   ldconfig -p | grep libc
   ```

**Hint:** A binary showing "not a dynamic executable" is statically linked — all its code is compiled in. Dynamically linked binaries are smaller but require the correct libraries at runtime.

**Self-check:** `ldd /usr/bin/ls` should include `libc.so.6` — almost every Linux binary links against glibc.

---

## Exercise 8: Magic Numbers Lab

**Goal:** Create files with known magic bytes and verify them with `file`.

**Steps:**
1. Create a fake PNG (just the magic bytes):
   ```bash
   printf '\x89PNG\r\n\x1a\n' > /tmp/m10/fake.png
   file /tmp/m10/fake.png
   xxd /tmp/m10/fake.png | head -2
   ```
2. Create a minimal shell script with shebang:
   ```bash
   printf '#!/bin/bash\n' > /tmp/m10/magic-script
   file /tmp/m10/magic-script
   xxd /tmp/m10/magic-script | head -2
   ```
3. Create a text file and confirm:
   ```bash
   echo "hello world" > /tmp/m10/text.bin
   file /tmp/m10/text.bin
   ```
4. Verify the gzip magic number:
   ```bash
   printf '\x1f\x8b' > /tmp/m10/fake.gz
   file /tmp/m10/fake.gz
   ```
5. Summary — match each magic byte sequence to its format:

   | Magic bytes (hex) | Format |
   |------------------|--------|
   | `7f 45 4c 46` | ELF binary |
   | `89 50 4e 47` | PNG image |
   | `1f 8b` | gzip archive |
   | `50 4b 03 04` | ZIP / JAR |
   | `23 21` | Shell script (`#!`) |

**Hint:** `printf '\xNN'` writes a single byte with hexadecimal value NN. This lets you craft files with specific magic bytes.

**Self-check:** Step 1 should make `file` report "PNG image data" despite the file having no real image content beyond the header.

---

Cleanup:
```bash
rm -rf /tmp/m10
```

Mark complete:
```bash
make done N=10
make next
```
