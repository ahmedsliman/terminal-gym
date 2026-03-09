# Exercises — Mission 08: File Management

---

## Exercise 1: mkdir -p — Building Directory Trees

**Goal:** Create multi-level directory structures in a single command.

**Setup:**
```bash
mkdir -p /tmp/m08
```

**Steps:**
1. Create a nested path in one shot:
   ```bash
   mkdir -p /tmp/m08/project/src/components
   ```
2. Verify the full tree was created:
   ```bash
   find /tmp/m08/project -type d | sort
   ```
3. Run the same `mkdir -p` again — confirm no error:
   ```bash
   mkdir -p /tmp/m08/project/src/components
   echo "exit code: $?"
   ```
4. Create a skeleton for a web app using brace expansion:
   ```bash
   mkdir -p /tmp/m08/webapp/{frontend,backend}/{src,tests,docs}
   find /tmp/m08/webapp -type d | sort
   ```
5. Count how many directories were created:
   ```bash
   find /tmp/m08/webapp -type d | wc -l
   ```

**Hint:** `mkdir` without `-p` fails if any parent is missing. With `-p` the entire path is created and repeat calls are safe.

**Self-check:** Step 5 should show 9 directories (the `webapp` root + 2 services × 3 subdirs each + 2 service roots).

---

## Exercise 2: cp — Copying Files and Directories

**Goal:** Copy single files, multiple files, and full directory trees.

**Setup:**
```bash
echo "server config" > /tmp/m08/server.conf
echo "app config"    > /tmp/m08/app.conf
echo "readme text"   > /tmp/m08/README.md
```

**Steps:**
1. Copy a single file:
   ```bash
   cp /tmp/m08/server.conf /tmp/m08/server.conf.bak
   ls /tmp/m08/*.conf*
   ```
2. Copy multiple files into a directory:
   ```bash
   mkdir -p /tmp/m08/backup
   cp /tmp/m08/server.conf /tmp/m08/app.conf /tmp/m08/backup/
   ls /tmp/m08/backup/
   ```
3. Recursive copy of a directory:
   ```bash
   cp -r /tmp/m08/webapp/frontend /tmp/m08/webapp/frontend-v1
   find /tmp/m08/webapp -type d | sort
   ```
4. Verbose copy to see what is happening:
   ```bash
   cp -v /tmp/m08/README.md /tmp/m08/backup/README.md
   ```
5. Copy and preserve timestamps:
   ```bash
   cp -p /tmp/m08/server.conf /tmp/m08/server.preserved.conf
   ls -l /tmp/m08/server.conf /tmp/m08/server.preserved.conf
   ```

**Hint:** Without `-r`, `cp` prints an error and refuses to copy a directory. `-p` preserves timestamps and permissions — useful when copying config files.

**Self-check:** After step 3, `find /tmp/m08/webapp -type d | sort` shows a `frontend-v1` entry with the same three subdirectories as `frontend`.

---

## Exercise 3: mv — Move and Rename

**Goal:** Rename files in place and move them across directories.

**Steps:**
1. Rename a file:
   ```bash
   mv /tmp/m08/server.conf.bak /tmp/m08/server.conf.old
   ls /tmp/m08/*.conf*
   ```
2. Move a file into a subdirectory:
   ```bash
   mv /tmp/m08/server.conf.old /tmp/m08/backup/
   ls /tmp/m08/backup/
   ```
3. Move multiple files at once using a glob:
   ```bash
   mv /tmp/m08/webapp/frontend-v1/src /tmp/m08/webapp/frontend-v1/source
   ls /tmp/m08/webapp/frontend-v1/
   ```
4. Rename an entire directory:
   ```bash
   mv /tmp/m08/webapp/backend /tmp/m08/webapp/api
   ls /tmp/m08/webapp/
   ```
5. Attempt an overwrite — move a file onto an existing file:
   ```bash
   echo "original" > /tmp/m08/target.txt
   echo "replacement" > /tmp/m08/source.txt
   mv /tmp/m08/source.txt /tmp/m08/target.txt
   cat /tmp/m08/target.txt
   ```

**Hint:** `mv` overwrites the destination without warning. Use `mv -i` to be prompted before overwriting. No `-r` flag is needed for directories.

