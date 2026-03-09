#!/bin/bash
# =============================================================================
#  lib/course.sh — Shared library for interactive practice sessions
# =============================================================================

# ── Colors ────────────────────────────────────────────────────────────────────
B='\033[1m'; D='\033[2m'; R='\033[0m'
RD='\033[31m'; GR='\033[32m'; YL='\033[33m'
BL='\033[34m'; MG='\033[35m'; CY='\033[36m'

# ── Runtime state ─────────────────────────────────────────────────────────────
MISSION_NUM=""
MISSION_NAME=""
STEP_NUM=0
STEP_TOTAL=0
STEP_TITLE=""     # set by step(), shown in compact headers
STEP_HINT=""      # set by set_hint() inside a step, shown via 'hint' command
ERRORS=0
RESUME_FROM=0
_STATE_DIR="${COURSE_ROOT}/.state"
_PRACTICE_PATH=""  # set by each practice.sh before sourcing this file

# ── Internal ──────────────────────────────────────────────────────────────────
_hr() {
  printf "  ${D}┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄${R}\n"
}

_compact_header() {
  printf "  ${D}Step ${STEP_NUM}/${STEP_TOTAL}  ·  ${STEP_TITLE}${R}\n"
  printf "  ${D}────────────────────────────────────────────────────────${R}\n\n"
}

_replaying() {
  [ "$RESUME_FROM" -gt 0 ] && [ "$STEP_NUM" -le "$RESUME_FROM" ]
}

# ── State ─────────────────────────────────────────────────────────────────────
_state_file() { echo "${_STATE_DIR}/mission-${MISSION_NUM}.state"; }

_save_state() {
  mkdir -p "$_STATE_DIR"
  printf "%d\n%d\n" "$STEP_NUM" "$ERRORS" > "$(_state_file)"
}

_load_state() {
  local f; f="$(_state_file)"
  [ -f "$f" ] || return 1
  RESUME_FROM=$(sed -n '1p' "$f")
  ERRORS=$(sed -n '2p' "$f")
}

_clear_state() { rm -f "$(_state_file)"; }

# =============================================================================
#  IN-SESSION COMMAND SYSTEM
#  Every read prompt ($ and "press enter") passes input through _is_meta().
#  Meta commands are handled inline and the prompt is re-shown.
# =============================================================================

# ── Help panel ────────────────────────────────────────────────────────────────
_meta_help() {
  clear
  printf "\n"
  printf "${B}${CY}  ╔══════════════════════════════════════════════════════════╗${R}\n"
  printf "${B}${CY}  ║${R}  ${B}IN-SESSION COMMANDS${R}                                      ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${D}Available at every prompt during practice${R}               ${B}${CY}║${R}\n"
  printf "${B}${CY}  ╠══════════════════════════════════════════════════════════╣${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${B}INFORMATION${R}                                              ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}help${R}  ${GR}?${R}        Show this panel                        ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}hint${R}          Show a hint for the current step           ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}status${R}        Show mission progress and error count      ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${B}NAVIGATION${R}                                               ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}skip${R}          Skip this exercise (move to the next)     ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}restart${R}       Repeat the current step from scratch      ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}goto N${R}        Jump to step N  (e.g. goto 5)             ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${B}EXIT${R}                                                     ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}q${R}  ${GR}quit${R}  ${GR}exit${R}  Save position and exit               ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${D}At \$ prompt: type any real shell command to run it${R}       ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${D}Empty Enter: skip the current exercise${R}                   ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${D}Ctrl+C: also saves position and exits${R}                   ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ╚══════════════════════════════════════════════════════════╝${R}\n"
  printf "\n"
}

# ── Status ────────────────────────────────────────────────────────────────────
_meta_status() {
  printf "\n"
  printf "  ${B}${CY}Mission${R}   ${MISSION_NUM} · ${MISSION_NAME}\n"
  printf "  ${B}${CY}Step${R}      ${STEP_NUM} / ${STEP_TOTAL}\n"
  # progress bar
  local filled=$(( STEP_NUM * 20 / STEP_TOTAL ))
  local empty=$(( 20 - filled ))
  local bar=""; for i in $(seq 1 "$filled" 2>/dev/null); do bar="${bar}█"; done
  local emp=""; for i in $(seq 1 "$empty"  2>/dev/null); do emp="${emp}░"; done
  printf "  ${B}${CY}Progress${R}  ${GR}${bar}${D}${emp}${R}\n"
  printf "  ${B}${CY}Errors${R}    ${ERRORS} missed check(s) so far\n"
  printf "\n"
}

