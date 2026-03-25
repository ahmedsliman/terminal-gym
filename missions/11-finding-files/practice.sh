#!/bin/bash
# Mission 11 — Finding Files: Interactive Practice
# TODO: fill in steps using lib/course.sh helpers
set -uo pipefail
COURSE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"

init_mission "11" "Finding Files" 1

step "Coming soon"
explain "This practice session is not yet written.
In the meantime, use:
  make mission   N=11   — read the concept brief
  make exercises N=11   — work through the exercises"

mission_complete
