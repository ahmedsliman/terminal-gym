# Exercises — Mission 16: Remote Servers & SSH

---

## Exercise 1: SSH Key Concepts and Local Setup

**Goal:** Understand SSH key pairs and inspect your local SSH directory.

**Steps:**
1. Check if you already have an SSH key pair:
   ```bash
   ls -la ~/.ssh/ 2>/dev/null || echo "~/.ssh does not exist"
   ```
2. If no key exists, generate one:
   ```bash
   ssh-keygen -t ed25519 -C "$(whoami)@$(hostname)" -f ~/.ssh/id_ed25519
   ```
   (Press Enter to accept defaults and skip the passphrase for this exercise)
3. View the public key:
   ```bash
   cat ~/.ssh/id_ed25519.pub
   ```
4. Confirm the permissions are correct:
   ```bash
   ls -la ~/.ssh/
   stat -c '%a %n' ~/.ssh ~/.ssh/id_ed25519 ~/.ssh/id_ed25519.pub 2>/dev/null
   ```
5. Understand the key anatomy:
   ```
   ssh-ed25519 AAAA...base64... user@hostname
   │           │                 └── comment
   │           └─────────────────── public key data (base64)
   └─────────────────────────────── algorithm
   ```

**Required permissions:**
| Path | Permission |
|------|-----------|
| `~/.ssh/` | `700` |
| `~/.ssh/id_*` (private key) | `600` |
| `~/.ssh/id_*.pub` (public key) | `644` |
| `~/.ssh/authorized_keys` | `600` |

**Hint:** SSH refuses to use keys with too-open permissions. If you see "Permissions are too open" errors, run `chmod 600 ~/.ssh/id_ed25519` and `chmod 700 ~/.ssh`.

**Self-check:** `stat -c '%a' ~/.ssh/id_ed25519` should print `600`.

---

## Exercise 2: SSH Key Algorithms

**Goal:** Understand the available SSH key types.

**Steps:**
1. List your existing keys:
   ```bash
   ls -la ~/.ssh/*.pub 2>/dev/null
   ```
2. Read about each algorithm:

   | Algorithm | Flag | Key size | Notes |
   |-----------|------|----------|-------|
   | Ed25519 | `-t ed25519` | Fixed (256-bit) | Recommended — modern, fast, secure |
   | RSA | `-t rsa -b 4096` | 4096 bits | Widely compatible but larger |
   | ECDSA | `-t ecdsa -b 521` | 256–521 bits | Good but Ed25519 is preferred |
   | DSA | `-t dsa` | 1024 bits | Deprecated — do not use |

3. Generate a test RSA key to compare:
   ```bash
   ssh-keygen -t rsa -b 4096 -C "rsa-test" -f /tmp/test_rsa -N ""
   ls -lh /tmp/test_rsa /tmp/test_rsa.pub
   cat /tmp/test_rsa.pub
   ```
4. Compare the public key sizes (Ed25519 is much shorter):
   ```bash
   wc -c ~/.ssh/id_ed25519.pub /tmp/test_rsa.pub 2>/dev/null
   ```
5. Clean up the test key:
   ```bash
   rm -f /tmp/test_rsa /tmp/test_rsa.pub
   ```

**Hint:** Ed25519 keys are compact (~68 bytes encoded), fast to verify, and considered the most secure option currently available. Use Ed25519 for all new keys.

**Self-check:** The RSA 4096 public key should be ~700+ bytes. The Ed25519 public key should be around 100 bytes.

---

## Exercise 3: SSH Configuration File

**Goal:** Write and use an SSH client config file to simplify connections.

**Steps:**
1. Check if `~/.ssh/config` exists:
   ```bash
   cat ~/.ssh/config 2>/dev/null || echo "no config file"
   ```
