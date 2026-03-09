# Exercises — Mission 15: Package Management

---

## Exercise 1: Searching for Packages

**Goal:** Find packages by name and description without installing anything.

**Steps:**
1. Search for packages related to "tree":
   ```bash
   apt search tree 2>/dev/null | head -20
   ```
2. Show detailed information about a package:
   ```bash
   apt show tree 2>/dev/null
   ```
3. Search with dpkg (already-installed packages):
   ```bash
   dpkg -l | grep -i tree
   ```
4. Check if a specific package is installed:
   ```bash
   dpkg -l jq 2>/dev/null | grep -E '^ii'
   dpkg-query -s jq 2>/dev/null | grep Status
   ```
5. List all installed packages (large output):
   ```bash
   dpkg -l | wc -l
   dpkg -l | grep '^ii' | wc -l
   ```

**Hint:** `apt search` searches both package names and descriptions. `dpkg -l` shows installed packages. The status `ii` means "installed and OK". `rc` means "removed but config remains".

**Self-check:** `dpkg -l | grep '^ii' | wc -l` shows the count of fully installed packages on your system.

---

## Exercise 2: Installing and Removing Packages

**Goal:** Install a package, verify it, and remove it cleanly.

**Steps:**
1. Update the package list first:
   ```bash
   sudo apt update
   ```
2. Install the `tree` package:
   ```bash
   sudo apt install -y tree
   ```
3. Verify installation:
   ```bash
   which tree
   tree --version
   dpkg -l tree | grep '^ii'
   ```
4. Use it briefly:
   ```bash
   tree /etc/apt 2>/dev/null | head -20
   ```
5. Remove the package (keep config files):
   ```bash
   sudo apt remove tree
   which tree 2>&1   # no longer found
   ```

**Hint:** `apt install -y` answers "yes" to all prompts automatically. `apt remove` removes the binary but keeps configuration files. `apt purge` removes both binary and config.

**Self-check:** After step 5, `which tree` prints nothing (or "not found"). `dpkg -l tree` should show `rc` (removed, config remaining) rather than `ii`.

---

## Exercise 3: Updating the System

**Goal:** Understand the update workflow.

**Steps:**
1. Fetch the current package index:
   ```bash
   sudo apt update
   ```
2. See what would be upgraded:
   ```bash
   apt list --upgradable 2>/dev/null
   ```
3. Count how many packages can be upgraded:
   ```bash
   apt list --upgradable 2>/dev/null | grep -c upgradable
   ```
4. Upgrade all packages (review changes before confirming):
   ```bash
   sudo apt upgrade
   ```
   (Review the list shown, then type `y` to confirm or `n` to cancel)

5. Understand the difference:
   - `apt update` — refresh the index (no changes to installed software)
   - `apt upgrade` — install available updates (no new packages, no removals)
   - `apt full-upgrade` — like upgrade, but also installs/removes packages if needed

**Hint:** Always run `apt update` before `apt upgrade`. Without it, `apt` uses a stale index and may not see the latest available versions.

**Self-check:** After `apt update`, the output shows the number of packages that can be upgraded.

---

## Exercise 4: Inspecting Installed Packages with dpkg

**Goal:** Query installed package details, file lists, and ownership.

**Steps:**
1. List all files installed by the `bash` package:
   ```bash
   dpkg -L bash | head -20
   ```
2. Count total files owned by bash:
   ```bash
   dpkg -L bash | wc -l
   ```
3. Find which package owns a specific file:
   ```bash
   dpkg -S /usr/bin/ls
   dpkg -S /etc/passwd
   ```
4. Show full info about an installed package:
   ```bash
   dpkg-query -s bash | head -20
   ```
5. List all installed packages sorted by size:
   ```bash
   dpkg-query -W --showformat='${Installed-Size}\t${Package}\n' | sort -n | tail -10
   ```

**Hint:** `dpkg -L package` lists files the package owns. `dpkg -S path` finds the package that owns a path. Both work on already-installed packages — they query the local dpkg database.

