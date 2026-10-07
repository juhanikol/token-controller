#!/usr/bin/env bash
# Shared helpers for scripts/install-tools/*.sh. Source it. It runs nothing by itself.
#
# Rules for every helper (see README.md in this folder):
#   - it prints the upstream source and says it may be out of date;
#   - it asks you to confirm before it downloads or installs anything;
#   - it installs one tool only;
#   - it never runs "rtk init", "lean-ctx setup", "lean-ctx wrap", "lean-ctx init", or "lean-ctx onboard";
#   - it never edits agent settings, MCP config, shell startup files, or hooks.

it_banner() { # tool name, upstream URL
  cat <<BANNER
Token Controller helper: install $1
Upstream: $2
This helper is a convenience. It may become outdated. Read the upstream page first, because upstream decides what the installer does.
It installs $1 only. It does not run "rtk init" or "lean-ctx setup/wrap/init/onboard", edit agent or MCP settings, or add hooks or shell startup lines.
BANNER
}

# Ask a yes/no question on stdin. Only "y" or "yes" means yes. Anything else, or no input, means no.
it_confirm() { # question
  local _answer=""
  printf '%s [y/N] ' "$1"
  read -r _answer || _answer=""
  case "$_answer" in y|Y|yes|YES|Yes) return 0 ;; esac
  printf '\nNothing was installed.\n'
  return 1
}

# Download a URL to a temporary file and print its path. The file is run by the caller with "sh" or "bash" (never piped).
it_download() { # url
  local _file
  _file="$(mktemp /tmp/token-controller-install.XXXXXX)" || return 1
  if ! curl -fsSL "$1" -o "$_file"; then
    rm -f -- "$_file"
    echo "Error: the download failed: $1" >&2
    return 1
  fi
  printf '%s\n' "$_file"
}

it_path_hint() { # directory that should be on PATH
  case ":$PATH:" in
    *":$1:"*) ;;
    *) printf 'Note: %s is not on your PATH. This helper does not edit ~/.bashrc. Add it yourself if you want:\n  export PATH="%s:$PATH"\n' "$1" "$1" ;;
  esac
}

it_parse_common() { # sets _DRY_RUN; unknown arguments are left in _REST
  _DRY_RUN=false
  _REST=()
  local _arg
  for _arg in "$@"; do
    case "$_arg" in
      --dry-run) _DRY_RUN=true ;;
      *) _REST+=("$_arg") ;;
    esac
  done
}
