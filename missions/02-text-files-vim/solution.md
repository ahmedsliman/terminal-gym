# Solution — Mission 02: Text Files & Vim

Reference answers for every exercise. Read only after a genuine attempt.

---

## Exercise 1: Copy and Move Files

```bash
mkdir -p /tmp/m02
cp /etc/hosts /tmp/m02/
cp /etc/hostname /tmp/m02/my-hostname
mkdir /tmp/m02/sub
cp /tmp/m02/my-hostname /tmp/m02/sub/
mv /tmp/m02/my-hostname /tmp/m02/renamed-hostname
ls -lh /tmp/m02/
ls -lh /tmp/m02/sub/
```

**Key points:**
- `cp src dst` — `src` is unchanged, `dst` is created
- `cp src dir/` — file lands inside the directory with its original name
- `mv old new` — the original path no longer exists after the move

---

## Exercise 2: Compare Files with diff

```bash
cp /etc/hosts /tmp/m02/hosts-v1
cp /etc/hosts /tmp/m02/hosts-v2
echo "# added line" >> /tmp/m02/hosts-v2
diff /tmp/m02/hosts-v1 /tmp/m02/hosts-v2
diff -u /tmp/m02/hosts-v1 /tmp/m02/hosts-v2
```

**Reading diff output:**
```
< old line    ← only in the first file (removed)
> new line    ← only in the second file (added)
```

In unified (`-u`) format:
```
--- hosts-v1
+++ hosts-v2
-removed line
+added line
 context line
```

---

## Exercise 3: Read Parts of a File

```bash
wc -l /etc/passwd
head -n 5 /etc/passwd
tail -n 3 /etc/passwd
less /etc/passwd
```

Inside `less`:
- `Space` — next page
- `b` — previous page
- `/root` — search for "root"
- `n` — next match
- `q` — quit

**Why not `cat`?** For files with hundreds of lines, `cat` floods the terminal. `less` lets you read at your own pace and search.

---

## Exercise 4: Edit a File in Vim

```bash
echo "line one" > /tmp/m02/vim-test.txt
echo "line two" >> /tmp/m02/vim-test.txt
vim /tmp/m02/vim-test.txt
```

Inside Vim:
1. Press `i` — you are now in Insert mode (bottom shows `-- INSERT --`)
2. Move to an empty line or press `o` to open a new line below
3. Type: `line three`
4. Press `Esc`
5. Type: `:wq` → Enter

```bash
cat /tmp/m02/vim-test.txt
# Output:
# line one
# line two
# line three
```

**Emergency exit:** If stuck, `Esc` then `:q!` always quits without saving.

---

## Exercise 5: Vim Movement and Deletion

```bash
cat > /tmp/m02/movement.txt << 'EOF'
the quick brown fox
delete this entire line
keep this line
delete just the word DELETE here: DELETE
EOF
vim /tmp/m02/movement.txt
```

Inside Vim:
| Key | Action |
|-----|--------|
| `j` | down one line |
| `k` | up one line |
| `h` / `l` | left / right |
| `w` | next word |
| `b` | previous word |
| `0` | line start |
| `$` | line end |
| `gg` | top of file |
| `G` | bottom of file |
| `dd` | delete current line |
| `dw` | delete word under cursor |
| `x` | delete one character |
| `u` | undo |

After deleting "delete this entire line" with `dd`, save: `:wq`

```bash
cat /tmp/m02/movement.txt
# Should show 3 lines
```

---

## Exercise 6: Vim Search and Replace

```bash
echo "the cat sat on the mat next to the vat" > /tmp/m02/replace.txt
vim /tmp/m02/replace.txt
```

Inside Vim:
1. `/the` → Enter — cursor jumps to first match
2. `n` — next match
3. `:%s/the/THE/g` → Enter — replaces all occurrences
4. `:wq` → Enter

```bash
cat /tmp/m02/replace.txt
# Output: THE cat sat on THE mat next to THE vat
grep -o "the" /tmp/m02/replace.txt | wc -l
# Output: 0
```

**Substitute syntax breakdown:**
```
:  %       s  / the / THE / g
   ^all    ^  ^src  ^dst  ^all matches per line
   lines   substitute
```

---

## Exercise 7: Shell Commands from Inside Vim

```bash
vim /tmp/m02/shell-in-vim.txt
```

Inside Vim:
1. `i` — Insert mode
2. Type: `REPLACE THIS WITH THE DATE`
3. `Esc` — Normal mode
4. `:.! date` → Enter — replaces current line with `date` output
5. `o` — open new line below, type `REPLACE WITH USERNAME`, `Esc`
6. `:.! whoami` → Enter
7. `:wq` → Enter

```bash
cat /tmp/m02/shell-in-vim.txt
# Output should contain the current date and your username
```

**`:.!` breakdown:**
- `.` = current line
- `!` = pipe through a shell command
- The line's content is replaced by the command's stdout

---

## Quick Reference: Vim Survival Cheat Sheet

| Situation | Keys |
|-----------|------|
| Stuck in Vim | `Esc` → `:q!` → Enter |
| Save and quit | `Esc` → `:wq` → Enter |
| Enter Insert mode | `i` |
| Open new line below | `o` |
| Delete a line | `dd` |
| Undo | `u` |
| Search | `/word` → `n` for next |
| Replace all | `:%s/old/new/g` |
| Run shell command | `:.! command` |
