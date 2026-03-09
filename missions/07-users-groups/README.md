# Mission 07 — Users & Groups

## Learning Goals

- Understand UIDs and GIDs — what they are and why the kernel uses numbers, not names
- Read and decode the seven fields of `/etc/passwd`
- Read `/etc/group` to see group membership
- Use `id`, `whoami`, and `groups` to inspect your own identity
- Understand the difference between `su` and `sudo`, and when to use each
- Check your own sudo privileges safely with `sudo -l`
- Know what `useradd`, `usermod`, `userdel`, `groupadd`, and `gpasswd` do (conceptually)
- Understand `/etc/shadow` — what it stores and why it is protected

---

## UIDs and GIDs

Linux identifies users and groups by **numbers**, not names.

| Term | Meaning |
|------|---------|
| UID | User ID — a number that identifies a user account |
| GID | Group ID — a number that identifies a group |
| EUID | Effective UID — the identity the kernel uses for permission checks |

The kernel never stores or compares names in permission checks. The name (`alice`) is only a human-readable label stored in `/etc/passwd`. The kernel compares UID numbers against file ownership numbers.

**Reserved UID ranges (typical Linux):**

| Range | Purpose |
|-------|---------|
| 0 | root — the superuser |
| 1 – 999 | system / service accounts (no real login) |
| 1000+ | regular human users |

---

## /etc/passwd — User Database

Each line is one account. Seven colon-separated fields:

```
username:password:UID:GID:GECOS:home:shell
```

| Field | Example | Meaning |
|-------|---------|---------|
| username | `alice` | Login name |
| password | `x` | `x` means the real hash is in `/etc/shadow` |
| UID | `1001` | Numeric user ID |
| GID | `1001` | Primary group ID |
| GECOS | `Alice Example` | Full name / comment (often empty) |
| home | `/home/alice` | Home directory path |
| shell | `/bin/bash` | Default login shell |

The `x` in the password field does not mean "no password" — it means the password hash has been moved to `/etc/shadow`, which only root can read.

Accounts with `/sbin/nologin` or `/usr/sbin/nologin` as their shell are service accounts that cannot start an interactive session.

---

## /etc/group — Group Database

Each line is one group. Four colon-separated fields:

```
groupname:password:GID:members
```

| Field | Example | Meaning |
|-------|---------|---------|
| groupname | `developers` | Group name |
| password | `x` | Rarely used; `x` or empty |
| GID | `1002` | Numeric group ID |
| members | `alice,bob` | Comma-separated list of supplementary members |

A user's **primary group** is recorded in `/etc/passwd` field 4, not in `/etc/group`. The group file lists only **supplementary** memberships.

---

## Inspecting Your Identity

```bash
whoami            # print your username
id                # print UID, primary GID, and all supplementary groups
id alice          # inspect another user
groups            # list just your group names
groups alice      # another user's groups
```

`id` output looks like:
```
uid=1000(alice) gid=1000(alice) groups=1000(alice),4(adm),27(sudo),1001(developers)
```

---

## /etc/shadow — Password Hashes

`/etc/shadow` stores the hashed passwords and password-aging policy.

```
username:hashed-password:last-change:min:max:warn:inactive:expire:reserved
```

It is readable only by root (permissions `640` or `000` depending on distro). Regular users cannot read it — that is the whole point. The hash itself uses algorithms like SHA-512 (prefix `$6$`).

**Never print `/etc/shadow` during practice sessions or paste it anywhere.**

---

## su vs sudo

| Tool | What it does |
|------|-------------|
| `su` | Substitutes user — starts a new shell as a different user (requires that user's password) |
| `su -` | Same but also loads the target user's full environment (login shell) |
| `sudo cmd` | Runs a single command as root (or another user), using YOUR password |
| `sudo -i` | Opens a root login shell (similar to `su -` for root) |
| `sudo -l` | Lists what commands you are allowed to run via sudo (safe, read-only) |

**Key difference:** `su` needs the *target user's* password. `sudo` needs *your own* password and requires a sudoers entry granting you permission.

---

## sudoers — Who Gets sudo Access

The sudoers configuration lives in `/etc/sudoers` and the drop-in directory `/etc/sudoers.d/`.

**Never edit `/etc/sudoers` with a regular editor.** Always use `visudo`, which validates the file before saving. A syntax error in sudoers can lock you out of root access entirely.

To check your own privileges safely:
```bash
sudo -l
```

This shows exactly which commands you can run, as which users, and whether a password is required.

---

## Managing Users and Groups

These commands require root/sudo. They are conceptual here — do not run them in practice unless you have a dedicated test system.

```bash
# Create a user
useradd -m -s /bin/bash alice     # -m creates home dir, -s sets shell

# Set or change a password
passwd alice

# Modify an existing user
usermod -aG sudo alice            # -aG appends to supplementary groups
usermod -s /bin/zsh alice         # change login shell
usermod -l newname alice          # rename the account

# Delete a user
userdel alice                     # keep home directory
userdel -r alice                  # also remove home directory

# Create a group
groupadd developers

# Add a user to a group
gpasswd -a alice developers       # add alice to developers
gpasswd -d alice developers       # remove alice from developers
```

After `usermod -aG`, the user must **log out and back in** for the new group membership to take effect in their shell session.

---

## getent — Query the Name Service

`getent` queries the name service switch (NSS), which unifies local files, LDAP, and other sources:

```bash
getent passwd alice        # same as grep in /etc/passwd but works with LDAP too
getent group developers    # look up a group
getent passwd              # dump the entire user database
```

---

## Key Commands This Mission

| Command | Purpose |
|---------|---------|
| `whoami` | Print your username |
| `id` | Print UID, GID, all groups |
| `groups` | Print group names |
| `getent passwd` | Look up user entries |
| `getent group` | Look up group entries |
| `sudo -l` | List your sudo privileges |
| `cut -d: -f1 /etc/passwd` | Extract all usernames |
| `cat /etc/group` | View group database |

---

## What's Next

Mission 08 covers File Management — copying, moving, linking, and the differences between hard links and symlinks.

```bash
make practice N=07
```
