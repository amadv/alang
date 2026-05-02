#!/usr/bin/env bash
# alang installer: php
# Uses system packages where possible, or PHP source builds

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "${_ALANG_HELPERS_LOADED:-}" ]] && source "$SCRIPT_DIR/helpers.sh"

install_tool() {
  local version="$1"
  local dest="$2"

  version="${version#v}"

  local os
  os=$(uname -s | tr '[:upper:]' '[:lower:]')

  case "$os" in
    darwin)
      _install_php_macos "$version" "$dest"
      ;;
    linux)
      _install_php_linux "$version" "$dest"
      ;;
    *)
      die "Unsupported OS: $os"
      ;;
  esac
}

_install_php_macos() {
  local version="$1"
  local dest="$2"

  # Try Homebrew first
  if command -v brew &>/dev/null; then
    log_info "Using Homebrew to install PHP ${version}..."

    local major_minor="${version%.*}"

    # Install the right formula
    brew install "php@${major_minor}" 2>&1 | tail -5 || {
      log_warn "Homebrew install failed, trying generic php..."
      brew install php || die "Could not install PHP via Homebrew"
    }

    # Find the brew-installed PHP
    local brew_prefix
    brew_prefix=$(brew --prefix "php@${major_minor}" 2>/dev/null || brew --prefix php)

    # Create a shim-like structure in dest
    mkdir -p "$dest/bin"
    for bin in "$brew_prefix/bin/"php*; do
      [[ -x "$bin" ]] && ln -sf "$bin" "$dest/bin/$(basename "$bin")"
    done

    log_dim "Linked PHP binaries from Homebrew"
    return 0
  fi

  # Fallback: build from source
  _build_php_from_source "$version" "$dest"
}

_install_php_linux() {
  local version="$1"
  local dest="$2"

  local major_minor="${version%.*}"

  # Try ondrej/php PPA on Ubuntu/Debian
  if command -v apt-get &>/dev/null; then
    log_info "Installing PHP ${version} via apt..."
    
    if ! command -v add-apt-repository &>/dev/null; then
      apt-get install -y software-properties-common 2>&1 | tail -3 || true
    fi

    # Add ondrej PPA if not present
    if ! grep -r "ondrej/php" /etc/apt/sources.list.d/ &>/dev/null 2>&1; then
      add-apt-repository -y ppa:ondrej/php 2>&1 | tail -5 || true
      apt-get update -q 2>&1 | tail -3 || true
    fi

    apt-get install -y "php${major_minor}" "php${major_minor}-cli" "php${major_minor}-common" \
      "php${major_minor}-mbstring" "php${major_minor}-xml" "php${major_minor}-curl" 2>&1 | tail -5 \
      || die "Failed to install PHP ${version}"

    # Build dest/bin structure
    mkdir -p "$dest/bin"
    local php_bin
    php_bin=$(command -v "php${major_minor}" 2>/dev/null || command -v php)
    ln -sf "$php_bin" "$dest/bin/php"

    log_dim "PHP ${version} installed and linked"
    return 0
  fi

  # yum/dnf
  if command -v dnf &>/dev/null || command -v yum &>/dev/null; then
    log_info "Installing PHP via dnf/yum..."
    local pkg_mgr
    command -v dnf &>/dev/null && pkg_mgr=dnf || pkg_mgr=yum
    "$pkg_mgr" install -y "php${major_minor//./}" || die "Failed to install PHP"
    mkdir -p "$dest/bin"
    ln -sf "$(command -v php)" "$dest/bin/php"
    return 0
  fi

  _build_php_from_source "$version" "$dest"
}

_build_php_from_source() {
  local version="$1"
  local dest="$2"

  require_cmd curl
  require_cmd tar
  require_cmd make

  local url="https://www.php.net/distributions/php-${version}.tar.gz"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  log_info "Downloading PHP ${version} source..."
  curl -fL --progress-bar -o "$tmp_dir/php.tar.gz" "$url" \
    || die "Failed to download PHP ${version}"

  log_info "Extracting..."
  tar -xzf "$tmp_dir/php.tar.gz" -C "$tmp_dir"

  local src_dir
  src_dir=$(find "$tmp_dir" -maxdepth 1 -type d -name "php-*" | head -1)
  cd "$src_dir"

  log_info "Configuring PHP ${version}..."
  ./configure \
    --prefix="$dest" \
    --with-openssl \
    --with-zlib \
    --enable-mbstring \
    --enable-xml \
    --with-curl \
    2>&1 | tail -5 &
  spinner $! "Configuring..."

  make -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu || echo 4)" 2>&1 | tail -3 &
  spinner $! "Compiling PHP ${version}..."

  make install 2>&1 | tail -3 &
  spinner $! "Installing..."

  log_dim "Installed: $(ls "$dest/bin/")"
  cd - > /dev/null
}
