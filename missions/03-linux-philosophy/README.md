# Mission 03 — Linux Philosophy

## Learning Goals

- Understand the core Unix philosophy and why it still matters
- Recognize text streams as the universal interface between tools
- Explore the "everything is a file" model (`/proc`, `/dev`, `/sys`)
- Compose simple tools into powerful pipelines
- Know the difference between a program and a script

---

## The Unix Philosophy

In 1978, Doug McIlroy summarized the Unix philosophy in three rules:

> 1. Write programs that do one thing and do it well.
> 2. Write programs to work together.
> 3. Write programs that handle text streams, because that is a universal interface.

These rules explain why Linux tools feel so different from GUI applications. Each tool is small and sharp — it solves one problem. Power comes from combining them.

---

## Text Streams Are the Universal Interface

Almost every Linux tool reads text from **stdin** and writes text to **stdout**. This is why you can chain them with pipes:

```bash
cat /etc/passwd | grep root | cut -d: -f1,3
```

Each tool does one step. The pipe `|` passes the output of one tool as the input of the next. No files, no temporary state — just a stream of text flowing through.

---

## Everything Is a File

In Linux, "file" means more than a document on disk. The kernel exposes almost everything through the file interface:

| Path | What it is |
|------|-----------|
| `/etc/hostname` | Your machine's name (a real file) |
| `/dev/sda` | Your hard drive (a device file) |
| `/dev/null` | A black hole — discards anything written to it |
| `/dev/zero` | Produces infinite null bytes when read |
| `/proc/cpuinfo` | Live CPU info from the kernel |
| `/proc/meminfo` | Live memory info |
| `/proc/self/fd/` | File descriptors of the current process |
| `/sys/class/net/` | Network interfaces |

You can `cat` any of these files the same way you would read a normal text file.

---

## /proc — The Kernel's Window

`/proc` is a virtual filesystem. Nothing in it is stored on disk — the kernel generates the content on demand when you read it.

```bash
cat /proc/cpuinfo      # CPU model, cores, flags
cat /proc/meminfo      # RAM usage
cat /proc/uptime       # seconds since boot
cat /proc/self/status  # info about the current process
ls /proc/              # one directory per running process (by PID)
```

---

## Composability in Practice

These are all equivalent ways to count the users on your system:

```bash
wc -l /etc/passwd                          # count lines directly
cat /etc/passwd | wc -l                    # same, through a pipe
grep -c '' /etc/passwd                     # grep counts matches
awk 'END{print NR}' /etc/passwd            # awk counts records
```

The Unix philosophy says: don't build a single "user counter" tool. Instead, build `wc`, `grep`, `awk` — each one general — and let the user compose them.

---

## Key Commands Introduced

| Command | What it does |
|---------|-------------|
| `cat /proc/cpuinfo` | Read kernel-generated CPU info |
| `wc -l file` | Count lines in a file |
| `wc -w file` | Count words |
| `wc -c file` | Count bytes |
| `cut -d: -f1 /etc/passwd` | Extract field 1 using `:` as delimiter |
| `sort file` | Sort lines alphabetically |
| `uniq file` | Remove consecutive duplicate lines |
| `tr a-z A-Z` | Translate characters (lowercase to uppercase) |

---

## What's Next

Mission 04 covers the Terminal & Shell — the difference between the emulator you see and the program interpreting your commands.

To start the interactive session:

```bash
make practice N=03
```
