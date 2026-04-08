#!/bin/bash
# =============================================================================
#  lib/course.sh — Shared library for interactive practice sessions
#  Three-panel TUI with vim-style keyboard navigation
# =============================================================================

# ── Colors ────────────────────────────────────────────────────────────────────
B='\033[1m'; D='\033[2m'; R='\033[0m'
RD='\033[31m'; GR='\033[32m'; YL='\033[33m'
BL='\033[34m'; MG='\033[35m'; CY='\033[36m'

# ── Panel layout state ───────────────────────────────────────────────────────
USE_PANELS="${USE_PANELS:-0}"
PANEL_WIDTH_LEFT="${PANEL_WIDTH_LEFT:-20}"

# ── Panel dimensions (computed at runtime) ───────────────────────────────────
TERM_ROWS=0
TERM_COLS=0
LEFT_COLS=0
RIGHT_COLS=0
MID_ROW=0
TOP_ROWS=0
BOTTOM_ROWS=0
STATUS_ROW=0

# ── Render tracking for partial updates ────────────────────────────────────
_PANEL_INITIALIZED=0
_PANEL_NEEDS_BORDERS=1
_PANEL_NEEDS_TREE=1
_PANEL_NEEDS_EXERCISES=1
_PANEL_NEEDS_TERMINAL=1
_PANEL_NEEDS_STATUS=1

_mark_all_dirty() {
  _PANEL_NEEDS_BORDERS=1
  _PANEL_NEEDS_TREE=1
  _PANEL_NEEDS_EXERCISES=1
  _PANEL_NEEDS_TERMINAL=1
  _PANEL_NEEDS_STATUS=1
}

_mark_tree_dirty() { _PANEL_NEEDS_TREE=1; _PANEL_NEEDS_BORDERS=1; }
_mark_exercises_dirty() { _PANEL_NEEDS_EXERCISES=1; }
_mark_terminal_dirty() { _PANEL_NEEDS_TERMINAL=1; }
_mark_focus_dirty() { _PANEL_NEEDS_BORDERS=1; _PANEL_NEEDS_STATUS=1; }

# ── Focus and navigation state ───────────────────────────────────────────────
FOCUSED_PANEL="terminal"
PANEL_MODE_ACTIVE=0

# ── Lesson tree state ───────────────────────────────────────────────────────
TREE_ITEMS=()
TREE_EXPANDED=()
TREE_CURSOR=0
TREE_SCROLL=0
CURRENT_LESSON=""

# ── Exercise panel state ─────────────────────────────────────────────────────
EXERCISES_SCROLL=0
EXERCISES_LINES=()

# ── Terminal panel state ─────────────────────────────────────────────────────
TERM_LINES=()
TERM_LINE_COUNT=0
_SHELL_SESSION_ACTIVE=0
_SHELL_PID=0

# ── PTY session state ─────────────────────────────────────────────────────────
_PTY_CWD_FILE=""
_YESNO_RESULT=""

# ── Content tracking for partial redraws ───────────────────────────────────
_TREE_CONTENT_HASH=""
_EXERCISES_CONTENT_HASH=""
_TERMINAL_STEP_HASH=""
_TREE_VISIBLE_HASH=""

_hash_content() {
  printf "%s" "$1" | md5sum 2>/dev/null | cut -d' ' -f1 || echo "$1"
}

# ── Search state ─────────────────────────────────────────────────────────────
SEARCH_MODE=0
SEARCH_QUERY=""
SEARCH_RESULTS=()
SEARCH_POS=0

# ── Runtime state ─────────────────────────────────────────────────────────────
MISSION_NUM=""
MISSION_NAME=""
STEP_NUM=0
STEP_TOTAL=0
STEP_TITLE=""
STEP_HINT=""
ERRORS=0
RESUME_FROM=0
_STATE_DIR="${COURSE_ROOT}/.state"
_PRACTICE_PATH=""

# =============================================================================
#  PANEL MODE FUNCTIONS
# =============================================================================

_panel_init() {
  TERM_ROWS=$(tput lines 2>/dev/null || echo 24)
  TERM_COLS=$(tput cols 2>/dev/null || echo 80)
  if [ "$TERM_ROWS" -lt 20 ] || [ "$TERM_COLS" -lt 80 ]; then
    PANEL_MODE_ACTIVE=0
    return 1
  fi
  PANEL_MODE_ACTIVE=1
  LEFT_COLS=20
  RIGHT_COLS=$(( TERM_COLS - LEFT_COLS - 1 ))
  _calculate_layout
  _parse_all_missions
  _init_shell_session
  _PANEL_INITIALIZED=1
  _mark_all_dirty
  return 0
}

_calculate_layout() {
  MID_ROW=$(( TERM_ROWS / 2 ))
  TOP_ROWS=$(( MID_ROW - 1 ))
  BOTTOM_ROWS=$(( TERM_ROWS - MID_ROW - 1 ))
  STATUS_ROW=$TERM_ROWS
}

