# alang

**AI-powered version manager** — like `mise` or `asdf`, but shell-native with Claude intelligence built in.

Manages Node.js, Ruby, PHP + Composer, Java (OpenJDK), and Python.

---

## Install

```bash
git clone <this-repo> alang
cd alang
bash setup.sh
source ~/.bashrc   # or ~/.zshrc
```

Set your Anthropic API key (for AI features):
```bash
export ANTHROPIC_API_KEY=sk-ant-...
# or:
alang auth sk-ant-...
```

---

## Usage

```bash
# Install a tool — Claude picks the latest stable version automatically
alang install node
alang install python
alang install go
alang install ruby
alang install java
alang install php
alang install composer
alang install rust

# Install specific version
alang install node 20.11.0
alang install python 3.12.2

# Set version for current project (writes .alang-version)
alang use node 20.11.0
alang use python 3.12.2

# Set global default
alang global ruby
alang global java 21

# Check what's installed
alang list
alang status

# Ask Claude for advice
alang ask "what node version should I use for Next.js 14?"
alang ask "is Python 3.11 or 3.12 better for data science?"
alang ask "what Ruby version does Rails 7.1 require?"

# Activate versions in current shell
eval "$(alang env)"

# Health check
alang doctor

# Remove old versions
alang prune
```

---

## Project file: `.alang-version`

Add a `.alang-version` file to your project root:

```ini
node = 20.11.0
python = 3.12.2
ruby = 3.2.2
```

`alang` automatically detects this file and uses those versions.

---

## Shell integration

```bash
# Add to ~/.bashrc or ~/.zshrc:
export PATH="$HOME/.alang/bin:$HOME/.alang/shims:$PATH"
eval "$(alang env)"
```

For automatic version switching when you `cd` into a directory:

```bash
alang_cd() { cd "$@" && eval "$(alang env)"; }
alias cd=alang_cd
```

---

## Tab completions

```bash
# Add to ~/.bashrc:
source /path/to/alang/completions/alang.bash
```

---

## How it works

- **Versions** are stored in `~/.alang/versions/<tool>/<version>/`
- **Shims** in `~/.alang/shims/` proxy to the right version
- **Config** in `~/.alang/config/` stores global defaults
- **`.alang-version`** in project dirs sets project-specific versions
- **Claude** answers version questions and picks sensible defaults

Each tool installer lives in `lib/install_<tool>.sh` — easy to extend.

---

## Supported tools

| Tool | Versions | Source |
|------|----------|--------|
| `node` | Any | nodejs.org binary distributions |
| `python` | Any | python.org source (or python-build) |
| `ruby` | Any | ruby-lang.org source (or ruby-build) |
| `php` | Any | Homebrew / ondrej PPA / source |
| `java` | 8–21+ | Eclipse Temurin (Adoptium) binaries |
| `composer` | 1.x, 2.x | getcomposer.org official installer |

---

## Environment variables

| Variable | Description |
|----------|-------------|
| `ANTHROPIC_API_KEY` | API key for Claude AI features |
| `ALANG_DIR` | Override installation dir (default: `~/.alang`) |
