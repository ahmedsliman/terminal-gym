# Exercises — Mission 19: jq

---

## Exercise 1: Navigation and Basic Extraction

**Goal:** Navigate JSON with `.field`, `.[index]`, and nested paths.

**Setup:**
```bash
mkdir -p /tmp/mission19
cat > /tmp/mission19/user.json << 'EOF'
{
  "name": "alice",
  "age": 31,
  "active": true,
  "address": {
    "city": "Berlin",
    "country": "DE"
  },
  "scores": [88, 95, 72, 100, 84]
}
EOF
```

**Steps:**
1. Pretty-print the whole file:
   ```bash
   jq '.' /tmp/mission19/user.json
   ```
2. Get the name:
   ```bash
   jq '.name' /tmp/mission19/user.json
   ```
3. Get the city (nested field):
   ```bash
   jq '.address.city' /tmp/mission19/user.json
   ```
4. Get the first score:
   ```bash
   jq '.scores[0]' /tmp/mission19/user.json
   ```
5. Get the last score:
   ```bash
   jq '.scores[-1]' /tmp/mission19/user.json
   ```
6. Get a raw string (no quotes):
   ```bash
   jq -r '.name' /tmp/mission19/user.json
   ```
7. Get the length of the scores array:
   ```bash
   jq '.scores | length' /tmp/mission19/user.json
   ```

**Hint:** `.field` `.nested.field` `.[0]` `.[-1]` `jq -r` `length`

**Self-check:** Step 3 should output `"Berlin"`. Step 6 outputs `alice` (no quotes). Step 7 outputs `5`.

---

## Exercise 2: Iterating and Filtering Arrays

**Goal:** Explode arrays, iterate, and select elements by condition.

**Setup:**
```bash
cat > /tmp/mission19/servers.json << 'EOF'
[
  {"name": "web01", "status": "running", "cpu": 12, "region": "eu"},
  {"name": "web02", "status": "stopped", "cpu": 0,  "region": "eu"},
  {"name": "db01",  "status": "running", "cpu": 45, "region": "us"},
  {"name": "db02",  "status": "running", "cpu": 78, "region": "us"},
  {"name": "cache01","status":"stopped", "cpu": 0,  "region": "eu"}
]
EOF
```

**Steps:**
1. Print all server names:
   ```bash
   jq '.[].name' /tmp/mission19/servers.json
   ```
2. Print names as a raw list (no quotes):
   ```bash
   jq -r '.[].name' /tmp/mission19/servers.json
   ```
3. Get only running servers (returns array):
   ```bash
   jq '[.[] | select(.status == "running")]' /tmp/mission19/servers.json
   ```
4. Get names of running servers only:
   ```bash
   jq -r '[.[] | select(.status == "running")] | .[].name' /tmp/mission19/servers.json
   ```
5. Get servers with CPU > 20:
   ```bash
   jq '[.[] | select(.cpu > 20)]' /tmp/mission19/servers.json
   ```
6. Count total servers:
   ```bash
   jq 'length' /tmp/mission19/servers.json
   ```
7. Count running servers:
   ```bash
   jq '[.[] | select(.status == "running")] | length' /tmp/mission19/servers.json
   ```

**Hint:** `.[]` `.[].name` `select(.field == "value")` `select(.n > 20)` `length`

**Self-check:** Step 3 should return an array of 3 running servers. Step 7 should output `3`.

---

## Exercise 3: Transforming and Reshaping

**Goal:** Build new objects and arrays from existing JSON.

**Steps:**
1. Extract only name and status into a new object per server:
   ```bash
   jq '[.[] | {name, status}]' /tmp/mission19/servers.json
   ```
2. Rename fields — output `{host, state}` instead of `{name, status}`:
   ```bash
   jq '[.[] | {host: .name, state: .status}]' /tmp/mission19/servers.json
   ```
3. Add a computed field — mark servers as "busy" if cpu > 50:
   ```bash
   jq '[.[] | . + {busy: (.cpu > 50)}]' /tmp/mission19/servers.json
   ```