# ── Hint ──────────────────────────────────────────────────────────────────────
_meta_hint() {
  printf "\n"
  if [ -n "$STEP_HINT" ]; then
    printf "  ${YL}${B}Hint for this step:${R}\n\n"
    while IFS= read -r line; do
      printf "  ${YL}  %s${R}\n" "$line"
    done <<< "$STEP_HINT"
  else
    printf "  ${D}No hint set for this step.${R}\n"
    printf "  ${D}Try: make hint N=${MISSION_NUM} for exercise hints.${R}\n"
  fi
  printf "\n"
}

# ── Restart ───────────────────────────────────────────────────────────────────
_meta_restart() {
  if [ -z "$_PRACTICE_PATH" ]; then
    printf "\n  ${YL}Restart not available (practice path not set).${R}\n\n"
    return
  fi
  local target=$(( STEP_NUM - 1 ))
  [ "$target" -lt 0 ] && target=0
  STEP_NUM=$target
  _save_state
  printf "\n  ${CY}Restarting step $((STEP_NUM + 1)) ...${R}\n\n"
  sleep 0.4
  exec bash "$_PRACTICE_PATH"
}

# ── Goto N ────────────────────────────────────────────────────────────────────
_meta_goto() {
  local n="$1"
  if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "$STEP_TOTAL" ]; then
    printf "\n  ${RD}Invalid step number '${n}'.${R}  ${D}Valid range: 1 – ${STEP_TOTAL}${R}\n\n"
    return
  fi
  if [ -z "$_PRACTICE_PATH" ]; then
    printf "\n  ${YL}goto not available (practice path not set).${R}\n\n"
    return
  fi
  local target=$(( n - 1 ))
  STEP_NUM=$target
  _save_state
  printf "\n  ${CY}Jumping to step ${n} ...${R}\n\n"
  sleep 0.4
  exec bash "$_PRACTICE_PATH"
}

# ── Dispatcher ────────────────────────────────────────────────────────────────
# Returns 0 if input was a meta command (handled — caller should re-prompt).
# Returns 1 if input is a regular command to process normally.
_is_meta() {
  local input="$1"
  case "$input" in
    "help"|"?")   _meta_help;                     return 0 ;;
    "hint")       _meta_hint;                     return 0 ;;
    "status")     _meta_status;                   return 0 ;;
    "skip")                                       return 2 ;;  # caller handles skip
    "restart")    _meta_restart;                  return 0 ;;
    "goto "*)     _meta_goto "${input#goto }";    return 0 ;;
    "q"|"quit"|"exit") _quit;                    return 0 ;;
    *)                                            return 1 ;;
  esac
}

# ── _read_try: looping read for $ prompts ─────────────────────────────────────
# Sets _TRY_CMD to the user's input. Returns 1 on skip, 0 on real command.
_TRY_CMD=""
_read_try() {
  while true; do
    printf "  ${B}${GR}\$${R} "
    local input; read -r input

    if [ -z "$input" ]; then
      _TRY_CMD=""; return 1   # empty = skip
    fi

    _is_meta "$input"
    local rc=$?
    if   [ $rc -eq 0 ]; then continue         # meta handled, re-show prompt
    elif [ $rc -eq 2 ]; then return 1          # skip command
    else _TRY_CMD="$input"; return 0           # real command
    fi
  done
}

# ── _read_pause: looping read for "press enter" prompts ───────────────────────
_read_pause() {
  local msg="${1:-Press Enter to continue (? for commands)}"
  while true; do
    printf "  ${D}${msg}${R}  "
    local input; read -r input
    _is_meta "$input"
    local rc=$?
    [ $rc -eq 0 ] && continue    # meta handled, re-show pause
    [ $rc -eq 2 ] && return 1    # skip
    return 0                      # Enter or any other = advance
  done
}

# =============================================================================
#  QUIT HANDLER
# =============================================================================
_quit() {
  _save_state
  printf "\n\n"
  printf "${B}${YL}  Paused — Step ${STEP_NUM}/${STEP_TOTAL}${R}\n\n"
  printf "  Your position is saved.\n\n"
  printf "  Resume:      ${GR}make practice N=${MISSION_NUM}${R}\n"
  printf "  Mark done:   ${GR}make done     N=${MISSION_NUM}${R}\n"
  printf "  Read brief:  ${GR}make mission  N=${MISSION_NUM}${R}\n"
  printf "\n"
  exit 0
}
trap '_quit' INT

# =============================================================================
#  PUBLIC API
# =============================================================================

