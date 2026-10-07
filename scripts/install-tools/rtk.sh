#!/usr/bin/env bash
# Path: scripts/install-tools/rtk.sh
# Usage: bash scripts/install-tools/rtk.sh [--dry-run]
# Installs RTK with its own upstream installer, after you confirm. Never runs "rtk init".
set -euo pipefail
source "$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)/common.sh"

_URL="https://raw.githubusercontent.com/rtk-ai/rtk/refs/heads/master/install.sh"
it_parse_common "$@"
if [ "${#_REST[@]}" -gt 0 ]; then echo "Error: unknown option: ${_REST[0]}" >&2; echo "Usage: bash scripts/install-tools/rtk.sh [--dry-run]" >&2; exit 2; fi

it_banner RTK "https://github.com/rtk-ai/rtk"
if command -v rtk >/dev/null 2>&1; then
  echo "RTK is already installed: $(command -v rtk)"
  rtk --version 2>/dev/null | head -n 1 || true
  exit 0
fi
cat <<PLAN

It would run:
  curl -fsSL $_URL -o <temporary file>
  sh <temporary file>        # the upstream installer; it downloads a release and checks its checksum
PLAN
if [ "$_DRY_RUN" = true ]; then echo "(--dry-run: nothing was downloaded or run.)"; exit 0; fi
it_confirm "Install RTK now?" || exit 0

_FILE="$(it_download "$_URL")"
trap 'rm -f -- "$_FILE"' EXIT
sh "$_FILE"
echo
if command -v rtk >/dev/null 2>&1; then rtk --version | head -n 1; else it_path_hint "$HOME/.local/bin"; fi
cat <<'DONE'

Done. Token Controller uses RTK only through "wx" (rtk pipe), after raw capture.
Token Controller never runs "rtk init", and you should not either: it installs hooks that make agents run commands through RTK directly, so wx raw capture is skipped.
Check the setup with: workflow doctor
DONE
