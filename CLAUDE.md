# CLAUDE.md — alang project instructions

This file is read by Claude Code and Claude agents when working on the alang codebase.
Follow these conventions exactly.

---

## What is alang

`alang` is a shell-native version manager (like `mise` / `asdf`) with Claude AI built in.
It installs and manages multiple versions of programming language runtimes on macOS and Linux.

- Main binary: `alang` (bash, ~850 lines)
- Installer modules: `lib/install_<tool>.sh` (one per tool)
- Shell completions: `completions/alang.bash`
- Config lives in: `~/.alang/`

---

## Architecture

```
alang/
├── alang                    ← main CLI (all commands, dispatch, AI calls)
├── setup.sh                 ← one-shot installer
├── lib/
│   ├── install_node.sh      ← Node.js installer module
│   ├── install_python.sh    ← Python installer module
│   ├── install_ruby.sh      ← Ruby installer module
│   ├── install_php.sh       ← PHP installer module
│   ├── install_java.sh      ← Java (Temurin/Adoptium) installer module
│   ├── install_composer.sh  ← PHP Composer installer module
│   ├── install_go.sh        ← Go installer module (official go.dev binaries)
│   └── install_rust.sh      ← Rust installer module (via rustup)
├── completions/
│   └── alang.bash           ← bash + zsh tab completions
├── CLAUDE.md                ← this file
└── README.md
```

### How installers are loaded

The main `alang` binary `source`s installer modules at runtime via `source_installer()`:

```bash
source_installer() {
  local tool="$1"
  local installer="$LIB_DIR/install_${tool}.sh"
  source "$installer"
}
```

Each installer module must define `install_tool(version, dest)` as its entry point.

---

## Installer module contract

Every file in `lib/install_<tool>.sh` MUST follow this exact interface:

### Required function: `install_tool`

```bash
install_tool() {
  local version="$1"   # e.g. "1.2.3"
  local dest="$2"      # e.g. "/home/user/.alang/versions/go/1.2.3"

  # After this function returns, binaries MUST exist at:
  #   $dest/bin/<toolname>
  #   $dest/bin/<other-binaries>
}
```

### Optional function: `list_remote_versions`

```bash
list_remote_versions() {
  # Print one version string per line, newest first
  # Used by: alang list --remote <tool>
}
```

### Helper functions available in scope (do NOT redefine)

These are defined in `alang` and available when the installer is sourced:

| Function | Usage |
|---|---|
| `log_info "msg"` | Cyan arrow info line |
| `log_success "msg"` | Green checkmark |
| `log_warn "msg"` | Yellow warning |
| `log_error "msg"` | Red error to stderr |
| `log_dim "msg"` | Dimmed secondary text |
| `log_header "msg"` | Bold blue section header |
| `die "msg"` | Print error and exit 1 |
| `require_cmd <cmd>` | Exit if command not found |
| `spinner <pid> <msg>` | Animated spinner while pid runs |

### Environment variables available

| Variable | Value |
|---|---|
| `ALANG_DIR` | `~/.alang` |
| `ALANG_VERSIONS_DIR` | `~/.alang/versions` |
| `ALANG_CONFIG` | `~/.alang/config` |

### Installer template

Use this as the starting point for any new installer:

```bash
#!/usr/bin/env bash
# alang installer: <tool>

install_tool() {
  local version="$1"
  local dest="$2"

  # Strip leading 'v' if user passes "v1.2.3"
  version="${version#v}"

  require_cmd curl
  require_cmd tar

  local os arch
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)

  # Normalize arch
  case "$arch" in
    x86_64)        arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *) die "Unsupported arch: $arch" ;;
  esac

  local tmp_dir
  tmp_dir=$(mktemp -d)
  trap 'rm -rf "$tmp_dir"' EXIT

  # --- download ---
  local url="https://example.com/releases/${version}/tool-${version}-${os}-${arch}.tar.gz"
  log_info "Downloading <tool> ${version}..."
  curl -fL --progress-bar -o "$tmp_dir/tool.tar.gz" "$url" \
    || die "Download failed: $url"

  # --- extract ---
  log_info "Extracting..."
  tar -xzf "$tmp_dir/tool.tar.gz" -C "$tmp_dir"

  # --- install ---
  mkdir -p "$dest/bin"
  local extracted
  extracted=$(find "$tmp_dir" -maxdepth 2 -name "<tool-binary>" -type f | head -1)
  cp "$extracted" "$dest/bin/<tool>"
  chmod +x "$dest/bin/<tool>"

  log_dim "Installed: $(ls "$dest/bin/")"
}

list_remote_versions() {
  # Example: scrape GitHub releases
  curl -sf "https://api.github.com/repos/<owner>/<repo>/releases" \
    | jq -r '.[].tag_name' \
    | sed 's/^v//' \
    | head -20
}
```

