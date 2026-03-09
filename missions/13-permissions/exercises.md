# Exercises — Mission 13: Ownership & Permissions

---

## Exercise 1: Decoding Permission Strings

**Goal:** Read and interpret a `ls -l` permission string without any tools.

**Steps:**
1. List several files with full details:
   ```bash
   ls -l /etc/hostname /usr/bin/ls /usr/bin/passwd /tmp
   ```
2. For each line, decode the ten-character permission string into:
   - File type (character 1)
   - User/owner bits (characters 2-4)
   - Group bits (characters 5-7)
   - Other bits (characters 8-10)
3. Identify which has setuid set:
   ```bash
   ls -l /usr/bin/passwd
   ```
   (Look for `s` in the user execute position)
4. Identify the sticky bit on /tmp:
   ```bash
   ls -ld /tmp
   ```
   (Look for `t` in the other execute position)
5. Find all setuid files in /usr/bin:
   ```bash
   find /usr/bin -perm -4000 -ls 2>/dev/null
   ```

**Hint:** The ten characters are: `[type][user-rwx][group-rwx][other-rwx]`. `s` replaces `x` when a special bit is set AND execute is set. `S` or `T` (uppercase) means the special bit is set but execute is not — usually a misconfiguration.

**Self-check:** `/usr/bin/passwd` should show `-rwsr-xr-x` — setuid set (the `s`), executable by all.

---

## Exercise 2: Octal Notation — Decoding

**Goal:** Convert between symbolic and octal permission notation.

**Steps:**
1. Read the octal value of several files:
   ```bash
   stat -c '%a %n' /etc/hostname /usr/bin/ls /usr/bin/passwd ~/.bashrc 2>/dev/null
   ```
2. Decode each octal value manually using: `r=4, w=2, x=1`
   - `644` = `110 100 100` = `rw-r--r--`
   - `755` = `111 101 101` = `rwxr-xr-x`
   - `600` = `110 000 000` = `rw-------`
3. Match these common patterns:

   | Octal | Symbolic | Typical use |
   |-------|----------|-------------|
   | `644` | `-rw-r--r--` | Regular files |
   | `755` | `-rwxr-xr-x` | Executables, public directories |
   | `600` | `-rw-------` | Private files (SSH keys) |
   | `700` | `-rwx------` | Private directories |
   | `664` | `-rw-rw-r--` | Group-shared files |

4. What is the octal for: `rwxr-x---`?
   ```
   u=rwx=7, g=r-x=5, o=---=0  ->  750
   ```
5. What symbolic string is: `640`?
   ```
   6=rw-, 4=r--, 0=---  ->  rw-r-----
   ```

**Hint:** Each digit is the sum of enabled bits: r=4, w=2, x=1. Work through each class (user, group, other) independently.

**Self-check:** `stat -c '%a' /usr/bin/ls` should return `755`.

---

## Exercise 3: chmod — Changing Permissions

**Goal:** Use both symbolic and numeric chmod modes.

**Setup:**
```bash
mkdir -p /tmp/m13
echo "content" > /tmp/m13/file.txt
cp /tmp/m13/file.txt /tmp/m13/script.sh
```

**Steps:**
1. Add execute for the owner:
   ```bash
   chmod u+x /tmp/m13/script.sh
   ls -l /tmp/m13/script.sh
   ```
2. Remove write from group and other:
   ```bash
   chmod go-w /tmp/m13/file.txt
   ls -l /tmp/m13/file.txt
   ```
3. Set permissions using numeric mode:
   ```bash
   chmod 644 /tmp/m13/file.txt
   chmod 755 /tmp/m13/script.sh
   ls -l /tmp/m13/
   ```
4. Set permissions precisely with `=`:
   ```bash
   chmod u=rw,go=r /tmp/m13/file.txt
   ls -l /tmp/m13/file.txt
   ```
