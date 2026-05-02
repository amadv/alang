#!/usr/bin/env bash
# alang installer: java
# Uses Adoptium (Eclipse Temurin) pre-built JDK binaries

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "${_ALANG_HELPERS_LOADED:-}" ]] && source "$SCRIPT_DIR/helpers.sh"

install_tool() {
  local version="$1"
  local dest="$2"

  version="${version#v}"

  require_cmd curl
  require_cmd tar

  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)

  # Normalize for Adoptium API
  case "$os" in
    darwin) os="mac" ;;
    linux)  os="linux" ;;
    *)      die "Unsupported OS: $os" ;;
  esac

  case "$arch" in
    x86_64)        arch="x64" ;;
    aarch64|arm64) arch="aarch64" ;;
    armv7l)        arch="arm" ;;
    *)             die "Unsupported arch: $arch" ;;
  esac

  # Get major version (e.g., 21 from 21.0.1)
  local major_version="${version%%.*}"

  # Try Adoptium API to find the exact release
  log_info "Fetching JDK ${version} (Temurin) for ${os}-${arch}..."

  local api_url="https://api.adoptium.net/v3/assets/feature_releases/${major_version}/ga"
  local release_info
  release_info=$(curl -sf "${api_url}?architecture=${arch}&image_type=jdk&jvm_impl=hotspot&os=${os}&page=0&page_size=5&project=jdk&vendor=eclipse") || {
    log_warn "Adoptium API unavailable, trying direct URL..."
    _install_java_direct "$version" "$major_version" "$os" "$arch" "$dest"
    return
  }

  local download_url checksum
  download_url=$(echo "$release_info" | jq -r '.[0].binaries[0].package.link // empty')
  checksum=$(echo "$release_info" | jq -r '.[0].binaries[0].package.checksum // empty')

  if [[ -z "$download_url" ]]; then
    log_warn "Could not find JDK via API, trying direct download..."
    _install_java_direct "$version" "$major_version" "$os" "$arch" "$dest"
    return
  fi

  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  log_info "Downloading Temurin JDK ${version}..."
  curl -fL --progress-bar -o "$tmp_dir/jdk.tar.gz" "$download_url" \
    || die "Download failed"

  log_info "Extracting JDK..."
  tar -xzf "$tmp_dir/jdk.tar.gz" -C "$tmp_dir"

  local jdk_dir
  jdk_dir=$(find "$tmp_dir" -maxdepth 2 -type d -name "jdk*" | grep -v "\.tar" | head -1)

  # macOS JDKs have Contents/Home structure
  if [[ -d "$jdk_dir/Contents/Home" ]]; then
    jdk_dir="$jdk_dir/Contents/Home"
  fi

  mkdir -p "$dest"
  cp -r "$jdk_dir/"* "$dest/"

  # Ensure bin is at $dest/bin
  if [[ ! -d "$dest/bin" ]] && [[ -d "$dest/Contents/Home/bin" ]]; then
    ln -s "$dest/Contents/Home/bin" "$dest/bin"
  fi

  log_dim "Installed: $(ls "$dest/bin/" | grep -E '^java|^javac|^jar' | head -5)"
}

_install_java_direct() {
  local version="$1"
  local major="$2"
  local os="$3"
  local arch="$4"
  local dest="$5"

  # Construct a known Adoptium URL pattern
  # e.g.: https://github.com/adoptium/temurin21-binaries/releases/download/jdk-21.0.1%2B12/...
  local arch_suffix="$arch"
  [[ "$arch" == "aarch64" ]] && arch_suffix="aarch64"

  local ext="tar.gz"
  [[ "$os" == "windows" ]] && ext="zip"

  # Use Adoptium latest for the major version
  local url="https://api.adoptium.net/v3/binary/latest/${major}/ga/${os}/${arch}/jdk/hotspot/normal/eclipse"

  local tmp_dir
  tmp_dir=$(mktemp -d)

  log_info "Downloading Temurin JDK ${major} (latest)..."
  curl -fL --progress-bar -o "$tmp_dir/jdk.tar.gz" "$url" \
    || die "Failed to download Java JDK. Check https://adoptium.net/"

  tar -xzf "$tmp_dir/jdk.tar.gz" -C "$tmp_dir"

  local jdk_dir
  jdk_dir=$(find "$tmp_dir" -maxdepth 2 -type d \( -name "jdk*" -o -name "temurin*" \) | grep -v "\.tar" | head -1)

  [[ -d "$jdk_dir/Contents/Home" ]] && jdk_dir="$jdk_dir/Contents/Home"

  mkdir -p "$dest"
  cp -r "$jdk_dir/"* "$dest/"

  log_dim "Installed: $(ls "$dest/bin/" | grep -E '^java' | head -5)"
}
