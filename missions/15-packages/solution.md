# Solution — Mission 15: Package Management

---

## Exercise 1: Searching for Packages

```bash
apt search tree 2>/dev/null | head -20
apt show tree 2>/dev/null
dpkg -l | grep -i tree
dpkg -l jq 2>/dev/null | grep -E '^ii'
dpkg-query -s jq 2>/dev/null | grep Status
dpkg -l | wc -l
dpkg -l | grep '^ii' | wc -l
```

**dpkg -l status codes:**
| Code | Meaning |
|------|---------|
| `ii` | Installed and OK |
| `rc` | Removed but config files remain |
| `un` | Unknown / not installed |
| `iU` | Installed but unpacked (upgrade in progress) |

First character = desired state, second = current state.

---

## Exercise 2: Installing and Removing Packages

```bash
sudo apt update
sudo apt install -y tree
which tree
tree --version
dpkg -l tree | grep '^ii'
tree /etc/apt 2>/dev/null | head -20
sudo apt remove tree
which tree 2>&1
```

**install vs remove vs purge:**
| Command | Binary | Config files |
|---------|--------|-------------|
| `apt install pkg` | Installed | — |
| `apt remove pkg` | Removed | Kept |
| `apt purge pkg` | Removed | Removed |

After `apt remove`, `dpkg -l pkg` shows `rc` (removed, config). After `apt purge`, the package disappears from `dpkg -l`.

---

## Exercise 3: Updating the System

```bash
sudo apt update
apt list --upgradable 2>/dev/null
apt list --upgradable 2>/dev/null | grep -c upgradable
sudo apt upgrade
```

**The three-command update workflow:**
```bash
sudo apt update          # 1. Fetch fresh package index from repositories
apt list --upgradable    # 2. Review what will change
sudo apt upgrade         # 3. Apply updates
```

**upgrade vs full-upgrade:**
| Command | New packages | Removals | Notes |
|---------|-------------|---------|-------|
| `apt upgrade` | No | No | Safest — updates in place |
| `apt full-upgrade` | Yes | Yes | Allows dependency resolution with adds/removes |
| `apt dist-upgrade` | Yes | Yes | Older alias for full-upgrade |

---

## Exercise 4: Inspecting Installed Packages with dpkg

```bash
dpkg -L bash | head -20
dpkg -L bash | wc -l
dpkg -S /usr/bin/ls
dpkg -S /etc/passwd
dpkg-query -s bash | head -20
dpkg-query -W --showformat='${Installed-Size}\t${Package}\n' | sort -n | tail -10
```

**dpkg query flags:**
| Flag | Purpose |
|------|---------|
| `dpkg -l [pkg]` | List package status |
| `dpkg -L pkg` | List files owned by installed package |
| `dpkg -S path` | Find which package owns a path |
| `dpkg-query -s pkg` | Show detailed status of installed package |
| `dpkg-query -W --showformat` | Custom format output |

`dpkg -S /etc/passwd` typically returns `passwd: /etc/passwd` — the `passwd` package (not the command) owns the file.

---

## Exercise 5: Package Sources and Repositories

```bash
cat /etc/apt/sources.list
ls /etc/apt/sources.list.d/
cat /etc/os-release | grep -E '^(NAME|VERSION|VERSION_CODENAME)'
```

**sources.list format:**
```
deb https://archive.ubuntu.com/ubuntu jammy main restricted universe multiverse
│   │                                 │     └────────────── components
│   └───────────────────────────────── repository URL
└─── package type: deb (binary) or deb-src (source)
```

**Ubuntu components:**
| Component | Contents |
|-----------|---------|
| `main` | Officially supported free software |
| `restricted` | Proprietary drivers (non-free but officially supported) |
| `universe` | Community-maintained free software |
| `multiverse` | Non-free software |

Third-party repos add files to `/etc/apt/sources.list.d/` and their GPG keys to `/etc/apt/trusted.gpg.d/`.

---

## Exercise 6: apt-cache — Offline Package Queries

```bash
apt-cache show bash | head -20
apt-cache depends bash
apt-cache rdepends bash | head -15
apt-cache pkgnames | grep ^python | head -10
apt-cache stats
```

**apt-cache vs apt:**
| | `apt-cache` | `apt` |
|-|-------------|-------|
| Network | No | Yes (for update) |
| Source | Local cache only | Online repositories |
| Use case | Querying, scripting | Interactive management |

`apt-cache depends pkg` — what the package requires.
`apt-cache rdepends pkg` — what requires the package (reverse dependencies).

---

## Exercise 7: Cleaning Up

```bash
sudo apt autoremove
du -sh /var/cache/apt/archives/
sudo apt clean
du -sh /var/cache/apt/archives/
sudo apt autoclean
dpkg -l | grep '^rc'
dpkg -l | grep '^rc' | awk '{print $2}' | xargs sudo dpkg --purge 2>/dev/null || echo "nothing to purge"
```

**Cache cleanup commands:**
| Command | Effect |
|---------|--------|
| `apt autoremove` | Remove auto-installed deps no longer needed |
| `apt clean` | Delete all cached .deb files |
| `apt autoclean` | Delete only outdated cached .deb files |

**Cache locations:**
| Path | Contents |
|------|---------|
| `/var/cache/apt/archives/` | Downloaded .deb files |
| `/var/lib/apt/lists/` | Repository package indexes |
| `/var/lib/dpkg/` | dpkg database (installed packages) |

---

## Quick Reference

```bash
apt update                     refresh package index
apt search pattern             search by name + description
apt show package               show package details
apt install -y pkg             install package (auto-yes)
apt remove pkg                 remove (keep config)
apt purge pkg                  remove (delete config too)
apt upgrade                    apply available updates
apt autoremove                 remove unused auto-deps
apt clean                      clear download cache
apt list --installed           list installed packages
dpkg -l                        list all packages + status
dpkg -l | grep '^ii'           installed packages only
dpkg -L pkg                    files owned by package
dpkg -S /path/to/file          package that owns this file
dpkg-query -s pkg              detailed package status
apt-cache show pkg             package info from cache
apt-cache depends pkg          what does this require
apt-cache rdepends pkg         what requires this
```
