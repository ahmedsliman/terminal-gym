#!/bin/bash
# Mission 19 — jq: Interactive Practice
set -uo pipefail
COURSE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"

init_mission "19" "jq" 1

step "Coming soon"
explain "This practice session is not yet written.
In the meantime, use:
  make mission   N=19   — read the concept brief
  make exercises N=19   — work through the exercises"

mission_complete
