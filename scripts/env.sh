#!/usr/bin/env bash
# scripts/env.sh — emit PATH/env exports for a tool version
# Usage: bash scripts/env.sh <tool> <version>   → single tool
#        bash scripts/env.sh                    → all globals from state/globals.md
# Eval the output: eval "$(bash scripts/env.sh node 20.11.0)"

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_DIR/lib/helpers.sh"

ALANG_VERSIONS_DIR="${ALANG_VERSIONS_DIR:-$HOME/.alang/versions}"

emit_export() {
  local t="$1" v="$2"
  v="${v#v}"
  local bin_dir="$ALANG_VERSIONS_DIR/$t/$v/bin"

  if [[ ! -d "$bin_dir" ]]; then
    log_error "$t $v does not appear to be installed (no bin dir at $bin_dir)" >&2
    return 1
  fi

  # Go and Rust write a .alang-env file with extra vars (GOROOT, RUSTUP_HOME, etc.)
  local env_file="$ALANG_VERSIONS_DIR/$t/$v/.alang-env"
  if [[ -f "$env_file" ]]; then
    cat "$env_file"
  else
    echo "export PATH=\"$bin_dir:\$PATH\""
  fi
}

tool="${1:-}"
version="${2:-}"

if [[ -n "$tool" && -n "$version" ]]; then
  emit_export "$tool" "$version"
else
  globals_file="$REPO_DIR/state/globals.md"
  if [[ ! -f "$globals_file" ]]; then
    echo "# No state/globals.md found"
    exit 0
  fi

  while IFS='|' read -r _ t v _rest; do
    t="${t// /}"
    v="${v// /}"
    [[ "$t" == "tool" || "$t" == "---"* || -z "$t" ]] && continue
    emit_export "$t" "$v" || true
  done < "$globals_file"
fi
