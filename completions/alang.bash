#!/usr/bin/env bash
# alang bash/zsh completions
# Source this or add to your completions directory

_alang_tools() {
  echo "node ruby php java python composer"
}

_alang_completion() {
  local cur prev words
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  words=("${COMP_WORDS[@]}")

  local commands="install use global list ls status which env shell exec uninstall rm prune doctor auth ask ai help version"
  local tools
  tools=$(_alang_tools)

  case "$prev" in
    alang)
      COMPREPLY=($(compgen -W "$commands" -- "$cur"))
      return 0
      ;;
    install|i|use|global|g|which|uninstall|rm|prune)
      COMPREPLY=($(compgen -W "$tools" -- "$cur"))
      return 0
      ;;
    node|ruby|php|java|python|composer)
      # List installed versions for this tool
      local tool_dir="$HOME/.alang/versions/$prev"
      if [[ -d "$tool_dir" ]]; then
        local versions
        versions=$(ls "$tool_dir" 2>/dev/null)
        COMPREPLY=($(compgen -W "$versions" -- "$cur"))
      fi
      return 0
      ;;
  esac

  return 0
}

# Bash
if [[ -n "${BASH_VERSION:-}" ]]; then
  complete -F _alang_completion alang
fi

# Zsh
if [[ -n "${ZSH_VERSION:-}" ]]; then
  autoload -U compinit
  compinit

  _alang_zsh() {
    local -a commands tools
    commands=(
      'install:Install a tool version'
      'use:Set version for current project'
      'global:Set global default version'
      'list:List installed versions'
      'status:Show active versions'
      'which:Show bin path for tool'
      'env:Print PATH exports'
      'shell:Print shell integration'
      'uninstall:Remove a version'
      'prune:Remove non-active versions'
      'doctor:Check system health'
      'auth:Store Anthropic API key'
      'ask:Ask Claude a question'
    )

    tools=(
      'node:Node.js JavaScript runtime'
      'ruby:Ruby programming language'
      'php:PHP programming language'
      'java:Java Development Kit'
      'python:Python programming language'
      'composer:PHP Composer package manager'
    )

    _arguments \
      '1:command:->command' \
      '2:tool:->tool' \
      '3:version:->version'

    case "$state" in
      command)
        _describe 'alang commands' commands
        ;;
      tool)
        _describe 'tools' tools
        ;;
      version)
        local tool="${words[2]}"
        local tool_dir="$HOME/.alang/versions/$tool"
        if [[ -d "$tool_dir" ]]; then
          local -a versions
          versions=("${(@f)$(ls "$tool_dir" 2>/dev/null)}")
          _describe 'installed versions' versions
        fi
        ;;
    esac
  }

  compdef _alang_zsh alang
fi
