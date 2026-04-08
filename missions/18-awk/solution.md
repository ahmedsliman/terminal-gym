# Solution — Mission 18: awk

---

## Exercise 1: Fields and Records

```bash
awk '{ print $1 }' /tmp/mission18/servers.txt
awk '{ print $1, $2 }' /tmp/mission18/servers.txt
awk '{ print $NF }' /tmp/mission18/servers.txt
awk '{ print NR, $0 }' /tmp/mission18/servers.txt
awk 'NF == 4 { print }' /tmp/mission18/servers.txt
```

**Key insight:** `$NF` is the last field regardless of how many fields there are. `NF` itself holds the count.

---

## Exercise 2: Pattern Filtering

```bash
awk '$3 == "running"' /tmp/mission18/servers.txt
awk '$4 > 10' /tmp/mission18/servers.txt
awk '/^db/' /tmp/mission18/servers.txt
awk '$3 == "running" && $4 > 0' /tmp/mission18/servers.txt
awk '$3 != "running"' /tmp/mission18/servers.txt
awk 'NR>=2 && NR<=4' /tmp/mission18/servers.txt
```

**Key insight:** A bare pattern with no `{ action }` defaults to `{ print }`. Patterns can be regex (`/re/`), expressions (`$3 > 10`), or combinations with `&&` / `||`.

---

## Exercise 3: BEGIN and END Blocks

```bash
awk 'BEGIN { print "=== Server Report ===" } { print $1, $3 }' /tmp/mission18/servers.txt

awk 'END { print NR, "servers total" }' /tmp/mission18/servers.txt

awk '{ total += $4 } END { print "Total uptime:", total, "hours" }' /tmp/mission18/servers.txt

awk '
  $3 == "running" { running++ }
  $3 == "stopped" { stopped++ }
  END { print "Running:", running, "  Stopped:", stopped }
' /tmp/mission18/servers.txt

awk '
  BEGIN { min=999; max=0 }
  { if ($4 > max) max=$4; if ($4 < min) min=$4 }
  END { print "Max:", max, "  Min:", min }
' /tmp/mission18/servers.txt
```

**Key insight:** `BEGIN` runs before awk reads any input — use it to initialise variables or print headers. `END` runs after all input — use it for totals and summaries. Counters start at 0 automatically.

---

## Exercise 4: Field Separator and Reformatting

```bash
awk -F, '{ print $1 }' /tmp/mission18/users.csv
awk -F, 'BEGIN { OFS="\t" } { print $1, $3 }' /tmp/mission18/users.csv
awk -F, '{ sum += $3 } END { printf "Average salary: $%.0f\n", sum/NR }' /tmp/mission18/users.csv
awk -F, '$2 == "eng" && $3 > 80000 { print $1, $3 }' /tmp/mission18/users.csv
awk -F, 'BEGIN { printf "%-10s %-6s %8s %s\n", "NAME","DEPT","SALARY","LEVEL" }
         { printf "%-10s %-6s %8s %s\n", $1, $2, $3, $4 }' /tmp/mission18/users.csv
awk -F: '$3 >= 1000 { print $1, $7 }' /etc/passwd
```

**Key insight:** `-F,` sets the field separator for the whole program. `OFS` controls what goes *between* fields when you print them with commas. `printf` works like C — `%-10s` left-aligns in 10 chars, `%8s` right-aligns in 8.

---

## Exercise 5: Built-in Functions and String Operations

```bash
awk '{ print toupper($1), tolower($3) }' /tmp/mission18/servers.txt
awk '{ print $1, length($1) }' /tmp/mission18/servers.txt
awk '{ print substr($1, 1, 3) }' /tmp/mission18/servers.txt
echo "the cat sat on the mat" | awk '{ gsub(/at/, "AT"); print }'
echo "the cat sat on the mat" | awk '{ sub(/at/, "AT"); print }'
echo "2024-07-15" | awk '{ n = split($1, parts, "-"); print parts[1], parts[2], parts[3] }'
awk '$2 ~ /^192\.168\.1\.[12]/' /tmp/mission18/servers.txt
```

**Key insight:**
- `sub(re, new)` replaces first match; `gsub(re, new)` replaces all matches — both modify `$0` in place.
- `split(str, arr, sep)` fills `arr[1]`, `arr[2]`, … and returns the count.
- `~` matches a field against a regex; `!~` is the negation.

---

## Exercise 6: Arrays and Aggregation

```bash
awk '{ count[$3]++ } END { for (s in count) print s, count[s] }' /tmp/mission18/servers.txt
awk '{ uptime[$3] += $4 } END { for (s in uptime) print s, uptime[s] }' /tmp/mission18/servers.txt
awk '!seen[$0]++' /tmp/mission18/dupes.txt
awk '{ for (i=1; i<=NF; i++) freq[$i]++ }
     END { for (w in freq) print freq[w], w }' /tmp/mission18/servers.txt | sort -rn | head -5
awk -F, '{ dept[$2] = dept[$2] (dept[$2] ? ", " : "") $1 }
         END { for (d in dept) print d": "dept[d] }' /tmp/mission18/users.csv
```

**Key insight:** awk arrays are associative (hash maps). Any string can be a key. `!seen[$0]++` is the canonical deduplication idiom: the post-increment returns the old value (0 = false on first occurrence, non-zero = true on subsequent ones), so `!` inverts it.

---

## Exercise 7: Multi-file Processing and Practical Pipeline

```bash
awk '{ count[$1]++ } END { for (ip in count) print count[ip], ip }' /tmp/mission18/access.log | sort -rn
awk '{ status[$4]++ } END { for (s in status) print s, status[s] }' /tmp/mission18/access.log | sort
awk '{ bytes[$1] += $5 } END { for (ip in bytes) printf "%-15s %d bytes\n", ip, bytes[ip] }' /tmp/mission18/access.log
awk '$4 == 404 { print $1, $3 }' /tmp/mission18/access.log
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

**Key insight:** `errors+0` forces numeric context — if no 4xx lines exist, `errors` is unset ("") and `""+0` gives 0 cleanly. Mixing awk with `sort`, `head`, and other tools via pipes is normal and encouraged.

---

## Quick Reference

```bash
# print a field
awk '{ print $2 }'

# filter by pattern
awk '/regex/'
awk '$3 > 100'

# custom separator
awk -F: '{ print $1 }'
awk -F, 'BEGIN{OFS="\t"} { print $1, $3 }'

# count / sum
awk '{ count++ } END { print count }'
awk '{ sum += $2 } END { print sum }'

# group by key
awk '{ bucket[$1] += $2 } END { for (k in bucket) print k, bucket[k] }'

# dedup
awk '!seen[$0]++'

# format output
awk '{ printf "%-15s %5d\n", $1, $2 }'
```
