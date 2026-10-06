#!/usr/bin/env bash

_wx_session_load_profile() {
  local _WX_ACTIVE_ENV_FILE="$1"

  if [ -z "${AICONTEXT_PROFILE:-}" ] && [ -r "$_WX_ACTIVE_ENV_FILE" ]; then
    # shellcheck source=/dev/null
    source "$_WX_ACTIVE_ENV_FILE"
  fi
}

_wx_session_validate() {
  local _WX_SESSION_FILE="$1"

  if grep -q '^[[:space:]]*$' "$_WX_SESSION_FILE"; then
    return 1
  fi
  jq -e -s 'all(.[]; type == "object")' "$_WX_SESSION_FILE" >/dev/null 2>&1
}

workflow_report() (
  local _WX_ACTIVE_ENV_FILE="$1"
  local _WX_CWD="$PWD"
  local _WX_CONTEXT_DIR="$_WX_CWD/.ai-context"
  local _WX_SESSION_FILE="$_WX_CONTEXT_DIR/session.jsonl"
  local _WX_RAW_ROOT
  local _WX_SUMMARY
  local _WX_COMMAND_COUNT
  local _WX_RAW_BYTES
  local _WX_VISIBLE_BYTES
  local _WX_FAILURE_COUNT
  local _WX_REDUCTION

  _wx_session_load_profile "$_WX_ACTIVE_ENV_FILE"
  _WX_RAW_ROOT="${AICONTEXT_RAW_LOG_DIR:-.ai-context/raw}"
  case "$_WX_RAW_ROOT" in
    /*) ;;
    *) _WX_RAW_ROOT="$_WX_CWD/$_WX_RAW_ROOT" ;;
  esac

  if [ ! -s "$_WX_SESSION_FILE" ]; then
    printf 'No workflow session data found at %s. Run a command with wx first.\n' "$_WX_SESSION_FILE"
    return 0
  fi

  if ! _wx_session_validate "$_WX_SESSION_FILE"; then
    printf 'Error: workflow session contains invalid JSONL: %s\n' "$_WX_SESSION_FILE" >&2
    return 1
  fi

  _WX_SUMMARY="$(
    jq -c -s '
      def raw_stdout: (.raw.stdout_bytes // .stdout.bytes // 0);
      def raw_stderr: (.raw.stderr_bytes // .stderr.bytes // 0);
      def visible_stdout: (.visible.stdout_bytes // .stdout.bytes // 0);
      def visible_stderr: (.visible.stderr_bytes // .stderr.bytes // 0);
      {
        commands: length,
        raw_bytes: (map(raw_stdout + raw_stderr) | add // 0),
        visible_bytes: (map(visible_stdout + visible_stderr) | add // 0),
        failures: (map(select((.exit_code // 0) != 0)) | length)
      }
    ' "$_WX_SESSION_FILE"
  )" || return 1

  _WX_COMMAND_COUNT="$(jq -r '.commands' <<< "$_WX_SUMMARY")"
  _WX_RAW_BYTES="$(jq -r '.raw_bytes' <<< "$_WX_SUMMARY")"
  _WX_VISIBLE_BYTES="$(jq -r '.visible_bytes' <<< "$_WX_SUMMARY")"
  _WX_FAILURE_COUNT="$(jq -r '.failures' <<< "$_WX_SUMMARY")"
  _WX_REDUCTION="$(
    jq -nr \
      --argjson raw "$_WX_RAW_BYTES" \
      --argjson visible "$_WX_VISIBLE_BYTES" \
      'if $raw == 0 then 0 else (($raw - $visible) * 100 / $raw) end'
  )"

  printf '%s\n' 'Workflow session report:'
  printf '  active profile: %s\n' "${AICONTEXT_PROFILE:-unset}"
  printf '  wrapped commands: %s\n' "$_WX_COMMAND_COUNT"
  printf '  raw bytes total: %s\n' "$_WX_RAW_BYTES"
  printf '  visible/emitted bytes total: %s\n' "$_WX_VISIBLE_BYTES"
  LC_NUMERIC=C printf '  estimated reduction: %.2f%%\n' "$_WX_REDUCTION"
  printf '  failures: %s\n' "$_WX_FAILURE_COUNT"
  printf '  raw log directory: %s\n' "$_WX_RAW_ROOT"
)

workflow_reset_session() (
  local _WX_ACTIVE_ENV_FILE="$1"
  local _WX_CWD="$PWD"
  local _WX_CONTEXT_DIR="$_WX_CWD/.ai-context"
  local _WX_SESSION_FILE="$_WX_CONTEXT_DIR/session.jsonl"
  local _WX_ARCHIVE_DIR="$_WX_CONTEXT_DIR/archive"
  local _WX_RAW_ROOT
  local _WX_ARCHIVE_STAMP
  local _WX_ARCHIVE_FILE

  _wx_session_load_profile "$_WX_ACTIVE_ENV_FILE"
  _WX_RAW_ROOT="${AICONTEXT_RAW_LOG_DIR:-.ai-context/raw}"
  case "$_WX_RAW_ROOT" in
    /*) ;;
    *) _WX_RAW_ROOT="$_WX_CWD/$_WX_RAW_ROOT" ;;
  esac

  if [ ! -s "$_WX_SESSION_FILE" ]; then
    printf 'No workflow session data found at %s. Nothing to reset.\n' "$_WX_SESSION_FILE"
    return 0
  fi

  if [ -L "$_WX_CONTEXT_DIR" ] || [ -L "$_WX_SESSION_FILE" ] || [ -L "$_WX_ARCHIVE_DIR" ]; then
    printf 'Error: refusing to reset through a symlinked context path.\n' >&2
    return 1
  fi
  if ! _wx_session_validate "$_WX_SESSION_FILE"; then
    printf 'Error: refusing to archive invalid workflow session JSONL: %s\n' "$_WX_SESSION_FILE" >&2
    return 1
  fi

  umask 077
  if ! mkdir -p -- "$_WX_ARCHIVE_DIR"; then
    printf 'Error: could not create workflow session archive: %s\n' "$_WX_ARCHIVE_DIR" >&2
    return 1
  fi

  _WX_ARCHIVE_STAMP="$(date -u '+%Y%m%dT%H%M%S.%3NZ')" || return 1
  if ! _WX_ARCHIVE_FILE="$(mktemp "$_WX_ARCHIVE_DIR/session-${_WX_ARCHIVE_STAMP}-$$.XXXXXX.jsonl")"; then
    printf 'Error: could not allocate a workflow session archive file.\n' >&2
    return 1
  fi
  if ! mv -- "$_WX_SESSION_FILE" "$_WX_ARCHIVE_FILE"; then
    rm -f -- "$_WX_ARCHIVE_FILE"
    printf 'Error: could not archive workflow session: %s\n' "$_WX_SESSION_FILE" >&2
    return 1
  fi
  if ! : > "$_WX_SESSION_FILE"; then
    mv -- "$_WX_ARCHIVE_FILE" "$_WX_SESSION_FILE"
    printf 'Error: could not create a new workflow session file; the original session was restored.\n' >&2
    return 1
  fi

  printf 'Archived workflow session: %s\n' "$_WX_ARCHIVE_FILE"
  printf 'Started new empty session: %s\n' "$_WX_SESSION_FILE"
  printf 'Raw logs were preserved under: %s\n' "$_WX_RAW_ROOT"
)

export -f _wx_session_load_profile _wx_session_validate workflow_report workflow_reset_session