2. Create or view the config structure:
   ```bash
   cat > ~/.ssh/config.example << 'EOF'
   # Default settings for all hosts
   Host *
       ServerAliveInterval 60
       ServerAliveCountMax 3
       AddKeysToAgent yes

   # Example alias for a server
   Host myserver
       HostName 192.168.1.10
       User alice
       Port 22
       IdentityFile ~/.ssh/id_ed25519

   # Bastion / jump host pattern
   Host internal
       HostName 10.0.0.5
       User bob
       ProxyJump myserver
   EOF
   cat ~/.ssh/config.example
   ```
3. Understand what each directive does:
   - `Host *` — applies to all connections
   - `HostName` — the real IP or hostname to connect to
   - `User` — the remote username
   - `Port` — defaults to 22
   - `IdentityFile` — which key to use
   - `ProxyJump` — connect through an intermediate host
4. Check the correct permissions for the config file:
   ```bash
   # SSH requires config to not be world-writable
   # Recommended: 600
   touch ~/.ssh/config 2>/dev/null || true
   chmod 600 ~/.ssh/config
   ```
5. Clean up:
   ```bash
   rm -f ~/.ssh/config.example
   ```

**Hint:** With a config entry `Host myserver`, you can type `ssh myserver` instead of `ssh alice@192.168.1.10 -i ~/.ssh/id_ed25519`. The config file makes complex setups manageable.

**Self-check:** `~/.ssh/config` permissions should be `600`.

---

## Exercise 4: ssh-agent — Managing Keys in Memory

**Goal:** Understand ssh-agent and how it avoids repeated passphrase prompts.

**Steps:**
1. Check if ssh-agent is running:
   ```bash
   echo $SSH_AUTH_SOCK
   ssh-add -l 2>/dev/null || echo "no agent or no keys loaded"
   ```
2. List keys currently held by the agent:
   ```bash
   ssh-add -l
   ```
3. Add your key to the agent:
   ```bash
   ssh-add ~/.ssh/id_ed25519 2>/dev/null || echo "key already added or agent not running"
   ssh-add -l
   ```
4. View key fingerprints in different formats:
   ```bash
   ssh-keygen -lf ~/.ssh/id_ed25519.pub
   ssh-keygen -lf ~/.ssh/id_ed25519.pub -E sha256
   ssh-keygen -lf ~/.ssh/id_ed25519.pub -E md5
   ```
5. Remove a key from the agent:
   ```bash
   ssh-add -d ~/.ssh/id_ed25519 2>/dev/null || echo "key was not loaded"
   ```

**Hint:** `ssh-agent` holds decrypted private keys in memory. Once you add a key with `ssh-add`, SSH uses the agent instead of asking for a passphrase on every connection. Modern desktop environments start ssh-agent automatically.

**Self-check:** `ssh-add -l` lists fingerprints of loaded keys. If the agent is not running, `$SSH_AUTH_SOCK` is empty.

---

## Exercise 5: scp — Secure Copy

**Goal:** Understand scp syntax for transferring files.

**Steps:**
1. Understand the syntax:
   ```bash
   # local-to-remote:
   scp local-file.txt user@host:/remote/path/

   # remote-to-local:
   scp user@host:/remote/file.txt /local/path/

   # directory copy (recursive):
   scp -r local-dir/ user@host:/remote/dir/

   # using a config alias:
   scp file.txt myserver:/tmp/
   ```

2. Simulate with localhost (if sshd is running):
   ```bash
   if ssh -o BatchMode=yes -o ConnectTimeout=2 localhost exit 2>/dev/null; then
     echo "test" > /tmp/m16-test.txt
     scp /tmp/m16-test.txt localhost:/tmp/m16-scp-copy.txt
     cat /tmp/m16-scp-copy.txt
     rm -f /tmp/m16-test.txt /tmp/m16-scp-copy.txt
   else
     echo "sshd not available on localhost — reading scp syntax only"
   fi
   ```

3. Key scp flags:
   | Flag | Effect |
   |------|--------|
   | `-r` | Recursive (directories) |
   | `-P port` | Specify port (capital P, unlike ssh) |
   | `-i key` | Specify identity file |
   | `-C` | Enable compression |
   | `-p` | Preserve timestamps and permissions |

