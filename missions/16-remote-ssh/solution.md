# Solution — Mission 16: Remote Servers & SSH

---

## Exercise 1: SSH Key Concepts and Local Setup

```bash
ls -la ~/.ssh/ 2>/dev/null || echo "~/.ssh does not exist"
ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f ~/.ssh/id_ed25519
cat ~/.ssh/id_ed25519.pub
ls -la ~/.ssh/
stat -c '%a %n' ~/.ssh ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub 2>/dev/null
```

**Required permissions:**
| Path | Required | Risk if wrong |
|------|----------|---------------|
| `~/.ssh/` | `700` | SSH refuses to use keys |
| Private key (`id_ed25519`) | `600` | "Permissions are too open" |
| Public key (`id_ed25519.pub`) | `644` | No SSH risk, just good practice |
| `authorized_keys` | `600` | SSH refuses to use it |

**Fix permissions if needed:**
```bash
chmod 700 ~/.ssh
chmod 600 ~/.ssh/id_ed25519
chmod 644 ~/.ssh/id_ed25519.pub
chmod 600 ~/.ssh/authorized_keys 2>/dev/null
```

---

## Exercise 2: SSH Key Algorithms

```bash
ls -la ~/.ssh/*.pub 2>/dev/null
ssh-keygen -t rsa -b 4096 -C "rsa-test" -f /tmp/test_rsa -N ""
ls -lh /tmp/test_rsa /tmp/test_rsa.pub
wc -c ~/.ssh/id_ed25519.pub /tmp/test_rsa.pub 2>/dev/null
rm -f /tmp/test_rsa /tmp/test_rsa.pub
```

**Algorithm comparison:**
| Algorithm | Flag | Security | Compatibility |
|-----------|------|----------|--------------|
| Ed25519 | `-t ed25519` | Excellent | OpenSSH 6.5+ (2014) |
| RSA 4096 | `-t rsa -b 4096` | Good | Universal |
| ECDSA | `-t ecdsa -b 521` | Good | OpenSSH 5.7+ |
| DSA | `-t dsa` | Broken | Deprecated, avoid |

Ed25519 is the current recommendation. If you need maximum compatibility with very old servers, use RSA 4096.

The `-N ""` flag sets an empty passphrase. For production keys, use a strong passphrase — ssh-agent will cache the decrypted key so you only type it once.

---

## Exercise 3: SSH Configuration File

```bash
cat ~/.ssh/config 2>/dev/null || echo "no config file"
chmod 600 ~/.ssh/config
```

**Full example config:**
```
Host *
    ServerAliveInterval 60
    ServerAliveCountMax 3
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519

Host prod
    HostName prod.example.com
    User deploy
    Port 2222

Host bastion
    HostName jump.example.com
    User alice

Host internal
    HostName 10.0.0.5
    User alice
    ProxyJump bastion
```

**Key directives:**
| Directive | Effect |
|-----------|--------|
| `HostName` | Actual hostname or IP |
| `User` | Remote username |
| `Port` | SSH port (default 22) |
| `IdentityFile` | Private key to use |
| `ProxyJump` | Tunnel through this host first |
| `ServerAliveInterval` | Send keepalive every N seconds |
| `ForwardAgent` | Forward ssh-agent to the remote host |

`Host *` applies to all connections. More specific `Host` blocks override `Host *` for matching connections.

---

## Exercise 4: ssh-agent — Managing Keys in Memory

```bash
echo $SSH_AUTH_SOCK
ssh-add -l 2>/dev/null || echo "no agent or no keys loaded"
ssh-add ~/.ssh/id_ed25519 2>/dev/null || echo "key already added or agent not running"
ssh-add -l
ssh-keygen -lf ~/.ssh/id_ed25519.pub
ssh-keygen -lf ~/.ssh/id_ed25519.pub -E sha256
ssh-keygen -lf ~/.ssh/id_ed25519.pub -E md5
ssh-add -d ~/.ssh/id_ed25519 2>/dev/null || echo "key was not loaded"
```

**ssh-add flags:**
| Flag | Effect |
|------|--------|
| `ssh-add key` | Add key to agent |
| `ssh-add -l` | List loaded keys (short fingerprint) |
| `ssh-add -L` | List loaded keys (full public key) |
| `ssh-add -d key` | Remove key from agent |
| `ssh-add -D` | Remove all keys from agent |
| `ssh-add -t seconds` | Add key with expiry time |

**Start a new agent if needed:**
```bash
eval "$(ssh-agent -s)"   # start agent and set environment variables
ssh-add ~/.ssh/id_ed25519
```

---

## Exercise 5: scp — Secure Copy

