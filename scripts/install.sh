#!/usr/bin/env bash
# scripts/install.sh — install a tool version
# Usage: bash scripts/install.sh <tool> <version>
# Installs to: ~/.alang/versions/<tool>/<version>/
# After success, Claude updates state/installed.md

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LIB_DIR="$REPO_DIR/lib"

source "$LIB_DIR/helpers.sh"

ALANG_VERSIONS_DIR="${ALANG_VERSIONS_DIR:-$HOME/.alang/versions}"

tool="${1:-}"
version="${2:-}"

[[ -n "$tool" ]]    || die "Usage: bash scripts/install.sh <tool> <version>"
[[ -n "$version" ]] || die "Usage: bash scripts/install.sh <tool> <version>"

case "$tool" in
  node|nodejs|node.js)  tool="node" ;;
  python|python3|py)    tool="python" ;;
  ruby|rb)              tool="ruby" ;;
  php)                  tool="php" ;;
  java|jdk|openjdk)     tool="java" ;;
  composer)             tool="composer" ;;
  go|golang)            tool="go" ;;
  rust|rustlang|rs)     tool="rust" ;;
esac

version="${version#v}"

dest="$ALANG_VERSIONS_DIR/$tool/$version"

if [[ -d "$dest" ]]; then
  log_warn "$tool $version is already installed at $dest"
  exit 0
fi

installer="$LIB_DIR/install_${tool}.sh"
[[ -f "$installer" ]] || die "No installer found for: $tool (looked for $installer)"

mkdir -p "$dest"

# NOTE: sourcing may cd into temp dirs (python/ruby source builds); this is expected
# shellcheck source=/dev/null
source "$installer"

log_header "Installing $tool $version"
install_tool "$version" "$dest"

log_success "Installed $tool $version to $dest"
