#!/bin/bash
# =============================================================================
#  Mission 07 — Users & Groups
# =============================================================================
set -uo pipefail
COURSE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"

init_mission "07" "Users & Groups" 10

# =============================================================================
step "UIDs and GIDs — identity by number"
set_hint "The kernel never uses names — it compares numbers.
Try: id   to see your UID, GID, and all supplementary groups."

explain "Linux identifies every user and group by a number, not a name.

  UID   User ID    — who you are
  GID   Group ID   — your primary group
  EUID  Effective UID — what the kernel checks for permissions

The name 'alice' in /etc/passwd is just a label.
The kernel compares UID numbers against file ownership numbers.

Reserved UID ranges (typical):
  0          root — the superuser
  1 – 999    system / service accounts (no login)
  1000+      regular human users"

demo 'id' \
     "Your full identity — UID, primary GID, and all supplementary groups:"

demo 'id root' \
     "root always has UID 0 and GID 0:"

try_match "Run id and confirm your UID is 1000 or higher" \
          "id" \
          "uid=[0-9]"

checkpoint \
  "Why does Linux use numbers for UIDs instead of names?" \
  "Names are only for humans. The kernel is faster and unambiguous with numbers.
A file stores the owning UID (a number) in its inode — not a string.
When you access a file, the kernel compares your EUID number to that stored
number. Names are translated at the edges (login, ls -l output) by reading
/etc/passwd — the kernel itself never touches strings."

# =============================================================================
step "whoami, id, and groups — three views of your identity"
set_hint "whoami: just the username.
id: full numeric detail.
groups: group names only, space-separated."

explain "Three commands, three levels of detail:

  whoami         print just your login name
  id             UID, primary GID, and every supplementary group
  groups         space-separated list of your group names

All three read from the kernel's credential tables for the current process —
they do not parse /etc/passwd themselves."

demo 'whoami' \
     "Your login name:"

demo 'id' \
     "Full credential breakdown:"

demo 'groups' \
     "Group names only:"

show 'id; groups' \
     "Comparing the two — same groups, different formats:"

try "Run all three commands on one line: whoami && id && groups" \
    "whoami && id && groups"

# =============================================================================
step "/etc/passwd — the user database"
set_hint "Seven colon-separated fields per line.
Format: username:x:UID:GID:GECOS:home:shell
The 'x' in field 2 means the hash lives in /etc/shadow."

explain "/etc/passwd has one line per account, with seven fields:

  username : password : UID : GID : GECOS : home : shell

  username   login name
  password   'x' — real hash is in /etc/shadow (only root can read it)
  UID        numeric user ID
  GID        numeric primary group ID
  GECOS      full name / comment (may be empty)
  home       home directory path
  shell      default login shell

Accounts using /sbin/nologin or /usr/sbin/nologin cannot start
an interactive session — they are service accounts."

demo 'cat /etc/passwd | head -5' \
     "First five lines of /etc/passwd:"

demo 'grep "^root:" /etc/passwd' \
     "The root account entry:"

demo "grep \"^$(whoami):\" /etc/passwd" \
     "Your own entry:"

try_match "Use grep to find your own entry in /etc/passwd" \
          "grep \"^$(whoami):\" /etc/passwd" \
          "$(whoami)"

# =============================================================================
step "Cutting fields from /etc/passwd"
set_hint "cut -d: -f1   extracts field 1 (username).
cut -d: -f7   extracts field 7 (shell).
Fields are numbered from 1."

explain "cut splits each line at a delimiter and picks fields.

  cut -d: -f1   first field (username)
  cut -d: -f3   third field (UID)
  cut -d: -f7   seventh field (login shell)
  cut -d: -f1,3 first and third fields

This is how you extract structured data from colon-delimited files
like /etc/passwd and /etc/group without writing a parser."

demo 'cut -d: -f1 /etc/passwd | head -10' \
     "Extract all usernames (field 1):"

demo 'cut -d: -f1,3 /etc/passwd | head -10' \
     "Username and UID side by side (fields 1 and 3):"

demo 'cut -d: -f7 /etc/passwd | sort | uniq -c | sort -rn' \
     "Which shells are used, and by how many accounts:"

