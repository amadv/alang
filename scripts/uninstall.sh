#!/usr/bin/env bash
# scripts/uninstall.sh — remove an installed tool version
# Usage: bash scripts/uninstall.sh <tool> <version>
# After success, Claude removes the row from state/installed.md

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_DIR/lib/helpers.sh"

ALANG_VERSIONS_DIR="${ALANG_VERSIONS_DIR:-$HOME/.alang/versions}"

tool="${1:-}"
version="${2:-}"

[[ -n "$tool" ]]    || die "Usage: bash scripts/uninstall.sh <tool> <version>"
[[ -n "$version" ]] || die "Usage: bash scripts/uninstall.sh <tool> <version>"

version="${version#v}"

dest="$ALANG_VERSIONS_DIR/$tool/$version"

[[ -d "$dest" ]] || die "$tool $version is not installed (expected: $dest)"

rm -rf "$dest"
log_success "Uninstalled $tool $version"
