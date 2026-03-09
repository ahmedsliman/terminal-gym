# Exercises — Mission 02: Text Files & Vim

Work through each exercise in your terminal. Use `man` or `--help` freely.

---

## Exercise 1: Copy and Move Files

**Goal:** Understand how `cp` and `mv` work and when to use each.

**Steps:**
1. Create a working directory: `mkdir -p /tmp/m02`
2. Copy `/etc/hosts` into it: `cp /etc/hosts /tmp/m02/`
3. Copy `/etc/hostname` into it with a new name: `cp /etc/hostname /tmp/m02/my-hostname`
4. Create a subdirectory and copy a file into it:
   ```bash
   mkdir /tmp/m02/sub
   cp /tmp/m02/my-hostname /tmp/m02/sub/
   ```
5. Rename a file: `mv /tmp/m02/my-hostname /tmp/m02/renamed-hostname`
6. Verify: `ls -lh /tmp/m02/ && ls -lh /tmp/m02/sub/`

**Hint:** `cp` keeps the original. `mv` removes it. When the destination is a directory, both commands keep the original filename.

**Self-check:** After step 5, `/tmp/m02/my-hostname` should not exist. `/tmp/m02/renamed-hostname` should exist.

---

## Exercise 2: Compare Files with diff

**Goal:** Use `diff` to spot changes between two versions of a file.

**Steps:**
1. Copy `/etc/hosts` twice:
   ```bash
   cp /etc/hosts /tmp/m02/hosts-v1
   cp /etc/hosts /tmp/m02/hosts-v2
   ```
2. Append a line to the second copy: `echo "# added line" >> /tmp/m02/hosts-v2`
3. Compare them: `diff /tmp/m02/hosts-v1 /tmp/m02/hosts-v2`
4. Compare again in unified format: `diff -u /tmp/m02/hosts-v1 /tmp/m02/hosts-v2`

**Hint:** `<` = line only in the first file, `>` = line only in the second. In unified format, `-` = removed, `+` = added.

**Self-check:** The diff should show exactly one added line (`# added line`). No output from `diff` means files are identical.

---

## Exercise 3: Read Parts of a File

**Goal:** Navigate large files without reading everything at once.

**Steps:**
1. Count lines in `/etc/passwd`: `wc -l /etc/passwd`
2. Show the first 5 lines: `head -n 5 /etc/passwd`
3. Show the last 3 lines: `tail -n 3 /etc/passwd`
4. Open `/etc/passwd` in `less` — practice:
   - `Space` to go to next page
   - `b` to go back
   - `/root` to search for "root"
   - `n` to jump to next match
   - `q` to quit

**Hint:** `tail -f /var/log/syslog` follows a live log. Press Ctrl+C to stop.

**Self-check:** Can you find the line for the `root` user using `/root` inside `less`?

---

## Exercise 4: Edit a File in Vim

**Goal:** Open, edit, save, and quit a file in Vim.

**Steps:**
1. Create a practice file: `echo "line one" > /tmp/m02/vim-test.txt && echo "line two" >> /tmp/m02/vim-test.txt`
2. Open it in Vim: `vim /tmp/m02/vim-test.txt`
3. Inside Vim:
   - Press `i` to enter Insert mode
   - Add a new line: `line three`
   - Press `Esc` to return to Normal mode
   - Type `:wq` and press Enter to save and quit
4. Verify: `cat /tmp/m02/vim-test.txt`

**Hint:** If you get stuck in Vim, press `Esc` then type `:q!` and press Enter to quit without saving.

**Self-check:** `cat /tmp/m02/vim-test.txt` should show three lines.

---

## Exercise 5: Vim Movement and Deletion

**Goal:** Navigate and edit in Vim without using arrow keys.

**Steps:**
1. Create a multi-line file:
   ```bash
   cat > /tmp/m02/movement.txt << 'EOF'
   the quick brown fox
   delete this entire line
   keep this line
   delete just the word DELETE here: DELETE
   EOF
   ```
2. Open it: `vim /tmp/m02/movement.txt`
3. Practice inside Vim:
   - Move with `h` `j` `k` `l` (left/down/up/right)
   - Jump to the "delete this entire line" line, press `dd` to delete it
   - Move to "DELETE" word, press `dw` to delete one word
   - Press `u` to undo your last action
   - Jump to top with `gg`, bottom with `G`
   - Save and quit: `:wq`

**Hint:** `w` jumps forward one word, `b` jumps back. `0` goes to line start, `$` goes to line end.

**Self-check:** After saving, `cat /tmp/m02/movement.txt` should show 3 lines (the "delete this entire line" line should be gone).

---

## Exercise 6: Vim Search and Replace

**Goal:** Find text and do a global substitution inside Vim.

**Steps:**
1. Create a file with repeated words:
   ```bash
   echo "the cat sat on the mat next to the vat" > /tmp/m02/replace.txt
   ```
2. Open it: `vim /tmp/m02/replace.txt`
3. Search for "the": type `/the` and press Enter — press `n` to jump to next match
4. Replace all occurrences: type `:%s/the/THE/g` and press Enter
5. Save and quit: `:wq`
6. Verify: `cat /tmp/m02/replace.txt`

**Hint:** `%` means whole file, `s` means substitute, `g` means all matches per line. Without `g`, only the first match per line is replaced.

**Self-check:** Every "the" should now be "THE". Count with: `grep -o "the" /tmp/m02/replace.txt | wc -l` (should print 0).

---

## Exercise 7: Run Shell Commands from Inside Vim (Stretch)

**Goal:** Use Vim as an interactive environment, not just a text editor.

**Steps:**
1. Create a file: `vim /tmp/m02/shell-in-vim.txt`
2. Inside Vim, type a placeholder line in Insert mode: `REPLACE THIS WITH THE DATE`
3. Press `Esc`, then with the cursor on that line run: `:.! date`
4. The line should be replaced with the output of `date`
5. Add another line with your username using: `:.! whoami`
6. Save and quit: `:wq`
7. Verify: `cat /tmp/m02/shell-in-vim.txt`

**Hint:** `:.!` means "replace the current line with the output of the following command".

**Self-check:** The file should contain the current date and your username, not placeholder text.

---

Cleanup when done:

```bash
rm -rf /tmp/m02
```

Then mark this mission complete:

```bash
make done N=02
make next
```