4. Use `map` shorthand (equivalent to `[.[] | expr]`):
   ```bash
   jq 'map({name, cpu})' /tmp/mission19/servers.json
   ```
5. Extract just the names into a flat array:
   ```bash
   jq '[.[].name]' /tmp/mission19/servers.json
   ```
6. Get all unique regions:
   ```bash
   jq '[.[].region] | unique' /tmp/mission19/servers.json
   ```

**Hint:** `{name, status}` `{host: .name}` `. + {field: expr}` `map(expr)` `unique`

**Self-check:** Step 3 — db02 (cpu 78) should have `"busy": true`. Step 6 should return `["eu", "us"]`.

---

## Exercise 4: Sorting, Grouping, and Aggregation

**Goal:** Sort, group, and compute summaries across JSON arrays.

**Steps:**
1. Sort servers by CPU usage (ascending):
   ```bash
   jq 'sort_by(.cpu)' /tmp/mission19/servers.json
   ```
2. Sort by CPU descending (highest first):
   ```bash
   jq 'sort_by(.cpu) | reverse' /tmp/mission19/servers.json
   ```
3. Find the server with the highest CPU:
   ```bash
   jq 'max_by(.cpu)' /tmp/mission19/servers.json
   ```
4. Group servers by region:
   ```bash
   jq 'group_by(.region)' /tmp/mission19/servers.json
   ```
5. Total CPU usage across all servers:
   ```bash
   jq '[.[].cpu] | add' /tmp/mission19/servers.json
   ```
6. Average CPU across running servers only:
   ```bash
   jq '[.[] | select(.status=="running") | .cpu] | add / length' /tmp/mission19/servers.json
   ```
7. Get all keys of the first server object:
   ```bash
   jq '.[0] | keys' /tmp/mission19/servers.json
   ```

**Hint:** `sort_by(.field)` `reverse` `max_by(.field)` `group_by(.field)` `add` `add / length` `keys`

**Self-check:** Step 3 — `db02` with cpu 78. Step 5 — total is 135. Step 6 — average is 45 ((12+45+78)/3).

---

## Exercise 5: Object Manipulation and del

**Goal:** Add, remove, and update fields in objects.

**Setup:**
```bash
cat > /tmp/mission19/config.json << 'EOF'
{
  "app": "terminal-gym",
  "version": "1.0.0",
  "debug": false,
  "database": {
    "host": "localhost",
    "port": 5432,
    "name": "tgym"
  },
  "secret_key": "s3cr3t",
  "max_connections": 100
}
EOF
```

**Steps:**
1. Remove the `secret_key` field:
   ```bash
   jq 'del(.secret_key)' /tmp/mission19/config.json
   ```
2. Update the version field:
   ```bash
   jq '.version = "2.0.0"' /tmp/mission19/config.json
   ```
3. Add a new field:
   ```bash
   jq '. + {environment: "production"}' /tmp/mission19/config.json
   ```
4. Update a nested field:
   ```bash
   jq '.database.host = "db.prod.internal"' /tmp/mission19/config.json
   ```
5. Remove multiple fields at once:
   ```bash
   jq 'del(.secret_key, .debug)' /tmp/mission19/config.json
   ```
6. Convert object to key-value pairs:
   ```bash
   jq 'to_entries' /tmp/mission19/config.json
   ```
7. Filter keys — keep only `app` and `version`:
   ```bash
   jq '{app, version}' /tmp/mission19/config.json
   ```

**Hint:** `del(.field)` `.field = value` `. + {key: val}` `to_entries` `{app, version}`

**Self-check:** Step 1 output should not contain `secret_key`. Step 6 outputs an array of `{key, value}` objects.

---

## Exercise 6: Real-world API Response Processing

**Goal:** Parse and extract data from a realistic API-style JSON payload.

