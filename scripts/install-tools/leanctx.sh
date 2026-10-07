#!/usr/bin/env bash
# Path: scripts/install-tools/leanctx.sh
# Usage: bash scripts/install-tools/leanctx.sh [--method cargo|script] [--dry-run]
# Installs the lean-ctx binary after you confirm. Never runs setup, wrap, init, or onboard.
#   cargo (default if cargo is installed): cargo install lean-ctx
#   script: the upstream installer, with its automatic "lean-ctx onboard" and its edit of your shell startup file turned OFF
#           (LEAN_CTX_NO_ONBOARD=1, LEAN_CTX_NO_PATH_FIX=1). Without these, the upstream installer connects your AI tools
#           (edits their MCP config) and appends a PATH line to ~/.bashrc.
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

_URL="https://leanctx.com/install.sh"
_METHOD=""
_ARGS=("$@")
it_parse_common "$@"
set -- "${_REST[@]+"${_REST[@]}"}"
while [ "$#" -gt 0 ]; do
  case "$1" in
    --method) [ "$#" -ge 2 ] || { echo "Error: --method needs cargo or script." >&2; exit 2; }; _METHOD="$2"; shift ;;
    *) echo "Error: unknown option: $1" >&2; echo "Usage: bash scripts/install-tools/leanctx.sh [--method cargo|script] [--dry-run]" >&2; exit 2 ;;
  esac
  shift
done
case "$_METHOD" in
  '') if command -v cargo >/dev/null 2>&1; then _METHOD=cargo; else _METHOD=script; fi ;;
  cargo|script) ;;
  *) echo "Error: --method must be cargo or script." >&2; exit 2 ;;
esac

it_banner LeanCTX "https://github.com/yvgude/lean-ctx (site: https://leanctx.com)"
if command -v lean-ctx >/dev/null 2>&1; then
  echo "lean-ctx is already installed: $(command -v lean-ctx)"
  lean-ctx --version 2>/dev/null | head -n 1 || true
  exit 0
fi
if [ "$_METHOD" = cargo ]; then
  command -v cargo >/dev/null 2>&1 || { echo "Error: cargo is not installed. Use --method script, or install Rust first." >&2; exit 1; }
  cat <<'PLAN'

It would run:
  cargo install lean-ctx        # builds from source; this can take several minutes
PLAN
else
  cat <<PLAN

It would run:
  curl -fsSL $_URL -o <temporary file>
  LEAN_CTX_NO_ONBOARD=1 LEAN_CTX_NO_PATH_FIX=1 sh <temporary file>
(The two variables stop the upstream installer from running "lean-ctx onboard" and from editing your shell startup file.)
PLAN
fi
if [ "$_DRY_RUN" = true ]; then echo "(--dry-run: nothing was downloaded or run.)"; exit 0; fi
it_confirm "Install lean-ctx now?" || exit 0

if [ "$_METHOD" = cargo ]; then
  cargo install lean-ctx
else
  _FILE="$(it_download "$_URL")"
  trap 'rm -f -- "$_FILE"' EXIT
  LEAN_CTX_NO_ONBOARD=1 LEAN_CTX_NO_PATH_FIX=1 sh "$_FILE"
fi
echo
if command -v lean-ctx >/dev/null 2>&1; then lean-ctx --version | head -n 1; else it_path_hint "$HOME/.local/bin"; it_path_hint "$HOME/.cargo/bin"; fi
cat <<'DONE'

Done. Token Controller uses LeanCTX only through "workflow leanctx" (bounded read, search, tree).
It never runs "lean-ctx setup", "wrap", "init", or "onboard". If you run them yourself, read what they change first:
they can edit your agents' MCP config and add shell hooks that skip wx raw capture.
Check the setup with: workflow doctor    and:    workflow leanctx status
DONE
