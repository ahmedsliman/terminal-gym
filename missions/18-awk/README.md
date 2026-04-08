# Mission 18: awk

## Concept

`awk` is a line-oriented text processing language built into every Unix system. It reads input line by line, splits each line into fields, and runs rules you define. It is the right tool when `grep` finds things but you need to compute, reformat, or summarise them.

## Learning Goals

By the end of this mission you will be able to:

- Understand awk's execution model: pattern { action } rules
- Split lines into fields and access them with `$1`, `$2`, `$NF`
- Use built-in variables: `NR`, `NF`, `FS`, `OFS`, `RS`
- Filter lines with pattern conditions
- Do arithmetic and string operations on fields
- Use `BEGIN` and `END` blocks for setup and summaries
- Write multi-rule awk programs
- Use awk as a replacement for common cut + grep + wc pipelines

## Key Concepts

### Execution Model

awk reads input one **record** at a time (default: one line). For each record it checks every rule in order:

```
pattern { action }
pattern { action }
...
```

- If the pattern matches, the action runs.
- If you omit the pattern, the action runs on every line.
- If you omit the action, the default action is `{ print }`.

### Fields

Each record is split into fields by the **field separator** (default: any whitespace).

| Variable | Meaning |
|----------|---------|
| `$0` | The whole record (entire line) |
| `$1` | First field |
| `$2` | Second field |
| `$NF` | Last field (`NF` = number of fields) |
| `$(NF-1)` | Second-to-last field |

```bash
echo "one two three" | awk '{ print $2 }'   # → two
echo "one two three" | awk '{ print $NF }'  # → three
```

### Built-in Variables

| Variable | Default | Meaning |
|----------|---------|---------|
| `FS` | `" "` | Field separator (split input) |
| `OFS` | `" "` | Output field separator (between fields on print) |
| `RS` | `"\n"` | Record separator |
| `NR` | — | Current record number (line count so far) |
| `NF` | — | Number of fields in the current record |
| `FILENAME` | — | Name of the current input file |

### Patterns

```bash
/regex/          # lines matching a regex
$3 > 100         # numeric comparison on a field
NR == 1          # first line only
NR % 2 == 0      # even-numbered lines
BEGIN            # runs once before any input
END              # runs once after all input
```

### Arithmetic & Strings

```bash
awk '{ sum += $1 } END { print sum }'       # sum a column
awk '{ print $1 * $2 }'                     # multiply two fields
awk '{ print toupper($1) }'                 # uppercase
awk '{ print length($0) }'                  # line length
awk '{ printf "%-10s %5d\n", $1, $2 }'      # formatted output
```

### Field Separator

```bash
awk -F: '{ print $1 }' /etc/passwd          # colon-delimited
awk -F, '{ print $2 }' file.csv             # CSV
awk 'BEGIN { FS=":" } { print $1 }' /etc/passwd   # same, inside program
```

### Changing Fields

Assigning to a field rebuilds `$0` using `OFS`:

```bash
echo "a b c" | awk '{ $2 = "X"; print }'   # → a X c
echo "a:b:c" | awk -F: 'BEGIN{OFS="-"} { $2="X"; print }' # → a-X-c
```

### Common One-liners

```bash
awk 'NR==5'                            # print line 5
awk 'NR>=10 && NR<=20'                 # print lines 10-20
awk '!seen[$0]++'                      # remove duplicate lines
awk '{ print NF }'                     # count fields per line
awk 'END { print NR }'                 # count lines (like wc -l)
awk -F: '$3 >= 1000 { print $1 }' /etc/passwd   # users with UID ≥ 1000
```

## Notes

- awk variables are untyped — they are strings or numbers depending on context. `"3" + 4` is `7`.
- Unset variables are `0` (numeric) or `""` (string). No need to initialise counters.
- Use `print` (adds newline) vs `printf` (C-style format, no auto newline).
- `-F` sets the field separator. For tab: `awk -F'\t'` or `awk -F$'\t'`.
- `gawk` (GNU awk) extends the standard with extra functions (`strftime`, `gensub`, arrays of arrays). On most Linux systems, `awk` is `gawk`.

## Next

```bash
make exercises N=18
```