# ── init_mission ──────────────────────────────────────────────────────────────
init_mission() {
  MISSION_NUM="$1"
  MISSION_NAME="$2"
  STEP_TOTAL="$3"
  STEP_NUM=0; ERRORS=0; RESUME_FROM=0; STEP_HINT=""

  local saved_step=0
  if _load_state 2>/dev/null; then
    saved_step=$RESUME_FROM
  fi

  clear
  printf "\n"
  printf "${B}${CY}  ╔══════════════════════════════════════════════════════╗${R}\n"
  printf "${B}${CY}  ║${R}  ${B}PRACTICE · Mission ${MISSION_NUM} · ${MISSION_NAME}${R}\n"
  printf "${B}${CY}  ║${R}  ${D}${STEP_TOTAL} steps  ·  type ${B}?${D} at any prompt for commands${R}\n"
  printf "${B}${CY}  ╚══════════════════════════════════════════════════════╝${R}\n"
  printf "\n"

  if [ "$saved_step" -gt 0 ] && [ "$saved_step" -lt "$STEP_TOTAL" ]; then
    printf "  ${YL}Saved position found:${R} Step ${saved_step} / ${STEP_TOTAL}\n\n"
    printf "  Resume from step ${saved_step}? [Y/n] "
    local ans; read -r ans
    if [[ "$ans" =~ ^[Nn]$ ]]; then
      RESUME_FROM=0; _clear_state
      printf "\n  Starting from the beginning ...\n\n"
    else
      RESUME_FROM=$saved_step
      printf "\n  Fast-forwarding ...\n"
    fi
  else
    printf "  ${D}Press Enter to begin (? for commands)${R}  "
    local ans; read -r ans
    _is_meta "$ans" 2>/dev/null || true
    printf "\n"
  fi
}

# ── step ──────────────────────────────────────────────────────────────────────
step() {
  STEP_NUM=$((STEP_NUM + 1))
  STEP_HINT=""       # reset hint each step
  _save_state

  if _replaying; then
    printf "\r  ${D}skipping step ${STEP_NUM}/${STEP_TOTAL} ...${R}   "
    return
  fi

  if [ "$RESUME_FROM" -gt 0 ] && [ "$STEP_NUM" -gt "$RESUME_FROM" ]; then
    RESUME_FROM=0
    clear
    printf "\n  ${GR}↩  Resumed at step ${STEP_NUM}/${STEP_TOTAL}${R}\n\n"
    sleep 0.5
  fi

  STEP_TITLE="$1"

  clear
  printf "\n"
  local dots=""
  for i in $(seq 1 "$STEP_TOTAL"); do
    if   [ "$i" -lt  "$STEP_NUM" ]; then dots="${dots}${GR}●${R}"
    elif [ "$i" -eq "$STEP_NUM"  ]; then dots="${dots}${B}${CY}●${R}"
    else                                  dots="${dots}${D}·${R}"
    fi
    [ "$i" -lt "$STEP_TOTAL" ] && dots="${dots} "
  done
  printf "  %b\n" "$dots"
  printf "  ${D}Step ${STEP_NUM}/${STEP_TOTAL}  ·  Mission ${MISSION_NUM} · ${MISSION_NAME}${R}\n\n"
  printf "  ${B}${CY}▌${R} ${B}${STEP_TITLE}${R}\n\n"
}

# ── set_hint ──────────────────────────────────────────────────────────────────
# Call inside a step to define what 'hint' shows:
#   set_hint "Use type -a to check where a command comes from."
set_hint() { STEP_HINT="$1"; }

# ── explain ───────────────────────────────────────────────────────────────────
explain() {
  _replaying && return
  while IFS= read -r line; do printf "  %s\n" "$line"; done <<< "$1"
  printf "\n"
}

# ── demo ──────────────────────────────────────────────────────────────────────
# Runs a command on a fresh screen and pauses.
demo() {
  _replaying && return
  local cmd="$1" label="${2:-}"
  clear; _compact_header
  [ -n "$label" ] && printf "  ${D}${label}${R}\n\n"
  printf "  ${B}${GR}\$${R} ${B}${cmd}${R}\n"
  _hr
  eval "$cmd" 2>&1 | while IFS= read -r line; do printf "  %s\n" "$line"; done
  _hr; printf "\n"
  _read_pause
}

# ── show ──────────────────────────────────────────────────────────────────────
# Like demo but no pause — used right before try() on the same screen.
show() {
  _replaying && return
  local cmd="$1" label="${2:-}"
  clear; _compact_header
  [ -n "$label" ] && printf "  ${D}${label}${R}\n\n"
  printf "  ${B}${GR}\$${R} ${B}${cmd}${R}\n"
  _hr
  eval "$cmd" 2>&1 | while IFS= read -r line; do printf "  %s\n" "$line"; done
  _hr; printf "\n"
}

