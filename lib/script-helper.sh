#!/bin/bash

# Check if already sourced
if [[ -n "${scr_help:-}" ]]; then
  return 0 &>/dev/null
else
  scr_help=1
fi

# Description: Script helper functions
# Author: monr3d
# License: GPL-3.0 license
# Version: 1.0

# Set strict mode
set -Eeuo pipefail

NC='\e[0m'
SC='\e[s'
RC='\e[u'

# Colors
RED="\e[31m"
BRE="\e[1;31m"
YEL="\e[33m"
BYE="\e[1;33m"
GRE="\e[32m"
BGR="\e[1;32m"
BLU="\e[34m"
BBL="\e[1;34m"

# Icons
ERR="${BRE}✘${NC}"
DONE="${BGR}✔${NC}"
WARN="${BYE}⚠️${NC}"
INFO="${BBL}ℹ️${NC}"
STD="${BBL}»${NC}"

add_trap() {
  local new_trap="$1"
  local signal="$2"
  local existing_trap

  if [ -n "$(trap -p "$signal")" ]; then
    existing_trap="$(trap -p "$signal" | awk -F"'" '{print $2}')"

    # Append the new trap only if it's not already included
    if [[ "$existing_trap" != *"$new_trap"* ]]; then
      trap "${existing_trap}; ${new_trap}" "$signal"
    fi
  else
    # Set the new trap if no existing trap is found
    trap "$new_trap" "$signal"
  fi
}

root_check() {
  if [[ "${EUID}" -ne 0 ]]; then
    printf "\n%bRoot privileges are required to run this script%b.\n" "$RED" "$NC" >&2
    printf "Please run it with %bsudo%b or as the %broot%b user.\n\n" "$RED" "$NC" "$YEL" "$NC" >&2
    exit 1
  fi
}

error_handler() {
  local exit_status=${?}
  local file_name=${1:-}
  local line_number=${2:-}
  local command=${3:-}

  printf "\n%b[ERROR]%b occurred in file %b at line %b while executing: %b\n" "$BRE" "$NC" "$RED${file_name}$NC" "$YEL${line_number}$NC" "$BLU${command}$NC" >&2
  printf "Exit status: %b\n\n" "$RED${exit_status}$NC" >&2

  exit "${exit_status}"
}