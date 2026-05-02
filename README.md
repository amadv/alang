# ∴ alang

**Language version manager — Claude-first.**

Install and manage language runtimes (Node.js, Python, Ruby, Go, Rust, PHP, Java, Composer)
by talking to Claude Code directly. No CLI, no PATH pollution, no shell config editing.

---

## How it works

1. Clone this repo and open it in Claude Code.
2. Tell Claude what you want — "install node 20.11.0", "set python 3.12 as my global", etc.
3. Claude runs scripts from `scripts/`, tracks state in `state/`, and shows you any shell command you need to run.

State lives in markdown files committed to git. Binaries install to `~/.alang/versions/<tool>/<version>/`.

---

## Quick start

```bash
git clone https://github.com/amadv/alang
cd alang
claude  # open Claude Code
```

Then just talk:

```
install node 20.11.0
install the latest stable python
set node 20.11.0 as my global
what versions do I have installed?
how do I activate go 1.22 in my current shell?
add deno support
```

---

## Shell activation

Claude will show you the command to activate a version in your current shell:

```bash
eval "$(bash scripts/env.sh node 20.11.0)"
```

For a permanent setup, add to your `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$HOME/.alang/versions/node/20.11.0/bin:$PATH"
```

No shims. No `alang` binary on your PATH. Just direct version directories.

---

## Supported tools

| Tool | Source |
|------|--------|
| `node` | nodejs.org binary distributions |
| `python` | python.org source (or python-build if available) |
| `ruby` | ruby-lang.org source (or ruby-build if available) |
| `php` | Homebrew / ondrej PPA / source |
| `java` | Eclipse Temurin (Adoptium) binaries |
| `composer` | getcomposer.org official installer |
| `go` | go.dev official binaries |
| `rust` | rustup (non-interactive) |

Ask Claude to add support for any other tool — it will generate a `lib/install_<tool>.sh` following the installer contract in `CLAUDE.md`.

---

## State files

| File | Purpose |
|------|---------|
| `state/installed.md` | Every installed version (tool, version, path, date) |
| `state/globals.md` | Global default version per tool |

These are committed to git by `scripts/backup.sh` after every operation, giving you a full history of your environment changes.

---

## Scripts (Claude runs these — you can too)

| Script | What it does |
|--------|-------------|
| `scripts/install.sh <tool> <version>` | Downloads and installs a version |
| `scripts/uninstall.sh <tool> <version>` | Removes an installed version |
| `scripts/env.sh [tool version]` | Emits `export PATH=...` for one or all globals |
| `scripts/backup.sh [msg]` | Commits `state/` to git |

---

## Adding a new language

Tell Claude: "add support for deno" (or elixir, bun, zig, etc.)

Claude generates `lib/install_<tool>.sh` following the installer contract in `CLAUDE.md`, tests it, and commits it.
