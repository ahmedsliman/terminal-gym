# Exercises — Mission 18: awk

---

## Exercise 1: Fields and Records

**Goal:** Access individual fields and understand awk's basic structure.

**Setup:**
```bash
mkdir -p /tmp/mission18
cat > /tmp/mission18/servers.txt << 'EOF'
web01   192.168.1.10   running   8
web02   192.168.1.11   stopped   0
db01    192.168.1.20   running   24
db02    192.168.1.21   running   12
cache01 192.168.1.30   stopped   0
EOF
```

**Steps:**
1. Print only the server names (field 1):
   ```bash
   awk '{ print $1 }' /tmp/mission18/servers.txt
   ```
2. Print the name and IP address only:
   ```bash
   awk '{ print $1, $2 }' /tmp/mission18/servers.txt
   ```
3. Print the last field of every line:
   ```bash
   awk '{ print $NF }' /tmp/mission18/servers.txt
   ```
4. Print each line with its line number:
   ```bash
   awk '{ print NR, $0 }' /tmp/mission18/servers.txt
   ```
5. Print lines that have exactly 4 fields:
   ```bash
   awk 'NF == 4 { print }' /tmp/mission18/servers.txt
   ```

**Hint:** `$1` `$2` `$NF` `NR` `NF`

**Self-check:** Step 3 should print the uptime column (8, 0, 24, 12, 0). Step 5 should print nothing — every line has 4 fields.

---

## Exercise 2: Pattern Filtering

**Goal:** Use patterns to select which lines awk processes.

**Steps:**
1. Print only running servers:
   ```bash
   awk '$3 == "running"' /tmp/mission18/servers.txt
   ```
2. Print servers with uptime > 10 hours:
   ```bash
   awk '$4 > 10' /tmp/mission18/servers.txt
   ```
3. Print lines matching a regex (db servers):
   ```bash
   awk '/^db/' /tmp/mission18/servers.txt
   ```
4. Combine two conditions (running AND uptime > 0):
   ```bash
   awk '$3 == "running" && $4 > 0' /tmp/mission18/servers.txt
   ```
5. Negate a pattern — print non-running servers:
   ```bash
   awk '$3 != "running"' /tmp/mission18/servers.txt
   ```
6. Print lines 2 through 4 only:
   ```bash
   awk 'NR>=2 && NR<=4' /tmp/mission18/servers.txt
   ```

**Hint:** `awk '/pattern/'` `awk '$N == "value"'` `awk 'NR>=2 && NR<=4'`

**Self-check:** Step 3 should print only db01 and db02. Step 6 should print exactly 3 lines.

---

## Exercise 3: BEGIN and END Blocks

**Goal:** Use BEGIN for setup and END for summaries.

**Steps:**
1. Print a header before the data:
   ```bash
   awk 'BEGIN { print "=== Server Report ===" } { print $1, $3 }' /tmp/mission18/servers.txt
   ```
2. Count the total number of lines:
   ```bash
   awk 'END { print NR, "servers total" }' /tmp/mission18/servers.txt
   ```
3. Sum the uptime column and report the total:
   ```bash
   awk '{ total += $4 } END { print "Total uptime:", total, "hours" }' /tmp/mission18/servers.txt
   ```
4. Count running vs stopped servers:
   ```bash
   awk '
     $3 == "running" { running++ }
     $3 == "stopped" { stopped++ }
     END { print "Running:", running, "  Stopped:", stopped }
   ' /tmp/mission18/servers.txt
   ```
5. Print min and max uptime:
   ```bash
   awk '
     BEGIN { min=999; max=0 }
     { if ($4 > max) max=$4; if ($4 < min) min=$4 }
     END { print "Max:", max, "  Min:", min }
   ' /tmp/mission18/servers.txt
   ```

**Hint:** `BEGIN { }` `END { print NR }` `{ sum += $N }`

**Self-check:** Step 3 — total uptime should be 44 (8+0+24+12+0). Step 4 — running: 3, stopped: 2.

---

## Exercise 4: Field Separator and Reformatting

**Goal:** Parse delimited files and reformat output.

**Setup:**
```bash
cat > /tmp/mission18/users.csv << 'EOF'
alice,eng,85000,senior
bob,ops,72000,mid
carol,eng,91000,senior
dan,ops,68000,junior
eve,eng,79000,mid
EOF
```

**Steps:**
1. Print only names from the CSV:
   ```bash
   awk -F, '{ print $1 }' /tmp/mission18/users.csv
   ```
2. Print name and salary, tab-separated:
   ```bash
   awk -F, 'BEGIN { OFS="\t" } { print $1, $3 }' /tmp/mission18/users.csv
   ```
3. Calculate average salary:
   ```bash
   awk -F, '{ sum += $3 } END { printf "Average salary: $%.0f\n", sum/NR }' /tmp/mission18/users.csv
   ```
4. Print only engineers earning over 80k:
   ```bash
   awk -F, '$2 == "eng" && $3 > 80000 { print $1, $3 }' /tmp/mission18/users.csv
   ```
5. Convert CSV to a formatted table:
   ```bash
   awk -F, 'BEGIN { printf "%-10s %-6s %8s %s\n", "NAME","DEPT","SALARY","LEVEL" }
            { printf "%-10s %-6s %8s %s\n", $1, $2, $3, $4 }' /tmp/mission18/users.csv
   ```
6. Parse /etc/passwd — print username and shell for real users (UID ≥ 1000):
   ```bash
   awk -F: '$3 >= 1000 { print $1, $7 }' /etc/passwd
   ```

