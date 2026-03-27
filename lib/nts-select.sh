#!/bin/sh
# nts-select.sh - Interactive selection menu helper
# Part of the NTS (New Terminal System)
#
# Provides a reusable numbered menu for selecting from a list of items.
# Intended to be sourced by other NTS scripts, not run directly.
#
# Usage:
#   . "$NTS_DIR/lib/nts-select.sh"
#   result=$(nts_select "Pick one" "item a" "item b" "item c")
#
# Newline-delimited input:
#   result=$(echo "$items" | nts_select_stdin "Pick one")
#
# Both functions print the selected item to stdout (for capture).
# Menu display and prompts go to stderr (visible to the user).
# Exit status: 0 on selection, 1 on quit/cancel.

# Present a numbered menu from positional arguments.
# $1 = prompt label, $2.. = items
nts_select() {
  _nts_sel_prompt="$1"
  shift

  if [ "$#" -eq 0 ]; then
    echo "Error: nothing to select." >&2
    return 1
  fi

  _nts_sel_count="$#"

  echo "" >&2
  _nts_sel_i=1
  for _nts_sel_item in "$@"; do
    printf "  %2d) %s\n" "$_nts_sel_i" "$_nts_sel_item" >&2
    _nts_sel_i=$((_nts_sel_i + 1))
  done

  echo "" >&2
  printf "%s (1-%d), or q to quit: " "$_nts_sel_prompt" "$_nts_sel_count" >&2
  read -r _nts_sel_choice </dev/tty

  case "$_nts_sel_choice" in
    q|Q|"")
      return 1
      ;;
  esac

  if ! echo "$_nts_sel_choice" | grep -q '^[0-9]\{1,\}$'; then
    echo "Error: invalid selection." >&2
    return 1
  fi

  if [ "$_nts_sel_choice" -lt 1 ] || [ "$_nts_sel_choice" -gt "$_nts_sel_count" ]; then
    echo "Error: selection out of range." >&2
    return 1
  fi

  _nts_sel_j=1
  for _nts_sel_item in "$@"; do
    if [ "$_nts_sel_j" -eq "$_nts_sel_choice" ]; then
      echo "$_nts_sel_item"
      return 0
    fi
    _nts_sel_j=$((_nts_sel_j + 1))
  done

  return 1
}

# Present a numbered menu from newline-delimited stdin.
# $1 = prompt label
nts_select_stdin() {
  _nts_sel_prompt="${1:-Select}"

  # Read stdin into numbered list
  _nts_sel_items=""
  _nts_sel_count=0

  echo "" >&2
  while IFS= read -r _nts_sel_line; do
    [ -z "$_nts_sel_line" ] && continue
    _nts_sel_count=$((_nts_sel_count + 1))
    printf "  %2d) %s\n" "$_nts_sel_count" "$_nts_sel_line" >&2
    _nts_sel_items="${_nts_sel_items}${_nts_sel_line}
"
  done

  if [ "$_nts_sel_count" -eq 0 ]; then
    echo "Error: nothing to select." >&2
    return 1
  fi

  echo "" >&2
  printf "%s (1-%d), or q to quit: " "$_nts_sel_prompt" "$_nts_sel_count" >&2
  read -r _nts_sel_choice </dev/tty

  case "$_nts_sel_choice" in
    q|Q|"")
      return 1
      ;;
  esac

  if ! echo "$_nts_sel_choice" | grep -q '^[0-9]\{1,\}$'; then
    echo "Error: invalid selection." >&2
    return 1
  fi

  if [ "$_nts_sel_choice" -lt 1 ] || [ "$_nts_sel_choice" -gt "$_nts_sel_count" ]; then
    echo "Error: selection out of range." >&2
    return 1
  fi

  echo "$_nts_sel_items" | sed -n "${_nts_sel_choice}p"
  return 0
}
