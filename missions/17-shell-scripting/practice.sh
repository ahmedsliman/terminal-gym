#!/bin/bash
# Mission 17 — Shell Scripting Intro: Interactive Practice
# TODO: fill in steps using lib/course.sh helpers
set -uo pipefail
COURSE_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
_PRACTICE_PATH="${BASH_SOURCE[0]}"
source "${COURSE_ROOT}/lib/course.sh"

init_mission "17" "Shell Scripting Intro" 5

step "Coming soon"
explain "This practice session is not yet written.
In the meantime, use:
  make mission   N=17   — read the concept brief
  make exercises N=17   — work through the exercises"

mission_complete