5. Remove all permissions from others:
   ```bash
   chmod o= /tmp/m13/file.txt
   ls -l /tmp/m13/file.txt
   stat -c '%a' /tmp/m13/file.txt
   ```

**Hint:** Symbolic mode syntax: `WHO OPERATOR PERMISSION` where WHO = `u`/`g`/`o`/`a`, OPERATOR = `+`/`-`/`=`, PERMISSION = `r`/`w`/`x`. Use `=` to set exactly (it clears bits not listed).

**Self-check:** After step 5, `stat -c '%a' /tmp/m13/file.txt` should print `640` (rw-r-----).

---

## Exercise 4: chmod -R — Recursive Permissions

**Goal:** Apply permissions recursively and understand why blanket recursion is dangerous.

**Setup:**
```bash
mkdir -p /tmp/m13/project/{src,docs}
touch /tmp/m13/project/src/main.sh /tmp/m13/project/docs/README.md
```

**Steps:**
1. Wrong approach — sets execute on files (dangerous):
   ```bash
   chmod -R 755 /tmp/m13/project/
   find /tmp/m13/project -type f -ls
   ```
   (Every file is now executable — that is usually wrong for data files)

2. Correct approach — separate rules for files and directories:
   ```bash
   find /tmp/m13/project -type d -exec chmod 755 {} +
   find /tmp/m13/project -type f -exec chmod 644 {} +
   find /tmp/m13/project -ls
   ```

3. Make only `.sh` files executable:
   ```bash
   find /tmp/m13/project -name "*.sh" -exec chmod 755 {} +
   find /tmp/m13/project -type f -ls
   ```

4. Verify the final state:
   ```bash
   stat -c '%a %n' /tmp/m13/project/src/main.sh /tmp/m13/project/docs/README.md
   ```

**Hint:** `chmod -R 755 dir/` makes every file executable — fine for directories, wrong for plain data files. Always use `find -type f` and `find -type d` separately when applying recursive permissions.

**Self-check:** After step 3, `main.sh` should be `755` (executable) and `README.md` should be `644` (not executable).

---

## Exercise 5: umask — Default Permissions

**Goal:** Understand and temporarily change the umask.

**Steps:**
1. Show the current umask:
   ```bash
   umask
   umask -S
   ```
2. Create a file and directory with the current umask and observe defaults:
   ```bash
   touch /tmp/m13/default-file.txt
   mkdir /tmp/m13/default-dir
   ls -l /tmp/m13/default-file.txt
   ls -ld /tmp/m13/default-dir
   stat -c '%a %n' /tmp/m13/default-file.txt /tmp/m13/default-dir
   ```
3. Temporarily change umask to `077` (private):
   ```bash
   umask 077
   touch /tmp/m13/private-file.txt
   mkdir /tmp/m13/private-dir
   stat -c '%a %n' /tmp/m13/private-file.txt /tmp/m13/private-dir
   ```
4. Restore the default umask:
   ```bash
   umask 022
   ```
5. Understand the calculation:
   - Files start at `666`; directories at `777`
   - umask `022` removes write from group and other
   - `666 - 022 = 644`; `777 - 022 = 755`

**Hint:** The umask is shell-local. Setting it in a subshell does not affect the parent shell. It is typically set in `~/.bashrc` or `/etc/profile`.

**Self-check:** With umask `077`, new files get `600` and new directories get `700`.

---

## Exercise 6: Special Bits — setuid, setgid, sticky

**Goal:** Observe the three special permission bits in their real-world usage.

**Steps:**
1. Confirm setuid on /usr/bin/passwd:
   ```bash
   ls -l /usr/bin/passwd
   stat -c '%a %n' /usr/bin/passwd
   ```
   (Octal should be `4755` — the leading `4` is the setuid bit)

2. Find setgid directories (group-inherited ownership):
   ```bash
   find /var /run -type d -perm -2000 2>/dev/null | head -5
   ```

