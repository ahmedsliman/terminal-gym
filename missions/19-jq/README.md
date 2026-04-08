# Mission 19: jq

## Concept

`jq` is a command-line JSON processor. It does for JSON what `awk` does for text: filter, transform, and reshape structured data using a concise expression language. It is essential for working with APIs, config files, and any modern tool that outputs JSON.

## Learning Goals

By the end of this mission you will be able to:

- Navigate JSON with `.field` and `.[index]` expressions
- Iterate arrays with `.[]`
- Filter arrays with `select()`
- Transform and reshape objects with `{key: .value}`
- Pipe expressions together with `|`
- Use built-in functions: `length`, `keys`, `has`, `type`, `sort_by`, `group_by`, `unique`, `map`
- Format and compact JSON output
- Extract values from real-world API responses

## Key Concepts

### Basic Navigation

```bash
# Identity — output as-is, pretty-printed
echo '{"name":"alice","age":30}' | jq '.'

# Get a field
echo '{"name":"alice","age":30}' | jq '.name'        # → "alice"
echo '{"name":"alice","age":30}' | jq '.age'         # → 30

# Nested field
echo '{"user":{"name":"alice"}}' | jq '.user.name'   # → "alice"

# Array index
echo '[10, 20, 30]' | jq '.[0]'                      # → 10
echo '[10, 20, 30]' | jq '.[-1]'                     # → 30 (last)
echo '[10, 20, 30]' | jq '.[1:3]'                    # → [20, 30] (slice)
```

### Iterating Arrays

```bash
# Explode array — output each element as a separate value
echo '[1,2,3]' | jq '.[]'

# Iterate array of objects
echo '[{"name":"a"},{"name":"b"}]' | jq '.[].name'

# Collect results back into an array
echo '[1,2,3]' | jq '[.[] | . * 2]'   # → [2, 4, 6]
```

### The Pipe `|`

Pipe passes the output of one expression as input to the next:

```bash
echo '{"users":[{"name":"alice"},{"name":"bob"}]}' \
  | jq '.users | .[0] | .name'     # → "alice"
```

### Filtering with `select()`

```bash
echo '[1,5,2,8,3]' | jq '[.[] | select(. > 3)]'   # → [5, 8]

# Filter array of objects
echo '[{"name":"alice","active":true},{"name":"bob","active":false}]' \
  | jq '[.[] | select(.active == true) | .name]'   # → ["alice"]
```

### Constructing Objects and Arrays

```bash
# Build a new object from fields
echo '{"name":"alice","age":30,"dept":"eng"}' \
  | jq '{user: .name, years: .age}'   # → {"user": "alice", "years": 30}

# Map over array — shorthand for [.[] | expr]
echo '[1,2,3]' | jq 'map(. * 10)'    # → [10, 20, 30]

# Map objects
echo '[{"name":"alice","age":30},{"name":"bob","age":25}]' \
  | jq 'map({name, doubled_age: (.age * 2)})'
```

### Useful Built-in Functions

| Function | What it does |
|----------|-------------|
| `length` | length of array/string, or number of object keys |
| `keys` | array of object keys, sorted |
| `values` | array of object values |
| `has("key")` | true if object has the key |
| `type` | type string: "object", "array", "string", "number", "boolean", "null" |
| `to_entries` | `[{key, value}]` — useful for iterating object fields |
| `from_entries` | reverse of `to_entries` |
| `sort` | sort array |
| `sort_by(.field)` | sort array of objects by a field |
| `group_by(.field)` | group array of objects into nested arrays |
| `unique` / `unique_by(.f)` | deduplicate |
| `add` | sum numbers / concatenate strings / merge objects in an array |
| `any(cond)` / `all(cond)` | test if any/all elements match |
| `min_by(.f)` / `max_by(.f)` | find min/max by field |
| `flatten` | flatten nested arrays |
| `del(.field)` | remove a field |
| `@base64` / `@csv` / `@tsv` / `@sh` | format strings |

### Raw Output and Compact Mode

```bash
jq -r '.name'       # raw output — no quotes around strings
jq -c '.'           # compact output (single line)
jq -r -c '.'        # compact + raw
jq -n '{a:1}'       # null input — build JSON without reading stdin
```

### Reading from Files

```bash
jq '.' file.json
jq '.users[]' data.json | jq -r '.name'
```

## Notes

- jq expressions are **filters** — they take input and produce output.
- `?` suppresses errors on missing fields: `.foo?` returns `null` instead of erroring if `.foo` doesn't exist.
- `//` is the alternative operator: `.foo // "default"` returns `"default"` if `.foo` is null or false.
- `@base64`, `@csv`, `@tsv` format strings for interpolation: `"\(.name | @base64)"`.
- For very large JSON files, use `--stream` or `jq -n 'first(inputs)'` to avoid loading everything into memory.

## Next

```bash
make exercises N=19
```
