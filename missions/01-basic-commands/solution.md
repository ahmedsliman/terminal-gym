# Solutions — Mission 01: Basic Commands

> Try hard before reading this. The struggle is where learning happens.

---

## Exercise 1

```bash
whoami                  # your username
hostname                # machine name
pwd                     # current working directory
ip a                    # full network info
hostname -I             # quick IP list
```

---

## Exercise 2

```bash
ls ~                    # basic list
ls -l ~                 # long format: permissions, owner, size, date
ls -la ~                # include hidden files (dotfiles)
ls -lah ~               # human-readable file sizes
ls -lahF ~              # classify: / = dir, * = exec, @ = symlink
```

---

## Exercise 3

```bash
type -a ls              # → ls is aliased to..., ls is /usr/bin/ls
type -a cd              # → cd is a shell builtin
type -a echo            # → echo is a shell builtin, echo is /usr/bin/echo
man cd                  # → No manual entry (it's a built-in)
help cd                 # → Built-in help page
```

`cd` is built into the shell. `man` only covers external programs, not built-ins. Use `help <builtin>` instead.

---

## Exercise 4

```bash
mkdir -p lab/{docs,logs}
touch lab/docs/{file{1..5}.txt,readme.md}
echo "hello world" > lab/logs/app.log
ls -lR lab/
ls lab/docs | wc -l     # → 6
```

---

## Exercise 5

```bash
true; echo $?           # → 0
false; echo $?          # → 1
ls /nonexistent; echo $?  # → 2 (or similar non-zero)
ls /etc; echo $?          # → 0
```

---

## Exercise 6

```bash
mkdir -p lab/bin
cat > lab/bin/hello << 'EOF'
#!/bin/bash
echo "Hello, $(whoami)! You are on $(hostname)."
EOF

chmod +x lab/bin/hello
export PATH="$PWD/lab/bin:$PATH"
hello
type -a hello           # → hello is /path/to/lab/bin/hello
```
