#!/bin/bash
# =============================================================================
#  Mission 08 — File Management
# =============================================================================
set -uo pipefail
COURSE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"

SCRATCH="/tmp/mission08"
mkdir -p "$SCRATCH"

init_mission "08" "File Management" 9

# =============================================================================
step "mkdir -p — create nested directories"
set_hint "mkdir -p creates all missing parent directories in one command.
Try: mkdir -p /tmp/mission08/app/{frontend,backend}/{src,tests}"

explain "mkdir creates a directory. Without -p, every parent must already exist.
With -p, bash creates the entire path in one shot — and never errors
if the directory already exists.

  mkdir -p a/b/c/d        creates all four levels
  mkdir -p existing/dir   no error — already exists

Combine with brace expansion to build full project skeletons instantly."

demo "mkdir -p ${SCRATCH}/project/{frontend,backend}/{src,tests} && find ${SCRATCH}/project -type d | sort" \
     "Build a two-service project layout in one command:"

demo "mkdir -p ${SCRATCH}/project/frontend/src && echo 'exit 0'" \
     "Run mkdir -p on a path that already exists — no error:"

try "Create a directory tree: /tmp/mission08/logs/{2024,2025}/{jan,feb,mar}" \
    "mkdir -p /tmp/mission08/logs/{2024,2025}/{jan,feb,mar} && find /tmp/mission08/logs -type d | sort"

checkpoint \
  "What happens if you run 'mkdir a/b/c' and 'a' does not exist?" \
  "mkdir fails with 'No such file or directory'.
It will not create intermediate directories unless you pass -p.
With -p: mkdir -p a/b/c  — all three levels are created automatically."

# =============================================================================
step "cp — copying files"
set_hint "cp source dest copies a file.
cp -r srcdir/ destdir/ copies a whole directory tree."

explain "cp copies files and directories.

  cp file.txt backup.txt         copy one file
  cp file1 file2 dir/            copy multiple files into a directory
  cp -r src/ dest/               recursive — required for directories
  cp -p file dest                preserve timestamps and permissions
  cp -v file dest                verbose — print each file copied

Without -r, cp refuses to copy a directory."

demo "echo 'config data' > ${SCRATCH}/config.conf && cp ${SCRATCH}/config.conf ${SCRATCH}/config.bak && ls -l ${SCRATCH}/config*" \
     "Copy a single file and verify both exist:"

demo "cp -r ${SCRATCH}/project/frontend ${SCRATCH}/project/frontend-backup && find ${SCRATCH}/project -maxdepth 2 -type d | sort" \
     "Recursive copy of a directory:"

demo "cp -v ${SCRATCH}/config.conf ${SCRATCH}/config.v2.conf" \
     "-v shows what is being copied:"

try "Copy the entire /tmp/mission08/project/backend directory to /tmp/mission08/project/backend-snapshot" \
    "cp -r /tmp/mission08/project/backend /tmp/mission08/project/backend-snapshot && ls /tmp/mission08/project/"

note "cp -r src/ dst/ (trailing slash on src) copies the *contents* of src into dst.
cp -r src dst/ (no trailing slash) copies the src directory itself into dst."

# =============================================================================
step "mv — move and rename"
set_hint "mv renames a file or directory. No -r flag needed for directories.
Try: mv /tmp/mission08/config.bak /tmp/mission08/config.old"

explain "mv both renames and moves. There is no separate rename command.

  mv old.txt new.txt          rename a file
  mv file.txt subdir/         move into a directory
  mv dir1/ dir2/              rename a directory (no -r needed)
  mv *.log archive/           move multiple files at once

mv is atomic on the same filesystem — either it fully succeeds or
nothing changes. Across filesystems it copies then deletes."

demo "mv ${SCRATCH}/config.bak ${SCRATCH}/config.old && ls -l ${SCRATCH}/config*" \
     "Rename a file:"

demo "mkdir -p ${SCRATCH}/archive && mv ${SCRATCH}/config.old ${SCRATCH}/archive/ && ls ${SCRATCH}/archive/" \
     "Move a file into a directory:"

demo "mv ${SCRATCH}/project/frontend-backup ${SCRATCH}/project/frontend-v1 && ls ${SCRATCH}/project/" \
     "Rename a directory (no -r required):"

try "Rename /tmp/mission08/config.v2.conf to /tmp/mission08/config.final.conf" \
    "mv /tmp/mission08/config.v2.conf /tmp/mission08/config.final.conf && ls /tmp/mission08/config*"

# =============================================================================
step "rm — delete files and directories"
set_hint "rm deletes files permanently — no Recycle Bin.
rm -r deletes a directory and everything inside it."

explain "rm removes files. There is no undo.

  rm file.txt           delete one file
  rm file1 file2        delete multiple files
  rm -i file.txt        interactive — prompt before each deletion
  rm -r dir/            recursive — delete directory and all contents
  rm -rf dir/           recursive + force — no prompts, ignores errors

rm -rf is powerful and irreversible. Always double-check the path."