3. Confirm the sticky bit on /tmp:
   ```bash
   ls -ld /tmp
   stat -c '%a' /tmp
   ```
   (Octal should be `1777` — the leading `1` is the sticky bit)

4. Show a setuid-set file's stat:
   ```bash
   stat /usr/bin/passwd | grep Access
   ```

5. Interpret these octal values:
   - `4755` = setuid + `rwxr-xr-x` (e.g., `/usr/bin/passwd`)
   - `2775` = setgid + `rwxrwxr-x` (e.g., shared group directory)
   - `1777` = sticky + `rwxrwxrwx` (e.g., `/tmp`)

**Hint:** The special bits occupy a fourth leading octal digit: setuid=4, setgid=2, sticky=1. A lowercase letter (`s`, `t`) means the special bit AND execute are both set. Uppercase (`S`, `T`) means special bit set but execute is NOT set — almost always unintentional.

**Self-check:** `stat -c '%a' /usr/bin/passwd` should print `4755`.

---

## Exercise 7: chown — Changing Ownership

**Goal:** Change file owner and group (demonstrates concept; requires sudo for most changes).

**Steps:**
1. Check your current file's ownership:
   ```bash
   ls -l /tmp/m13/file.txt
   stat -c '%U %G %n' /tmp/m13/file.txt
   ```
2. Change the group to your primary group (no sudo needed for own files):
   ```bash
   chown :$(id -gn) /tmp/m13/file.txt
   ls -l /tmp/m13/file.txt
   ```
3. Understand the syntax:
   ```bash
   # chown owner:group file
   # chown owner file         (owner only)
   # chown :group file        (group only, same as chgrp)
   # chown -R owner:group dir/ (recursive)
   ```
4. Observe that you cannot chown to a different user without sudo:
   ```bash
   chown root /tmp/m13/file.txt 2>&1
   ```
   (Should print: `Operation not permitted`)
5. View a real chown use case:
   ```bash
   ls -la /var/www/html 2>/dev/null || echo "Apache web root not installed"
   # The web server runs as www-data; files should be owned by www-data:www-data
   ```

**Hint:** Regular users can only `chown` files they own, and only to themselves. Only root can transfer ownership to another user. You can change the group to any group you belong to.

**Self-check:** Step 4 should print an error. Only step 2 (changing group to your own group) should succeed.

---

## Exercise 8: Real-world Permission Scenarios

**Goal:** Apply permission knowledge to practical scenarios.

**Steps:**
1. Create a private SSH-style key file (correct permissions):
   ```bash
   echo "-----BEGIN PRIVATE KEY-----" > /tmp/m13/id_rsa_fake
   chmod 600 /tmp/m13/id_rsa_fake
   stat -c '%a %n' /tmp/m13/id_rsa_fake
   ```
2. Create a shared directory where all group members can write:
   ```bash
   mkdir -p /tmp/m13/shared
   chmod 775 /tmp/m13/shared
   ls -ld /tmp/m13/shared
   ```
3. Create a shared directory where only owners can delete their files (sticky):
   ```bash
   mkdir -p /tmp/m13/shared-sticky
   chmod 1777 /tmp/m13/shared-sticky
   ls -ld /tmp/m13/shared-sticky
   ```
4. Make a script executable by owner only:
   ```bash
   chmod 700 /tmp/m13/script.sh
   ls -l /tmp/m13/script.sh
   ```
5. Audit: find files with too-open permissions in your home:
   ```bash
   find ~ -type f -perm /o+w 2>/dev/null | head -10
   ```

**Hint:** For SSH keys, permissions MUST be `600` or `700` — SSH refuses to use keys that are too open. For web server files, typically `644` for files and `755` for directories, owned by `www-data`.

**Self-check:** Step 5 — ideally shows nothing. If files appear, they are world-writable, which is usually unintentional.

---

Cleanup:
```bash
rm -rf /tmp/m13
umask 022   # restore if changed
```

Mark complete:
```bash
make done N=13
make next
```