# ── try ───────────────────────────────────────────────────────────────────────
try() {
  _replaying && return
  local prompt="${1:-Your turn:}" hint="${2:-}"
  clear; _compact_header
  printf "  ${YL}▶  ${B}${prompt}${R}\n"
  [ -n "$hint" ] && printf "  ${D}   hint: ${hint}${R}\n"
  printf "\n"

  _read_try
  local skipped=$?

  if [ "$skipped" -eq 1 ] || [ -z "$_TRY_CMD" ]; then
    printf "\n  ${D}  ↳ skipped${R}\n\n"
    _read_pause; return
  fi

  printf "\n  ${D}ran:${R}  ${B}${_TRY_CMD}${R}\n"
  _hr
  local output exit_code=0
  output=$(eval "$_TRY_CMD" 2>&1) || exit_code=$?
  [ -z "$output" ] && printf "  ${D}(no output)${R}\n" \
    || echo "$output" | while IFS= read -r line; do printf "  %s\n" "$line"; done
  _hr
  [ "$exit_code" -eq 0 ] \
    && printf "  ${GR}✓  exit 0 — success${R}\n" \
    || printf "  ${RD}✗  exit ${exit_code}${R}  ${D}— non-zero exit${R}\n"
  printf "\n"
  _read_pause
}

# ── try_match ─────────────────────────────────────────────────────────────────
try_match() {
  _replaying && return
  local prompt="$1" hint="$2" expected="$3"
  clear; _compact_header
  printf "  ${YL}▶  ${B}${prompt}${R}\n"
  printf "  ${D}   hint: ${hint}${R}\n\n"

  _read_try
  local skipped=$?

  if [ "$skipped" -eq 1 ] || [ -z "$_TRY_CMD" ]; then
    printf "\n  ${D}  ↳ skipped${R}\n\n"
    _read_pause; return
  fi

  printf "\n  ${D}ran:${R}  ${B}${_TRY_CMD}${R}\n"
  _hr
  local output exit_code=0
  output=$(eval "$_TRY_CMD" 2>&1) || exit_code=$?
  [ -z "$output" ] && printf "  ${D}(no output)${R}\n" \
    || echo "$output" | while IFS= read -r line; do printf "  %s\n" "$line"; done
  _hr
  if echo "$output" | grep -q "$expected"; then
    printf "  ${GR}✓  Correct${R}  ${D}— output contains '${expected}'${R}\n"
  else
    printf "  ${YL}~  Expected output to contain '${expected}'${R}\n"
    printf "  ${D}   Run it again, or press Enter to move on${R}\n"
    ERRORS=$((ERRORS + 1)); _save_state
  fi
  printf "\n"
  _read_pause
}

# ── tip / note / warn ─────────────────────────────────────────────────────────
tip()  { _replaying && return; printf "  ${YL}┃ Tip${R}   %s\n\n" "$1"; }
note() { _replaying && return; printf "  ${CY}┃ Note${R}  %s\n\n" "$1"; }
warn() { _replaying && return; printf "  ${RD}┃ !${R}    %s\n\n" "$1"; }

# ── checkpoint ────────────────────────────────────────────────────────────────
checkpoint() {
  _replaying && return
  clear; _compact_header
  printf "  ${MG}${B}?  Checkpoint${R}\n\n"
  printf "  ${MG}%s${R}\n\n" "$1"
  _read_pause "Think, then press Enter to reveal the answer (? for commands)"
  printf "\n  ${GR}${B}Answer${R}\n\n"
  while IFS= read -r line; do printf "  ${GR}  %s${R}\n" "$line"; done <<< "$2"
  printf "\n"
  _read_pause
}

# ── section ───────────────────────────────────────────────────────────────────
section() {
  _replaying && return
  printf "\n  ${B}${BL}▌ ${R}${B}$1${R}\n\n"
}

# ── mission_complete ──────────────────────────────────────────────────────────
mission_complete() {
  _clear_state
  clear
  printf "\n"
  printf "${B}${GR}  ╔══════════════════════════════════════════════════════╗${R}\n"
  printf "${B}${GR}  ║                                                      ║${R}\n"
  printf "${B}${GR}  ║   ✓  MISSION ${MISSION_NUM} COMPLETE                           ║${R}\n"
  printf "${B}${GR}  ║                                                      ║${R}\n"
  printf "${B}${GR}  ╚══════════════════════════════════════════════════════╝${R}\n"
  printf "\n"
  [ "$ERRORS" -eq 0 ] \
    && printf "  ${GR}Clean run — all checks passed.${R}\n" \
    || printf "  ${YL}${ERRORS} check(s) didn't match.${R}  ${D}Review: make exercises N=${MISSION_NUM}${R}\n"
  printf "\n"
  printf "  ${D}What's next:${R}\n\n"
  printf "    ${GR}make done      N=${MISSION_NUM}${R}   mark this mission complete\n"
  printf "    ${GR}make next${R}              open the next mission\n"
  printf "    ${GR}make exercises N=${MISSION_NUM}${R}   re-read the exercises\n"
  printf "\n"
}
