#!/usr/bin/env bash
# alang setup script — installs alang to ~/.alang/bin and configures shell

set -euo pipefail

ALANG_DIR="${ALANG_DIR:-$HOME/.alang}"
ALANG_BIN_DIR="$ALANG_DIR/bin"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

log_info()    { echo -e "${CYAN}→${RESET} $*"; }
log_success() { echo -e "${GREEN}✓${RESET} $*"; }
log_dim()     { echo -e "${DIM}  $*${RESET}"; }

echo ""
echo -e "  ${BOLD}alang${RESET} installer"
echo ""

# Create dirs
mkdir -p "$ALANG_BIN_DIR"
mkdir -p "$ALANG_DIR/versions"
mkdir -p "$ALANG_DIR/shims"
mkdir -p "$ALANG_DIR/config"

# Copy alang CLI
cp "$SCRIPT_DIR/alang" "$ALANG_BIN_DIR/alang"
chmod +x "$ALANG_BIN_DIR/alang"
log_success "Installed alang CLI to $ALANG_BIN_DIR/alang"

# Copy lib
mkdir -p "$ALANG_DIR/lib"
cp -r "$SCRIPT_DIR/lib/"* "$ALANG_DIR/lib/"
log_success "Installed library files"

# Update the LIB_DIR reference in the installed alang binary
sed -i.bak "s|LIB_DIR=.*|LIB_DIR=\"$ALANG_DIR/lib\"|" "$ALANG_BIN_DIR/alang" 2>/dev/null || true
sed -i.bak "s|ALANG_BIN=.*|ALANG_BIN=\"$ALANG_BIN_DIR/alang\"|" "$ALANG_BIN_DIR/alang" 2>/dev/null || true
rm -f "$ALANG_BIN_DIR/alang.bak"

# Detect shell and config file
detect_shell_config() {
  local shell_name
  shell_name=$(basename "$SHELL")
  case "$shell_name" in
    zsh)   echo "$HOME/.zshrc" ;;
    bash)
      if [[ "$(uname)" == "Darwin" ]]; then
        echo "$HOME/.bash_profile"
      else
        echo "$HOME/.bashrc"
      fi
      ;;
    fish)  echo "$HOME/.config/fish/config.fish" ;;
    *)     echo "$HOME/.profile" ;;
  esac
}

SHELL_CONFIG=$(detect_shell_config)

# Shell snippet
SHELL_SNIPPET='
# alang version manager
export PATH="$HOME/.alang/bin:$HOME/.alang/shims:$PATH"
'

# Add to shell config if not already present
if [[ -f "$SHELL_CONFIG" ]] && grep -q "alang version manager" "$SHELL_CONFIG" 2>/dev/null; then
  log_info "Shell config already updated: $SHELL_CONFIG"
else
  echo "$SHELL_SNIPPET" >> "$SHELL_CONFIG"
  log_success "Updated $SHELL_CONFIG"
fi

# Check for API key
echo ""
if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
  echo "$ANTHROPIC_API_KEY" > "$ALANG_DIR/anthropic_key"
  chmod 600 "$ALANG_DIR/anthropic_key"
  log_success "Saved ANTHROPIC_API_KEY to $ALANG_DIR/anthropic_key"
elif [[ -f "$ALANG_DIR/anthropic_key" ]]; then
  log_info "Existing API key found"
else
  echo -e "  ${DIM}No ANTHROPIC_API_KEY set. You can add it later with:${RESET}"
  echo -e "  ${DIM}  alang auth <your-key>${RESET}"
  echo -e "  ${DIM}or:${RESET}"
  echo -e "  ${DIM}  export ANTHROPIC_API_KEY=sk-ant-...${RESET}"
fi

echo ""
echo -e "  ${GREEN}${BOLD}alang installed!${RESET}"
echo ""
echo -e "  Reload your shell or run:"
echo -e "  ${CYAN}  source $SHELL_CONFIG${RESET}"
echo ""
echo -e "  Then try:"
echo -e "  ${CYAN}  alang doctor${RESET}          — check everything is ready"
echo -e "  ${CYAN}  alang install node${RESET}     — install latest Node.js"
echo -e "  ${CYAN}  alang install python${RESET}   — install latest Python"
echo -e "  ${CYAN}  alang ask 'what version of Ruby for Rails 7?'${RESET}"
echo ""