```bash
# Syntax reference:
scp local-file.txt user@host:/remote/path/    # local → remote
scp user@host:/remote/file.txt /local/path/   # remote → local
scp -r local-dir/ user@host:/remote/dir/      # recursive

# Localhost test (if sshd is available):
echo "test" > /tmp/m16-test.txt
scp /tmp/m16-test.txt localhost:/tmp/m16-scp-copy.txt
rm -f /tmp/m16-test.txt /tmp/m16-scp-copy.txt
```

**scp flags:**
| Flag | Effect |
|------|--------|
| `-r` | Recursive (directories) |
| `-P port` | Port number (capital P!) |
| `-i keyfile` | Specify identity file |
| `-C` | Enable compression |
| `-p` | Preserve timestamps and permissions |

**scp gotchas:**
- `-P` (port) is capital in `scp`, lowercase in `ssh`
- No progress bar for large files (use rsync with `-P` instead)
- Cannot resume partial transfers (use rsync instead)
- scp is being deprecated in some distributions in favor of sftp/rsync

---

## Exercise 6: rsync — Efficient File Synchronization

```bash
mkdir -p /tmp/m16/{source,dest}
echo "file 1" > /tmp/m16/source/a.txt
echo "file 2" > /tmp/m16/source/b.txt
mkdir -p /tmp/m16/source/subdir
echo "nested" > /tmp/m16/source/subdir/c.txt

rsync -av /tmp/m16/source/ /tmp/m16/dest/
find /tmp/m16/dest -type f | sort

rsync -av /tmp/m16/source/ /tmp/m16/dest/   # nothing to transfer

echo "updated" >> /tmp/m16/source/a.txt
rsync -av /tmp/m16/source/ /tmp/m16/dest/   # only a.txt transfers

echo "new content" > /tmp/m16/source/d.txt
rsync -avn /tmp/m16/source/ /tmp/m16/dest/  # dry run
```

**rsync flags:**
| Flag | Effect |
|------|--------|
| `-a` | Archive: `-rlptgoD` (recursive, preserve symlinks, permissions, times, owner, group, devices) |
| `-v` | Verbose |
| `-z` | Compress during transfer |
| `-P` | Progress bar + partial file support |
| `-n` | Dry run — show what would transfer |
| `--delete` | Delete destination files not in source |
| `--exclude='*.log'` | Exclude matching files |

**The trailing slash rule:**
```bash
rsync -av source/ dest/   # sync contents of source INTO dest
rsync -av source  dest/   # sync source directory into dest (creates dest/source/)
```

**Remote rsync:**
```bash
rsync -avP local/dir/ user@host:/remote/dir/
rsync -avP user@host:/remote/dir/ local/dir/
```

---

## Exercise 7: known_hosts and Host Key Verification

```bash
cat ~/.ssh/known_hosts 2>/dev/null | head -5 || echo "no known_hosts yet"
ssh-keygen -F localhost 2>/dev/null || echo "localhost not in known_hosts"
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub 2>/dev/null || echo "no host key found"
```

**known_hosts format:**
```
hostname key_type base64_public_key
# or hashed (HashKnownHosts yes):
|1|hash1|hash2 key_type base64_public_key
```

**Managing known_hosts:**
```bash
ssh-keygen -F hostname       # check if host is known
ssh-keygen -R hostname       # remove a host's key (e.g., after server reinstall)
```

**Security note:** When a server's key changes (e.g., after reinstall), SSH warns:
```
WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED!
```
This is the TOFU (Trust On First Use) model. In production, verify fingerprints through a secure out-of-band channel before connecting.

---

## Quick Reference

```bash
# Key generation
ssh-keygen -t ed25519 -C "comment"    generate Ed25519 key pair
ssh-keygen -lf key.pub                show fingerprint of key

# Agent
ssh-add key                           add key to agent
ssh-add -l                            list loaded keys
eval "$(ssh-agent -s)"                start agent

# Connecting
ssh user@host                         connect
ssh -p 2222 user@host                 non-standard port
ssh -i ~/.ssh/key user@host           specify key
ssh -J bastion user@internal          jump through bastion

# File transfer
scp file.txt user@host:/path/         copy to remote
scp user@host:/path/file.txt .        copy from remote
rsync -avP source/ user@host:/dest/   sync with progress
rsync -avn source/ dest/              dry run

# known_hosts
ssh-keygen -F hostname                check if host is known
ssh-keygen -R hostname                remove host key

# Config
~/.ssh/config                         client config file
~/.ssh/authorized_keys                public keys allowed to log in
chmod 700 ~/.ssh && chmod 600 ~/.ssh/id_* && chmod 644 ~/.ssh/*.pub
```
