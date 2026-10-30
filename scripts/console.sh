#!/bin/bash
# The shared look of everything the project prints, so every command reads alike.
#
# Start:  . scripts/console.sh in a script, then console_passed "Built" "build/…"; or started on
#         its own for one piece: scripts/console.sh passed "Built" "build/…" (as make does)
# Needs:  nothing
# The same pieces as scripts/checks/console.py: a heading, lines with a mark (✔ done, ✘ failed,
# › under way) and dimmed details, dimmed hints, a table and a frame that sums up. Colors appear
# in a terminal and on GitHub; NO_COLOR=1 turns them off and FORCE_COLOR=1 turns them on.

set -euo pipefail

# MARK: Settings

# Terminal codes for text styles (ECMA-48 "select graphic rendition").
BOLD=1
DIM=2
RED=31
GREEN=32
CYAN=36
PASSED_MARK="✔"
FAILED_MARK="✘"
STEP_MARK="›"
NOTE_INDENT="   "  # hints start below the text of a result line
TABLE_WIDTH=16  # the names of a table fill this many characters, so the texts line up
UNICODE_LOCALE=en_US.UTF-8  # so a mark such as ✔ counts as one character, not three bytes

# MARK: Pieces

uses_color() {
  [ -z "${NO_COLOR+set}" ] \
    && { [ -t 1 ] || [ "${GITHUB_ACTIONS:-}" = true ] || [ -n "${FORCE_COLOR+set}" ]; }
}

# console_paint <text> <style>…: the text in these styles, or plain without colors.
console_paint() {
  local text=$1
  shift
  if [ $# -eq 0 ] || ! uses_color; then
    printf '%s' "$text"
    return
  fi
  local IFS=';'
  printf '\033[%sm%s\033[0m' "$*" "$text"
}

result_line() {
  local mark=$1 text=$2 detail=${3:-}
  if [ -n "$detail" ]; then
    detail="  $(console_paint "$detail" "$DIM")"
  fi
  printf ' %s %s%s\n' "$mark" "$text" "$detail"
}

frame_color() {
  case "$1" in
    success) printf '%s' "$GREEN" ;;
    failure) printf '%s' "$RED" ;;
    *) printf 'Unknown kind of frame: %s\n' "$1" >&2; return 1 ;;
  esac
}

repeated() {
  local text=$1 count=$2 result=""
  for (( index = 0; index < count; index++ )); do
    result+=$text
  done
  printf '%s' "$result"
}

# MARK: What a command prints

console_heading() {
  printf '\n%s  %s\n\n' "$(console_paint "$1" "$BOLD")" "$(console_paint "${2:-}" "$DIM")"
}

console_passed() {
  result_line "$(console_paint "$PASSED_MARK" "$GREEN" "$BOLD")" "$@"
}

console_failed() {
  result_line "$(console_paint "$FAILED_MARK" "$RED" "$BOLD")" "$@"
}

console_step() {
  result_line "$(console_paint "$STEP_MARK" "$CYAN" "$BOLD")" "$@"
}

console_note() {
  printf '%s\n' "$(console_paint "$NOTE_INDENT$1" "$DIM")"
}

# console_table: reads "name<tab>text" lines and lines the texts up behind the names.
console_table() {
  local name text
  while IFS=$'\t' read -r name text; do
    printf '  %s %s\n' "$(console_paint "$(printf "%-${TABLE_WIDTH}s" "$name")" "$CYAN" "$BOLD")" \
      "$text"
  done
}

# console_frame <success|failure> <line>…
console_frame() {
  local LC_ALL=$UNICODE_LOCALE
  local color width=0 line
  color=$(frame_color "$1")
  shift
  for line in "$@"; do
    width=$(( ${#line} + 2 > width ? ${#line} + 2 : width ))
  done
  local side
  side=$(console_paint "│" "$color")
  printf '\n %s\n' "$(console_paint "╭$(repeated "─" "$width")╮" "$color")"
  for line in "$@"; do
    printf ' %s %s%*s%s\n' "$side" "$(console_paint "$line" "$color" "$BOLD")" \
      $(( width - ${#line} - 1 )) "" "$side"
  done
  printf ' %s\n\n' "$(console_paint "╰$(repeated "─" "$width")╯" "$color")"
}

# MARK: Run

# Started on its own, it draws the one piece it is asked for; loaded with ".", it only defines
# the pieces above.
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  "console_$1" "${@:2}"
fi
