#!/usr/bin/env bash

set -u

_WX_BENCH_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_WX_BENCH_FIXTURES="$_WX_BENCH_ROOT/benchmarks/fixtures"
_WX_BENCH_TMP="$(mktemp -d /tmp/token-controller-benchmark.XXXXXX)"
_WX_BENCH_ROWS="$_WX_BENCH_TMP/rows.md"
_WX_BENCH_TOTAL_RAW=0
_WX_BENCH_TOTAL_EMITTED=0
_WX_BENCH_FAILED=false
trap 'rm -rf -- "$_WX_BENCH_TMP"' EXIT

if ! command -v jq >/dev/null 2>&1; then
  printf '%s\n' 'Benchmark requires jq.' >&2
  exit 1
fi

mkdir -p "$_WX_BENCH_TMP/work" "$_WX_BENCH_TMP/bin"
ln -s "$_WX_BENCH_FIXTURES/noisy-pass.sh" "$_WX_BENCH_TMP/bin/npm"
export PATH="$_WX_BENCH_TMP/bin:$PATH"
export AICONTEXT_CONFIG_DIR="$_WX_BENCH_TMP/config"
cd "$_WX_BENCH_TMP/work" || exit 1

fail_case() {
  _WX_BENCH_FAILED=true
}

run_case() {
  local _WX_CASE_NAME="$1"
  local _WX_CASE_PROFILE="$2"
  shift 2

  local _WX_CASE_DIR="$_WX_BENCH_TMP/$_WX_CASE_NAME"
  local _WX_BASELINE_EXIT
  local _WX_WRAPPED_EXIT
  local _WX_BASELINE_BYTES
  local _WX_RAW_BYTES
  local _WX_VISIBLE_COMMAND_BYTES
  local _WX_EMITTED_BYTES
  local _WX_REDUCTION
  local _WX_METADATA
  local _WX_RAW_STDOUT
  local _WX_RAW_STDERR
  local _WX_POLICY
  local _WX_PRESERVATION='PASS'

  mkdir -p "$_WX_CASE_DIR"
  command "$@" >"$_WX_CASE_DIR/baseline.stdout" 2>"$_WX_CASE_DIR/baseline.stderr"
  _WX_BASELINE_EXIT=$?

  if ! source "$_WX_BENCH_ROOT/scripts/workflow.sh" "$_WX_CASE_PROFILE" >"$_WX_CASE_DIR/activation.out"; then
    printf 'Benchmark could not activate profile %s.\n' "$_WX_CASE_PROFILE" >&2
    exit 1
  fi
  wx "$@" >"$_WX_CASE_DIR/wx.stdout" 2>"$_WX_CASE_DIR/wx.stderr"
  _WX_WRAPPED_EXIT=$?

  _WX_METADATA="$(jq -c -s '.[-1]' .ai-context/session.jsonl)"
  _WX_RAW_STDOUT="$(jq -r '.stdout.path' <<< "$_WX_METADATA")"
  _WX_RAW_STDERR="$(jq -r '.stderr.path' <<< "$_WX_METADATA")"
  _WX_POLICY="$(jq -r '.output_policy' <<< "$_WX_METADATA")"
  _WX_RAW_BYTES="$(jq -r '.raw.stdout_bytes + .raw.stderr_bytes' <<< "$_WX_METADATA")"
  _WX_VISIBLE_COMMAND_BYTES="$(jq -r '.visible.stdout_bytes + .visible.stderr_bytes' <<< "$_WX_METADATA")"
  _WX_BASELINE_BYTES=$(($(stat -c '%s' "$_WX_CASE_DIR/baseline.stdout") + $(stat -c '%s' "$_WX_CASE_DIR/baseline.stderr")))
  _WX_EMITTED_BYTES=$(($(stat -c '%s' "$_WX_CASE_DIR/wx.stdout") + $(stat -c '%s' "$_WX_CASE_DIR/wx.stderr")))
  _WX_REDUCTION="$(
    LC_ALL=C awk -v raw="$_WX_BASELINE_BYTES" -v visible="$_WX_EMITTED_BYTES" \
      'BEGIN { if (raw == 0) printf "0.00"; else printf "%.2f", (raw - visible) * 100 / raw }'
  )"

  if [ "$_WX_BASELINE_EXIT" -ne "$_WX_WRAPPED_EXIT" ] ||
    [ "$_WX_BASELINE_BYTES" -ne "$_WX_RAW_BYTES" ] ||
    ! cmp -s "$_WX_CASE_DIR/baseline.stdout" "$_WX_RAW_STDOUT" ||
    ! cmp -s "$_WX_CASE_DIR/baseline.stderr" "$_WX_RAW_STDERR" ||
    ! grep -Fq '[wx] raw logs:' "$_WX_CASE_DIR/wx.stderr"; then
    _WX_PRESERVATION='FAIL'
  fi

  case "$_WX_CASE_NAME" in
    noisy-pass)
      if [ "$_WX_POLICY" != 'compress-exact-repeats-v1' ] ||
        [ "$_WX_VISIBLE_COMMAND_BYTES" -ge "$_WX_RAW_BYTES" ] ||
        [ "$_WX_EMITTED_BYTES" -ge "$_WX_BASELINE_BYTES" ] ||
        ! grep -Fq '[wx] repeated 199 additional times: exact line above' "$_WX_CASE_DIR/wx.stdout"; then
        _WX_PRESERVATION='FAIL'
      fi
      ;;
    failing-stacktrace)
      if [ "$_WX_POLICY" != 'raw-nonzero-exit' ] ||
        [ "$_WX_VISIBLE_COMMAND_BYTES" -ne "$_WX_RAW_BYTES" ] ||
        ! grep -Fq 'at Widget.validate (/workspace/src/widget.js:42:13)' "$_WX_CASE_DIR/wx.stderr" ||
        ! grep -Fq 'Last relevant line: benchmark failure id bench-001' "$_WX_CASE_DIR/wx.stderr"; then
        _WX_PRESERVATION='FAIL'
      fi
      ;;
    security|db)
      if [ "$_WX_POLICY" != 'raw-protected-profile' ] ||
        [ "$_WX_VISIBLE_COMMAND_BYTES" -ne "$_WX_RAW_BYTES" ] ||
        ! cmp -s "$_WX_CASE_DIR/baseline.stdout" "$_WX_CASE_DIR/wx.stdout"; then
        _WX_PRESERVATION='FAIL'
      fi
      ;;
  esac

  if [ "$_WX_PRESERVATION" != 'PASS' ]; then
    fail_case
  fi

  _WX_BENCH_TOTAL_RAW=$((_WX_BENCH_TOTAL_RAW + _WX_BASELINE_BYTES))
  _WX_BENCH_TOTAL_EMITTED=$((_WX_BENCH_TOTAL_EMITTED + _WX_EMITTED_BYTES))
  printf '| %s | `%s` | %s | %s | %s | %s | %s%% | %s |\n' \
    "$_WX_CASE_NAME" "$_WX_CASE_PROFILE" "$_WX_WRAPPED_EXIT" "$_WX_BASELINE_BYTES" \
    "$_WX_VISIBLE_COMMAND_BYTES" "$_WX_EMITTED_BYTES" "$_WX_REDUCTION" "$_WX_PRESERVATION" >> "$_WX_BENCH_ROWS"
}