**Self-check:** `dpkg -S /usr/bin/ls` should return `coreutils: /usr/bin/ls` — the `ls` command belongs to the `coreutils` package.

---

## Exercise 5: Package Sources and Repositories

**Goal:** Understand where packages come from.

**Steps:**
1. View the main package sources list:
   ```bash
   cat /etc/apt/sources.list
   ```
2. Check for additional source files:
   ```bash
   ls /etc/apt/sources.list.d/
   ```
3. View one of them if present:
   ```bash
   ls /etc/apt/sources.list.d/*.list 2>/dev/null | head -1 | xargs cat 2>/dev/null || echo "no .list files"
   ls /etc/apt/sources.list.d/*.sources 2>/dev/null | head -1 | xargs cat 2>/dev/null || echo "no .sources files"
   ```
4. Understand a sources.list line:
   ```
   deb https://archive.ubuntu.com/ubuntu jammy main restricted
   │   │                                 │     │
   │   │                                 │     └── components (sections)
   │   │                                 └──────── codename (release)
   │   └────────────────────────────────────────── repository URL
   └────────────────────────────────────────────── package type (deb = binary)
   ```
5. Show what Ubuntu release you are on:
   ```bash
   cat /etc/os-release | grep -E '^(NAME|VERSION|VERSION_CODENAME)'
   ```

**Hint:** `main` = official free software, `universe` = community-maintained, `restricted` = proprietary drivers, `multiverse` = non-free software. Third-party software adds its own file to `/etc/apt/sources.list.d/`.

**Self-check:** `cat /etc/apt/sources.list` should contain at least one `deb` line pointing to an Ubuntu or Debian archive URL.

---

## Exercise 6: apt-cache — Offline Package Queries

**Goal:** Query the local package cache without a network connection.

**Steps:**
1. Show package information from cache:
   ```bash
   apt-cache show bash | head -20
   ```
2. Find what a package depends on:
   ```bash
   apt-cache depends bash
   ```
3. Find what packages depend on bash:
   ```bash
   apt-cache rdepends bash | head -15
   ```
4. Search in package names only (faster than `apt search`):
   ```bash
   apt-cache pkgnames | grep ^python | head -10
   ```
5. Show statistics about the package cache:
   ```bash
   apt-cache stats
   ```

**Hint:** `apt-cache` works entirely from the local database — no network needed. After `apt update`, the cache contains information about all packages in your configured repositories.

**Self-check:** `apt-cache stats` shows the total number of packages in the cache. This number should match roughly what you'd expect for your distribution.

---

## Exercise 7: Cleaning Up

**Goal:** Remove unused packages and clean the cache.

**Steps:**
1. Remove packages that were automatically installed as dependencies and are no longer needed:
   ```bash
   sudo apt autoremove
   ```
2. Show how much disk space the package cache uses:
   ```bash
   du -sh /var/cache/apt/archives/
   ```
3. Remove downloaded package files (free disk space):
   ```bash
   sudo apt clean
   du -sh /var/cache/apt/archives/
   ```
4. Remove only outdated cached packages (keeps current versions):
   ```bash
   sudo apt autoclean
   ```
5. Show orphaned config files from removed packages:
   ```bash
   dpkg -l | grep '^rc'
   ```
   To purge them all:
   ```bash
   dpkg -l | grep '^rc' | awk '{print $2}' | xargs sudo dpkg --purge 2>/dev/null || echo "nothing to purge"
   ```

**Hint:** `apt clean` removes all downloaded `.deb` files from the cache. The cache is in `/var/cache/apt/archives/`. Packages can always be re-downloaded, so it is safe to clean.

**Self-check:** After `apt clean`, `du -sh /var/cache/apt/archives/` should show a much smaller size.

---

Cleanup (no scratch files):
```bash
# Nothing to clean — all commands modified system state, not /tmp
```

Mark complete:
```bash
make done N=15
make next
```
