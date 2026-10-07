#!/usr/bin/env bash
# Replays a recorded command output. Used by the fixture commands in tests/fixtures/bin when FIXTURE_CASE is set.
# Usage: replay-case.sh <tool> [args...]
# Environment: FIXTURE_CASE=<filter>/<case> (a folder under tests/fixtures/rtk with stdout, stderr, exit, cmd),
#              FIXTURE_RUN_LOG=<file> (one line with the command and its arguments is appended per run).
dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rtk/${FIXTURE_CASE:?FIXTURE_CASE is not set}"
if [ ! -d "$dir" ]; then
  printf 'replay-case: no fixture folder: %s\n' "$FIXTURE_CASE" >&2
  exit 99
fi
if [ -n "${FIXTURE_RUN_LOG:-}" ]; then
  printf '%s\n' "$*" >> "$FIXTURE_RUN_LOG"
fi
if [ -f "$dir/stdout" ]; then
  cat "$dir/stdout"
fi
if [ -f "$dir/stderr" ]; then
  cat "$dir/stderr" >&2
fi
if [ -f "$dir/exit" ]; then
  exit "$(cat "$dir/exit")"
fi
exit 0
