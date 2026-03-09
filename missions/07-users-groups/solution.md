# Solution — Mission 07: Users & Groups

---

## Exercise 1: Inspect Your Identity

```bash
whoami
id
groups
id root
```

**Key differences:**
| Command | Shows |
|---------|-------|
| `whoami` | Username only |
| `id` | UID, GID, all supplementary GIDs with names |
| `groups` | Supplementary group names only (no numbers) |

`id` shows numeric UIDs and GIDs alongside names. `groups` shows only names. `id root` shows UID=0, GID=0.

---

## Exercise 2: Decode /etc/passwd

```bash
head -5 /etc/passwd
grep "^$(whoami):" /etc/passwd
grep "^root:" /etc/passwd
grep 'nologin\|false' /etc/passwd | cut -d: -f1,7
```

**Seven-field structure:**
```
username : x : UID : GID : GECOS : /home/dir : /bin/shell
```

Field 2 is always `x` — the actual password hash is in `/etc/shadow`.
Accounts with `/usr/sbin/nologin` or `/bin/false` as their shell cannot log in interactively.

---

## Exercise 3: Extracting Fields with cut

```bash
cut -d: -f1 /etc/passwd
cut -d: -f3 /etc/passwd | sort -n | head -10
cut -d: -f1,7 /etc/passwd | head -10
cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn
awk -F: '$3 >= 1000 {print $1, $3}' /etc/passwd
```

**Flag reference:**
- `-d:` — use `:` as the delimiter
- `-f1,7` — print fields 1 and 7 (comma-separated field list)
- `awk -F:` — set the awk field separator to `:`
- `$3 >= 1000` — filter rows where field 3 is at least 1000

---

## Exercise 4: Reading /etc/group

```bash
head -10 /etc/group
getent group $(id -gn)
getent group $(id -g)
getent group sudo 2>/dev/null || getent group wheel 2>/dev/null
getent group | wc -l
```

**Four-field structure of /etc/group:**
```
group_name : x : GID : member1,member2,...
```

Field 4 lists supplementary members. Primary members are not listed here — they appear in `/etc/passwd` field 4 (GID).

---

## Exercise 5: getent — Portable Lookups

```bash
getent passwd $(whoami)
getent passwd root
getent passwd 0
getent group $(id -gn)
grep "^$(whoami):" /etc/passwd
```

**Why getent:**
`getent` queries NSS (Name Service Switch) — it works transparently on systems using LDAP, Active Directory, or other directory services in addition to local files. `grep /etc/passwd` only sees local files.

On a system using only local files, both methods return identical output.

---

## Exercise 6: /etc/shadow — Observe Without Reading

```bash
ls -la /etc/shadow
ls -la /etc/passwd /etc/shadow
cat /etc/shadow         # Permission denied (expected)
chage -l $(whoami)
```

**Permission comparison:**
| File | Permissions | Readable by |
|------|-------------|-------------|
| `/etc/passwd` | `644` | Everyone |
| `/etc/shadow` | `640` or `000` | root only |

`cat /etc/shadow` must print `Permission denied`. `chage -l` shows password aging info safely without requiring root.

---

## Exercise 7: sudo -l — Read Your Privileges

```bash
sudo -l
ls -la /etc/sudoers.d/ 2>/dev/null
sudo -k
```

**Reading sudo -l output:**
- `(ALL : ALL) ALL` — can run any command as any user
- `NOPASSWD:` — no password prompt for those commands
- A specific list — restricted sudo access

`sudo -k` clears the cached sudo credential without running anything. Safe to run anytime.

---

## Exercise 8: User Management Commands — Read and Recognise

```bash
# A — Create user with home dir, bash shell, and comment
useradd -m -s /bin/bash -c "Test User" testuser

# B — Append alice to the docker group (CRITICAL: -a flag)
usermod -aG docker alice

# C — Change bob's login shell to zsh
usermod -s /bin/zsh bob

# D — Delete testuser and remove home directory and mail spool
userdel -r testuser

# E — Create group 'devops' with GID 2001
groupadd -g 2001 devops

# F — Add carol to the devops group
gpasswd -a carol devops
```

**The -aG rule:**
```
usermod -aG groupname user    # SAFE: appends to existing groups
usermod -G  groupname user    # DANGEROUS: replaces all supplementary groups
```

---

## Exercise 9: Real-world Queries

```bash
# 1. How many human accounts (UID >= 1000)?
awk -F: '$3 >= 1000' /etc/passwd | wc -l

# 2. Account with the highest UID?
awk -F: '{print $3, $1}' /etc/passwd | sort -n | tail -1

# 3. Are you in the sudo group?
groups | grep -q sudo && echo "yes" || echo "no"

# 4. Login shell of the nobody account?
getent passwd nobody | cut -d: -f7

# 5. How many groups does your account belong to?
id | grep -o 'groups=.*' | tr ',' '\n' | wc -l
```

---

## Quick Reference

```bash
whoami              print your username
id                  print UID, GID, and all supplementary groups
id user             print identity for another user
groups              print group names only
getent passwd name  look up a user account via NSS
getent group name   look up a group via NSS
cut -d: -f1,3       extract fields 1 and 3 (colon delimiter)
awk -F: '$3>=1000'  filter rows where field 3 >= 1000
sudo -l             list your sudo privileges (read-only)
sudo -k             invalidate cached sudo credential
chage -l user       show password aging info
```
