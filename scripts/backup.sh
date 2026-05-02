#!/usr/bin/env bash
# scripts/backup.sh — commit state/ changes to git
# Usage: bash scripts/backup.sh [commit-message]

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$REPO_DIR/lib/helpers.sh"

msg="${1:-"chore: update state [$(date '+%Y-%m-%d')]"}"

cd "$REPO_DIR"

if ! git diff --quiet state/ 2>/dev/null || git ls-files --others --exclude-standard state/ | grep -q .; then
  git add state/
  git commit -m "$msg"
  git push
  log_success "State backed up: $msg"
else
  log_info "No changes in state/ to commit"
fi
