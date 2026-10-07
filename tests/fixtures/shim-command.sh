#!/usr/bin/env bash
# Stands in for a command in the RTK fixture matrix (grep, find, git, rg, fd, mypy, ruff, prettier, log).
# Link it under the command name in a directory that is put first on the PATH for one wx call (see link-shims.sh).
# With FIXTURE_CASE set and the exact recorded command line, it replays the recording (replay-case.sh).
# Any other call, for example one that wx or the fake RTK makes itself, runs the real command, or fails with 127.
_SH_NAME="$(basename "$0")"
_SH_FIX="$(cd "$(dirname "$(readlink -f "$0")")" && pwd)"
if [ -n "${FIXTURE_CASE:-}" ] && [ -f "$_SH_FIX/rtk/$FIXTURE_CASE/cmd" ] && [ "$_SH_NAME $*" = "$(cat "$_SH_FIX/rtk/$FIXTURE_CASE/cmd")" ]; then
  exec bash "$_SH_FIX/replay-case.sh" "$_SH_NAME" "$@"
fi
_SH_DIR="$(dirname "$0")"
_SH_PATH=":$PATH:"
_SH_PATH="${_SH_PATH//:$_SH_DIR:/:}"
_SH_PATH="${_SH_PATH#:}"
PATH="${_SH_PATH%:}"
if ! command -v "$_SH_NAME" >/dev/null 2>&1; then
  printf '%s: command not found\n' "$_SH_NAME" >&2
  exit 127
fi
exec "$_SH_NAME" "$@"
