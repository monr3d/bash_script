#!/bin/bash

# Check if already sourced
if [[ -n "${msg_help:-}" ]]; then
  return 0 &>/dev/null
else
  msg_help=1
fi

set -euo pipefail

#Source helper functions
source <(wget -qO- https://raw.githubusercontent.com/monr3d/bash_script/refs/heads/master/lib/script-helper.sh)

# Variables
#SPINSTR='|/-\'
#SPINSTR='⠁⠂⠄⡀⢀⠠⠐⠈'
#SPINSTR='◴◵◶◷'
#SPINSTR='⣾⣽⣻⢿⡿⣟⣯⣷'
#SPINSTR='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPINSTR='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
SPINCOLOR="${BBL}" # blue
SPINPID=""
SPINSPEED=0.2
LINES=${LINES:-$(tput lines)}
COLUMNS=${COLUMNS:-$(tput cols)}

add_trap '_stop_spinner; tput sgr0' EXIT

_spinner() {
  local i=0
  local len=${#SPINSTR}

  tput civis cr cuf 3 sc

  while true; do
    tput rc cub 3
    printf " %b " "${SPINCOLOR}${SPINSTR:i++%len:1}$NC"
    sleep "$SPINSPEED"
  done
}

_stop_spinner() {
  if [[ -n "${SPINPID:-}" ]]; then
    kill "$SPINPID" &>/dev/null || true # Avoid error
    wait "$SPINPID" 2>/dev/null || true # Avoid zombie processes
    SPINPID=""                          # Clear variable
    tput cr sc cnorm                    # Show cursor
  fi

  return 0
}

_box() {
  local title="$1"
  local width="$2"
  local height="$3"
  local -i i

  # Print the box
  printf "\r ╔%s╗" "$(gen_separator $width ═)"
  tput cr cuf 3 && printf "╣ %b: ╠\n" "$title"
  for ((i = 0; i < height; i++)); do printf "\r ║%*s║\n" "$width" ""; done
  printf "\r ╚%s╝" "$(gen_separator $width ═)"

  return 0
}

gen_separator() {
  local length="${1:-0}" # Default length is 0
  local char="${2:-" "}" # Default character is ' '
  local sep

  printf -v sep "%*s" "$length" ""
  printf "%s" "${sep// /$char}"

  return 0
}

show_msg() {
  local msg="${1:-}"
  local color="${2:-$YEL}"

  if [[ -z "$SPINPID" || ! -d /proc/"$SPINPID" ]]; then
    _spinner &
    SPINPID=$!
    sleep 0.1 # Wait for the spinner to start
  fi

  tput rc el
  printf "${color}%b${NC}" "$msg"

  return 0
}

print_msg() {
  _stop_spinner

  local icon msg color

  OPTIND=1
  while getopts "i:c:" opt; do
    case "$opt" in
    i) icon=" ${OPTARG} " ;;
    c) color="$OPTARG" ;;
    *) icon="" ;;
    esac
  done
  shift $((OPTIND - 1))

  icon="${icon:-}"
  color="${color:-$NC}"
  msg="${1:-}"

  tput el
  printf "%b%b\n" "$icon" "${color}$msg${NC}"
  tput sc

  return 0
}

prompt() {
  local prompt answer color
  local default=""
  local -i timeout=10

  # Ensure the default is valid
  OPTIND=1
  while getopts "ynt:c:" opt; do
    case "$opt" in
    y) default="y" && prompt+=" [Y/n]" ;;
    n) default="n" && prompt+=" [y/N]" ;;
    t) timeout="$OPTARG" ;;
    c) color="$OPTARG" ;;
    *) exit 1 ;;
    esac
  done
  shift $((OPTIND - 1))

  # Set defaults
  color=${color:-$YEL}
  prompt="$1${prompt:-" [y/n]"}"

  # Display the prompt and countdown
  while ((timeout > 0)); do
    show_msg "$prompt$([ -n "$default" ] && echo " ($timeout)"): " "$color"
    if read -r -n 1 -s -t 1 answer; then
      case "$answer" in
      [yY]) answer="y" && break ;;
      [nN]) answer="n" && break ;;
      *)
        show_msg "Invalid input. Please enter 'y/Y' or 'n/N'."
        answer=""
        read -r -s -t 1 || true
        ;;
      esac
    fi
    [[ -z "$default" ]] || ((timeout--))
  done

  answer="${answer:-$default}"

  # Return the user's answer
  [[ "$answer" == "y" ]] && return 0 || return 1
}

print_boxed() {

  # Stop any running spinner and set terminal settings
  _stop_spinner && stty -echo && tput civis

  # Define variables
  local msg cmd title buffer
  local -i y_pos countdown height width exit_code

  # Get terminal dimensions
  IFS='[;' read -p $'\e[6n' -d R -rs _ y_pos _
  width=$((COLUMNS - 4))
  [[ $((LINES - y_pos)) -le 12 ]] && [[ $((LINES)) -ge 12 ]] && height=10 || height=$((LINES - y_pos - 2))

  # Parse options
  OPTIND=1
  while getopts "c:h:m:t:" opt; do
    case "$opt" in
    c) countdown="$OPTARG" ;;
    h) [[ $OPTARG -le $((LINES - 2)) ]] && height=$OPTARG || height=$((LINES - 2)) ;;
    m) msg="$OPTARG" ;;
    t) title="$OPTARG" ;;
    *) continue ;;
    esac
  done
  shift $((OPTIND - 1))

  # Set defaults
  cmd="$*"
  msg=${msg:-"Press any key or wait..."}
  title=${title:-$cmd}
  countdown=${countdown:-0}

  # Print the box
  _box "$title" "$width" "$height"

  # Print the message
  tput cuu $height cr sc

  eval "$cmd" 2>&1 | while IFS= read -r line; do

    # Wrap the line
    if [[ ${#line} -gt $((width - 2)) ]]; then
      line="$(echo "$line..." | fold -w $((width - 5)))"
    fi  

    buffer+=("$line")

    if ((${#buffer[@]} > height)); then
      buffer=("${buffer[@]:1}")
    fi

    tput rc

    for ((i = 0; i < height; i++)); do
      if ((i < ${#buffer[@]})); then
        tput cr cuf 3
        printf "%-*s\n" "$((width - 2))" "${buffer[i]}"
      else
        tput cr cuf 3
        printf "%-*s\n" "$((width - 2))" "" # Blank line
      fi
    done
  done

  exit_code=${PIPESTATUS[0]}

  # No action, just consume input
  while IFS= read -r -s -t 0.1 -n 1; do
    :
  done || true

  # Wait for user input or timeout
  while ((countdown > 0)); do
    tput cr cuf $((width - ${#msg} - 8))
    printf "╣ %b (%2d) ╠" "$msg" "$countdown"
    if read -r -t 1 -n 1 -s; then
      break
    fi
    ((countdown--))
  done

  # Restore terminal settings
  tput rc cuu1 ed cnorm && stty echo

  # Return the exit code
  CMD="$FUNCNAME $*"
  return $exit_code
}