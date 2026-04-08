# Solution — Mission 19: jq

---

## Exercise 1: Navigation and Basic Extraction

```bash
jq '.' /tmp/mission19/user.json
jq '.name' /tmp/mission19/user.json
jq '.address.city' /tmp/mission19/user.json
jq '.scores[0]' /tmp/mission19/user.json
jq '.scores[-1]' /tmp/mission19/user.json
jq -r '.name' /tmp/mission19/user.json
jq '.scores | length' /tmp/mission19/user.json
```

**Key insight:** `.` is the identity filter — it pretty-prints the input. Chain fields with `.` for nesting. Array indices are zero-based; negative indices count from the end. `-r` strips the JSON string quotes, giving you a bare string suitable for shell use. `length` works on arrays (count of elements), strings (byte length), and objects (number of keys).

---

## Exercise 2: Iterating and Filtering Arrays

```bash
jq '.[].name' /tmp/mission19/servers.json
jq -r '.[].name' /tmp/mission19/servers.json
jq '[.[] | select(.status == "running")]' /tmp/mission19/servers.json
jq -r '[.[] | select(.status == "running")] | .[].name' /tmp/mission19/servers.json
jq '[.[] | select(.cpu > 20)]' /tmp/mission19/servers.json
jq 'length' /tmp/mission19/servers.json
jq '[.[] | select(.status == "running")] | length' /tmp/mission19/servers.json
```

**Key insight:** `.[]` explodes an array into a stream of values — each element flows through the pipe independently. Wrap in `[…]` to collect the stream back into an array. `select(cond)` acts as a filter: only values where the condition is true pass through. Combining `.[]`, `select()`, and `[…]` is the idiomatic way to filter arrays in jq.

---

## Exercise 3: Transforming and Reshaping

```bash
jq '[.[] | {name, status}]' /tmp/mission19/servers.json
jq '[.[] | {host: .name, state: .status}]' /tmp/mission19/servers.json
jq '[.[] | . + {busy: (.cpu > 50)}]' /tmp/mission19/servers.json
jq 'map({name, cpu})' /tmp/mission19/servers.json
jq '[.[].name]' /tmp/mission19/servers.json
jq '[.[].region] | unique' /tmp/mission19/servers.json
```

**Key insight:** `{name, status}` is shorthand for `{name: .name, status: .status}` — jq infers the value from the current input. `. + {key: value}` merges a new field into the existing object. `map(expr)` is exactly equivalent to `[.[] | expr]` — use whichever reads more clearly. `unique` sorts and deduplicates a flat array.

---

## Exercise 4: Sorting, Grouping, and Aggregation

```bash
jq 'sort_by(.cpu)' /tmp/mission19/servers.json
jq 'sort_by(.cpu) | reverse' /tmp/mission19/servers.json
jq 'max_by(.cpu)' /tmp/mission19/servers.json
jq 'group_by(.region)' /tmp/mission19/servers.json
jq '[.[].cpu] | add' /tmp/mission19/servers.json
jq '[.[] | select(.status=="running") | .cpu] | add / length' /tmp/mission19/servers.json
jq '.[0] | keys' /tmp/mission19/servers.json
```

**Key insight:** `sort_by(.field)` always sorts ascending — pipe to `reverse` for descending. `max_by` and `min_by` return the whole object, not just the field value. `group_by(.field)` produces an array of arrays — each sub-array holds all objects sharing that field value (sorted). `add` on a number array sums it; dividing by `length` gives the average. `keys` returns sorted key names — useful for introspection.

---

## Exercise 5: Object Manipulation and del

```bash
jq 'del(.secret_key)' /tmp/mission19/config.json
jq '.version = "2.0.0"' /tmp/mission19/config.json
jq '. + {environment: "production"}' /tmp/mission19/config.json
jq '.database.host = "db.prod.internal"' /tmp/mission19/config.json
jq 'del(.secret_key, .debug)' /tmp/mission19/config.json
jq 'to_entries' /tmp/mission19/config.json
jq '{app, version}' /tmp/mission19/config.json
```

