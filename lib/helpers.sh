#!/usr/bin/env bash
# lib/helpers.sh — shared helper functions for alang installers

[[ -n "${_ALANG_HELPERS_LOADED:-}" ]] && return 0
_ALANG_HELPERS_LOADED=1

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

log_info()    { echo -e "${CYAN}→${RESET} $*"; }
log_success() { echo -e "${GREEN}✓${RESET} $*"; }
log_warn()    { echo -e "${YELLOW}⚠${RESET} $*"; }
log_error()   { echo -e "${RED}✗${RESET} $*" >&2; }
log_dim()     { echo -e "${DIM}  $*${RESET}"; }
log_header()  { echo -e "\n${BOLD}${BLUE}$*${RESET}"; }

die() { log_error "$*"; exit 1; }

require_cmd() {
  command -v "$1" &>/dev/null || die "Required command not found: $1"
}

spinner() {
  local pid=$1 msg=${2:-"Working..."}
  local frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
  local i=0
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r${CYAN}%s${RESET} %s" "${frames[$((i % 10))]}" "$msg"
    sleep 0.08
    ((i++))
  done
  printf "\r\033[K"
}
