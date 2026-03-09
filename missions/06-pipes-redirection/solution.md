# Solution — Mission 06: Pipes & Redirection

---

## Exercise 1: stdout vs stderr

```bash
ls /etc /doesnotexist
ls /etc /doesnotexist 2>/dev/null     # files only, no error
ls /etc /doesnotexist 1>/dev/null     # error only, no files
ls /etc /doesnotexist 2>/tmp/m06-err.txt
cat /tmp/m06-err.txt
```

**File descriptor reference:**
| FD | Name | Default |
|----|------|---------|
| 0 | stdin | keyboard |
| 1 | stdout | terminal |
| 2 | stderr | terminal |

---

## Exercise 2: > and >> — Writing Files

```bash
echo "entry 1" > /tmp/m06-log.txt
echo "entry 2" >> /tmp/m06-log.txt
echo "entry 3" >> /tmp/m06-log.txt
cat /tmp/m06-log.txt      # 3 lines
echo "fresh start" > /tmp/m06-log.txt
cat /tmp/m06-log.txt      # 1 line
```

**Safe pattern — check before overwriting:**
```bash
[ -f important.txt ] && echo "file exists — won't overwrite" || echo "data" > important.txt
```

---

## Exercise 3: Capturing and Merging Streams

```bash
ls /etc /fake > /tmp/m06-stdout.txt         # error on screen, files in file
ls /etc /fake 2> /tmp/m06-stderr.txt        # files on screen, error in file
ls /etc /fake > /tmp/m06-both.txt 2>&1      # both in file
ls /etc /fake 2>&1 | wc -l                 # both through pipe
```

**Why order matters for 2>&1:**
```
> file 2>&1    FD1 → file, then FD2 → wherever FD1 is (file) ✓
2>&1 > file    FD2 → wherever FD1 is (terminal!) then FD1 → file ✗
```

The right-hand side of `>&` captures the *current* destination of that FD at the moment the redirection is evaluated.

---

## Exercise 4: Pipes

```bash
ls /usr/bin | wc -l
ls /usr/bin | awk '{print length, $0}' | sort -rn | head -5
ls /usr/bin | grep '^g' | wc -l
ls /etc | grep '\.' | sed 's/.*\.//' | sort -u
```

**Pipeline anatomy:**
```
ls /usr/bin | grep '^g' | wc -l
    ^            ^           ^
 source       filter      aggregate
```

Each stage is a separate process. They run concurrently, not sequentially. The kernel buffers data between them.

---

## Exercise 5: tee — Save and Display

```bash
ls /etc | tee /tmp/m06-etc.txt | wc -l
wc -l /tmp/m06-etc.txt   # same number

for i in 1 2 3; do
  echo "$(date +%T) event $i" | tee -a /tmp/m06-events.log
done
cat /tmp/m06-events.log

{ for i in {1..5}; do echo "step $i"; done; } 2>&1 | tee /tmp/m06-build.log
```

**Common tee patterns:**
```bash
make 2>&1 | tee build.log          # capture build output
sudo apt upgrade 2>&1 | tee upgrade.log   # capture package upgrade
command | tee >(grep ERROR > errors.log)  # process substitution — advanced
```

---

## Exercise 6: Here-doc and Here-string

```bash
cat > /tmp/m06-config.txt << 'EOF'
host=localhost
port=8080
debug=true
EOF
cat /tmp/m06-config.txt

cat << EOF
user: $USER
home: $HOME
date: $(date +%F)
EOF

wc -w <<< "the quick brown fox"     # 4

grep "port" <<< "host=localhost port=8080 debug=true"
```

**When to use each:**
| Form | Use when |
|------|---------|
| `> file` | Writing output of a command to a file |
| `<< 'EOF'` | Feeding multi-line static text to a command |
| `<< EOF` | Feeding multi-line text with variable/command expansion |
| `<<<` | Feeding a single string — compact, no subshell |

---

## Exercise 7: Real Pipeline Challenge

```bash
# Top 5 directories in /usr by size
du -sh /usr/*/ 2>/dev/null | sort -rh | head -5

# Longest username
cut -d: -f1 /etc/passwd | awk '{print length, $0}' | sort -rn | head -1
```

---

## Quick Reference

```bash
>          redirect stdout (overwrite)
>>         redirect stdout (append)
2>         redirect stderr
2>&1       merge stderr into stdout
&>         redirect both stdout and stderr (bash shorthand)
<          redirect file to stdin
|          pipe stdout to next stdin
tee        split to stdout AND file
/dev/null  discard anything written to it
<<'EOF'    here-doc (no expansion)
<<EOF      here-doc (with expansion)
<<<        here-string
```