---

## Adding a new language/tool

### Automated (preferred): `alang add <tool>`

```bash
alang add go       # Claude generates lib/install_go.sh
alang add rust     # Claude generates lib/install_rust.sh
alang add deno     # Claude generates lib/install_deno.sh
alang add elixir   # etc.
```

Claude will:
1. Generate `lib/install_<tool>.sh` following the contract above
2. Write it to the lib directory
3. Make it immediately available via `alang install <tool>`

### Manual

1. Create `lib/install_<toolname>.sh` following the contract above
2. Add name aliases to the `cmd_install` normalization block in `alang`:

```bash
case "$tool" in
  node|nodejs|node.js) tool="node" ;;
  python|python3|py)   tool="python" ;;
  # add yours:
  go|golang)           tool="go" ;;
  rust|rustlang)       tool="rust" ;;
esac
```

3. Add the tool to `cmd_status` and `cmd_doctor` loops if desired
4. Add tab completion entries in `completions/alang.bash`

---

## Claude AI integration

The `alang` binary talks to the Anthropic API in two ways:

### Version recommendation (`claude_recommend_version`)

Called when user runs `alang install node` with no version. Asks Claude for the latest stable version and returns just the version string.

### Free-form ask (`cmd_ask` / `ask_claude`)

Called via `alang ask "..."`. Streams Claude's answer directly to terminal.

### New installer generation (`cmd_add`)

Called via `alang add <tool>`. Sends a structured prompt asking Claude to write a full `lib/install_<tool>.sh` following the installer contract. The response is written directly to disk.

**API key** is read from `$ANTHROPIC_API_KEY` env var or `~/.alang/anthropic_key` file.

---

## Coding conventions

- **Bash 4+** — use `[[ ]]`, `local`, arrays, `set -euo pipefail`
- **No external deps** beyond: `bash`, `curl`/`wget`, `tar`, `jq` (for API calls)
- All functions prefixed: `cmd_*` for commands, `_*` for private helpers
- Variables: `UPPER_CASE` for globals/env, `lower_case` for locals
- Always `local` every variable inside functions
- Temp dirs always cleaned with `trap 'rm -rf "$tmp_dir"' EXIT`
- Use `die()` for fatal errors, never `exit 1` directly
- Spinner pattern: run slow command with `&`, capture PID, call `spinner $! "msg"`

---

## Testing a new installer

```bash
# Quick smoke test
ALANG_DIR=/tmp/alang-test bash alang install <tool> <version>
ls /tmp/alang-test/versions/<tool>/<version>/bin/

# Run doctor
bash alang doctor

# Check shims
bash alang list
```

---

## Common tasks for Claude Code

### "Add Go support"
→ Already included as `lib/install_go.sh`. Uses official go.dev binary tarballs.
   Sets `GOROOT=$dest`. Writes `$dest/.alang-env` with env vars.
   Aliases: `go`, `golang`

### "Add Rust support"
→ Already included as `lib/install_rust.sh`. Uses rustup in non-interactive mode.
   Stores toolchain in `$dest/rustup/`, cargo bins in `$dest/cargo/bin/`, symlinks into `$dest/bin/`.
   Supports `stable`, `nightly`, `beta`, or a pinned version like `1.78.0`.
   Aliases: `rust`, `rustlang`, `rs`

### "Add Deno support"
→ Official binaries at `https://github.com/denoland/deno/releases/download/v<version>/deno-<arch>-<os>.zip`.
   Single binary, just unzip to `$dest/bin/deno`.

### "Fix an installer"
→ Edit `lib/install_<tool>.sh`. The function signature and `$dest/bin/` output location must not change.

### "Add a new alang command"
→ 1. Write `cmd_<name>()` function in `alang`
   2. Add `<name>) cmd_<name> "$@" ;;` to the `main()` case block
   3. Add entry to `cmd_help()`
   4. Add completion entry in `completions/alang.bash`

### "Update Claude model"
→ Search for `claude-opus-4-5` in `alang` and update. Only one place per API call site.

---

## File ownership map

| File | What to edit it for |
|---|---|
| `alang` | New commands, AI prompts, core version logic, shell integration |
| `lib/install_*.sh` | Install logic for a specific tool |
| `completions/alang.bash` | Tab completion for new tools/commands |
| `setup.sh` | Installation / shell config detection |
| `README.md` | User-facing docs |
| `CLAUDE.md` | This file — update when architecture changes |
