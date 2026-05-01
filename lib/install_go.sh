#!/usr/bin/env bash
# alang installer: go

install_tool() {
  local version="$1"
  local dest="$2"

  version="${version#v}"

  require_cmd curl
  require_cmd tar

  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)

  case "$arch" in
    x86_64)        arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    armv7l)        arch="armv6l" ;;
    *) die "Unsupported arch: $arch" ;;
  esac

  local tarball="go${version}.${os}-${arch}.tar.gz"
  local url="https://go.dev/dl/${tarball}"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  log_info "Downloading Go ${version} for ${os}-${arch}..."
  curl -fL --progress-bar -o "$tmp_dir/$tarball" "$url" \
    || die "Failed to download Go ${version}. Check https://go.dev/dl/ for available versions."

  log_info "Extracting..."
  tar -xzf "$tmp_dir/$tarball" -C "$tmp_dir"

  local go_src="$tmp_dir/go"
  [[ -d "$go_src" ]] || die "Unexpected archive structure — go/ dir not found"

  mkdir -p "$dest"
  cp -r "$go_src/"* "$dest/"

  # go installs to $dest/bin/go and $dest/bin/gofmt natively
  # Also set GOROOT so toolchain can find stdlib
  if [[ ! -f "$dest/bin/go" ]]; then
    die "go binary not found after extraction"
  fi

  # Write an env file that alang can source to set GOROOT
  cat > "$dest/.alang-env" <<ENV
export GOROOT="$dest"
export PATH="$dest/bin:\$PATH"
ENV

  log_dim "Installed: $(ls "$dest/bin/")"
  log_dim "GOROOT: $dest"
  log_dim "Note: set GOPATH=~/go (or your preferred workspace) separately"
}

list_remote_versions() {
  curl -sf "https://go.dev/dl/?mode=json&include=all" \
    | jq -r '.[].version' \
    | sed 's/^go//' \
    | grep -E '^[0-9]+\.[0-9]+(\.[0-9]+)?$' \
    | sort -V -r \
    | head -20
}