**Self-check:** After step 5, `cat /tmp/m08/target.txt` prints `replacement`. The original is gone.

---

## Exercise 4: rm — Deleting Files and Directories

**Goal:** Delete files safely and understand the dangers of `rm -rf`.

**Steps:**
1. Delete a single file:
   ```bash
   echo "junk" > /tmp/m08/junk.txt
   rm /tmp/m08/junk.txt
   ls /tmp/m08/junk.txt 2>&1
   ```
2. Delete multiple files at once:
   ```bash
   touch /tmp/m08/a.tmp /tmp/m08/b.tmp /tmp/m08/c.tmp
   rm /tmp/m08/a.tmp /tmp/m08/b.tmp /tmp/m08/c.tmp
   ls /tmp/m08/*.tmp 2>&1
   ```
3. Interactive delete:
   ```bash
   echo "test" > /tmp/m08/careful.txt
   rm -i /tmp/m08/careful.txt
   ```
   (type `y` to confirm, or `n` to cancel)

4. Recursive delete of a directory tree:
   ```bash
   mkdir -p /tmp/m08/deleteme/sub1/sub2
   touch /tmp/m08/deleteme/file1.txt /tmp/m08/deleteme/sub1/file2.txt
   ls -R /tmp/m08/deleteme
   rm -r /tmp/m08/deleteme
   ls /tmp/m08/deleteme 2>&1
   ```

**Hint:** `rm` has no undo. Practice using `-i` until you are confident. Never run `rm -rf` against a shell variable without first verifying it is not empty.

**Self-check:** After step 4, `ls /tmp/m08/deleteme` prints `No such file or directory`.

---

## Exercise 5: Hard Links — ln

**Goal:** Create hard links and observe how they relate to inodes.

**Steps:**
1. Create a file and a hard link to it:
   ```bash
   echo "shared data" > /tmp/m08/original.txt
   ln /tmp/m08/original.txt /tmp/m08/link-a.txt
   ls -li /tmp/m08/original.txt /tmp/m08/link-a.txt
   ```
2. Write via the hard link and observe the change through the original:
   ```bash
   echo "updated via link" >> /tmp/m08/link-a.txt
   cat /tmp/m08/original.txt
   ```
3. Delete the original name — data survives via the link:
   ```bash
   rm /tmp/m08/original.txt
   cat /tmp/m08/link-a.txt
   ls -li /tmp/m08/link-a.txt
   ```
4. Confirm you cannot hard-link across filesystems:
   ```bash
   # /tmp and /run are usually on different filesystems
   ln /tmp/m08/link-a.txt /run/crossfs-test 2>&1 || echo "expected: cross-device link error"
   ```
5. Confirm you cannot hard-link a directory:
   ```bash
   ln /tmp/m08/backup /tmp/m08/backup-hard 2>&1 || echo "expected: cannot hard-link a directory"
   ```

**Hint:** The link count in `ls -li` (the number after the permissions) shows how many hard links point to that inode. It drops to 1 after you delete one name.

**Self-check:** After step 3, `ls -li /tmp/m08/link-a.txt` shows link count `1` — only one name remains, but the data is intact.

---

## Exercise 6: Symbolic Links — ln -s

**Goal:** Create and inspect symlinks; understand dangling links.

**Steps:**
1. Create a symlink to a file:
   ```bash
   ln -s /tmp/m08/link-a.txt /tmp/m08/soft-link.txt
   ls -l /tmp/m08/soft-link.txt
   readlink /tmp/m08/soft-link.txt
   ```
2. Read through the symlink:
   ```bash
   cat /tmp/m08/soft-link.txt
   ```
3. Create a symlink to a directory and list through it:
   ```bash
   ln -s /tmp/m08/webapp /tmp/m08/current-webapp
   ls /tmp/m08/current-webapp/
   ```
4. Make a dangling link and observe the error:
   ```bash
   ln -s /tmp/m08/does-not-exist /tmp/m08/dangling
   ls -l /tmp/m08/dangling
   cat /tmp/m08/dangling 2>&1
   file /tmp/m08/dangling
   ```
5. Use `readlink -f` to resolve a real link's full path:
   ```bash
   readlink -f /tmp/m08/soft-link.txt
   ```

