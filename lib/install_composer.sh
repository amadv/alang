#!/usr/bin/env bash
# alang installer: composer
# Downloads official Composer PHAR

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "${_ALANG_HELPERS_LOADED:-}" ]] && source "$SCRIPT_DIR/helpers.sh"

install_tool() {
  local version="$1"
  local dest="$2"

  version="${version#v}"

  require_cmd curl
  require_cmd php

  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  mkdir -p "$dest/bin"

  if [[ "$version" == "latest" || "$version" == "2" || -z "$version" ]]; then
    log_info "Downloading latest Composer..."
    curl -fL --progress-bar \
      -o "$tmp_dir/composer-setup.php" \
      "https://getcomposer.org/installer" \
      || die "Failed to download Composer installer"

    php "$tmp_dir/composer-setup.php" \
      --install-dir="$dest/bin" \
      --filename=composer \
      || die "Composer installer failed"
  else
    # Specific version
    log_info "Downloading Composer ${version}..."
    local url
    if [[ "$version" == 1* ]]; then
      url="https://getcomposer.org/download/${version}/composer.phar"
    else
      url="https://github.com/composer/composer/releases/download/${version}/composer.phar"
    fi

    curl -fL --progress-bar \
      -o "$dest/bin/composer" \
      "$url" \
      || die "Failed to download Composer ${version}"
    chmod +x "$dest/bin/composer"
  fi

  log_dim "Composer installed at $dest/bin/composer"
  log_dim "Version: $("$dest/bin/composer" --version 2>/dev/null | head -1)"
}
