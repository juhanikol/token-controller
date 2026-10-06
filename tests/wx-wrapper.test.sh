#!/usr/bin/env bash

set -u

_WX_TEST_ROOT="$(mktemp -d /tmp/token-controller-wx-test.XXXXXX)"
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

wx npm install >"$_WX_TEST_ROOT/success.stdout" 2>"$_WX_TEST_ROOT/success.stderr"
_WX_SUCCESS_EXIT=$?
[ "$_WX_SUCCESS_EXIT" -eq 0 ] || fail "successful fixture exited $_WX_SUCCESS_EXIT"
[ "$(grep -Fc 'PASS tests/widget.test.js' "$_WX_TEST_ROOT/success.stdout")" -eq 1 ] || fail 'repeated success lines were not reduced to one line'
assert_file_contains "$_WX_TEST_ROOT/success.stdout" '[wx] repeated 11 additional times: exact line above'
assert_file_contains "$_WX_TEST_ROOT/success.stderr" '[wx] raw logs:'

_WX_SUCCESS_RAW="$(jq -r -s '.[0].stdout.path' .ai-context/session.jsonl)"
[ "$(grep -Fc 'PASS tests/widget.test.js' "$_WX_SUCCESS_RAW")" -eq 12 ] || fail 'raw success log was modified'
jq -e -s '
  .[0].exit_code == 0
  and .[0].output_policy == "compress-exact-repeats-v1"
  and .[0].raw.stdout_bytes > .[0].visible.stdout_bytes
  and .[0].raw.stderr_bytes == .[0].visible.stderr_bytes
' .ai-context/session.jsonl >/dev/null || fail 'success metadata is invalid'

wx "$_WX_REPOSITORY_ROOT/tests/fixtures/failing-stack.sh" >"$_WX_TEST_ROOT/failure.stdout" 2>"$_WX_TEST_ROOT/failure.stderr"
_WX_FAILURE_EXIT=$?
[ "$_WX_FAILURE_EXIT" -eq 3 ] || fail "failing fixture exited $_WX_FAILURE_EXIT instead of 3"
assert_file_contains "$_WX_TEST_ROOT/failure.stderr" 'ERROR: request failed'
assert_file_contains "$_WX_TEST_ROOT/failure.stderr" 'at Widget.run (/workspace/src/widget.js:42:13)'
assert_file_contains "$_WX_TEST_ROOT/failure.stderr" 'at main (/workspace/src/main.js:8:5)'
assert_file_contains "$_WX_TEST_ROOT/failure.stderr" 'Last relevant line: request id fixture-123'
assert_file_contains "$_WX_TEST_ROOT/failure.stderr" '[wx] raw logs:'
jq -e -s '
  .[1].exit_code == 3
  and .[1].output_policy == "raw-nonzero-exit"
  and .[1].raw.stdout_bytes == .[1].visible.stdout_bytes
  and .[1].raw.stderr_bytes == .[1].visible.stderr_bytes
' .ai-context/session.jsonl >/dev/null || fail 'failure metadata is invalid'

wx npm audit >"$_WX_TEST_ROOT/audit.stdout" 2>"$_WX_TEST_ROOT/audit.stderr"
[ "$?" -eq 0 ] || fail 'protected command fixture failed'
[ "$(grep -Fc 'VULNERABILITY CVE-2099-0001' "$_WX_TEST_ROOT/audit.stdout")" -eq 2 ] || fail 'protected command output was compressed'
jq -e -s '
  .[2].output_policy == "raw-protected-command"
  and .[2].raw.stdout_bytes == .[2].visible.stdout_bytes
' .ai-context/session.jsonl >/dev/null || fail 'protected command metadata is invalid'

for _WX_PROFILE in security db release migration; do
  source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" "$_WX_PROFILE" >"$_WX_TEST_ROOT/activation-${_WX_PROFILE}.out"
  wx npm install >"$_WX_TEST_ROOT/${_WX_PROFILE}.stdout" 2>"$_WX_TEST_ROOT/${_WX_PROFILE}.stderr"
  [ "$?" -eq 0 ] || fail "$_WX_PROFILE fixture failed"
  [ "$(grep -Fc 'PASS tests/widget.test.js' "$_WX_TEST_ROOT/${_WX_PROFILE}.stdout")" -eq 12 ] || fail "$_WX_PROFILE output was compressed"
  if grep -Fq '[wx] repeated' "$_WX_TEST_ROOT/${_WX_PROFILE}.stdout"; then
    fail "$_WX_PROFILE emitted a compression marker"
  fi
  jq -e -s --arg profile "$_WX_PROFILE" '
    .[-1].profile == $profile
    and .[-1].output_policy == "raw-protected-profile"
    and .[-1].raw.stdout_bytes == .[-1].visible.stdout_bytes
  ' .ai-context/session.jsonl >/dev/null || fail "$_WX_PROFILE metadata is invalid"
done

source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" status >"$_WX_TEST_ROOT/status.out"
assert_file_contains "$_WX_TEST_ROOT/status.out" 'Current AI Context Workflow Status:'
jq -e -s 'length == 7' .ai-context/session.jsonl >/dev/null || fail 'session JSONL did not contain seven valid records'

_WX_SUCCESS_RAW_BYTES="$(jq -r -s '.[0].raw.stdout_bytes' .ai-context/session.jsonl)"
_WX_SUCCESS_VISIBLE_BYTES="$(jq -r -s '.[0].visible.stdout_bytes' .ai-context/session.jsonl)"
printf 'PASS: wx wrapper compression, raw preservation, metadata, and exit codes (success stdout %s -> %s bytes)\n' \
  "$_WX_SUCCESS_RAW_BYTES" "$_WX_SUCCESS_VISIBLE_BYTES"