**Hint:** `ls -l` shows broken symlinks with an arrow pointing to a non-existent path. The colour in the terminal (if enabled) is usually red. `file` will say "broken symbolic link".

**Self-check:** Step 4 — `cat /tmp/m08/dangling` gives `No such file or directory`. `file /tmp/m08/dangling` prints "broken symbolic link".

---

## Exercise 7: Inspecting Links — ls -li, file, readlink

**Goal:** Use inspection tools to understand the type and targets of all file entries.

**Setup:**
```bash
echo "data" > /tmp/m08/data.txt
ln      /tmp/m08/data.txt /tmp/m08/hard.txt
ln -s   /tmp/m08/data.txt /tmp/m08/soft.txt
ln -s   /tmp/m08/soft.txt /tmp/m08/chain.txt
```

**Steps:**
1. Show all four with `ls -li` and identify which share an inode:
   ```bash
   ls -li /tmp/m08/data.txt /tmp/m08/hard.txt /tmp/m08/soft.txt /tmp/m08/chain.txt
   ```
2. Use `file` to describe each:
   ```bash
   file /tmp/m08/data.txt /tmp/m08/hard.txt /tmp/m08/soft.txt /tmp/m08/chain.txt
   ```
3. Follow the chain with `readlink` vs `readlink -f`:
   ```bash
   readlink /tmp/m08/chain.txt      # one step only
   readlink -f /tmp/m08/chain.txt   # full resolution to the real file
   ```
4. Check the link count changes:
   ```bash
   ls -l /tmp/m08/data.txt   # link count should be 2
   rm /tmp/m08/hard.txt
   ls -l /tmp/m08/data.txt   # link count drops to 1
   ```

**Hint:** The first column of `ls -li` is the inode number. Two files with the same inode are hard links. Symlinks have their own (different) inode.

**Self-check:** In step 1, `data.txt` and `hard.txt` share the same inode number. `soft.txt` and `chain.txt` have different inode numbers.

---

## Exercise 8: du — Measuring Disk Usage

**Goal:** Measure space used by files and directories at different granularities.

**Steps:**
1. Total size of a directory:
   ```bash
   du -sh /tmp/m08/
   ```
2. Size of each item inside a directory:
   ```bash
   du -sh /tmp/m08/*
   ```
3. Size of all items including files, one level deep:
   ```bash
   du -ah --max-depth=1 /tmp/m08/ 2>/dev/null | sort -rh | head -10
   ```
4. Measure a real system directory:
   ```bash
   du -sh /var/log 2>/dev/null
   ```
5. Show sizes for all first-level subdirectories of /usr:
   ```bash
   du -sh /usr/*/ 2>/dev/null | sort -rh | head -5
   ```

**Hint:** `-s` gives a summary total. Without `-s`, `du` recurses and prints every subdirectory. Use `-h` for K/M/G units. Use `--max-depth=1` or `-d 1` to limit depth.

**Self-check:** Step 5 should show 5 lines, each starting with a size like `500M /usr/lib`.

---

## Exercise 9: df — Filesystem Free Space and Finding Large Files

**Goal:** Understand filesystem-level capacity and pinpoint what is filling the disk.

**Steps:**
1. Show all mounted filesystems:
   ```bash
   df -h
   ```
2. Show the filesystem that holds `/var`:
   ```bash
   df -h /var
   ```
3. Include filesystem type in the output:
   ```bash
   df -hT
   ```
4. Find the top 10 largest consumers at the top level of `/`:
   ```bash
   du -sh /* 2>/dev/null | sort -rh | head -10
   ```
5. Drill into the largest result from step 4 (replace `/usr` with whatever was largest):
   ```bash
   du -sh /usr/*/ 2>/dev/null | sort -rh | head -5
   ```

**Hint:** `sort -h` sorts human-readable sizes correctly — `1K < 10K < 1M`. Without `-h`, `sort` would treat them as strings and get the order wrong.

**Self-check:** Step 4 should produce 10 lines ordered from largest to smallest size.

---

Cleanup:
```bash
rm -rf /tmp/m08
```

Mark complete:
```bash
make done N=08
make next
```
