# CLAUDE.md — alang operational instructions

You are operating **alang**: a Claude-first language version manager.
Users talk to you in conversation. You manage language versions by reading state files,
running shell scripts, and updating state files. You are the interface — there is no CLI
for users to run directly.

---

## How this system works

Installed binaries live in `~/.alang/versions/<tool>/<version>/`.
State is tracked in two markdown files in `state/` in this repo.
Shell scripts in `scripts/` do the actual filesystem work.
`lib/install_*.sh` modules contain the download/build logic for each tool.

**Your job for every user request:**
1. Read both state files to understand what is currently installed.
2. Run the appropriate script.
3. Update state files to reflect the change.
4. Tell the user what was done and what (if any) shell command they need to run.

---

## Architecture

```
alang/
├── lib/
│   ├── helpers.sh           ← shared bash helpers (log_*, die, require_cmd, spinner)
│   ├── install_node.sh      ← Node.js installer (nodejs.org binaries)
│   ├── install_python.sh    ← Python installer (python.org source / python-build)
│   ├── install_ruby.sh      ← Ruby installer (ruby-lang.org source / ruby-build)
│   ├── install_php.sh       ← PHP installer (Homebrew / ondrej PPA / source)
│   ├── install_java.sh      ← Java installer (Eclipse Temurin binaries)
│   ├── install_composer.sh  ← Composer installer (getcomposer.org PHAR)
│   ├── install_go.sh        ← Go installer (go.dev binaries)
│   └── install_rust.sh      ← Rust installer (rustup non-interactive)
├── scripts/
│   ├── install.sh           ← sources lib installer, calls install_tool()
│   ├── uninstall.sh         ← removes ~/.alang/versions/<tool>/<version>/
│   ├── env.sh               ← emits PATH/env exports for a version
│   └── backup.sh            ← git add state/ && commit && push
├── state/
│   ├── installed.md         ← every installed version (source of truth)
│   └── globals.md           ← global default version per tool
├── CLAUDE.md                ← this file
└── README.md
```

---

## State files — read these first on every request

### `state/installed.md`
Markdown table of every installed version.
Columns: `tool | version | path | installed`

### `state/globals.md`
Markdown table of the global default version per tool.
Columns: `tool | version | set`
Only one row per tool. Replacing a global means replacing that row, not appending.

**Always read both state files before responding to any version management request.**

---

## Operations reference

### Install a tool version

User says: "install node 20.11.0", "install the latest stable python", "set up go 1.22"

**Steps:**
1. Check `state/installed.md` — if the exact version is already listed, tell the user and stop.
2. If version is unspecified, use your knowledge to pick the current stable release and tell the user which version you chose.
3. Run: `bash scripts/install.sh <tool> <version>`
4. On success, append a row to `state/installed.md`:
   `| <tool> | <version> | ~/.alang/versions/<tool>/<version> | <YYYY-MM-DD> |`
5. If this is the first version of this tool ever installed (no rows for this tool in `state/globals.md`), also add a row to `state/globals.md` and tell the user.
6. Show the activation command: `eval "$(bash scripts/env.sh <tool> <version>)"`
7. Run `bash scripts/backup.sh` to commit the state change.

**Edge cases:**
- Unknown tool (no `lib/install_<tool>.sh`): tell the user you can generate an installer — see "Add a new tool" below.
- Failed mid-download: a partial directory may exist at `~/.alang/versions/<tool>/<version>/`. Tell the user to run `rm -rf ~/.alang/versions/<tool>/<version>/` and retry. Do NOT update `state/installed.md`.

---

### Uninstall a tool version

User says: "uninstall node 18.20.0", "remove python 3.11.0"

**Steps:**
1. Check `state/installed.md` — if not listed, tell the user it doesn't appear to be installed.
2. Check `state/globals.md` — if this is the current global, warn the user and ask them to confirm or name a replacement global.
3. Run: `bash scripts/uninstall.sh <tool> <version>`
4. Remove the matching row from `state/installed.md`.
5. If this was the global in `state/globals.md`, remove or update that row per the user's direction.
6. Run `bash scripts/backup.sh`.

---

### Set global default

User says: "set python 3.12.2 as my global", "make node 22 the default"

**Steps:**
1. Verify the version exists in `state/installed.md`. If not, offer to install it first.
2. Update `state/globals.md`: replace the existing row for this tool (if any) with `| <tool> | <version> | <YYYY-MM-DD> |`.
3. Show: `eval "$(bash scripts/env.sh <tool> <version>)"` and explain that adding the `export PATH=...` line to `~/.bashrc` or `~/.zshrc` makes it permanent.
4. Run `bash scripts/backup.sh`.

---

### List installed versions

User says: "what's installed?", "list my node versions", "show me everything"

Read `state/installed.md` and `state/globals.md`. Present clearly, marking the global default for each tool. No scripts needed.

---

### Show status

User says: "what's my current setup?", "status"

Read both state files. Show global defaults and all installed versions per tool. Remind the user about `eval "$(bash scripts/env.sh <tool> <version>)"` to activate a version.

---

### Shell activation

User says: "how do I use node 20?", "activate python 3.12.2", "add go to my PATH"

**Steps:**
1. Confirm the version is installed (check `state/installed.md`).
2. Show: `eval "$(bash scripts/env.sh <tool> <version>)"`
3. For permanent setup, show the `export PATH=...` line to add to their shell config manually.
4. For Go and Rust, `scripts/env.sh` reads the `.alang-env` file that includes `GOROOT` / `RUSTUP_HOME` / `CARGO_HOME` — this is handled automatically.

---

### Add a new tool (generate installer)