4. Note that scp is being replaced by rsync and sftp in modern workflows:
   ```bash
   # scp limitation: no progress bar, no partial transfer resume
   # rsync advantages: resume, delta transfer, verbose progress
   ```

**Hint:** `scp` syntax is `scp SOURCE DESTINATION` where either source or destination (or both) can be `user@host:/path`. Note: `scp -P` uses capital P for port (lowercase `-p` preserves timestamps — opposite of ssh).

**Self-check:** `scp` without arguments should print usage. The key syntax is `[[user@]host:]file`.

---

## Exercise 6: rsync — Efficient File Synchronization

**Goal:** Use rsync for efficient, resumable file transfers.

**Setup:**
```bash
mkdir -p /tmp/m16/{source,dest}
echo "file 1" > /tmp/m16/source/a.txt
echo "file 2" > /tmp/m16/source/b.txt
mkdir -p /tmp/m16/source/subdir
echo "nested" > /tmp/m16/source/subdir/c.txt
```

**Steps:**
1. Sync a local directory:
   ```bash
   rsync -av /tmp/m16/source/ /tmp/m16/dest/
   find /tmp/m16/dest -type f | sort
   ```
2. Run rsync again — notice nothing is transferred (already in sync):
   ```bash
   rsync -av /tmp/m16/source/ /tmp/m16/dest/
   ```
3. Modify a file and re-sync — only the changed file transfers:
   ```bash
   echo "updated" >> /tmp/m16/source/a.txt
   rsync -av /tmp/m16/source/ /tmp/m16/dest/
   ```
4. Dry run — show what would transfer without doing it:
   ```bash
   echo "new content" > /tmp/m16/source/d.txt
   rsync -avn /tmp/m16/source/ /tmp/m16/dest/
   ```
5. Common rsync flags:
   ```bash
   # -a  archive (preserves permissions, timestamps, symlinks, owner)
   # -v  verbose
   # -z  compress data during transfer (useful over slow networks)
   # -P  progress bar + resume partial transfers
   # -n  dry run
   # --delete  remove files in destination that no longer exist in source
   ```

**Hint:** Note the trailing slash: `rsync -av source/ dest/` syncs the *contents* of `source`. `rsync -av source dest/` syncs the `source` *directory itself* into `dest`, creating `dest/source/`. The trailing slash on the source matters.

**Self-check:** Step 2 should output `sent N bytes` with a very small number — rsync skips files that haven't changed.

---

## Exercise 7: known_hosts and Host Key Verification

**Goal:** Understand host key fingerprints and the known_hosts file.

**Steps:**
1. View known hosts (servers you've connected to before):
   ```bash
   cat ~/.ssh/known_hosts 2>/dev/null | head -5 || echo "no known_hosts yet"
   ```
2. Understand the format:
   ```
   hostname|hashed_hostname key_type public_key_data
   ```
3. Check if a specific host's key is in known_hosts:
   ```bash
   ssh-keygen -F localhost 2>/dev/null || echo "localhost not in known_hosts"
   ```
4. View the fingerprint of a host key (server-side, if sshd is installed):
   ```bash
   ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub 2>/dev/null || echo "no host key found"
   ```
5. Understand what happens on first connection:
   - SSH shows the server's host key fingerprint
   - You verify it (against a known fingerprint from the admin)
   - You type `yes` — the key is added to `~/.ssh/known_hosts`
   - Future connections verify silently

**Warning:** Typing `yes` without verifying the fingerprint is a habit that makes you vulnerable to man-in-the-middle attacks. In production, always verify fingerprints out-of-band.

**Self-check:** `cat ~/.ssh/known_hosts` shows one line per server you've previously connected to and accepted.

---

Cleanup:
```bash
rm -rf /tmp/m16
```

Mark complete:
```bash
make done N=16
make next
```
