#!/usr/bin/env bash
# Path: scripts/install-wsl.sh
# Usage: bash scripts/install-wsl.sh [--skip-apt] [--dry-run] [--bashrc <file>]
#
# Sets up Token Controller on WSL/Ubuntu:
#   1. installs the basic prerequisites with apt: jq, git, curl, ca-certificates, coreutils
#   2. adds the "workflow" alias to ~/.bashrc, only if no "workflow" alias is there yet
#   3. runs scripts/check-tools.sh and prints the next steps
#
# It never installs RTK, LeanCTX, Headroom, Caveman, ccusage, Claude Code, or MemStack. They are optional.
# To see their install commands: bash scripts/show-optional-tools.sh
# It changes nothing else: no hooks, no agent or editor settings, no AGENTS.md.
#   --skip-apt       do not run apt (use this when jq, git, and curl are already installed, or you have no sudo)
#   --dry-run        print what would be done and change nothing
#   --bashrc <file>  alias file (default: ~/.bashrc)

set -euo pipefail

_SELF="$(readlink -f -- "${BASH_SOURCE[0]}")"
_SCRIPTS_DIR="$(cd -- "$(dirname -- "$_SELF")" && pwd)"
_ROOT="$(cd -- "$_SCRIPTS_DIR/.." && pwd)"
_BASHRC="${HOME}/.bashrc"
_SKIP_APT=false
_DRY_RUN=false

while [ "$#" -gt 0 ]; do
  case "$1" in
    --skip-apt) _SKIP_APT=true ;;
    --dry-run) _DRY_RUN=true ;;
    --bashrc) [ "$#" -ge 2 ] || { echo "Error: --bashrc needs a file." >&2; exit 2; }; _BASHRC="$2"; shift ;;
    -h|--help) sed -n '2,17p' "$_SELF" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "Error: unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

say() { printf '%s\n' "$*"; }
step() { printf '\n== %s\n' "$*"; }

if [ "$(uname -s)" != Linux ]; then
  say "Error: Token Controller supports WSL 2 with Ubuntu. Run this script inside WSL." >&2
  exit 1
fi
if [ -z "${WSL_DISTRO_NAME:-}" ] && ! grep -qi microsoft /proc/version 2>/dev/null; then
  say "Note: this does not look like WSL. Only WSL 2 with Ubuntu is tested. Continuing."
fi
if [ "$(id -u)" -eq 0 ]; then
  say "Note: you are running as root. The alias goes to root's $_BASHRC. Use your normal user for daily work."
fi
case "$_ROOT" in
  *\'*) say "Error: the controller path contains a quote ($_ROOT). Move it to a path without quotes." >&2; exit 1 ;;
  /mnt/[a-zA-Z]/*) say "Warning: the controller is on a Windows drive ($_ROOT). A path in the WSL Linux home (for example ~/projects/token-controller) is more reliable." ;;
esac
say "Token Controller: $_ROOT"
[ "$_DRY_RUN" = true ] && say "Dry run: nothing will be changed."

# 1. Basic prerequisites. No optional tool.
step "1. Basic prerequisites (jq, git, curl, ca-certificates, coreutils)"
_missing=()
for _tool in jq git curl; do
  command -v "$_tool" >/dev/null 2>&1 || _missing+=("$_tool")
done
if [ "$_SKIP_APT" = true ]; then
  say "Skipped (--skip-apt). Missing now: ${_missing[*]:-nothing}"
elif [ "$_DRY_RUN" = true ]; then
  say "Would run: sudo apt-get update && sudo apt-get install -y jq git curl ca-certificates coreutils"
else
  _sudo=""
  [ "$(id -u)" -eq 0 ] || _sudo="sudo"
  $_sudo apt-get update
  $_sudo apt-get install -y jq git curl ca-certificates coreutils
fi

# 2. The workflow alias. Only if there is none.
step "2. The workflow alias in $_BASHRC"
_ALIAS="alias workflow='source \"$_ROOT/scripts/workflow.sh\"'"
if [ -f "$_BASHRC" ] && grep -Eq '^[[:space:]]*alias[[:space:]]+workflow=' "$_BASHRC"; then
  say "A workflow alias already exists. It was not changed:"
  grep -E '^[[:space:]]*alias[[:space:]]+workflow=' "$_BASHRC" | head -n 1 | sed 's/^/  /'
  if ! grep -E '^[[:space:]]*alias[[:space:]]+workflow=' "$_BASHRC" | grep -Fq "$_ROOT/scripts/workflow.sh"; then
    say "Warning: it does not point to this controller ($_ROOT). Edit $_BASHRC if you want this copy."
  fi
elif [ "$_DRY_RUN" = true ]; then
  say "Would add to $_BASHRC:"
  say "  $_ALIAS"
else
  mkdir -p -- "$(dirname -- "$_BASHRC")"
  { printf '\n# Token Controller\n%s\n' "$_ALIAS"; } >> "$_BASHRC"
  say "Added to $_BASHRC:"
  say "  $_ALIAS"
fi

# 3. Check the tools.
step "3. Tool check"
if [ -f "$_SCRIPTS_DIR/check-tools.sh" ]; then
  bash "$_SCRIPTS_DIR/check-tools.sh" || say "The tool check did not finish. That is not a problem for the install."
else
  say "scripts/check-tools.sh was not found. Skipped."
fi

step "Next steps"
cat <<NEXT
1. Open a new terminal, or run:  source $_BASHRC
2. Check it works:               workflow status
3. In each project:              cd ~/projects/my-project && workflow init
4. Choose a mode:                workflow code     (also workflow debug, workflow architect, ...)
5. Install the VS Code extension into the WSL extension host (optional). See README.md, "VS Code extension".
6. Read-only health check:       workflow doctor

RTK, LeanCTX, Caveman and the other tools are optional. Token Controller works without them and falls back to raw output.
This script installed none of them. When you want one, run its helper (it shows the upstream source and asks first):
  bash $_ROOT/scripts/install-tools/rtk.sh
  bash $_ROOT/scripts/install-tools/leanctx.sh
  bash $_ROOT/scripts/install-tools/caveman.sh
Or read all the commands first:  bash $_ROOT/scripts/show-optional-tools.sh --print-only
NEXT
