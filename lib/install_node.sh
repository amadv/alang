#!/usr/bin/env bash
# alang installer: node
# Uses official Node.js binary distributions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "${_ALANG_HELPERS_LOADED:-}" ]] && source "$SCRIPT_DIR/helpers.sh"

install_tool() {
  local version="$1"
  local dest="$2"

  require_cmd curl
  require_cmd tar

  # Strip leading 'v' if present
  version="${version#v}"

  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)

  # Normalize arch
  case "$arch" in
    x86_64)  arch="x64" ;;
    aarch64|arm64) arch="arm64" ;;
    armv7l)  arch="armv7l" ;;
    *) die "Unsupported architecture: $arch" ;;
  esac

  # macOS -> darwin
  [[ "$os" == "darwin" ]] && os="darwin"
  [[ "$os" == "linux" ]]  && os="linux"

  local tarball="node-v${version}-${os}-${arch}.tar.gz"
  local url="https://nodejs.org/dist/v${version}/${tarball}"
  local tmp_dir
  tmp_dir=$(mktemp -d)

  trap 'rm -rf "$tmp_dir"' EXIT

  log_info "Downloading Node.js v${version} for ${os}-${arch}..."
  curl -fL --progress-bar -o "$tmp_dir/$tarball" "$url" \
    || die "Failed to download Node.js v${version}. Check version exists at https://nodejs.org/dist/"

  log_info "Extracting..."
  mkdir -p "$dest"
  tar -xzf "$tmp_dir/$tarball" -C "$tmp_dir"

  local extracted_dir
  extracted_dir=$(find "$tmp_dir" -maxdepth 1 -type d -name "node-v*" | head -1)
  [[ -n "$extracted_dir" ]] || die "Could not find extracted Node.js directory"

  # Move to destination
  mv "$extracted_dir/bin"    "$dest/bin"    2>/dev/null || true
  mv "$extracted_dir/lib"    "$dest/lib"    2>/dev/null || true
  mv "$extracted_dir/share"  "$dest/share"  2>/dev/null || true
  mv "$extracted_dir/include" "$dest/include" 2>/dev/null || true

  log_dim "Installed: $(ls "$dest/bin/")"
}

list_remote_versions() {
  curl -sf "https://nodejs.org/dist/index.json" \
    | jq -r '.[].version' \
    | sed 's/^v//' \
    | head -30
}
