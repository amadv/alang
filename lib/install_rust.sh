#!/usr/bin/env bash
# alang installer: rust

install_tool() {
  local version="$1"
  local dest="$2"

  version="${version#v}"

  require_cmd curl

  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  # rustup needs RUSTUP_HOME and CARGO_HOME pointed into $dest
  local rustup_home="$dest/rustup"
  local cargo_home="$dest/cargo"
  mkdir -p "$rustup_home" "$cargo_home" "$dest/bin"

  log_info "Downloading rustup installer..."
  curl -fL --progress-bar \
    -o "$tmp_dir/rustup-init" \
    "https://sh.rustup.rs" \
    || die "Failed to download rustup"

  chmod +x "$tmp_dir/rustup-init"

  log_info "Installing Rust ${version} via rustup (non-interactive)..."

  local toolchain
  if [[ "$version" == "latest" || "$version" == "stable" ]]; then
    toolchain="stable"
  elif [[ "$version" == "nightly" ]]; then
    toolchain="nightly"
  else
    toolchain="${version}"
  fi

  RUSTUP_HOME="$rustup_home" \
  CARGO_HOME="$cargo_home" \
    "$tmp_dir/rustup-init" \
      --no-modify-path \
      --quiet \
      -y \
      --default-toolchain "$toolchain" \
    || die "rustup-init failed"

  # Symlink key binaries into $dest/bin so alang shims can find them
  for bin in rustc cargo rustup rustfmt clippy-driver rust-analyzer; do
    local src="$cargo_home/bin/$bin"
    if [[ -x "$src" ]]; then
      ln -sf "$src" "$dest/bin/$bin"
    fi
  done

  # Write env file for RUSTUP_HOME / CARGO_HOME
  cat > "$dest/.alang-env" <<ENV
export RUSTUP_HOME="$rustup_home"
export CARGO_HOME="$cargo_home"
export PATH="$dest/bin:\$PATH"
ENV

  log_dim "Installed: $(ls "$dest/bin/")"
  log_dim "rustc: $("$dest/bin/rustc" --version 2>/dev/null || echo 'unknown')"
  log_dim "cargo: $("$dest/bin/cargo" --version 2>/dev/null || echo 'unknown')"
}

list_remote_versions() {
  # Rust stable channel versions via releases JSON
  curl -sf "https://static.rust-lang.org/dist/channel-rust-stable.toml" \
    | grep -E '^version = ' \
    | head -1 \
    | grep -oE '[0-9]+\.[0-9]+\.[0-9]+' \
    || echo "stable"

  # Common pinnable versions
  cat <<VERSIONS
stable
nightly
beta
1.78.0
1.77.0
1.76.0
1.75.0
1.74.0
1.73.0
1.72.0
1.70.0
VERSIONS
}
