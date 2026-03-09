# Exercises — Mission 07: Users & Groups

---

## Exercise 1: Inspect Your Identity

**Goal:** Use the three identity commands and understand what each shows.

**Steps:**
1. Print just your username: `whoami`
2. Print your full identity: `id`
3. Print only group names: `groups`
4. Look up root's identity: `id root`
5. Compare the three outputs — what does `id` show that `groups` does not?

**Hint:** `id` shows numeric UIDs and GIDs alongside names. `groups` shows only names.

**Self-check:** Your UID should be 1000 or higher. Root's UID is always 0.

---

## Exercise 2: Decode /etc/passwd

**Goal:** Read and understand the seven-field structure of `/etc/passwd`.

**Steps:**
1. Look at the first five lines: `head -5 /etc/passwd`
2. Find your own entry: `grep "^$(whoami):" /etc/passwd`
3. Find the root entry: `grep "^root:" /etc/passwd`
4. Find all accounts that cannot log in:
   ```bash
   grep 'nologin\|false' /etc/passwd | cut -d: -f1,7
   ```
5. Label each field in your own entry by hand. Use this template:
   ```
   username : password : UID : GID : GECOS : home : shell
   ```

**Hint:** Field 2 is always `x` on modern systems — the real hash is in `/etc/shadow`.

**Self-check:** Your entry's shell field (field 7) should be `/bin/bash` or `/bin/zsh`.

---

## Exercise 3: Extracting Fields with cut

**Goal:** Use `cut` to pull specific columns from `/etc/passwd`.

**Steps:**
1. Extract all usernames: `cut -d: -f1 /etc/passwd`
2. Extract all UIDs: `cut -d: -f3 /etc/passwd | sort -n | head -10`
3. Extract username and shell: `cut -d: -f1,7 /etc/passwd | head -10`
4. Count unique shells in use:
   ```bash
   cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn
   ```
5. Find accounts with UIDs in the human range (1000+):
   ```bash
   awk -F: '$3 >= 1000 {print $1, $3}' /etc/passwd
   ```

**Hint:** Fields are numbered from 1. `-d:` sets the delimiter to colon.

**Self-check:** Step 4 should show `/bin/bash` (or `/bin/zsh`) as the most common shell for human accounts. Step 5 should show your own username.

---

## Exercise 4: Reading /etc/group

**Goal:** Understand group membership by reading `/etc/group`.

**Steps:**
1. Look at the first ten lines: `head -10 /etc/group`
2. Find your primary group: `getent group $(id -gn)`
3. Find your primary group by GID number: `getent group $(id -g)`
4. Look for the sudo or wheel group:
   ```bash
   getent group sudo 2>/dev/null || getent group wheel 2>/dev/null
   ```
5. Count total groups: `getent group | wc -l`

**Hint:** Field 4 (members) is empty for a group's primary members — those are tracked in `/etc/passwd` field 4, not here.

**Self-check:** The sudo or wheel group's member list should contain your username if you have sudo access.

---

## Exercise 5: getent — Portable Lookups

**Goal:** Use `getent` instead of grepping files directly.

**Steps:**
1. Look up your own account: `getent passwd $(whoami)`
2. Look up root: `getent passwd root`
3. Look up by UID number: `getent passwd 0` (should return the root entry)
4. Look up your primary group: `getent group $(id -gn)`
5. Compare: `grep "^$(whoami):" /etc/passwd` vs `getent passwd $(whoami)`

**Hint:** `getent` queries NSS — it works on systems that use LDAP or Active Directory in addition to local files. It is the production-safe way to look up users.

**Self-check:** Steps 1 and 5 should produce identical output (on a system using only local files).

---

## Exercise 6: /etc/shadow — Observe Without Reading

**Goal:** Understand /etc/shadow's purpose by inspecting its permissions only.

**Steps:**
1. Check the permissions:
   ```bash
   ls -la /etc/shadow
   ```
2. Compare with /etc/passwd:
   ```bash
   ls -la /etc/passwd /etc/shadow
   ```
3. Try to read it as a regular user (expect a permission denied error):
   ```bash
   cat /etc/shadow
   ```
4. Check your own password aging info (safe to run):
   ```bash
   chage -l $(whoami)
   ```

**Hint:** `/etc/passwd` is world-readable (permissions `644`). `/etc/shadow` is readable only by root (`640` or `000`). This protects the hashes from offline cracking.

**Self-check:** Step 3 should print `Permission denied`. Step 4 should show password aging details for your account.

---

## Exercise 7: sudo -l — Read Your Privileges

**Goal:** Check what sudo allows you to do without actually running anything privileged.

**Steps:**
1. List your sudo privileges:
   ```bash
   sudo -l
   ```
2. Read the output:
   - `(ALL : ALL) ALL` means you can run any command as any user
   - `NOPASSWD:` means no password prompt is required for those commands
   - A list of specific commands means you have restricted sudo

3. Check the sudoers drop-in directory (read-only):
   ```bash
   ls -la /etc/sudoers.d/ 2>/dev/null
   ```

4. Immediately clear your cached sudo credential:
   ```bash
   sudo -k
   ```

**Hint:** `sudo -l` is completely safe — it reads configuration, it does not execute anything.

**Self-check:** If `sudo -l` shows `(ALL : ALL) ALL`, you have unrestricted sudo on this machine.

---

## Exercise 8: User Management Commands — Read and Recognise

**Goal:** Understand the flag patterns for useradd, usermod, userdel without running them.

For each command below, identify what it does. Write your answer before reading the explanation.

**Commands to decode:**

```bash
# A
useradd -m -s /bin/bash -c "Test User" testuser

# B
usermod -aG docker alice

# C
usermod -s /bin/zsh bob

# D
userdel -r testuser

# E
groupadd -g 2001 devops

# F
gpasswd -a carol devops
```

**Explanations:**

- A: Create `testuser` with a home directory (`-m`), bash shell (`-s /bin/bash`), and a comment
- B: Append (`-a`) alice to the `docker` group (`-G docker`) — `-a` is critical; without it, alice would be removed from all other groups
- C: Change bob's login shell to zsh
- D: Delete `testuser` and remove their home directory and mail spool (`-r`)
- E: Create the group `devops` with a specific GID of 2001
- F: Add carol to the devops group

**Critical:** `usermod -G groupname` WITHOUT `-a` **replaces** the user's supplementary groups entirely. Always use `-aG` to append.

---

## Exercise 9: Real-world Queries

**Goal:** Answer practical questions using the commands from this mission.

**Questions — answer each with a single command or short pipeline:**

1. How many human accounts (UID >= 1000) exist on this system?
   ```bash
   awk -F: '$3 >= 1000' /etc/passwd | wc -l
   ```

2. Which account has the highest UID?
   ```bash
   awk -F: '{print $3, $1}' /etc/passwd | sort -n | tail -1
   ```

3. Are you in the sudo group?
   ```bash
   groups | grep -q sudo && echo "yes" || echo "no"
   ```

4. What is the login shell of the nobody account?
   ```bash
   getent passwd nobody | cut -d: -f7
   ```

5. How many groups does your account belong to?
   ```bash
   id | grep -o 'groups=.*' | tr ',' '\n' | wc -l
   ```

**Self-check:** For question 3, the answer should match what `sudo -l` shows you.

---

Cleanup (no scratch files used this mission):
```bash
# Nothing to clean up — all commands were read-only
```

Mark complete:
```bash
make done N=07
make next
```