try_match "Extract just the UID column (field 3) from /etc/passwd" \
          "cut -d: -f3 /etc/passwd | head -5" \
          "^[0-9]"

# =============================================================================
step "/etc/group — the group database"
set_hint "Four fields: groupname:x:GID:members
The members column lists supplementary members only —
a user's primary group is in /etc/passwd field 4."

explain "/etc/group has four colon-separated fields per line:

  groupname : password : GID : members

  groupname   group name
  password    'x' or empty — rarely used
  GID         numeric group ID
  members     comma-separated list of supplementary members

Important: a user's PRIMARY group is stored in /etc/passwd (field 4).
The members list in /etc/group only shows SUPPLEMENTARY group members.
So a user may not appear in their own primary group's member list."

demo 'cat /etc/group | head -10' \
     "First ten lines of /etc/group:"

demo "grep sudo /etc/group 2>/dev/null || grep wheel /etc/group 2>/dev/null || echo '(no sudo/wheel group found)'" \
     "Which users have sudo or wheel group membership:"

demo 'getent group | wc -l' \
     "Total number of groups on this system:"

try_match "Use grep to show your primary GID's group entry in /etc/group" \
          "getent group $(id -g)" \
          "$(id -gn)"

note "getent group queries the name service switch (NSS), which works with
local files, LDAP, and other directory services — unlike grepping /etc/group directly."

# =============================================================================
step "getent — portable user and group lookups"
set_hint "getent passwd username   to look up one user.
getent group groupname   to look up one group.
Works with LDAP / AD / NIS too, not just /etc files."

explain "getent queries the Name Service Switch (NSS) — the same layer
the system uses internally for all user/group lookups.

  getent passwd              dump all user entries
  getent passwd alice        look up user 'alice'
  getent group               dump all group entries
  getent group sudo          look up the 'sudo' group
  getent passwd 1000         look up by UID number

Unlike grepping /etc/passwd directly, getent also works when users
are stored in LDAP, Active Directory, or NIS — so it is the portable
and correct tool for any production environment."

demo "getent passwd $(whoami)" \
     "Look up your own account entry via NSS:"

demo 'getent passwd root' \
     "Look up root:"

demo "getent group $(id -gn)" \
     "Look up your primary group:"

show 'getent passwd | cut -d: -f1 | sort | head -10' \
     "All usernames from NSS, sorted:"

try "Use getent to look up your own account by username" \
    "getent passwd $(whoami)"

# =============================================================================
step "/etc/shadow — existence and purpose"
set_hint "Do not print /etc/shadow.
Its purpose is to hide password hashes from regular users.
Verify it exists and check its permissions with ls -la."

explain "/etc/shadow stores the actual password hashes and aging policy.

Format (nine colon-separated fields):
  username : hash : last-change : min : max : warn : inactive : expire : reserved

  hash           the algorithm + salt + hash (e.g. \$6\$ = SHA-512)
  last-change    days since epoch when password was last changed
  min/max        minimum and maximum days between changes
  warn           days before expiry to warn the user

The file is readable only by root — permissions are 640 or 000.
Regular users are deliberately locked out.

This separation from /etc/passwd was introduced because /etc/passwd
must be world-readable (programs need to resolve UIDs to names),
but password hashes must never be world-readable."

demo 'ls -la /etc/shadow' \
     "Permissions on /etc/shadow — notice root ownership and no world read:"

demo 'ls -la /etc/passwd /etc/shadow' \
     "Contrast: /etc/passwd is world-readable, /etc/shadow is not:"

warn "Never run: cat /etc/shadow
Never paste its contents anywhere.
Even a single hashed line can be cracked offline with tools like hashcat."

tip "To check password aging for your own account: chage -l \$(whoami)
Root can run: chage -l alice   for any account."

checkpoint \
  "Why is /etc/shadow separate from /etc/passwd?" \
  "/etc/passwd must be world-readable so that any program can translate
UIDs to names (e.g. ls -l, ps aux). If password hashes were stored there,
any user could copy the file and run an offline dictionary attack.
/etc/shadow is a separate file readable only by root, so hashes are
protected while name resolution still works for everyone."