**Setup:**
```bash
cat > /tmp/mission19/api-response.json << 'EOF'
{
  "status": "ok",
  "page": 1,
  "total": 3,
  "users": [
    {
      "id": 1,
      "username": "alice",
      "email": "alice@example.com",
      "role": "admin",
      "active": true,
      "last_login": "2024-07-10T09:22:00Z",
      "tags": ["devops", "python"]
    },
    {
      "id": 2,
      "username": "bob",
      "email": "bob@example.com",
      "role": "viewer",
      "active": false,
      "last_login": "2024-05-01T14:00:00Z",
      "tags": ["frontend"]
    },
    {
      "id": 3,
      "username": "carol",
      "email": "carol@example.com",
      "role": "admin",
      "active": true,
      "last_login": "2024-07-15T11:30:00Z",
      "tags": ["devops", "go"]
    }
  ]
}
EOF
```

**Steps:**
1. Get the response status:
   ```bash
   jq -r '.status' /tmp/mission19/api-response.json
   ```
2. List all usernames:
   ```bash
   jq -r '.users[].username' /tmp/mission19/api-response.json
   ```
3. Get active users only:
   ```bash
   jq '[.users[] | select(.active == true) | {id, username, role}]' /tmp/mission19/api-response.json
   ```
4. Get all admin emails (raw, one per line):
   ```bash
   jq -r '.users[] | select(.role == "admin") | .email' /tmp/mission19/api-response.json
   ```
5. Check if any user has the "devops" tag:
   ```bash
   jq '[.users[] | select(.tags | contains(["devops"]))] | length > 0' /tmp/mission19/api-response.json
   ```
6. Build a summary — just id, username, active:
   ```bash
   jq '.users | map({id, username, active})' /tmp/mission19/api-response.json
   ```
7. Output as TSV for shell scripting (raw, tab-separated):
   ```bash
   jq -r '.users[] | [.id, .username, .role, .active] | @tsv' /tmp/mission19/api-response.json
   ```

**Hint:** `.users[]` `select(.active == true)` `contains(["tag"])` `@tsv` `map({id, username})`

**Self-check:** Step 3 — alice and carol (both active). Step 4 — alice@example.com and carol@example.com. Step 7 outputs 3 tab-separated rows.

---

## Exercise 7: Practical Shell Integration

**Goal:** Combine jq with shell variables, loops, and other tools.

**Steps:**
1. Use jq output in a shell variable:
   ```bash
   APP=$(jq -r '.app' /tmp/mission19/config.json)
   echo "App is: $APP"
   ```
2. Loop over jq output line by line:
   ```bash
   while IFS= read -r username; do
     echo "Processing user: $username"
   done < <(jq -r '.users[].username' /tmp/mission19/api-response.json)
   ```
3. Build JSON from a shell variable:
   ```bash
   NAME="dave"
   jq -n --arg name "$NAME" '{username: $name, active: true}'
   ```
4. Use `--argjson` for numeric arguments:
   ```bash
   THRESHOLD=50
   jq --argjson t "$THRESHOLD" '[.[] | select(.cpu > $t)]' /tmp/mission19/servers.json
   ```
5. Combine jq with curl (simulate with cat):
   ```bash
   cat /tmp/mission19/api-response.json \
     | jq -r '.users[] | select(.role == "admin") | .email' \
     | sort
   ```
6. Validate JSON — exit code 0 if valid, non-zero if not:
   ```bash
   echo '{"valid": true}' | jq '.' > /dev/null && echo "valid JSON" || echo "invalid"
   echo 'not json'        | jq '.' > /dev/null && echo "valid JSON" || echo "invalid"
   ```
7. Compact JSON for storing in a variable or piping:
   ```bash
   jq -c '.users[0]' /tmp/mission19/api-response.json
   ```

**Hint:** `jq -r` `jq -n --arg name "$VAR"` `--argjson` `jq -c` `jq '.' > /dev/null`

**Self-check:** Step 3 should output `{"username":"dave","active":true}`. Step 6 — first command exits 0 ("valid JSON"), second exits non-zero ("invalid").

---

Cleanup:
```bash
rm -rf /tmp/mission19
```

Mark complete:
```bash
make done N=19
```