demo "echo 'temp' > ${SCRATCH}/deleteme.txt && ls ${SCRATCH}/deleteme.txt && rm ${SCRATCH}/deleteme.txt && ls ${SCRATCH}/deleteme.txt 2>&1 || true" \
     "Create and delete a file:"

demo "mkdir -p ${SCRATCH}/junk/a/b && touch ${SCRATCH}/junk/a/b/file.txt && ls -R ${SCRATCH}/junk && rm -r ${SCRATCH}/junk && ls ${SCRATCH}/" \
     "rm -r removes a whole tree:"

warn "rm has no undo. 'rm -rf \$DIR' where DIR is an empty variable becomes
'rm -rf /' — which tries to erase the entire filesystem.
Always verify your variable is not empty: [ -n \"\$DIR\" ] && rm -rf \"\$DIR\""

tip "Use rm -i for an interactive prompt: rm -i file.txt
Or alias rm='rm -i' in your ~/.bashrc for safer default behaviour."

try "Delete the file /tmp/mission08/archive/config.old" \
    "rm /tmp/mission08/archive/config.old && ls /tmp/mission08/archive/"

# =============================================================================
step "Hard links — ln"
set_hint "ln target linkname creates a hard link.
Both names share the same inode. Verify with ls -li."

explain "A hard link is a second directory entry pointing to the SAME inode —
the same data block on disk. Neither entry is the 'original'.

  ln original.txt hardlink.txt    create a hard link

Properties:
  - Shares the inode — ls -li shows identical inode numbers
  - Deleting one name leaves the other fully intact
  - The file data is removed only when ALL hard links are deleted
  - Cannot cross filesystem boundaries (different partitions)
  - Cannot link directories (on most Linux systems)"

demo "echo 'shared content' > ${SCRATCH}/original.txt && ln ${SCRATCH}/original.txt ${SCRATCH}/hardlink.txt && ls -li ${SCRATCH}/original.txt ${SCRATCH}/hardlink.txt" \
     "Create a hard link — notice matching inode numbers and link count 2:"

demo "echo 'appended via hardlink' >> ${SCRATCH}/hardlink.txt && cat ${SCRATCH}/original.txt" \
     "Write through the hard link — original sees the change immediately:"

demo "rm ${SCRATCH}/original.txt && cat ${SCRATCH}/hardlink.txt && ls -li ${SCRATCH}/hardlink.txt" \
     "Delete the original — data survives through the hard link:"

try "Create a hard link from /tmp/mission08/config.conf to /tmp/mission08/config.hardlink, then check they share an inode" \
    "ln /tmp/mission08/config.conf /tmp/mission08/config.hardlink && ls -li /tmp/mission08/config.conf /tmp/mission08/config.hardlink"

checkpoint \
  "A file has a hard link count of 3. You delete one of the names.
How many copies of the data exist on disk now?" \
  "Still one — the same data block, now referenced by 2 names.
Hard link count drops from 3 to 2.
The actual data is only freed when ALL hard links (all names) are removed
and no process has the file open."

# =============================================================================
step "Symbolic links — ln -s"
set_hint "ln -s target linkname creates a symlink.
ls -l shows the arrow: linkname -> target
readlink linkname prints the target path."

explain "A symbolic link (symlink) is a special file that stores a PATH
pointing to another file or directory. It is a pointer, not a copy.

  ln -s /etc/hosts my-hosts-link    create a symlink
  ls -l my-hosts-link               shows: my-hosts-link -> /etc/hosts
  readlink my-hosts-link            prints: /etc/hosts
  readlink -f my-hosts-link         resolves to absolute canonical path

Properties:
  - Has its own inode — different from the target
  - Can cross filesystem boundaries
  - Can link to directories
  - Becomes a dangling (broken) link if the target is deleted or moved
  - Permissions shown are the link's own (usually lrwxrwxrwx)"

demo "ln -s ${SCRATCH}/config.conf ${SCRATCH}/config-link && ls -l ${SCRATCH}/config-link" \
     "Create a symlink — notice the l at the start and the arrow:"

demo "readlink ${SCRATCH}/config-link" \
     "readlink shows the target path:"

demo "cat ${SCRATCH}/config-link" \
     "Reading through the symlink reads the real file:"

demo "ln -s /tmp/mission08/project/backend ${SCRATCH}/current-backend && ls -l ${SCRATCH}/current-backend && ls ${SCRATCH}/current-backend/" \
     "Symlink to a directory — you can ls through it:"

try "Create a symlink called /tmp/mission08/hardlink-alias that points to /tmp/mission08/config.hardlink, then run readlink on it" \
    "ln -s /tmp/mission08/config.hardlink /tmp/mission08/hardlink-alias && readlink /tmp/mission08/hardlink-alias"

# =============================================================================
step "Inspecting links — ls -l, readlink, file"
set_hint "ls -li shows inode numbers — hard links share them.
file linkname tells you what a symlink points to.
readlink -f resolves the full chain."

explain "Three tools help you understand links:

  ls -l     the first character: '-' file, 'd' dir, 'l' symlink
            symlinks show: name -> target
  ls -li    adds the inode number — hard links have matching inodes
  readlink  prints the raw target stored in a symlink
  readlink -f  follows the full chain to the final real path
  file      identifies file type, including symlinks and their targets"

demo "ls -l ${SCRATCH}/config-link ${SCRATCH}/config.conf ${SCRATCH}/config.hardlink" \
     "ls -l — note l prefix for symlink, and the link counts:"

demo "ls -li ${SCRATCH}/config.conf ${SCRATCH}/config.hardlink" \
     "ls -li — hard links share the same inode number:"

demo "file ${SCRATCH}/config-link ${SCRATCH}/config.conf ${SCRATCH}/config.hardlink" \
     "file — describes the type of each path:"

demo "readlink -f ${SCRATCH}/hardlink-alias" \
     "readlink -f — resolves the full chain through all symlinks:"

show "ln -s ${SCRATCH}/config-link ${SCRATCH}/chain-link && readlink ${SCRATCH}/chain-link && readlink -f ${SCRATCH}/chain-link" \
     "Chained symlinks — readlink vs readlink -f:"

try_match "Show the inode numbers for /tmp/mission08/config.conf and /tmp/mission08/config.hardlink" \
          "ls -li /tmp/mission08/config.conf /tmp/mission08/config.hardlink" \
          "config"

checkpoint \
  "What is the difference between a hard link and a symbolic link?" \
  "Hard link:   a second directory entry pointing to the SAME inode.
               Cannot cross filesystems. Cannot link directories.
               Survives deletion of the original name.

Symbolic link: a special file storing a PATH to the target.
               Has its own inode. Can cross filesystems.
               Can point to directories. Breaks if the target is removed."

# =============================================================================
step "du — measuring directory disk usage"
set_hint "du -sh dir/ gives the total size of a directory in human-readable form.
du -sh * shows the size of every item in the current directory."

explain "du (disk usage) measures how much space directories and files occupy.

  du -sh path/        total size, human-readable (K, M, G)
  du -sh *            size of every item in the current directory
  du -sh /var/log     size of the log directory
  du -ah path/        like -sh but shows every file, not just totals
  du -d 1 /var        depth limit — only one level deep

-s   summary (total only — don't recurse and show subdirs)
-h   human-readable (1K, 45M, 2G)
-a   all files, not just directory totals"

demo "du -sh ${SCRATCH}/" \
     "Total size of our scratch directory:"

demo "du -sh ${SCRATCH}/*" \
     "Size of each item inside the scratch directory:"

demo 'du -sh /var/log 2>/dev/null' \
     "How much space /var/log uses:"

demo 'du -sh /usr/*/  2>/dev/null | sort -rh | head -5' \
     "Largest first-level subdirectories of /usr:"

try "Show the size of each item in /tmp (suppress permission errors)" \
    "du -sh /tmp/* 2>/dev/null | head -10"

note "du counts disk blocks used, not the sum of file sizes.
A file using 1 byte still consumes at least one block (usually 4 KB).
That is why du may report more than you expect."

# =============================================================================
step "df — filesystem free space and finding large files"
set_hint "df -h shows all mounted filesystems with human-readable sizes.
du -sh /* 2>/dev/null | sort -rh | head  finds what is eating your disk."

explain "df (disk free) shows filesystem-level usage — the whole partition.

  df -h           all mounted filesystems
  df -h /         just the root filesystem
  df -h /home     filesystem containing /home
  df -hT          same, with filesystem type column

Finding large consumers — combine du, sort, and head:

  du -sh /* 2>/dev/null | sort -rh | head       top items under /
  du -sh /var/*/ 2>/dev/null | sort -rh | head  top items under /var

sort -h  sorts human-readable sizes correctly (1K < 1M < 1G)
sort -rh reverses — largest first
2>/dev/null  silences 'permission denied' errors"

demo 'df -h' \
     "Filesystem usage overview:"

demo 'df -h /' \
     "Root filesystem specifically:"

demo 'du -sh /* 2>/dev/null | sort -rh | head -10' \
     "Top 10 largest top-level directories:"

demo 'du -sh /usr/*/ 2>/dev/null | sort -rh | head -5' \
     "Largest subdirectories inside /usr:"

try_match "Show disk space usage for the filesystem that holds /var" \
          "df -h /var" \
          "Filesystem"

checkpoint \
  "Your disk is nearly full. What two commands would you run first to
diagnose which directory is consuming the most space?" \
  "Step 1 — see the overall picture:
  df -h
  This shows which filesystem is full and how much space remains.

Step 2 — drill down to find the culprit:
  du -sh /* 2>/dev/null | sort -rh | head
  Then repeat inside the largest directory:
  du -sh /var/* 2>/dev/null | sort -rh | head
  Keep narrowing until you find the large file or directory."

# =============================================================================
# Cleanup
rm -rf "$SCRATCH"

mission_complete