**Hint:** `awk -F,` `awk -F:` `BEGIN { OFS="\t" }` `printf "%-10s %5d\n", $1, $2`

**Self-check:** Step 3 — average salary is ~$79000. Step 4 — should print alice and carol only.

---

## Exercise 5: Built-in Functions and String Operations

**Goal:** Use awk's built-in string and math functions.

**Steps:**
1. Convert to uppercase / lowercase:
   ```bash
   awk '{ print toupper($1), tolower($3) }' /tmp/mission18/servers.txt
   ```
2. Get the length of each server name:
   ```bash
   awk '{ print $1, length($1) }' /tmp/mission18/servers.txt
   ```
3. Extract a substring (first 3 chars of name):
   ```bash
   awk '{ print substr($1, 1, 3) }' /tmp/mission18/servers.txt
   ```
4. Search and replace with `sub` (first match) and `gsub` (all matches):
   ```bash
   echo "the cat sat on the mat" | awk '{ gsub(/at/, "AT"); print }'
   echo "the cat sat on the mat" | awk '{ sub(/at/, "AT"); print }'
   ```
5. Split a field into an array:
   ```bash
   echo "2024-07-15" | awk '{ n = split($1, parts, "-"); print parts[1], parts[2], parts[3] }'
   ```
6. Match a field against a regex and extract:
   ```bash
   awk '$2 ~ /^192\.168\.1\.[12]/' /tmp/mission18/servers.txt
   ```

**Hint:** `toupper()` `tolower()` `length()` `substr($1, start, len)` `gsub(/re/, "new")` `split($0, arr, "sep")`

**Self-check:** Step 4 with `gsub` replaces all three "at" occurrences: "the cAT sAT on the mAT". With `sub` only the first: "the cAT sat on the mat".

---

## Exercise 6: Arrays and Aggregation

**Goal:** Use associative arrays to group and summarise data.

**Steps:**
1. Count servers per status:
   ```bash
   awk '{ count[$3]++ } END { for (s in count) print s, count[s] }' /tmp/mission18/servers.txt
   ```
2. Sum uptime per status group:
   ```bash
   awk '{ uptime[$3] += $4 } END { for (s in uptime) print s, uptime[s] }' /tmp/mission18/servers.txt
   ```
3. Remove duplicate lines (keep first occurrence):
   ```bash
   cat > /tmp/mission18/dupes.txt << 'EOF'
   apple
   banana
   apple
   cherry
   banana
   date
   EOF
   awk '!seen[$0]++' /tmp/mission18/dupes.txt
   ```
4. Count word frequency in a file:
   ```bash
   awk '{ for (i=1; i<=NF; i++) freq[$i]++ }
        END { for (w in freq) print freq[w], w }' /tmp/mission18/servers.txt | sort -rn | head -5
   ```
5. Group users by department and list names:
   ```bash
   awk -F, '{ dept[$2] = dept[$2] (dept[$2] ? ", " : "") $1 }
            END { for (d in dept) print d": "dept[d] }' /tmp/mission18/users.csv
   ```

**Hint:** `{ count[$1]++ }` `{ for (k in arr) print k, arr[k] }` `!seen[$0]++`

**Self-check:** Step 3 should print 4 unique lines: apple, banana, cherry, date (no duplicates).

---

## Exercise 7: Multi-file Processing and Practical Pipeline

**Goal:** Process multiple files and build a real reporting pipeline.

**Setup:**
```bash
cat > /tmp/mission18/access.log << 'EOF'
192.168.1.5  GET  /index.html     200  1234
192.168.1.10 GET  /api/users      200  890
192.168.1.5  POST /api/login      201  340
192.168.1.20 GET  /index.html     200  1234
192.168.1.10 GET  /nonexistent    404  56
192.168.1.5  GET  /api/users      200  890
192.168.1.20 POST /api/login      400  120
192.168.1.10 GET  /index.html     200  1234
EOF
```

**Steps:**
1. Count total requests per IP:
   ```bash
   awk '{ count[$1]++ } END { for (ip in count) print count[ip], ip }' /tmp/mission18/access.log | sort -rn
   ```
2. Count HTTP status codes:
   ```bash
   awk '{ status[$4]++ } END { for (s in status) print s, status[s] }' /tmp/mission18/access.log | sort
   ```
3. Find total bytes transferred per IP:
   ```bash
   awk '{ bytes[$1] += $5 } END { for (ip in bytes) printf "%-15s %d bytes\n", ip, bytes[ip] }' /tmp/mission18/access.log
   ```
4. Print only 404 errors with their path:
   ```bash
   awk '$4 == 404 { print $1, $3 }' /tmp/mission18/access.log
   ```
5. Build a full summary report:
   ```bash
   awk '
     BEGIN { print "=== Access Log Summary ===" }
     { total++; bytes_total += $5 }
     $4 >= 400 { errors++ }
     END {
       print "Total requests:", total
       print "Total bytes:   ", bytes_total
       print "Errors (4xx+): ", errors+0
       printf "Error rate:    %.1f%%\n", (errors/total)*100
     }
   ' /tmp/mission18/access.log
   ```

**Hint:** `{ count[$1]++ }` `{ bytes[$1] += $5 }` `$4 >= 400 { errors++ }` `printf "%.1f%%\n", val`

**Self-check:** Step 5 — total requests: 8, errors: 2, error rate: 25.0%.

---

Cleanup:
```bash
rm -rf /tmp/mission18
```

Mark complete:
```bash
make done N=18
```