**Key insight:** `del()` accepts a path expression — it removes the field and returns the modified object (jq never mutates the original). `.field = value` is an update expression that also returns the whole modified object. `to_entries` converts `{"k": "v"}` to `[{"key": "k", "value": "v"}]` — pair it with `from_entries` to round-trip, or use `with_entries(expr)` to transform key-value pairs in one step.

---

## Exercise 6: Real-world API Response Processing

```bash
jq -r '.status' /tmp/mission19/api-response.json
jq -r '.users[].username' /tmp/mission19/api-response.json
jq '[.users[] | select(.active == true) | {id, username, role}]' /tmp/mission19/api-response.json
jq -r '.users[] | select(.role == "admin") | .email' /tmp/mission19/api-response.json
jq '[.users[] | select(.tags | contains(["devops"]))] | length > 0' /tmp/mission19/api-response.json
jq '.users | map({id, username, active})' /tmp/mission19/api-response.json
jq -r '.users[] | [.id, .username, .role, .active] | @tsv' /tmp/mission19/api-response.json
```

**Key insight:** Navigate into nested arrays with `.users[]` — this is equivalent to `.users | .[]`. `contains(["tag"])` checks that all elements of the argument appear in the input array. `@tsv` formats an array as a tab-separated line — combine with `-r` to get plain text (without the surrounding quotes that `@tsv` normally adds in JSON output). The `[.id, .username, .role, .active] | @tsv` pattern is the standard way to export JSON to shell-friendly tabular text.

---

## Exercise 7: Practical Shell Integration

```bash
APP=$(jq -r '.app' /tmp/mission19/config.json)
echo "App is: $APP"

while IFS= read -r username; do
  echo "Processing user: $username"
done < <(jq -r '.users[].username' /tmp/mission19/api-response.json)

NAME="dave"
jq -n --arg name "$NAME" '{username: $name, active: true}'

THRESHOLD=50
jq --argjson t "$THRESHOLD" '[.[] | select(.cpu > $t)]' /tmp/mission19/servers.json

cat /tmp/mission19/api-response.json \
  | jq -r '.users[] | select(.role == "admin") | .email' \
  | sort

echo '{"valid": true}' | jq '.' > /dev/null && echo "valid JSON" || echo "invalid"
echo 'not json'        | jq '.' > /dev/null && echo "valid JSON" || echo "invalid"

jq -c '.users[0]' /tmp/mission19/api-response.json
```

**Key insight:** Always use `-r` when capturing jq output into a shell variable — without it you get JSON-quoted strings (`"alice"` instead of `alice`). Use `--arg` for string shell variables and `--argjson` for numbers or booleans (it parses the value as JSON). `-n` (null input) lets you build JSON from scratch without reading stdin. `-c` (compact) outputs single-line JSON — useful when storing JSON in a variable or piping between tools. Validating JSON with `jq '.' > /dev/null` is the idiomatic zero-dependency check.

---

## Quick Reference

```bash
# Navigate
jq '.field'
jq '.nested.field'
jq '.[0]'  jq '.[-1]'
jq '.[1:3]'                        # slice

# Iterate
jq '.[]'
jq '.[].name'
jq '[.[] | expr]'                  # collect back to array

# Filter
jq '[.[] | select(.f == "v")]'
jq '[.[] | select(.n > 10)]'
jq '[.[] | select(.tags | contains(["x"]))]'

# Transform
jq 'map({name, cpu})'
jq '[.[] | {host: .name}]'
jq '[.[] | . + {busy: (.cpu > 50)}]'

# Aggregate
jq 'sort_by(.field)'
jq 'sort_by(.field) | reverse'
jq 'group_by(.field)'
jq '[.[].n] | add'
jq '[.[].n] | add / length'
jq 'unique'

# Edit objects
jq 'del(.key)'
jq '.key = "value"'
jq '. + {newkey: "val"}'
jq 'to_entries'

# Output
jq -r '.field'                     # raw (no quotes)
jq -c '.'                          # compact
jq -n --arg v "$VAR" '{k: $v}'    # build from shell var
jq --argjson n "$NUM" 'select(. > $n)'
jq -r '.[...] | @tsv'             # TSV for shell
```
