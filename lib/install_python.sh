#!/usr/bin/env bash
# alang installer: python
# Builds from source using python.org tarballs

install_tool() {
  local version="$1"
  local dest="$2"

  # Strip leading 'v' if present
  version="${version#v}"

  # Check if we can use a pre-built approach first
  if _try_pyenv_style "$version" "$dest"; then
    return 0
  fi

  _build_from_source "$version" "$dest"
}

_try_pyenv_style() {
  local version="$1"
  local dest="$2"

  # Try python-build if available (from pyenv)
  if command -v python-build &>/dev/null; then
    log_info "Using python-build..."
    python-build "$version" "$dest" && return 0
  fi
  return 1
}

_build_from_source() {
  local version="$1"
  local dest="$2"

  require_cmd curl
  require_cmd tar
  require_cmd make
  require_cmd gcc

  local url="https://www.python.org/ftp/python/${version}/Python-${version}.tgz"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  log_info "Downloading Python ${version}..."
  curl -fL --progress-bar -o "$tmp_dir/python.tgz" "$url" \
    || die "Failed to download Python ${version}"

  log_info "Extracting..."
  tar -xzf "$tmp_dir/python.tgz" -C "$tmp_dir"

  local src_dir
  src_dir=$(find "$tmp_dir" -maxdepth 1 -type d -name "Python-*" | head -1)

  log_info "Configuring Python ${version} (this may take a few minutes)..."
  cd "$src_dir"

  local configure_flags=(
    "--prefix=$dest"
    "--enable-optimizations"
    "--with-ensurepip=install"
  )

  # Add OpenSSL path hints for common locations
  for ssl_dir in /usr/local/opt/openssl /opt/homebrew/opt/openssl /usr/local/ssl; do
    if [[ -d "$ssl_dir" ]]; then
      configure_flags+=("--with-openssl=$ssl_dir")
      break
    fi
  done

  ./configure "${configure_flags[@]}" 2>&1 | tail -5 &
  spinner $! "Configuring..."

  log_info "Building (this takes 2-5 minutes)..."
  make -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)" 2>&1 | tail -3 &
  spinner $! "Compiling Python ${version}..."

  log_info "Installing..."
  make install 2>&1 | tail -3 &
  spinner $! "Installing..."

  # Create python -> python3 symlink if needed
  if [[ ! -f "$dest/bin/python" ]] && [[ -f "$dest/bin/python3" ]]; then
    ln -s "$dest/bin/python3" "$dest/bin/python"
  fi
  if [[ ! -f "$dest/bin/pip" ]] && [[ -f "$dest/bin/pip3" ]]; then
    ln -s "$dest/bin/pip3" "$dest/bin/pip"
  fi

  log_dim "Installed: $(ls "$dest/bin/" | grep -E '^python|^pip')"
  cd - > /dev/null
}

list_remote_versions() {
  curl -sf "https://www.python.org/ftp/python/" \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
    | sort -V -r \
    | uniq \
    | head -20
}
