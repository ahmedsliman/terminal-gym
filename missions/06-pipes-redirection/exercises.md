# Exercises — Mission 06: Pipes & Redirection

---

## Exercise 1: stdout vs stderr

**Goal:** See that stdout and stderr are separate streams.

**Steps:**
1. Run a command that produces both: `ls /etc /doesnotexist`
2. Suppress stderr only: `ls /etc /doesnotexist 2>/dev/null`
3. Suppress stdout only: `ls /etc /doesnotexist 1>/dev/null`
4. Capture stderr to a file: `ls /etc /doesnotexist 2>/tmp/m06-err.txt`
5. Read the captured errors: `cat /tmp/m06-err.txt`

**Hint:** `2>` redirects FD 2 (stderr). `1>` or just `>` redirects FD 1 (stdout).

**Self-check:** Step 2 shows files but no error message. Step 3 shows the error message but no file list.

---

## Exercise 2: > and >> — Writing Files

**Goal:** Create and append to files using redirection.

**Steps:**
1. Create a file: `echo "entry 1" > /tmp/m06-log.txt`
2. Append to it: `echo "entry 2" >> /tmp/m06-log.txt`
3. Append again: `echo "entry 3" >> /tmp/m06-log.txt`
4. Read it: `cat /tmp/m06-log.txt`
5. Overwrite it: `echo "fresh start" > /tmp/m06-log.txt`
6. Read again: `cat /tmp/m06-log.txt`

**Hint:** `>` creates or truncates. `>>` creates or appends. Neither asks for confirmation.

**Self-check:** After step 4, the file has 3 lines. After step 6, it has 1 line.

---

## Exercise 3: Capturing and Merging Streams

**Goal:** Redirect both stdout and stderr to the same file.

**Steps:**
1. Capture stdout only:
   ```bash
   ls /etc /fake > /tmp/m06-stdout.txt
   cat /tmp/m06-stdout.txt
   ```
   (notice: the error still appears on screen)

2. Capture stderr only:
   ```bash
   ls /etc /fake 2> /tmp/m06-stderr.txt
   cat /tmp/m06-stderr.txt
   ```

3. Capture both to one file:
   ```bash
   ls /etc /fake > /tmp/m06-both.txt 2>&1
   cat /tmp/m06-both.txt
   ```

4. Both into a pipe:
   ```bash
   ls /etc /fake 2>&1 | wc -l
   ```

**Hint:** `2>&1` must come AFTER `>`. Writing `2>&1 > file` is a common mistake — stderr ends up on screen.

**Self-check:** `/tmp/m06-both.txt` should contain both file listings and the error message.

---

## Exercise 4: Pipes

**Goal:** Build multi-stage pipelines.

**Steps:**
1. Count entries in /usr/bin: `ls /usr/bin | wc -l`
2. Find the 5 longest command names in /usr/bin:
   ```bash
   ls /usr/bin | awk '{print length, $0}' | sort -rn | head -5
   ```
3. Count how many commands start with 'g':
   ```bash
   ls /usr/bin | grep '^g' | wc -l
   ```
4. List all unique file extensions in /etc:
   ```bash
   ls /etc | grep '\.' | sed 's/.*\.//' | sort -u
   ```

**Hint:** Build one step at a time. Run each partial pipeline and check the output before adding `|` and the next stage.

**Self-check:** Step 1 should print a number in the hundreds.

---

## Exercise 5: tee — Save and Display

**Goal:** Use `tee` to simultaneously display output and save it.

**Steps:**
1. List /etc and save + count:
   ```bash
   ls /etc | tee /tmp/m06-etc.txt | wc -l
   ```
2. Verify the file was saved: `wc -l /tmp/m06-etc.txt`
3. Simulate logging:
   ```bash
   for i in 1 2 3; do
     echo "$(date +%T) event $i" | tee -a /tmp/m06-events.log
   done
   cat /tmp/m06-events.log
   ```
4. Capture and watch a build (simulate with a loop):
   ```bash
   { for i in {1..5}; do echo "step $i"; done; } 2>&1 | tee /tmp/m06-build.log
   ```

**Hint:** `tee -a` appends. `tee` without `-a` overwrites on each call.

**Self-check:** The count printed to screen should match `wc -l /tmp/m06-etc.txt`.

---

## Exercise 6: Here-doc and Here-string

**Goal:** Write multi-line input inline and feed strings to commands.

**Steps:**
1. Write a file with a here-doc:
   ```bash
   cat > /tmp/m06-config.txt << 'EOF'
   host=localhost
   port=8080
   debug=true
   EOF
   cat /tmp/m06-config.txt
   ```
2. Use an unquoted delimiter (variables expand):
   ```bash
   cat << EOF
   user: $USER
   home: $HOME
   date: $(date +%F)
   EOF
   ```
3. Count words with a here-string:
   ```bash
   wc -w <<< "the quick brown fox"
   ```
4. grep a string without a file:
   ```bash
   grep "port" <<< "host=localhost port=8080 debug=true"
   ```

**Hint:** Single-quote `'EOF'` to prevent expansion inside the here-doc. Leave it unquoted when you want `$VAR` and `$()` to expand.

**Self-check:** The here-doc file should have exactly 3 lines: `wc -l /tmp/m06-config.txt` should print `3`.

---

## Exercise 7: Real Pipeline Challenge

**Goal:** Answer a real question by building a pipeline.

**Question:** Which 5 directories in `/usr` take up the most disk space?

```bash
# Build it step by step:
du -sh /usr/*/          # Step 1: sizes of first-level subdirectories
du -sh /usr/*/ 2>/dev/null | sort -rh    # Step 2: sort by size, largest first
du -sh /usr/*/ 2>/dev/null | sort -rh | head -5   # Step 3: top 5
```

Now try: which user in `/home` (or system account in `/etc/passwd`) has the longest username?

```bash
cut -d: -f1 /etc/passwd | awk '{print length, $0}' | sort -rn | head -1
```

**Hint:** `sort -h` sorts human-readable sizes (1K, 2M, 3G). `sort -rh` sorts in reverse.

**Self-check:** The output should be 5 lines, each starting with a size (e.g. `45M /usr/lib`).

---

Cleanup:
```bash
rm -f /tmp/m06-*.txt /tmp/m06-*.log /tmp/m06-err.txt
```

Mark complete:
```bash
make done N=06
make next
```
