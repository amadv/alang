#!/usr/bin/env bash
# alang installer: ruby
# Uses ruby-build logic or builds from source via ruby-lang.org

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "${_ALANG_HELPERS_LOADED:-}" ]] && source "$SCRIPT_DIR/helpers.sh"

install_tool() {
  local version="$1"
  local dest="$2"

  version="${version#v}"

  # Prefer ruby-build if available
  if command -v ruby-build &>/dev/null; then
    log_info "Using ruby-build..."
    ruby-build "$version" "$dest" && return 0
  fi

  _build_ruby_from_source "$version" "$dest"
}

_build_ruby_from_source() {
  local version="$1"
  local dest="$2"

  require_cmd curl
  require_cmd tar
  require_cmd make

  local url="https://cache.ruby-lang.org/pub/ruby/${version%.*}/ruby-${version}.tar.gz"
  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  log_info "Downloading Ruby ${version}..."
  curl -fL --progress-bar -o "$tmp_dir/ruby.tar.gz" "$url" \
    || die "Failed to download Ruby ${version}. Check: https://www.ruby-lang.org/en/downloads/"

  log_info "Extracting..."
  tar -xzf "$tmp_dir/ruby.tar.gz" -C "$tmp_dir"

  local src_dir
  src_dir=$(find "$tmp_dir" -maxdepth 1 -type d -name "ruby-*" | head -1)

  cd "$src_dir"

  log_info "Configuring Ruby ${version}..."
  ./configure \
    --prefix="$dest" \
    --enable-shared \
    --disable-install-doc \
    2>&1 | tail -5 &
  spinner $! "Configuring..."

  log_info "Building Ruby ${version}..."
  make -j"$(nproc 2>/dev/null || sysctl -n hw.ncpu 2>/dev/null || echo 4)" 2>&1 | tail -3 &
  spinner $! "Compiling Ruby ${version}..."

  make install 2>&1 | tail -3 &
  spinner $! "Installing..."

  log_dim "Installed: $(ls "$dest/bin/" | grep -E '^ruby|^gem|^irb|^bundle')"
  cd - > /dev/null
}

list_remote_versions() {
  curl -sf "https://cache.ruby-lang.org/pub/ruby/" \
    | grep -oE 'ruby-[0-9]+\.[0-9]+\.[0-9]+\.tar\.gz' \
    | sed 's/ruby-\(.*\)\.tar\.gz/\1/' \
    | sort -V -r \
    | uniq \
    | head -20
}
