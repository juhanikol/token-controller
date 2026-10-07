#!/usr/bin/env bash
# Creates the shim directory for the RTK fixture matrix. Usage: link-shims.sh <directory>
# Put the directory first on the PATH for a wx call, together with FIXTURE_CASE=<filter>/<case>.
set -eu
_LS_DIR="${1:?usage: link-shims.sh <directory>}"
_LS_FIX="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
mkdir -p "$_LS_DIR"
for _LS_NAME in grep find git rg fd mypy ruff prettier log; do
  ln -sf "$_LS_FIX/shim-command.sh" "$_LS_DIR/$_LS_NAME"
done
