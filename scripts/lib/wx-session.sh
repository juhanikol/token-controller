#!/usr/bin/env bash

# Sourced by scripts/workflow.sh after wx.sh. Uses the same policy precedence as wx
# (_wx_load_policy_state in wx.sh): active_mode.env first, shell variables as fallback.
_wx_session_load_profile() {
  _wx_load_policy_state "$1"
}

_wx_session_validate() {
  local _WX_SESSION_FILE="$1"

  if grep -q '^[[:space:]]*$' "$_WX_SESSION_FILE"; then
    return 1
  fi
  jq -e -s 'all(.[]; type == "object")' "$_WX_SESSION_FILE" >/dev/null 2>&1
}

# Usage: workflow_report <active env file> [--json] [--project <dir>]
# Text output is the original report. --json prints the same numbers for tools (schema in lib/versions.sh).
# All numbers are byte counts from .ai-context/session.jsonl, not token counts.
workflow_report() (
  local _WX_ACTIVE_ENV_FILE="$1"
  shift
  local _WX_FORMAT=text
  local _WX_CWD="$PWD"
  local _WX_CONTEXT_DIR
  local _WX_SESSION_FILE
  local _WX_RAW_ROOT
  local _WX_SUMMARY
  local _WX_COMMAND_COUNT
  local _WX_RAW_BYTES
  local _WX_VISIBLE_BYTES
  local _WX_FAILURE_COUNT
  local _WX_REDUCTION

  while [ "$#" -gt 0 ]; do
    case "$1" in
      --json) _WX_FORMAT=json ;;
      --text) _WX_FORMAT=text ;;
      --project)
        shift
        if [ "$#" -eq 0 ] || [ ! -d "$1" ]; then
          printf 'Error: report --project needs a directory.\n' >&2
          return 2
        fi
        _WX_CWD="$(cd "$1" && pwd)"
        ;;
      *)
        printf 'Error: unknown report option: %s. Use: workflow report [--json] [--project <dir>]\n' "$1" >&2
        return 2
        ;;
    esac
    shift
  done

  _WX_CONTEXT_DIR="$_WX_CWD/.ai-context"
  _WX_SESSION_FILE="$_WX_CONTEXT_DIR/session.jsonl"

  _wx_session_load_profile "$_WX_ACTIVE_ENV_FILE"
  _WX_RAW_ROOT="${AICONTEXT_RAW_LOG_DIR:-.ai-context/raw}"
  case "$_WX_RAW_ROOT" in
    /*) ;;
    *) _WX_RAW_ROOT="$_WX_CWD/$_WX_RAW_ROOT" ;;
  esac

  if [ ! -s "$_WX_SESSION_FILE" ]; then
    if [ "$_WX_FORMAT" = json ]; then
      _wx_report_json '{"commands":0,"raw_stdout":0,"raw_stderr":0,"visible_stdout":0,"visible_stderr":0,"raw_bytes":0,"visible_bytes":0,"failures":0,"last_run_at":null}' false
      return $?
    fi
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
        raw_stdout: (map(raw_stdout) | add // 0),
        raw_stderr: (map(raw_stderr) | add // 0),
        visible_stdout: (map(visible_stdout) | add // 0),
        visible_stderr: (map(visible_stderr) | add // 0),
        raw_bytes: (map(raw_stdout + raw_stderr) | add // 0),
        visible_bytes: (map(visible_stdout + visible_stderr) | add // 0),
        failures: (map(select((.exit_code // 0) != 0)) | length),
        last_run_at: (.[-1] | (.completed_at // .started_at // null))
      }
    ' "$_WX_SESSION_FILE"
  )" || return 1

  if [ "$_WX_FORMAT" = json ]; then
    _wx_report_json "$_WX_SUMMARY" true
    return $?
  fi

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

# Print the JSON report. Reads _WX_SESSION_FILE, _WX_RAW_ROOT and AICONTEXT_PROFILE from workflow_report.
# Args: summary object, available (true when the session file has records).
# byte_reduction_percent is null when there are no raw bytes. It is a byte count ratio, not a token saving.
_wx_report_json() {
  jq -n \
    --argjson schema_version "$AIW_REPORT_SCHEMA_VERSION" \
    --argjson s "$1" \
    --argjson available "$2" \
    --arg session_file "$_WX_SESSION_FILE" \
    --arg raw_log_dir "$_WX_RAW_ROOT" \
    --arg profile "${AICONTEXT_PROFILE:-}" \
    '{
      schema_version: $schema_version,
      available: $available,
      profile: (if $profile == "" then null else $profile end),
      command_count: $s.commands,
      failure_count: $s.failures,
      raw_stdout_bytes_total: $s.raw_stdout,
      raw_stderr_bytes_total: $s.raw_stderr,
      visible_stdout_bytes_total: $s.visible_stdout,
      visible_stderr_bytes_total: $s.visible_stderr,
      raw_bytes_total: $s.raw_bytes,
      visible_bytes_total: $s.visible_bytes,
      byte_reduction_percent: (if $s.raw_bytes == 0 then null else ((($s.raw_bytes - $s.visible_bytes) * 10000 / $s.raw_bytes) | round) / 100 end),
      session_file: $session_file,
      raw_log_dir: $raw_log_dir,
      last_run_at: $s.last_run_at
    }'
}

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