run_case noisy-pass code npm install
run_case failing-stacktrace debug "$_WX_BENCH_FIXTURES/failing-stacktrace.sh"
run_case security security cat "$_WX_BENCH_FIXTURES/security-scan-output.txt"
run_case db db cat "$_WX_BENCH_FIXTURES/db-migration-warning.txt"

_WX_BENCH_TOTAL_REDUCTION="$(
  LC_ALL=C awk -v raw="$_WX_BENCH_TOTAL_RAW" -v visible="$_WX_BENCH_TOTAL_EMITTED" \
    'BEGIN { if (raw == 0) printf "0.00"; else printf "%.2f", (raw - visible) * 100 / raw }'
)"
_WX_BENCH_DATE="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
_WX_BENCH_ENVIRONMENT="$(uname -srmo)"

printf '%s\n\n' '### Experiment: practical wx context reduction benchmark'
printf '%s\n' "- Date: $_WX_BENCH_DATE"
printf '%s\n' "- Environment: $_WX_BENCH_ENVIRONMENT"
printf '%s\n' '- Optional tools: none'
printf '%s\n\n' '- Method: each fixture ran once through the normal shell and once through `wx`; emitted bytes include the raw-log pointer.'
printf '%s\n' '| Fixture | Profile | Exit | Raw bytes | Visible command bytes | Emitted bytes | Practical reduction | Evidence |'
printf '%s\n' '| --- | --- | ---: | ---: | ---: | ---: | ---: | --- |'
command cat "$_WX_BENCH_ROWS"
printf '\n- Aggregate raw bytes: %s\n' "$_WX_BENCH_TOTAL_RAW"
printf '%s\n' "- Aggregate emitted bytes: $_WX_BENCH_TOTAL_EMITTED"
printf '%s\n' "- Aggregate practical reduction: $_WX_BENCH_TOTAL_REDUCTION%"

if [ "$_WX_BENCH_FAILED" = false ]; then
  printf '%s\n' '- Result: **PROVES practical byte reduction for the noisy-success fixture while preserving failure, security, and database evidence.**'
  printf '%s\n' '- Scope: byte reduction only; no tokenizer-backed token saving is claimed.'
  exit 0
fi

printf '%s\n' '- Result: **DISPROVES the current wrapper safety or reduction claim for at least one fixture.**'
printf '%s\n' '- Scope: inspect rows marked FAIL and the raw logs before changing policy.'
exit 1
