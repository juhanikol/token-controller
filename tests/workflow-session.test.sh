#!/usr/bin/env bash

set -u

_WX_TEST_ROOT="$(mktemp -d /tmp/token-controller-session-test.XXXXXX)"
_WX_REPOSITORY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
trap 'rm -rf -- "$_WX_TEST_ROOT"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_file_contains() {
  local _WX_FILE="$1"
  local _WX_TEXT="$2"
  grep -Fq -- "$_WX_TEXT" "$_WX_FILE" || fail "missing '$_WX_TEXT' in $_WX_FILE"
}

export AICONTEXT_CONFIG_DIR="$_WX_TEST_ROOT/config"
export PATH="$_WX_REPOSITORY_ROOT/tests/fixtures/bin:$PATH"
mkdir -p "$_WX_TEST_ROOT/work"
cd "$_WX_TEST_ROOT/work" || exit 1

# shellcheck source=../scripts/workflow.sh
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >"$_WX_TEST_ROOT/activation.out"

source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" report >"$_WX_TEST_ROOT/no-session.report"
assert_file_contains "$_WX_TEST_ROOT/no-session.report" 'No workflow session data found'

wx echo hello >"$_WX_TEST_ROOT/one.stdout" 2>"$_WX_TEST_ROOT/one.stderr"
[ "$?" -eq 0 ] || fail 'single-command fixture failed'
jq -e -s 'length == 1 and all(.[]; type == "object")' .ai-context/session.jsonl >/dev/null || fail 'single-command JSONL is invalid'

source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" report >"$_WX_TEST_ROOT/one.report"
assert_file_contains "$_WX_TEST_ROOT/one.report" 'active profile: code'
assert_file_contains "$_WX_TEST_ROOT/one.report" 'wrapped commands: 1'
assert_file_contains "$_WX_TEST_ROOT/one.report" 'raw bytes total: 6'
assert_file_contains "$_WX_TEST_ROOT/one.report" 'visible/emitted bytes total: 6'
assert_file_contains "$_WX_TEST_ROOT/one.report" 'estimated reduction: 0.00%'
assert_file_contains "$_WX_TEST_ROOT/one.report" 'failures: 0'
assert_file_contains "$_WX_TEST_ROOT/one.report" "raw log directory: $_WX_TEST_ROOT/work/.ai-context/raw"

wx npm install >"$_WX_TEST_ROOT/multiple.stdout" 2>"$_WX_TEST_ROOT/multiple.stderr"
[ "$?" -eq 0 ] || fail 'multiple-command success fixture failed'
wx "$_WX_REPOSITORY_ROOT/tests/fixtures/failing-stack.sh" >"$_WX_TEST_ROOT/failure.stdout" 2>"$_WX_TEST_ROOT/failure.stderr"
_WX_FAILURE_EXIT=$?
[ "$_WX_FAILURE_EXIT" -eq 3 ] || fail "failure fixture exited $_WX_FAILURE_EXIT instead of 3"
jq -e -s 'length == 3 and all(.[]; type == "object")' .ai-context/session.jsonl >/dev/null || fail 'multiple-command JSONL is invalid'

_WX_RAW_BYTES="$(jq -r -s 'map((.raw.stdout_bytes // .stdout.bytes // 0) + (.raw.stderr_bytes // .stderr.bytes // 0)) | add' .ai-context/session.jsonl)"
_WX_VISIBLE_BYTES="$(jq -r -s 'map((.visible.stdout_bytes // .stdout.bytes // 0) + (.visible.stderr_bytes // .stderr.bytes // 0)) | add' .ai-context/session.jsonl)"
_WX_REDUCTION="$(jq -nr --argjson raw "$_WX_RAW_BYTES" --argjson visible "$_WX_VISIBLE_BYTES" '($raw - $visible) * 100 / $raw')"
LC_NUMERIC=C printf -v _WX_REDUCTION_FORMATTED '%.2f%%' "$_WX_REDUCTION"

source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" report >"$_WX_TEST_ROOT/multiple.report"
assert_file_contains "$_WX_TEST_ROOT/multiple.report" 'wrapped commands: 3'
assert_file_contains "$_WX_TEST_ROOT/multiple.report" "raw bytes total: $_WX_RAW_BYTES"
assert_file_contains "$_WX_TEST_ROOT/multiple.report" "visible/emitted bytes total: $_WX_VISIBLE_BYTES"
assert_file_contains "$_WX_TEST_ROOT/multiple.report" "estimated reduction: $_WX_REDUCTION_FORMATTED"
assert_file_contains "$_WX_TEST_ROOT/multiple.report" 'failures: 1'

_WX_RAW_FILE_COUNT_BEFORE="$(find .ai-context/raw -type f | wc -l)"
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" reset-session >"$_WX_TEST_ROOT/reset.out"
assert_file_contains "$_WX_TEST_ROOT/reset.out" 'Archived workflow session:'
assert_file_contains "$_WX_TEST_ROOT/reset.out" 'Raw logs were preserved under:'
[ -f .ai-context/session.jsonl ] || fail 'reset did not create a new session file'
[ ! -s .ai-context/session.jsonl ] || fail 'new session file is not empty'

_WX_ARCHIVE_FILE="$(find .ai-context/archive -type f -name '*.jsonl' -print -quit)"
[ -n "$_WX_ARCHIVE_FILE" ] || fail 'reset did not create a session archive'
jq -e -s 'length == 3 and all(.[]; type == "object")' "$_WX_ARCHIVE_FILE" >/dev/null || fail 'archived JSONL is invalid'
_WX_RAW_FILE_COUNT_AFTER="$(find .ai-context/raw -type f | wc -l)"
[ "$_WX_RAW_FILE_COUNT_AFTER" -eq "$_WX_RAW_FILE_COUNT_BEFORE" ] || fail 'reset removed or added raw log files'

source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" report >"$_WX_TEST_ROOT/after-reset.report"
assert_file_contains "$_WX_TEST_ROOT/after-reset.report" 'No workflow session data found'
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" reset-session >"$_WX_TEST_ROOT/empty-reset.out"
assert_file_contains "$_WX_TEST_ROOT/empty-reset.out" 'Nothing to reset.'

printf '%s\n' 'PASS: workflow report and reset-session'