_update_layout_for_content() {
  if [ ${#EXERCISES_LINES[@]} -gt 0 ]; then
    local content_lines=${#EXERCISES_LINES[@]}
    local available_rows=$((TERM_ROWS - 4))
    local needed=$((content_lines + 3))
    local min_exercises=8
    local max_exercises=$((TERM_ROWS - 10))
    [ $min_exercises -gt $max_exercises ] && min_exercises=$max_exercises
    
    if [ $needed -lt $min_exercises ]; then
      needed=$min_exercises
    elif [ $needed -gt $max_exercises ]; then
      needed=$max_exercises
    fi
    
    local new_mid=$((needed + 1))
    if [ $new_mid -lt 10 ]; then new_mid=10
    elif [ $new_mid -gt $((TERM_ROWS - 8)) ]; then new_mid=$((TERM_ROWS - 8))
    fi
    
    MID_ROW=$new_mid
    TOP_ROWS=$((MID_ROW - 1))
    BOTTOM_ROWS=$((TERM_ROWS - MID_ROW - 1))
  else
    _calculate_layout
  fi
}

# ── Shell Session Management ─────────────────────────────────────────────────

_init_shell_session() {
  # Initialize persistent bash session using coproc
  # This keeps shell state across commands (cd, variables, etc.)
  if [ "$_SHELL_SESSION_ACTIVE" -eq 1 ]; then
    return 0
  fi
  
  if [ "$BASH_VERSINFO" -lt 4 ]; then
    _SHELL_SESSION_ACTIVE=0
    return 1
  fi
  
  coproc SHELL_SESSION { bash --noprofile --norc 2>&1; }
  _SHELL_PID=$!
  _SHELL_SESSION_ACTIVE=1

  return 0
}

_exec_in_session() {
  local cmd="$1"
  
  if [ "$_SHELL_SESSION_ACTIVE" -ne 1 ]; then
    # Fallback to eval if session not active
    eval "$cmd" 2>&1
    return $?
  fi
  
  # Send command to persistent shell
  echo "$cmd" >&${SHELL_SESSION[1]}
  
  # Read output until we get a marker
  local output=""
  local line=""
  
  # Send marker command to know when output ends
  echo "__TERMINAL_GYM_MARKER__" >&${SHELL_SESSION[1]}
  
  while IFS= read -r -t 0.5 line <&${SHELL_SESSION[0]}; do
    if [ "$line" = "__TERMINAL_GYM_MARKER__" ]; then
      break
    fi
    output+="$line"$'\n'
  done
  
  # Remove trailing newline
  output="${output%$'\n'}"
  
  echo "$output"
  return 0
}

_terminate_shell_session() {
  if [ "$_SHELL_SESSION_ACTIVE" -eq 1 ] && [ "$_SHELL_PID" -gt 0 ]; then
    kill $_SHELL_PID 2>/dev/null
    _SHELL_SESSION_ACTIVE=0
  fi
}

_ensure_pty_state() {
  if [ -z "$_PTY_CWD_FILE" ] || [ ! -f "$_PTY_CWD_FILE" ]; then
    _PTY_CWD_FILE=$(mktemp /tmp/tgym_cwd.XXXXXX)
    printf '%s' "$HOME" > "$_PTY_CWD_FILE"
  fi
}

_enter_real_terminal() {
  local hint="${1:-}" demo_cmd="${2:-}"
  _ensure_pty_state
  local initial_cwd
  initial_cwd=$(cat "$_PTY_CWD_FILE" 2>/dev/null)
  [ -d "$initial_cwd" ] || initial_cwd="$HOME"

  if ! command -v python3 >/dev/null 2>&1; then
    _term_add "${RD}Error: python3 not found — cannot open real terminal${R}"
    _panel_draw_all; _read_pause; return
  fi

  # Switch to alternate screen so panels are preserved underneath
  tput smcup 2>/dev/null || true
  clear

  # ── Context header ────────────────────────────────────────────────────────
  printf "${B}${CY}  terminal-gym${R}  ${D}·  Mission ${MISSION_NUM} · ${MISSION_NAME}${R}\n"
  if [ -n "$STEP_TITLE" ]; then
    printf "${B}  Step ${STEP_NUM}/${STEP_TOTAL}${R}  ${D}·  ${STEP_TITLE}${R}\n"
  fi
  if [ -n "$demo_cmd" ]; then
    printf "${D}  demo command:${R}  ${B}${demo_cmd}${R}\n"
  elif [ -n "$hint" ]; then
    printf "${YL}  hint: ${hint}${R}\n"
  fi
  printf "${D}  ──────────────────────────────────────────────────${R}\n"
  printf "${D}  type 'exit' or press Ctrl+D to return to the course${R}\n\n"

  local header_rows=6
  [ -n "$STEP_TITLE" ]  && header_rows=$((header_rows + 1))
  [ -n "$demo_cmd" ] || [ -n "$hint" ] && header_rows=$((header_rows + 1))
  local shell_rows=$(( TERM_ROWS - header_rows ))
  [ "$shell_rows" -lt 3 ] && shell_rows=3

  LINES=$shell_rows \
  COLUMNS=$TERM_COLS \
  INITIAL_CWD="$initial_cwd" \
  STATE_FILE="$_PTY_CWD_FILE" \
  DEMO_CMD="$demo_cmd" \
  python3 "${COURSE_ROOT}/lib/real-shell.py"

  # Restore panels
  tput rmcup 2>/dev/null || true
  _mark_all_dirty
  _panel_draw_all
}

_panel_clear() { tput clear 2>/dev/null || clear; }
_panel_goto() { tput cup $(($1 - 1)) $(($2 - 1)) 2>/dev/null; }
_panel_hide_cursor() { tput civis 2>/dev/null; }
_panel_show_cursor() { tput cnorm 2>/dev/null; }

_panel_draw_border() {
  local sr=$1 sc=$2 rows=$3 cols=$4 title=$5
  local er=$((sr + rows - 1)) ec=$((sc + cols - 1))
  _panel_goto $sr $sc
  printf "${D}+"
  if [ -n "$title" ]; then
    printf "${B}${CY} %s ${D}" "$title"
    local tl=$(( ${#title} + 2 )) dc=$(( cols - tl - 1 ))
    [ "$dc" -lt 0 ] && dc=0
    printf '%*s' "$dc" | tr ' ' '-'
  else
    printf '%*s' "$((cols - 2))" | tr ' ' '-'
  fi
  printf "+${R}"
  local r
  for ((r = sr + 1; r < er; r++)); do
    _panel_goto $r $sc; printf "${D}|${R}"
    _panel_goto $r $ec; printf "${D}|${R}"
  done
  _panel_goto $er $sc
  printf "${D}+"
  printf '%*s' "$((cols - 2))" | tr ' ' '-'
  printf "+${R}"
}

_panel_draw_divider() {
  if [ "$1" = "v" ]; then
    local r
    for ((r = 1; r <= TERM_ROWS - 1; r++)); do
      _panel_goto $r $((LEFT_COLS + 1))
      printf "${D}|${R}"
    done
  elif [ "$1" = "h" ]; then
    local c
    for ((c = LEFT_COLS + 2; c <= TERM_COLS - 1; c++)); do
      _panel_goto $MID_ROW $c; printf "${D}-${R}"
    done
  fi
}

_get_progress() {
  local total=$(ls -d "${COURSE_ROOT}/missions"/[0-9]*-*/ 2>/dev/null | wc -l)
  local completed=0
  if [ -f "${COURSE_ROOT}/progress.md" ]; then
    completed=$(grep -c "^DONE:" "${COURSE_ROOT}/progress.md" 2>/dev/null || echo 0)
  fi
  echo "${completed}/${total}"
}

_draw_status_bar() {
  local progress=$(_get_progress)
  
  _panel_goto $STATUS_ROW 1
  printf "${D}+"
  printf '%*s' "$((TERM_COLS - 2))" | tr ' ' '-'
  printf "+${R}"
  _panel_goto $STATUS_ROW 2
  
  case "$FOCUSED_PANEL" in
    tree)      printf "${B}${YL}[TREE]${R}      Tab:switch  j/k:nav  1-3:jump  ?:help  q:quit  ${D}progress: ${progress}${R}" ;;
    exercises) printf "${B}${GR}[EXERCISES]${R}  Tab:switch  j/k:scroll  1-3:jump  ?:help  q:quit  ${D}progress: ${progress}${R}" ;;
    terminal)  printf "${B}${CY}[TERMINAL]${R}   Tab:switch  type commands  1-3:jump  ?:help  q:quit  ${D}progress: ${progress}${R}" ;;
  esac
}

_parse_all_missions() {
  local md="${COURSE_ROOT}/missions"
  TREE_ITEMS=()
  TREE_EXPANDED=()
  local dir
  for dir in $(ls -d "$md"/*/ 2>/dev/null | sort); do
    local num=$(basename "$dir" | cut -d'-' -f1)
    local name=$(basename "$dir" | sed 's/^[0-9]*-//' | tr '-' ' ')
    name=$(echo "$name" | awk '{for(i=1;i<=NF;i++) $i=toupper(substr($i,1,1)) substr($i,2)}1')
    TREE_ITEMS+=("M:${num}:${name}")
    local readme="${dir}README.md"
    if [ -f "$readme" ]; then
      local heading
      while IFS= read -r heading; do
        heading=$(echo "$heading" | sed 's/^##[[:space:]]*//' | sed 's/[[:space:]]*$//')
        [ -n "$heading" ] && TREE_ITEMS+=("L:${num}:${heading}")
      done < <(grep '^## ' "$readme")
    fi
    TREE_EXPANDED+=("0")
  done
  _TREE_CONTENT_HASH=$(_hash_content "${TREE_ITEMS[*]}")
}

_get_visible_tree_items() {
  local result=()
  local total=${#TREE_ITEMS[@]} i=0 showing=0 midx=-1
  while [ $i -lt $total ]; do
    local item="${TREE_ITEMS[$i]}"
    local type="${item%%:*}"
    if [ "$type" = "M" ]; then
      midx=$((midx + 1)); showing=1
      result+=("$i:$item")
    elif [ "$type" = "L" ] && [ $showing -eq 1 ]; then
      if [ "${TREE_EXPANDED[$midx]}" = "1" ]; then
        result+=("$i:$item")
      fi
    fi
    i=$((i + 1))
  done
  echo "${result[@]}"
}

_render_tree() {
  local max_lines=$((TOP_ROWS - 2))
  local visible_items=($(_get_visible_tree_items))
  local vis_count=${#visible_items[@]}

  [ $TREE_SCROLL -lt 0 ] && TREE_SCROLL=0
  [ $TREE_SCROLL -gt $((vis_count - max_lines)) ] && TREE_SCROLL=$((vis_count - max_lines))
  [ $TREE_SCROLL -lt 0 ] && TREE_SCROLL=0
  [ $TREE_CURSOR -ge $vis_count ] && TREE_CURSOR=$((vis_count - 1))
  [ $TREE_CURSOR -lt 0 ] && TREE_CURSOR=0

  if [ $TREE_CURSOR -lt $TREE_SCROLL ]; then TREE_SCROLL=$TREE_CURSOR
  elif [ $TREE_CURSOR -ge $((TREE_SCROLL + max_lines)) ]; then
    TREE_SCROLL=$((TREE_CURSOR - max_lines + 1))
  fi

  _panel_goto 2 2
  if [ "$FOCUSED_PANEL" = "tree" ]; then printf "${B}${YL}> MISSIONS${R}"
  else printf "${B}${GR}MISSIONS${R}"; fi

  local r
  for ((r = 3; r <= TOP_ROWS - 1; r++)); do
    _panel_goto $r 2
    printf '%*s' "$((LEFT_COLS - 2))" ""
  done

  local row=3 vi=$TREE_SCROLL midx=-1 showing=0
  while [ $vi -lt $vis_count ] && [ $row -le $((TOP_ROWS - 1)) ]; do
    local entry="${visible_items[$vi]}"
    local item="${entry#*:}"
    local type="${item%%:*}" rest="${item#*:}"
    local num="${rest%%:*}" label="${rest#*:}"

    if [ "$type" = "M" ]; then
      midx=$((midx + 1)); showing=1
      local expanded="${TREE_EXPANDED[$midx]}"
      local is_cursor=0; [ $vi -eq $TREE_CURSOR ] && is_cursor=1
      _panel_goto $row 2
      if [ $is_cursor -eq 1 ]; then printf "${B}${YL}> ${num} ${label}${R}"
      else printf "${B}${CY}>${R} ${D}${num}${R} ${label}"; fi
    elif [ "$type" = "L" ] && [ $showing -eq 1 ]; then
      if [ "${TREE_EXPANDED[$midx]}" = "1" ]; then
        local is_cursor=0; [ $vi -eq $TREE_CURSOR ] && is_cursor=1
        _panel_goto $row 2
        if [ $is_cursor -eq 1 ]; then printf "${D}  ${YL}> ${label}${R}"
        else printf "${D}  > ${label}"; fi
      fi
    fi
    row=$((row + 1))
    vi=$((vi + 1))
  done
}

_load_exercises() {
  EXERCISES_LINES=()
  if [ -n "$CURRENT_LESSON" ]; then
    local num="${CURRENT_LESSON%%-*}"
    local md="${COURSE_ROOT}/missions"
    local dir=$(ls -d "$md/${num}-"* 2>/dev/null | head -1)
    local ex="${dir}/exercises.md"
    if [ -f "$ex" ]; then
      while IFS= read -r line; do EXERCISES_LINES+=("$line"); done < "$ex"
    fi
  fi
  _EXERCISES_CONTENT_HASH=$(_hash_content "${EXERCISES_LINES[*]}")
  _update_layout_for_content
}

_render_exercises() {
  local max_lines=$((TOP_ROWS - 3))
  local total=${#EXERCISES_LINES[@]}
  [ $EXERCISES_SCROLL -lt 0 ] && EXERCISES_SCROLL=0
  [ $EXERCISES_SCROLL -gt $((total - max_lines)) ] && EXERCISES_SCROLL=$((total - max_lines))
  [ $EXERCISES_SCROLL -lt 0 ] && EXERCISES_SCROLL=0

  _panel_goto 2 $((LEFT_COLS + 3))
  if [ "$FOCUSED_PANEL" = "exercises" ]; then printf "${B}${YL}> EXERCISES${R}"
  else printf "${B}${GR}EXERCISES${R}"; fi
  if [ -n "$CURRENT_LESSON" ]; then printf " ${D}— ${CURRENT_LESSON}${R}"
  else printf " ${D}— Select a mission${R}"; fi

  local r
  for ((r = 3; r <= TOP_ROWS - 1; r++)); do
    _panel_goto $r $((LEFT_COLS + 3)); printf '%*s' "$((RIGHT_COLS - 3))" ""
  done

  if [ $total -eq 0 ]; then
    _panel_goto 4 $((LEFT_COLS + 3)); printf "${D}Select a mission to view exercises${R}"
    return
  fi

  local max_len=$((RIGHT_COLS - 5)) display_row=3 li=$EXERCISES_SCROLL
  while [ $li -lt $total ] && [ $display_row -le $((TOP_ROWS - 2)) ]; do
    local line="${EXERCISES_LINES[$li]}"
    [ ${#line} -gt $max_len ] && line="${line:0:$((max_len - 1))}…"
    _panel_goto $display_row $((LEFT_COLS + 3))
    if [[ "$line" =~ ^##[[:space:]] ]]; then printf "${B}${YL}%s${R}" "${line#### }"
    elif [[ "$line" =~ ^--- ]]; then printf "${D}%s${R}" "$(printf '%*s' "$max_len" | tr ' ' '-')"
    elif [[ "$line" =~ ^\*\* ]]; then printf "${B}%s${R}" "$line"
    elif [[ "$line" =~ ^\` ]]; then printf "${GR}%s${R}" "$line"
    elif [[ "$line" =~ ^[0-9]+\. ]]; then printf "  ${YL}%s${R}" "$line"
    elif [[ "$line" =~ ^- ]]; then printf "  ${CY}*${R}${D}${line#-}${R}"
    else printf "${D}%s${R}" "$line"; fi
    display_row=$((display_row + 1))
    li=$((li + 1))
  done
}

_render_terminal() {
  # last_content: last scrollable content row (row TERM_ROWS-2 is reserved for the prompt)
  local last_content=$((TERM_ROWS - 3))
  local fill=$((RIGHT_COLS - 3))   # safe fill width — stays left of the right border
  local max_line=$((RIGHT_COLS - 4))  # max visible chars per content line

  _panel_goto $((MID_ROW + 1)) $((LEFT_COLS + 3))
  printf '%*s' "$fill" ""
  _panel_goto $((MID_ROW + 1)) $((LEFT_COLS + 3))
  if [ "$FOCUSED_PANEL" = "terminal" ]; then printf "${B}${YL}> TERMINAL${R}"
  else printf "${B}${CY}TERMINAL${R}"; fi

  local r
  for ((r = MID_ROW + 2; r <= last_content; r++)); do
    _panel_goto $r $((LEFT_COLS + 3)); printf '%*s' "$fill" ""
  done

  local row=$((MID_ROW + 2))
  if [ -n "$STEP_TITLE" ]; then
    _panel_goto $row $((LEFT_COLS + 3))
    printf "${B}${CY}Step ${STEP_NUM}/${STEP_TOTAL}${R} ${D}· ${MISSION_NAME}${R}"
    row=$((row + 1))
    _panel_goto $row $((LEFT_COLS + 3))
    printf "${B}> ${STEP_TITLE}${R}"
    row=$((row + 1))

    local dots="" max_dots=$((RIGHT_COLS / 2)) sd=$STEP_TOTAL
    [ $sd -gt $max_dots ] && sd=$max_dots
    for i in $(seq 1 "$sd"); do
      if   [ "$i" -lt  "$STEP_NUM" ]; then dots="${dots}${GR}*${R}"
      elif [ "$i" -eq "$STEP_NUM"  ]; then dots="${dots}${B}${CY}*${R}"
      else                                  dots="${dots}${D}o${R}"; fi
      [ "$i" -lt "$sd" ] && dots="${dots} "
    done
    _panel_goto $row $((LEFT_COLS + 3))
    printf "  %b" "$dots"
    row=$((row + 1))
  fi

  local i=0 total=${#TERM_LINES[@]}
  local avail=$((last_content - row + 1))
  local start=0
  [ $total -gt $avail ] && start=$((total - avail))
  while [ $i -lt $start ]; do i=$((i + 1)); done
  while [ $i -lt $total ] && [ $row -le $last_content ]; do
    local raw="${TERM_LINES[$i]}"
    local visible; visible=$(printf '%b' "$raw" | sed $'s/\033\\[[0-9;]*[mKHJABCDfu]//g' 2>/dev/null)
    _panel_goto $row $((LEFT_COLS + 3))
    if [ ${#visible} -le $max_line ]; then
      printf "%b" "$raw"
    else
      printf "%s…" "${visible:0:$((max_line - 1))}"
    fi
    row=$((row + 1))
    i=$((i + 1))
  done
}

_panel_draw_all() {
  if [ "$_PANEL_INITIALIZED" -eq 0 ]; then return; fi
  
  _panel_hide_cursor
  if [ "$_PANEL_NEEDS_BORDERS" -eq 1 ]; then
    tput clear 2>/dev/null || clear
    tput cup 0 0 2>/dev/null
    _panel_draw_border 1 1 $((TERM_ROWS - 1)) $LEFT_COLS ""
    _panel_draw_border 1 $((LEFT_COLS + 2)) $TOP_ROWS $RIGHT_COLS ""
    _panel_draw_border $((MID_ROW + 1)) $((LEFT_COLS + 2)) $BOTTOM_ROWS $RIGHT_COLS ""
    _panel_draw_divider "v"
    _panel_draw_divider "h"
    _PANEL_NEEDS_BORDERS=0
  fi
  
  if [ "$_PANEL_NEEDS_TREE" -eq 1 ]; then
    _render_tree
    _PANEL_NEEDS_TREE=0
  fi
  
  if [ "$_PANEL_NEEDS_EXERCISES" -eq 1 ]; then
    _render_exercises
    _PANEL_NEEDS_EXERCISES=0
  fi
  
  if [ "$_PANEL_NEEDS_TERMINAL" -eq 1 ]; then
    _render_terminal
    _PANEL_NEEDS_TERMINAL=0
  fi
  
  if [ "$_PANEL_NEEDS_STATUS" -eq 1 ]; then
    _draw_status_bar
    _PANEL_NEEDS_STATUS=0
  fi
  
  # Clear the prompt row (TERM_ROWS-2, 1-indexed) so callers start with a clean line
  _panel_goto $((TERM_ROWS - 2)) $((LEFT_COLS + 3))
  printf '%*s' "$((RIGHT_COLS - 3))" ""
  tput cup $((TERM_ROWS - 3)) $((LEFT_COLS + 3))
  _panel_show_cursor
}

# ── Tree navigation ──────────────────────────────────────────────────────────
_tree_navigate() {
  local dir=$1
  local max_lines=$((TOP_ROWS - 2))
  local visible_items=($(_get_visible_tree_items))
  local vis_count=${#visible_items[@]}

  TREE_CURSOR=$((TREE_CURSOR + dir))
  [ $TREE_CURSOR -lt 0 ] && TREE_CURSOR=0
  [ $TREE_CURSOR -ge $vis_count ] && TREE_CURSOR=$((vis_count - 1))

  if [ $TREE_CURSOR -lt $TREE_SCROLL ]; then
    TREE_SCROLL=$TREE_CURSOR
  elif [ $TREE_CURSOR -ge $((TREE_SCROLL + max_lines)) ]; then
    TREE_SCROLL=$((TREE_CURSOR - max_lines + 1))
  fi
  [ $TREE_SCROLL -lt 0 ] && TREE_SCROLL=0
}

_tree_get_mission_idx() {
  local visible_items=($(_get_visible_tree_items))
  local entry="${visible_items[$TREE_CURSOR]}"
  [ -z "$entry" ] && echo "-1" && return
  local item="${entry#*:}" type="${item%%:*}"
  [ "$type" != "M" ] && echo "-1" && return
  local rest="${item#*:}" num="${rest%%:*}"
  local i=0 midx=0
  for t in "${TREE_ITEMS[@]}"; do
    if [[ "$t" == M:* ]]; then
      local tnum="${t#M:}"; tnum="${tnum%%:*}"
      if [ "$tnum" = "$num" ]; then echo "$midx"; return; fi
      midx=$((midx + 1))
    fi
  done
  echo "-1"
}

_tree_expand() {
  local midx=$(_tree_get_mission_idx)
  [ "$midx" = "-1" ] && return
  TREE_EXPANDED[$midx]="$1"
}

_tree_expand_all() {
  local i; for ((i = 0; i < ${#TREE_EXPANDED[@]}; i++)); do TREE_EXPANDED[$i]="1"; done
}

_tree_collapse_all() {
  local i; for ((i = 0; i < ${#TREE_EXPANDED[@]}; i++)); do TREE_EXPANDED[$i]="0"; done
}

_tree_select() {
  local visible_items=($(_get_visible_tree_items))
  local entry="${visible_items[$TREE_CURSOR]}"
  [ -z "$entry" ] && return
  local item="${entry#*:}" type="${item%%:*}" rest="${item#*:}"
  local num="${rest%%:*}" label="${rest#*:}"
  if [ "$type" = "M" ]; then
    local midx=$(_tree_get_mission_idx)
    if [ "${TREE_EXPANDED[$midx]}" = "1" ]; then TREE_EXPANDED[$midx]="0"
    else TREE_EXPANDED[$midx]="1"; fi
    CURRENT_LESSON="$num"; EXERCISES_SCROLL=0; _load_exercises
  elif [ "$type" = "L" ]; then
    CURRENT_LESSON="${num}-${label}"; EXERCISES_SCROLL=0; _load_exercises
  fi
}

_scroll_exercises() {
  local dir=$1 total=${#EXERCISES_LINES[@]}
  local max_lines=$((TOP_ROWS - 3))
  local ns=$((EXERCISES_SCROLL + dir))
  [ $ns -lt 0 ] && ns=0
  [ $ns -gt $((total - max_lines)) ] && ns=$((total - max_lines))
  [ $ns -lt 0 ] && ns=0
  EXERCISES_SCROLL=$ns
  _mark_exercises_dirty
}

_focus_next_panel() {
  case "$FOCUSED_PANEL" in
    tree)      FOCUSED_PANEL="exercises" ;;
    exercises) FOCUSED_PANEL="terminal" ;;
    terminal)  FOCUSED_PANEL="tree" ;;
  esac
  _mark_focus_dirty
}

_focus_prev_panel() {
  case "$FOCUSED_PANEL" in
    tree)      FOCUSED_PANEL="terminal" ;;
    exercises) FOCUSED_PANEL="tree" ;;
    terminal)  FOCUSED_PANEL="exercises" ;;
  esac
  _mark_focus_dirty
}

_focus_panel() {
  case "$1" in
    1|tree)      FOCUSED_PANEL="tree" ;;
    2|exercises) FOCUSED_PANEL="exercises" ;;
    3|terminal)  FOCUSED_PANEL="terminal" ;;
  esac
  _mark_focus_dirty
}

# ── Terminal buffer helpers ──────────────────────────────────────────────────
_term_add() {
  TERM_LINES+=("$1")
  local content="${TERM_LINES[*]}"
  _TERMINAL_CONTENT_HASH=$(_hash_content "$content")
  _PANEL_NEEDS_TERMINAL=1
}

_term_add_raw() {
  TERM_LINES+=("$1")
  _PANEL_NEEDS_TERMINAL=1
}

# ── Help overlay ─────────────────────────────────────────────────────────────
_show_help_overlay() {
  _panel_clear
  local mid=$((TERM_ROWS / 2 - 10))
  printf "\n"
  printf "${B}${CY}  ╔══════════════════════════════════════════════════════════╗${R}\n"
  printf "${B}${CY}  ║${R}  ${B}KEYBOARD SHORTCUTS${R}                                      ${B}${CY}║${R}\n"
  printf "${B}${CY}  ╠══════════════════════════════════════════════════════════╣${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${B}PANEL NAVIGATION${R}                                        ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}Tab${R} / ${GR}Shift+Tab${R}   Cycle focus forward/backward          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}1${R} / ${GR}2${R} / ${GR}3${R}          Focus tree / exercises / terminal     ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${B}TREE NAVIGATION${R}                                         ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}j${R} / ${GR}k${R} / ${GR}↑${R} / ${GR}↓${R}     Move cursor down/up                   ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}g${R} / ${GR}G${R}             Jump to top/bottom                    ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}Enter${R} / ${GR}Space${R}      Select / toggle expand                ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}+${R} / ${GR}-${R}              Expand all / collapse all             ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}Ctrl+d${R} / ${GR}Ctrl+u${R}   Half-page down/up                     ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}Ctrl+f${R} / ${GR}Ctrl+b${R}   Full-page down/up                     ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${B}EXERCISES PANEL${R}                                         ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}j${R} / ${GR}k${R} / ${GR}↑${R} / ${GR}↓${R}     Scroll down/up                        ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}g${R} / ${GR}G${R}             Jump to top/bottom                    ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}Ctrl+d${R} / ${GR}Ctrl+u${R}   Half-page scroll                      ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${B}TERMINAL PANEL${R}                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    Type commands normally; ↑/↓ for history         ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}Ctrl+l${R}            Clear terminal                        ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${B}GLOBAL${R}                                                  ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}Esc${R}               Focus terminal panel                  ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}?${R}                Show this help                        ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}q${R}                Quit session                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ╚══════════════════════════════════════════════════════════╝${R}\n"
  printf "\n"
  printf "  ${D}Press any key to return...${R}"
  read -rsn1
  _panel_draw_all
}

# ── Panel input handler (single-key mode for tree/exercises) ─────────────────
_panel_input_loop() {
  while true; do
    local key
    read -rsn1 key 2>/dev/null
    
    case "$key" in
      $'\x1b')
        read -rsn2 -t 0.5 seq 2>/dev/null
        case "$seq" in
          '[A'|'OA')
            if [ "$FOCUSED_PANEL" = "tree" ]; then _tree_navigate -1
            elif [ "$FOCUSED_PANEL" = "exercises" ]; then _scroll_exercises -1; fi
            _mark_all_dirty; _panel_draw_all ;;
          '[B'|'OB')
            if [ "$FOCUSED_PANEL" = "tree" ]; then _tree_navigate 1
            elif [ "$FOCUSED_PANEL" = "exercises" ]; then _scroll_exercises 1; fi
            _mark_all_dirty; _panel_draw_all ;;
          '[C'|'OC')
            if [ "$FOCUSED_PANEL" = "tree" ]; then _tree_expand 1; _mark_all_dirty; _panel_draw_all; fi ;;
          '[D'|'OD')
            if [ "$FOCUSED_PANEL" = "tree" ]; then _tree_expand 0; _mark_all_dirty; _panel_draw_all; fi ;;
          '[5')
            read -rsn1 -t 0.1 2>/dev/null
            if [ "$FOCUSED_PANEL" = "tree" ]; then
              local page=$(( TOP_ROWS - 2 ))
              TREE_CURSOR=$((TREE_CURSOR - page))
              [ $TREE_CURSOR -lt 0 ] && TREE_CURSOR=0
            elif [ "$FOCUSED_PANEL" = "exercises" ]; then
              _scroll_exercises $((-(TOP_ROWS - 3)))
            fi
            _mark_all_dirty; _panel_draw_all ;;
          '[6')
            read -rsn1 -t 0.1 2>/dev/null
            if [ "$FOCUSED_PANEL" = "tree" ]; then
              local visible_items=($(_get_visible_tree_items))
              local page=$(( TOP_ROWS - 2 ))
              TREE_CURSOR=$((TREE_CURSOR + page))
              local max=$(( ${#visible_items[@]} - 1 ))
              [ $TREE_CURSOR -gt $max ] && TREE_CURSOR=$max
            elif [ "$FOCUSED_PANEL" = "exercises" ]; then
              _scroll_exercises $((TOP_ROWS - 3))
            fi
            _mark_all_dirty; _panel_draw_all ;;
          '[Z')  # Shift+Tab
            _focus_prev_panel; _mark_all_dirty; _panel_draw_all ;;
          '')
            FOCUSED_PANEL="terminal"
            _mark_all_dirty; _panel_draw_all ;;
        esac
        continue ;;
      $'\x09')  # Tab
        _focus_next_panel; _mark_all_dirty; _panel_draw_all; continue ;;
      'j')
        if [ "$FOCUSED_PANEL" = "tree" ]; then _tree_navigate 1
        elif [ "$FOCUSED_PANEL" = "exercises" ]; then _scroll_exercises 1; fi
        _mark_all_dirty; _panel_draw_all; continue ;;
      'k')
        if [ "$FOCUSED_PANEL" = "tree" ]; then _tree_navigate -1
        elif [ "$FOCUSED_PANEL" = "exercises" ]; then _scroll_exercises -1; fi
        _mark_all_dirty; _panel_draw_all; continue ;;
      'g')
        local key2; read -rsn1 -t 0.5 key2 2>/dev/null
        if [ "$key2" = "g" ]; then
          if [ "$FOCUSED_PANEL" = "tree" ]; then TREE_CURSOR=0; TREE_SCROLL=0
          elif [ "$FOCUSED_PANEL" = "exercises" ]; then EXERCISES_SCROLL=0; fi
          _mark_all_dirty; _panel_draw_all
        fi
        continue ;;
      'G')
        if [ "$FOCUSED_PANEL" = "tree" ]; then
          local visible_items=($(_get_visible_tree_items))
          TREE_CURSOR=$((${#visible_items[@]} - 1))
        elif [ "$FOCUSED_PANEL" = "exercises" ]; then
          local total=${#EXERCISES_LINES[@]}
          local max_lines=$((TOP_ROWS - 3))
          EXERCISES_SCROLL=$((total - max_lines))
          [ $EXERCISES_SCROLL -lt 0 ] && EXERCISES_SCROLL=0
        fi
        _mark_all_dirty; _panel_draw_all; continue ;;
      '+')
        if [ "$FOCUSED_PANEL" = "tree" ]; then _tree_expand_all; _mark_all_dirty; _panel_draw_all; fi
        continue ;;
      '-')
        if [ "$FOCUSED_PANEL" = "tree" ]; then _tree_collapse_all; _mark_all_dirty; _panel_draw_all; fi
        continue ;;
      ' ')  # Space
        if [ "$FOCUSED_PANEL" = "tree" ]; then _tree_select; _mark_all_dirty; _panel_draw_all; fi
        continue ;;
      $'\x0d')  # Enter
        if [ "$FOCUSED_PANEL" = "tree" ]; then _tree_select; _mark_all_dirty; _panel_draw_all
        elif [ "$FOCUSED_PANEL" = "exercises" ]; then FOCUSED_PANEL="terminal"; _mark_all_dirty; _panel_draw_all
        else return 0; fi
        continue ;;
      $'\x04')  # Ctrl+D
        if [ "$FOCUSED_PANEL" = "tree" ]; then
          local half=$(( (TOP_ROWS - 2) / 2 ))
          TREE_CURSOR=$((TREE_CURSOR + half))
          local visible_items=($(_get_visible_tree_items))
          local max=$(( ${#visible_items[@]} - 1 ))
          [ $TREE_CURSOR -gt $max ] && TREE_CURSOR=$max
        elif [ "$FOCUSED_PANEL" = "exercises" ]; then
          _scroll_exercises $(( (TOP_ROWS - 3) / 2 ))
        fi
        _mark_all_dirty; _panel_draw_all; continue ;;
      $'\x15')  # Ctrl+U
        if [ "$FOCUSED_PANEL" = "tree" ]; then
          local half=$(( (TOP_ROWS - 2) / 2 ))
          TREE_CURSOR=$((TREE_CURSOR - half))
          [ $TREE_CURSOR -lt 0 ] && TREE_CURSOR=0
        elif [ "$FOCUSED_PANEL" = "exercises" ]; then
          _scroll_exercises $(( -(TOP_ROWS - 3) / 2 ))
        fi
        _mark_all_dirty; _panel_draw_all; continue ;;
      $'\x06')  # Ctrl+F
        if [ "$FOCUSED_PANEL" = "tree" ]; then
          local page=$(( TOP_ROWS - 2 ))
          TREE_CURSOR=$((TREE_CURSOR + page))
          local visible_items=($(_get_visible_tree_items))
          local max=$(( ${#visible_items[@]} - 1 ))
          [ $TREE_CURSOR -gt $max ] && TREE_CURSOR=$max
        elif [ "$FOCUSED_PANEL" = "exercises" ]; then
          _scroll_exercises $((TOP_ROWS - 3))
        fi
        _mark_all_dirty; _panel_draw_all; continue ;;
      $'\x02')  # Ctrl+B
        if [ "$FOCUSED_PANEL" = "tree" ]; then
          local page=$(( TOP_ROWS - 2 ))
          TREE_CURSOR=$((TREE_CURSOR - page))
          [ $TREE_CURSOR -lt 0 ] && TREE_CURSOR=0
        elif [ "$FOCUSED_PANEL" = "exercises" ]; then
          _scroll_exercises $((-(TOP_ROWS - 3)))
        fi
        _mark_all_dirty; _panel_draw_all; continue ;;
      '1') _focus_panel 1; _mark_all_dirty; _panel_draw_all; continue ;;
      '2') _focus_panel 2; _mark_all_dirty; _panel_draw_all; continue ;;
      '3') _focus_panel 3; _mark_all_dirty; _panel_draw_all; continue ;;
      '?') _show_help_overlay; continue ;;
      'r') _parse_all_missions; _load_exercises; _mark_all_dirty; _panel_draw_all; continue ;;
      'q'|'Q') _quit; continue ;;
      *) return 0 ;;
    esac
  done
}

# =============================================================================
#  CLASSIC MODE HELPERS
# =============================================================================

_hr() { printf "  ${D}┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄${R}\n"; }

_compact_header() {
  local filled=$(( STEP_NUM * 12 / STEP_TOTAL ))
  local empty=$(( 12 - filled ))
  local bar="" emp=""
  for i in $(seq 1 $filled 2>/dev/null); do bar="${bar}━"; done
  for i in $(seq 1 $empty  2>/dev/null); do emp="${emp}─"; done
  printf "  ${CY}${bar}${D}${emp}  ${R}${B}${CY}${STEP_NUM}${R}${D}/${STEP_TOTAL}  ·  ${STEP_TITLE}${R}\n"
  printf "  ${D}────────────────────────────────────────────────────────${R}\n\n"
}

_replaying() { [ "$RESUME_FROM" -gt 0 ] && [ "$STEP_NUM" -le "$RESUME_FROM" ]; }

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
# =============================================================================

_meta_help() {
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    _show_help_overlay; return
  fi
  clear; printf "\n"
  printf "${B}${CY}  ╔══════════════════════════════════════════════════════════╗${R}\n"
  printf "${B}${CY}  ║${R}  ${B}IN-SESSION COMMANDS${R}                                     ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${D}Available at every prompt during practice${R}               ${B}${CY}║${R}\n"
  printf "${B}${CY}  ╠══════════════════════════════════════════════════════════╣${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${B}INFORMATION${R}                                             ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}help${R}  ${GR}?${R}        Show this panel                        ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}hint${R}          Show a hint for the current step        ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}status${R}        Show mission progress and error count   ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${B}NAVIGATION${R}                                              ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}skip${R}          Skip this exercise (move to the next)   ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}restart${R}       Repeat the current step from scratch    ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}goto N${R}        Jump to step N  (e.g. goto 5)           ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${B}EXIT${R}                                                    ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}    ${GR}q${R}  ${GR}quit${R}  ${GR}exit${R}  Save position and exit                 ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${D}At \$ prompt: type any real shell command to run it${R}      ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${D}Empty Enter (at \$ prompt): skip the exercise${R}            ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}  ${D}Ctrl+C: also saves position and exits${R}                   ${B}${CY}║${R}\n"
  printf "${B}${CY}  ║${R}                                                          ${B}${CY}║${R}\n"
  printf "${B}${CY}  ╚══════════════════════════════════════════════════════════╝${R}\n"
  printf "\n"
}

_meta_status() {
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    _panel_clear
    local mid=$((TERM_ROWS / 2 - 3))
    _panel_goto $mid $((LEFT_COLS + 3))
    printf "${B}${CY}Mission${R}   ${MISSION_NUM} · ${MISSION_NAME}\n"
    _panel_goto $((mid + 1)) $((LEFT_COLS + 3))
    printf "${B}${CY}Step${R}      ${STEP_NUM} / ${STEP_TOTAL}\n"
    local filled=$(( STEP_NUM * 20 / STEP_TOTAL ))
    local empty=$(( 20 - filled ))
    local bar=""; for i in $(seq 1 "$filled" 2>/dev/null); do bar="${bar}█"; done
    local emp=""; for i in $(seq 1 "$empty"  2>/dev/null); do emp="${emp}░"; done
    _panel_goto $((mid + 2)) $((LEFT_COLS + 3))
    printf "${B}${CY}Progress${R}  ${GR}${bar}${D}${emp}${R}\n"
    _panel_goto $((mid + 3)) $((LEFT_COLS + 3))
    printf "${B}${CY}Errors${R}    ${ERRORS} missed check(s) so far\n"
    _panel_goto $((mid + 5)) $((LEFT_COLS + 3))
    printf "${D}Press any key to continue...${R}"
    read -rsn1
    _panel_draw_all
    return
  fi
  printf "\n"
  printf "  ${B}${CY}Mission${R}   ${MISSION_NUM} · ${MISSION_NAME}\n"
  printf "  ${B}${CY}Step${R}      ${STEP_NUM} / ${STEP_TOTAL}\n"
  local filled=$(( STEP_NUM * 20 / STEP_TOTAL ))
  local empty=$(( 20 - filled ))
  local bar=""; for i in $(seq 1 "$filled" 2>/dev/null); do bar="${bar}█"; done
  local emp=""; for i in $(seq 1 "$empty"  2>/dev/null); do emp="${emp}░"; done
  printf "  ${B}${CY}Progress${R}  ${GR}${bar}${D}${emp}${R}\n"
  printf "  ${B}${CY}Errors${R}    ${ERRORS} missed check(s) so far\n"
  printf "\n"
}

_meta_hint() {
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    if [ -n "$STEP_HINT" ]; then
      _term_add "${YL}${B}Hint:${R} ${YL}${STEP_HINT}${R}"
    else
      _term_add "${D}No hint set for this step.${R}"
    fi
    _panel_draw_all
    return
  fi
  printf "\n"
  if [ -n "$STEP_HINT" ]; then
    printf "  ${YL}${B}Hint for this step:${R}\n\n"
    while IFS= read -r line; do printf "  ${YL}  %s${R}\n" "$line"; done <<< "$STEP_HINT"
  else
    printf "  ${D}No hint set for this step.${R}\n"
    printf "  ${D}Try: make hint N=${MISSION_NUM} for exercise hints.${R}\n"
  fi
  printf "\n"
}

_meta_restart() {
  if [ -z "$_PRACTICE_PATH" ]; then
    printf "\n  ${YL}Restart not available (practice path not set).${R}\n\n"; return
  fi
  local target=$(( STEP_NUM - 1 ))
  [ "$target" -lt 0 ] && target=0
  STEP_NUM=$target; _save_state
  printf "\n  ${CY}Restarting step $((STEP_NUM + 1)) ...${R}\n\n"
  sleep 0.4
  exec bash "$_PRACTICE_PATH"
}

_meta_goto() {
  local n="$1"
  if ! [[ "$n" =~ ^[0-9]+$ ]] || [ "$n" -lt 1 ] || [ "$n" -gt "$STEP_TOTAL" ]; then
    printf "\n  ${RD}Invalid step number '${n}'.${R}  ${D}Valid range: 1 – ${STEP_TOTAL}${R}\n\n"; return
  fi
  if [ -z "$_PRACTICE_PATH" ]; then
    printf "\n  ${YL}goto not available (practice path not set).${R}\n\n"; return
  fi
  local target=$(( n - 1 ))
  STEP_NUM=$target; _save_state
  printf "\n  ${CY}Jumping to step ${n} ...${R}\n\n"
  sleep 0.4
  exec bash "$_PRACTICE_PATH"
}

_is_meta() {
  local input="$1"
  case "$input" in
    "help"|"?")   _meta_help;                     return 0 ;;
    "hint")       _meta_hint;                     return 0 ;;
    "status")     _meta_status;                   return 0 ;;
    "skip")                                       return 2 ;;
    "restart")    _meta_restart;                  return 0 ;;
    "goto "*)     _meta_goto "${input#goto }";    return 0 ;;
    "q"|"quit"|"exit") _quit;                    return 0 ;;
    *)                                            return 1 ;;
  esac
}

# =============================================================================
#  READ LOOPS
# =============================================================================

_TRY_CMD=""

_read_try() {
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    FOCUSED_PANEL="terminal"
    _mark_all_dirty; _panel_draw_all

    # Auto-launch the real terminal immediately — no Enter required
    _enter_real_terminal "$STEP_HINT"

    # After shell exits, let user skip, retry, or continue
    local _show_post_prompt
    _show_post_prompt() {
      _panel_goto $((TERM_ROWS - 2)) $((LEFT_COLS + 3))
      tput el 2>/dev/null
      printf "${B}${GR}Enter${R}${D}: continue  r: retry  s: skip  q: quit${R}  "
      _panel_show_cursor
    }
    _show_post_prompt

    while true; do
      local key; read -rsn1 key 2>/dev/null
      case "$key" in
        $'\x0d'|'')  _TRY_CMD="_pty_session"; return 0 ;;
        'r')
          _enter_real_terminal "$STEP_HINT"
          _show_post_prompt ;;
        's')  _TRY_CMD=""; return 1 ;;
        'q'|'Q') _quit ;;
        *) ;;
      esac
    done
  fi

  # ── Classic mode ──────────────────────────────────────────────────────────
  while true; do
    printf "  ${B}${GR}\$${R} "
    local input; read -r input
    if [ -z "$input" ]; then _TRY_CMD=""; return 1; fi
    _is_meta "$input"
    local rc=$?
    if   [ $rc -eq 0 ]; then continue
    elif [ $rc -eq 2 ]; then return 1
    else _TRY_CMD="$input"; return 0; fi
  done
}

_read_pause() {
  local msg="${1:-}" first=1
  while true; do
    if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
      _panel_input_loop
      if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
        _panel_goto $((TERM_ROWS - 2)) $((LEFT_COLS + 3))
        if [ "$first" -eq 1 ]; then
          if [ -z "$msg" ]; then printf "${B}press Enter for next${R}${D}  (hint · skip · q · ?)${R}  "
          else printf "${B}press Enter for next${R}${D}  (${msg})${R}  "; fi
          first=0
        else printf "${B}press Enter for next${R}  "; fi
      fi
    else
      if [ "$first" -eq 1 ]; then
        if [ -z "$msg" ]; then printf "  ${B}press Enter for next${R}${D}  (hint · skip · q · ?)${R}  "
        else printf "  ${B}press Enter for next${R}${D}  (${msg})${R}  "; fi
        first=0
      else printf "  ${B}press Enter for next${R}  "; fi
    fi
    local input; read -rs input
    _is_meta "$input"
    local rc=$?
    [ $rc -eq 0 ] && continue
    [ $rc -eq 2 ] && return 1
    return 0
  done
}

# =============================================================================
#  QUIT HANDLER
# =============================================================================
_quit() {
  _save_state
  _terminate_shell_session
  [ -n "$_PTY_CWD_FILE" ] && rm -f "$_PTY_CWD_FILE" 2>/dev/null
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    _panel_clear
    local mid=$((TERM_ROWS / 2 - 2))
    _panel_goto $mid 3
    printf "${B}${YL}  Paused — Step ${STEP_NUM}/${STEP_TOTAL}${R}\n\n"
    _panel_goto $((mid + 2)) 3
    printf "  Your position is saved.\n\n"
    _panel_goto $((mid + 4)) 3
    printf "  Resume:      ${GR}make practice N=${MISSION_NUM}${R}\n"
    _panel_goto $((mid + 5)) 3
    printf "  Mark done:   ${GR}make done     N=${MISSION_NUM}${R}\n"
    _panel_goto $((mid + 6)) 3
    printf "  Read brief:  ${GR}make mission  N=${MISSION_NUM}${R}\n"
  else
    printf "\n\n"
    printf "${B}${YL}  Paused — Step ${STEP_NUM}/${STEP_TOTAL}${R}\n\n"
    printf "  Your position is saved.\n\n"
    printf "  Resume:      ${GR}make practice N=${MISSION_NUM}${R}\n"
    printf "  Mark done:   ${GR}make done     N=${MISSION_NUM}${R}\n"
    printf "  Read brief:  ${GR}make mission  N=${MISSION_NUM}${R}\n"
    printf "\n"
  fi
  exit 0
}
trap '_quit' INT

# =============================================================================
#  PUBLIC API
# =============================================================================

_prompt_yes_no_panel() {
  local prompt="$1"
  local row=$((MID_ROW + 6))
  local col=$((LEFT_COLS + 3))
  _panel_goto $row $col
  tput el 2>/dev/null
  printf "%b" "$prompt"
  _panel_show_cursor
  _YESNO_RESULT="y"
  while true; do
    local key; read -rsn1 key 2>/dev/null
    case "$key" in
      [yY]) _YESNO_RESULT="y"; break ;;
      [nN]) _YESNO_RESULT="n"; break ;;
      "")   _YESNO_RESULT="y"; break ;;
    esac
  done
  _panel_hide_cursor
}

init_mission() {
  MISSION_NUM="$1"; MISSION_NAME="$2"; STEP_TOTAL="$3"
  STEP_NUM=0; ERRORS=0; RESUME_FROM=0; STEP_HINT=""
  local saved_step=0
  if _load_state 2>/dev/null; then saved_step=$RESUME_FROM; fi

  if [ "$USE_PANELS" = "1" ] && _panel_init; then
    CURRENT_LESSON="$MISSION_NUM"; _load_exercises; TERM_LINES=()
    _panel_draw_all
    _panel_goto $((MID_ROW + 2)) $((LEFT_COLS + 3))
    printf "${B}${CY}Mission ${MISSION_NUM} · ${MISSION_NAME}${R}\n"
    _panel_goto $((MID_ROW + 3)) $((LEFT_COLS + 3))
    printf "${D}${STEP_TOTAL} steps  ·  type ? at any prompt for commands${R}\n"
    if [ "$saved_step" -gt 0 ] && [ "$saved_step" -lt "$STEP_TOTAL" ]; then
      _panel_goto $((MID_ROW + 5)) $((LEFT_COLS + 3))
      printf "${YL}Saved position found:${R} Step ${saved_step} / ${STEP_TOTAL}\n"
      _prompt_yes_no_panel "Resume from step ${saved_step}? [Y/n] "
      if [[ "$_YESNO_RESULT" =~ ^[Nn]$ ]]; then RESUME_FROM=0; _clear_state
      else RESUME_FROM=$saved_step; fi
    fi
    return
  fi

  clear; printf "\n"
  printf "${B}${CY}  ╔══════════════════════════════════════════════════════╗${R}\n"
  printf "${B}${CY}  ║${R}  ${B}PRACTICE · Mission ${MISSION_NUM} · ${MISSION_NAME}${R}\n"
  printf "${B}${CY}  ║${R}  ${D}${STEP_TOTAL} steps  ·  type ${B}?${D} at any prompt for commands${R}\n"
  printf "${B}${CY}  ╚══════════════════════════════════════════════════════╝${R}\n"
  printf "\n"
  if [ "$saved_step" -gt 0 ] && [ "$saved_step" -lt "$STEP_TOTAL" ]; then
    printf "  ${YL}Saved position found:${R} Step ${saved_step} / ${STEP_TOTAL}\n\n"
    printf "  Resume from step ${saved_step}? [Y/n] "
    local ans; read -r ans
    if [[ "$ans" =~ ^[Nn]$ ]]; then RESUME_FROM=0; _clear_state; printf "\n  Starting from the beginning ...\n\n"
    else RESUME_FROM=$saved_step; printf "\n  Fast-forwarding ...\n"; fi
  else
    printf "  ${B}↵${R}${D} start  ·  ? commands${R}  "
    local ans; read -r ans; _is_meta "$ans" 2>/dev/null || true; printf "\n"
  fi
}

step() {
  STEP_NUM=$((STEP_NUM + 1)); STEP_HINT=""; _save_state
  if _replaying; then
    if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
      _panel_goto $((MID_ROW + 2)) $((LEFT_COLS + 3))
      printf "${D}skipping step ${STEP_NUM}/${STEP_TOTAL} ...${R}   "
    else printf "\r  ${D}skipping step ${STEP_NUM}/${STEP_TOTAL} ...${R}   "; fi
    return
  fi
  if [ "$RESUME_FROM" -gt 0 ] && [ "$STEP_NUM" -gt "$RESUME_FROM" ]; then
    RESUME_FROM=0
    if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
      _panel_goto $((MID_ROW + 2)) $((LEFT_COLS + 3))
      printf "${GR}↩  Resumed at step ${STEP_NUM}/${STEP_TOTAL}${R}\n"; sleep 0.5
    else clear; printf "\n  ${GR}↩  Resumed at step ${STEP_NUM}/${STEP_TOTAL}${R}\n\n"; sleep 0.5; fi
  fi
  STEP_TITLE="$1"
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    _panel_draw_all; return
  fi
  clear; printf "\n"
  local dots=""
  for i in $(seq 1 "$STEP_TOTAL"); do
    if   [ "$i" -lt  "$STEP_NUM" ]; then dots="${dots}${GR}●${R}"
    elif [ "$i" -eq "$STEP_NUM"  ]; then dots="${dots}${B}${CY}●${R}"
    else                                  dots="${dots}${D}·${R}"; fi
    [ "$i" -lt "$STEP_TOTAL" ] && dots="${dots} "
  done
  printf "  %b\n" "$dots"
  printf "  ${D}Step ${STEP_NUM}/${STEP_TOTAL}  ·  Mission ${MISSION_NUM} · ${MISSION_NAME}${R}\n\n"
  printf "  ${B}${CY}>${R} ${B}${STEP_TITLE}${R}\n\n"
}

set_hint() { STEP_HINT="$1"; }

explain() {
  _replaying && return
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    while IFS= read -r line; do _term_add "$line"; done <<< "$1"
    _panel_draw_all; return
  fi
  while IFS= read -r line; do printf "  %s\n" "$line"; done <<< "$1"
  printf "\n"
}

demo() {
  _replaying && return
  local cmd="$1" label="${2:-}"
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    [ -n "$label" ] && _term_add "${D}${label}${R}"
    _panel_draw_all
    _enter_real_terminal "$STEP_HINT" "$cmd"
    _read_pause; return
  fi
  clear; _compact_header
  [ -n "$label" ] && printf "  ${D}${label}${R}\n\n"
  printf "  ${B}${GR}\$${R} ${B}${cmd}${R}\n"
  _hr; eval "$cmd" 2>&1 | while IFS= read -r line; do printf "  %s\n" "$line"; done
  _hr; printf "\n"; _read_pause
}

show() {
  _replaying && return
  local cmd="$1" label="${2:-}"
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    [ -n "$label" ] && _term_add "${D}${label}${R}"
    _panel_draw_all
    _enter_real_terminal "$STEP_HINT" "$cmd"
    return
  fi
  clear; _compact_header
  [ -n "$label" ] && printf "  ${D}${label}${R}\n\n"
  printf "  ${B}${GR}\$${R} ${B}${cmd}${R}\n"
  _hr; eval "$cmd" 2>&1 | while IFS= read -r line; do printf "  %s\n" "$line"; done
  _hr; printf "\n"
}

try() {
  _replaying && return
  local prompt="${1:-Your turn:}" hint="${2:-}"
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    _term_add "${YL}>  ${B}${prompt}${R}"
    [ -n "$hint" ] && _term_add "  ${D}hint: ${hint}${R}"
    _panel_draw_all
    _read_try
    local skipped=$?
    if [ "$skipped" -eq 1 ] || [ -z "$_TRY_CMD" ]; then
      _term_add "${D}  ↳ skipped${R}"; _panel_draw_all; _read_pause; return
    fi
    if [ "$_TRY_CMD" = "_pty_session" ]; then
      _term_add "${GR}  terminal session complete${R}"
      _panel_draw_all; _read_pause; return
    fi
    _term_add "${D}ran:${R}  ${B}${_TRY_CMD}${R}"
    local output exit_code=0
    output=$(eval "$_TRY_CMD" 2>&1) || exit_code=$?
    if [ -z "$output" ]; then _term_add "  ${D}(no output)${R}"
    else while IFS= read -r line; do _term_add "  ${line}"; done <<< "$output"; fi
    if [ "$exit_code" -eq 0 ]; then _term_add "${GR}✓  exit 0 — success${R}"
    else _term_add "${RD}✗  exit ${exit_code}${R}  ${D}— non-zero exit${R}"; fi
    _panel_draw_all; _read_pause; return
  fi
  clear; _compact_header
  printf "  ${YL}>  ${B}${prompt}${R}\n"
  [ -n "$hint" ] && printf "  ${D}   hint: ${hint}${R}\n"
  printf "\n"
  _read_try; local skipped=$?
  if [ "$skipped" -eq 1 ] || [ -z "$_TRY_CMD" ]; then
    printf "\n  ${D}  ↳ skipped${R}\n\n"; _read_pause; return
  fi
  printf "\n  ${D}ran:${R}  ${B}${_TRY_CMD}${R}\n"
  _hr; local output exit_code=0
  output=$(eval "$_TRY_CMD" 2>&1) || exit_code=$?
  [ -z "$output" ] && printf "  ${D}(no output)${R}" \
    || echo "$output" | while IFS= read -r line; do printf "  %s\n" "$line"; done
  _hr
  [ "$exit_code" -eq 0 ] && printf "  ${GR}✓  exit 0 — success${R}" \
    || printf "  ${RD}✗  exit ${exit_code}${R}  ${D}— non-zero exit${R}"
  printf "\n"; _read_pause
}

try_match() {
  _replaying && return
  local prompt="$1" hint="$2" expected="$3"
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    _term_add "${YL}>  ${B}${prompt}${R}"
    _term_add "  ${D}hint: ${hint}${R}"
    _panel_draw_all
    _read_try; local skipped=$?
    if [ "$skipped" -eq 1 ] || [ -z "$_TRY_CMD" ]; then
      _term_add "${D}  ↳ skipped${R}"; _panel_draw_all; _read_pause; return
    fi
    if [ "$_TRY_CMD" = "_pty_session" ]; then
      local verify_out verify_exit=0
      verify_out=$(eval "$hint" 2>&1) || verify_exit=$?
      if echo "$verify_out" | grep -q "$expected"; then
        _term_add "${GR}✓  Correct${R}  ${D}— output contains '${expected}'${R}"
      else
        _term_add "${YL}~  Expected output to contain '${expected}'${R}"
        _term_add "${D}   Open the terminal again to retry, or press Enter for next${R}"
        ERRORS=$((ERRORS + 1)); _save_state
      fi
      _panel_draw_all; _read_pause; return
    fi
    _term_add "${D}ran:${R}  ${B}${_TRY_CMD}${R}"
    local output exit_code=0
    output=$(eval "$_TRY_CMD" 2>&1) || exit_code=$?
    if [ -z "$output" ]; then _term_add "  ${D}(no output)${R}"
    else while IFS= read -r line; do _term_add "  ${line}"; done <<< "$output"; fi
    if echo "$output" | grep -q "$expected"; then
      _term_add "${GR}✓  Correct${R}  ${D}— output contains '${expected}'${R}"
    else
      _term_add "${YL}~  Expected output to contain '${expected}'${R}"
      _term_add "${D}   Run it again, or press Enter for next to move on${R}"
      ERRORS=$((ERRORS + 1)); _save_state
    fi
    _panel_draw_all; _read_pause; return
  fi
  clear; _compact_header
  printf "  ${YL}>  ${B}${prompt}${R}\n"
  printf "  ${D}   hint: ${hint}${R}\n\n"
  _read_try; local skipped=$?
  if [ "$skipped" -eq 1 ] || [ -z "$_TRY_CMD" ]; then
    printf "\n  ${D}  ↳ skipped${R}\n\n"; _read_pause; return
  fi
  printf "\n  ${D}ran:${R}  ${B}${_TRY_CMD}${R}\n"
  _hr; local output exit_code=0
  output=$(eval "$_TRY_CMD" 2>&1) || exit_code=$?
  [ -z "$output" ] && printf "  ${D}(no output)${R}" \
    || echo "$output" | while IFS= read -r line; do printf "  %s\n" "$line"; done
  _hr
  if echo "$output" | grep -q "$expected"; then
    printf "  ${GR}✓  Correct${R}  ${D}— output contains '${expected}'${R}"
  else
    printf "  ${YL}~  Expected output to contain '${expected}'${R}\n"
    printf "  ${D}   Run it again, or press Enter for next to move on${R}"
    ERRORS=$((ERRORS + 1)); _save_state
  fi
  printf "\n"; _read_pause
}

tip()  { _replaying && return; if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then _term_add "${YL}┃ Tip${R}   $1"; _panel_draw_all; else printf "  ${YL}┃ Tip${R}   %s\n\n" "$1"; fi; }
note() { _replaying && return; if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then _term_add "${CY}┃ Note${R}  $1"; _panel_draw_all; else printf "  ${CY}┃ Note${R}  %s\n\n" "$1"; fi; }
warn() { _replaying && return; if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then _term_add "${RD}┃ !${R}    $1"; _panel_draw_all; else printf "  ${RD}┃ !${R}    %s\n\n" "$1"; fi; }

checkpoint() {
  _replaying && return
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    _term_add "${MG}${B}?  Checkpoint${R}"
    _term_add ""
    _term_add "${MG}$1${R}"
    _panel_draw_all; _read_pause "to reveal answer"
    _term_add ""
    _term_add "${GR}${B}Answer${R}"
    _term_add ""
    while IFS= read -r line; do _term_add "${GR}  ${line}${R}"; done <<< "$2"
    _panel_draw_all; _read_pause; return
  fi
  clear; _compact_header
  printf "  ${MG}${B}?  Checkpoint${R}\n\n"
  printf "  ${MG}%s${R}\n\n" "$1"
  _read_pause "to reveal answer"
  printf "\n  ${GR}${B}Answer${R}\n\n"
  while IFS= read -r line; do printf "  ${GR}  %s${R}\n" "$line"; done <<< "$2"
  printf "\n"; _read_pause
}

section() {
  _replaying && return
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    _term_add "${B}${BL}> ${R}${B}$1${R}"; _panel_draw_all; return
  fi
  printf "\n  ${B}${BL}> ${R}${B}$1${R}\n\n"
}

mission_complete() {
  _clear_state
  [ -n "$_PTY_CWD_FILE" ] && rm -f "$_PTY_CWD_FILE" 2>/dev/null
  if [ "$PANEL_MODE_ACTIVE" -eq 1 ]; then
    _panel_clear
    local mid=$((TERM_ROWS / 2 - 3))
    _panel_goto $mid 3
    printf "${B}${GR}  ╔══════════════════════════════════════════════════════╗${R}\n"
    _panel_goto $((mid + 1)) 3
    printf "${B}${GR}  ║                                                      ║${R}\n"
    _panel_goto $((mid + 2)) 3
    printf "${B}${GR}  ║   ✓  MISSION ${MISSION_NUM} COMPLETE                             ║${R}\n"
    _panel_goto $((mid + 3)) 3
    printf "${B}${GR}  ║                                                      ║${R}\n"
    _panel_goto $((mid + 4)) 3
    printf "${B}${GR}  ╚══════════════════════════════════════════════════════╝${R}\n"
    _panel_goto $((mid + 6)) 3
    [ "$ERRORS" -eq 0 ] && printf "${GR}Clean run — all checks passed.${R}" \
      || printf "${YL}${ERRORS} check(s) didn't match.${R}  ${D}Review: make exercises N=${MISSION_NUM}${R}"
    _panel_goto $((mid + 8)) 3
    printf "${D}What's next:${R}\n\n"
    _panel_goto $((mid + 9)) 3
    printf "    ${GR}make done      N=${MISSION_NUM}${R}   mark this mission complete\n"
    _panel_goto $((mid + 10)) 3
    printf "    ${GR}make next${R}              open the next mission\n"
    _panel_goto $((mid + 11)) 3
    printf "    ${GR}make exercises N=${MISSION_NUM}${R}   re-read the exercises\n"
    return
  fi
  clear; printf "\n"
  printf "${B}${GR}  ╔══════════════════════════════════════════════════════╗${R}\n"
  printf "${B}${GR}  ║                                                      ║${R}\n"
  printf "${B}${GR}  ║   ✓  MISSION ${MISSION_NUM} COMPLETE                             ║${R}\n"
  printf "${B}${GR}  ║                                                      ║${R}\n"
  printf "${B}${GR}  ╚══════════════════════════════════════════════════════╝${R}\n"
  printf "\n"
  [ "$ERRORS" -eq 0 ] && printf "  ${GR}Clean run — all checks passed.${R}" \
    || printf "  ${YL}${ERRORS} check(s) didn't match.${R}  ${D}Review: make exercises N=${MISSION_NUM}${R}"
  printf "\n"
  printf "  ${D}What's next:${R}\n\n"
  printf "    ${GR}make done      N=${MISSION_NUM}${R}   mark this mission complete\n"
  printf "    ${GR}make next${R}              open the next mission\n"
  printf "    ${GR}make exercises N=${MISSION_NUM}${R}   re-read the exercises\n"
  printf "\n"
}
