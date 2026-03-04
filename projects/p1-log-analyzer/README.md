# Weekly Project 1 — Log Analyzer

## Goal

Parse a log file and produce a report: unique IPs, request counts, and the top 5
most active clients. Pure pipes — no Python, no awk scripts longer than one line.

## Setup

Generate a sample log file in your lab:

```bash
mkdir -p lab/logs
# Generate 200 fake Apache-style log lines
python3 -c "
import random, datetime
ips = ['192.168.1.'+str(i) for i in range(1,15)]
paths = ['/index.html','/about','/api/data','/login','/static/app.js']
for _ in range(200):
    ip = random.choice(ips)
    path = random.choice(paths)
    code = random.choice([200,200,200,404,301])
    size = random.randint(100,5000)
    print(f'{ip} - - [01/Mar/2026:10:00:00 +0000] \"GET {path} HTTP/1.1\" {code} {size}')
" > lab/logs/access.log
```

## Tasks

### Task 1: Count total requests
```bash
wc -l lab/logs/access.log
```

### Task 2: List all unique IPs
```bash
cut -d' ' -f1 lab/logs/access.log | sort -u
```

### Task 3: Count requests per IP
```bash
cut -d' ' -f1 lab/logs/access.log | sort | uniq -c | sort -rn
```

### Task 4: Top 5 most active IPs
```bash
cut -d' ' -f1 lab/logs/access.log | sort | uniq -c | sort -rn | head -5
```

### Task 5: Count only 404 errors
```bash
grep '" 404 ' lab/logs/access.log | wc -l
```

### Task 6: Save a full report
```bash
{
  echo "=== Log Report: $(date) ==="
  echo ""
  echo "Total requests: $(wc -l < lab/logs/access.log)"
  echo ""
  echo "Top 5 IPs:"
  cut -d' ' -f1 lab/logs/access.log | sort | uniq -c | sort -rn | head -5
  echo ""
  echo "404 errors: $(grep '" 404 ' lab/logs/access.log | wc -l)"
} > lab/logs/report.txt

cat lab/logs/report.txt
```

## Self-check

- Can you explain every `|` in Task 4's pipeline?
- What does `uniq -c` add to the output?
- Why do we need `sort` before `uniq`?

## Done

```bash
make done N=P1
```