# =============================================================================
step "su and sudo — switching identity"
set_hint "su needs the TARGET user's password.
sudo needs YOUR OWN password (and a sudoers entry granting permission).
sudo -l is always safe — it just lists what you can run."

explain "Two ways to act as another user:

  su alice           start a shell as alice (needs alice's password)
  su -               start a root LOGIN shell (needs root's password)
  su - alice         login shell as alice (loads alice's environment)

  sudo command       run one command as root (uses YOUR password)
  sudo -u alice cmd  run one command as alice
  sudo -i            open a root login shell (like 'su -' but uses sudo auth)
  sudo -l            list your own sudo privileges (safe, read-only)

Key difference:
  su    requires the TARGET user's password
  sudo  requires YOUR password + a sudoers entry

Most modern Ubuntu/Debian systems disable the root password and rely
entirely on sudo. On such systems, 'su -' will fail for regular users."

demo 'sudo -l' \
     "List your own sudo privileges (requires your password or cached session):"

tip "sudo caches your credentials for 15 minutes by default.
After that, it will prompt for your password again.
Run: sudo -k   to immediately clear the cached credential."

try "Run sudo -l to see what commands you are allowed to run" \
    "sudo -l"

# =============================================================================
step "User and group management — commands to know"
set_hint "These commands require root. We will only read about them here.
The key ones: useradd, usermod, userdel, groupadd, gpasswd."

explain "User management commands (all require sudo or root):

  useradd -m -s /bin/bash alice   create user, make home dir, set shell
  passwd alice                     set or change a user's password
  usermod -aG sudo alice           append alice to the sudo group
  usermod -s /bin/zsh alice        change alice's login shell
  userdel alice                    delete user (keep home dir)
  userdel -r alice                 delete user AND home directory

Group management:
  groupadd developers              create a new group
  gpasswd -a alice developers      add alice to developers
  gpasswd -d alice developers      remove alice from developers

IMPORTANT: After usermod -aG, the user must log out and back in.
The kernel reads group memberships at login — a running session keeps
its old credentials until a new login shell is started.

Safe pattern to verify a user was created:
  getent passwd alice
  id alice"

show 'getent passwd | cut -d: -f1,3,4,7 | sort -t: -k2 -n | head -15' \
     "All accounts sorted by UID — username, UID, GID, shell:"

demo 'getent passwd | awk -F: '"'"'$7 ~ /nologin|false/ {print $1}'"'"' | head -10' \
     "Service accounts that cannot log in interactively:"

try_match "Count the number of human accounts (UID >= 1000)" \
          "awk -F: '\$3 >= 1000 {print \$1}' /etc/passwd | wc -l" \
          "^[0-9]"

# =============================================================================
step "Putting it together — reading the full picture"
set_hint "Combine id, getent, and cut to answer real questions about users and groups."

explain "In real work you often need to answer questions like:
  - Is alice a member of the sudo group?
  - What is the primary group of the nginx service account?
  - Which accounts have /bin/bash as their shell?

These are all answerable by reading /etc/passwd and /etc/group."

demo "getent passwd | awk -F: '\$7 ~ /bash/ {print \$1, \"uid=\"\$3}'" \
     "All accounts using /bin/bash as their login shell:"

demo 'getent group sudo 2>/dev/null || getent group wheel 2>/dev/null || echo "(no sudo/wheel group)"' \
     "Show the sudo (or wheel) group and all its members:"

demo "id $(whoami)" \
     "Your complete identity — the authoritative summary:"

show 'getent passwd | cut -d: -f1,3 | awk -F: '"'"'{if ($2+0 >= 1000) print $0}'"'"'' \
     "Human accounts (UID >= 1000) — name and UID:"

try_match "Show all users in the sudo or wheel group using getent group" \
          "getent group sudo 2>/dev/null || getent group wheel 2>/dev/null" \
          ":"

checkpoint \
  "You add alice to the developers group with: sudo usermod -aG developers alice
Alice is already logged in. Is she immediately a member of developers?" \
  "No. The kernel loads group memberships at login time into the process's
credential set. A running session keeps its original groups.
Alice must log out and log back in (or open a new login shell with 'su - alice')
for the new membership to appear in her session.
She can verify with: id   after a fresh login.
The entry in /etc/group is updated immediately — only the running session lags."

mission_complete