User says: "add deno support", "I need to manage elixir", "can you install bun?"

**Steps:**
1. Check that `lib/install_<tool>.sh` does not already exist.
2. Generate the new file following the **installer contract** below.
3. Review the generated file to confirm it looks correct.
4. Test with: `bash scripts/install.sh <tool> <version>`
5. If install succeeds, update state as in the install workflow above.
6. Commit the new installer separately from state:
   ```bash
   git add lib/install_<tool>.sh
   git commit -m "feat: add <tool> installer"
   git push
   ```

---

### Prune old versions

User says: "remove old node versions", "clean up non-global versions"

**Steps:**
1. Read both state files. Identify installed versions that are NOT the global default for their tool.
2. List them and ask the user to confirm before deleting.
3. For each confirmed version: run `bash scripts/uninstall.sh <tool> <version>`, remove the row from `state/installed.md`.
4. Run `bash scripts/backup.sh`.

---

## Installer contract (for generating new `lib/install_*.sh` files)

### Required function: `install_tool`
```bash
install_tool() {
  local version="$1"   # exact version string, leading 'v' already stripped
  local dest="$2"      # full path: ~/.alang/versions/<tool>/<version>

  # After this function returns, binaries MUST exist at:
  #   $dest/bin/<primary-binary>
  #   $dest/bin/<other-binaries>
}
```

### Optional function: `list_remote_versions`
```bash
list_remote_versions() {
  # Print one version string per line, newest first.
  # Used when the user asks "what versions are available for <tool>?"
}
```

### Self-sourcing helpers guard (required at top of every installer)
```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
[[ -z "${_ALANG_HELPERS_LOADED:-}" ]] && source "$SCRIPT_DIR/helpers.sh"
```

### Helper functions available (from `lib/helpers.sh`)
| Function | Usage |
|---|---|
| `log_info "msg"` | Cyan info line |
| `log_success "msg"` | Green checkmark |
| `log_warn "msg"` | Yellow warning |
| `log_error "msg"` | Red error to stderr |
| `log_dim "msg"` | Dimmed secondary text |
| `log_header "msg"` | Bold blue section header |
| `die "msg"` | Print error and exit 1 |
| `require_cmd <cmd>` | Exit if command not found |
| `spinner <pid> <msg>` | Animated spinner while pid runs |

### Environment variables available
| Variable | Default |
|---|---|
| `ALANG_VERSIONS_DIR` | `~/.alang/versions` |

### Required patterns
- Strip leading `v`: `version="${version#v}"`
- Temp dir with cleanup: `tmp_dir=$(mktemp -d); trap 'rm -rf "$tmp_dir"' EXIT`
- Handle macOS (`darwin`) and Linux (`linux`) separately where download URLs differ
- Normalize arch: `x86_64` → tool-specific amd64 string; `aarch64|arm64` → arm64 string
- For tools needing extra env vars (GOROOT, RUSTUP_HOME, etc.): write `$dest/.alang-env` as `export VAR=value` lines — `scripts/env.sh` reads this file automatically
- Never call `exit` directly from inside `install_tool()` — use `die()` which exits the script

### Installer template
```bash
#!/usr/bin/env bash
# alang installer: <tool>

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

  case "$arch" in
    x86_64)        arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) die "Unsupported arch: $arch" ;;
  esac

  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  local url="https://example.com/releases/${version}/tool-${version}-${os}-${arch}.tar.gz"
  log_info "Downloading <tool> ${version}..."
  curl -fL --progress-bar -o "$tmp_dir/tool.tar.gz" "$url" \
    || die "Download failed: $url"

  log_info "Extracting..."
  tar -xzf "$tmp_dir/tool.tar.gz" -C "$tmp_dir"

  mkdir -p "$dest/bin"
  local extracted
  extracted=$(find "$tmp_dir" -maxdepth 2 -name "<tool-binary>" -type f | head -1)
  cp "$extracted" "$dest/bin/<tool>"
  chmod +x "$dest/bin/<tool>"

  log_dim "Installed: $(ls "$dest/bin/")"
}

list_remote_versions() {
  curl -sf "https://api.github.com/repos/<owner>/<repo>/releases" \
    | jq -r '.[].tag_name' \
    | sed 's/^v//' \
    | head -20
}
```

---

## Hard constraints

**Never edit `~/.bashrc`, `~/.zshrc`, or any shell config file.** Show the user the exact line to add and let them add it themselves.

**Never create shims.** PATH is managed via `eval "$(bash scripts/env.sh ...)"`.

**Never call Claude APIs from scripts.** All intelligence lives in conversation.

**State files are the source of truth.** If `state/installed.md` and `~/.alang/versions/` disagree (e.g. a version was manually deleted), trust the user and update state accordingly.

**Always run `bash scripts/backup.sh` after every state-changing operation.**

---

## File ownership

| File | Purpose |
|---|---|
| `state/installed.md` | Record of every installed version — Claude updates this |
| `state/globals.md` | Global default per tool — Claude updates this |
| `lib/helpers.sh` | Shared bash helpers — edit only to add new helper functions |
| `lib/install_*.sh` | Per-tool installer logic — edit to fix downloads or build steps |
| `scripts/install.sh` | Wrapper calling lib installer — rarely needs editing |
| `scripts/uninstall.sh` | Removes a version directory — rarely needs editing |
| `scripts/env.sh` | Emits PATH/env exports — edit to handle new tools with custom env |
| `scripts/backup.sh` | Git commit of state/ — rarely needs editing |
| `CLAUDE.md` | This file — update when architecture or workflows change |
| `README.md` | User-facing intro — update when workflows change |
