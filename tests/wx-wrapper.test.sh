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

# Stale terminal safety. The shell says "code" (compressible), active_mode.env says "security" (protected).
# wx must use the env file by default.
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" security >"$_WX_TEST_ROOT/activation-stale.out"
export AICONTEXT_PROFILE=code AICONTEXT_RISK=normal AICONTEXT_COMPRESS_SHELL=safe
wx npm install >"$_WX_TEST_ROOT/stale.stdout" 2>"$_WX_TEST_ROOT/stale.stderr"
[ "$?" -eq 0 ] || fail 'stale-shell fixture failed'
[ "$(grep -Fc 'PASS tests/widget.test.js' "$_WX_TEST_ROOT/stale.stdout")" -eq 12 ] || fail 'stale shell state compressed protected output'
if grep -Fq '[wx] repeated' "$_WX_TEST_ROOT/stale.stdout"; then
  fail 'stale shell state produced a compression marker'
fi
assert_file_contains "$_WX_TEST_ROOT/stale.stderr" 'Using profile "security" from active_mode.env'
jq -e -s '
  .[-1].profile == "security"
  and .[-1].output_policy == "raw-protected-profile"
  and .[-1].policy_source == "active_mode.env"
  and .[-1].stale_shell_profile == "code"
  and .[-1].raw.stdout_bytes == .[-1].visible.stdout_bytes
' .ai-context/session.jsonl >/dev/null || fail 'stale-shell metadata is invalid'
# The caller's shell is not changed by wx.
[ "$AICONTEXT_PROFILE" = code ] || fail 'wx changed the caller shell profile'

# workflow status shows both states.
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" status >"$_WX_TEST_ROOT/status-stale.out"
assert_file_contains "$_WX_TEST_ROOT/status-stale.out" 'AICONTEXT_PROFILE=code'
assert_file_contains "$_WX_TEST_ROOT/status-stale.out" 'Env file profile (used by wx): security'
assert_file_contains "$_WX_TEST_ROOT/status-stale.out" "Warning: this shell has profile 'code', but the env file has 'security'"

# Escape hatch: AICONTEXT_USE_SHELL_STATE=true keeps the shell state.
AICONTEXT_USE_SHELL_STATE=true wx npm install >"$_WX_TEST_ROOT/shellstate.stdout" 2>"$_WX_TEST_ROOT/shellstate.stderr"
jq -e -s '
  .[-1].profile == "code"
  and .[-1].policy_source == "shell"
  and .[-1].output_policy == "compress-exact-repeats-v1"
' .ai-context/session.jsonl >/dev/null || fail 'escape hatch did not keep the shell state'

# Old terminal with an env file that is missing: shell state is the fallback.
_WX_SAVED_CONFIG_DIR="$AICONTEXT_CONFIG_DIR"
export AICONTEXT_CONFIG_DIR="$_WX_TEST_ROOT/no-config"
wx npm install >"$_WX_TEST_ROOT/nofile.stdout" 2>"$_WX_TEST_ROOT/nofile.stderr"
jq -e -s '.[-1].profile == "code" and .[-1].policy_source == "shell"' .ai-context/session.jsonl >/dev/null || fail 'missing env file did not fall back to shell state'

# Env file with an unsafe line and no profile: the line is not executed, output stays raw.
mkdir -p "$_WX_TEST_ROOT/bad-config"
printf 'export AICONTEXT_COMPRESS_SHELL="safe"; touch "%s"\nexport AICONTEXT_RISK="$(touch %s)"\n' "$_WX_TEST_ROOT/EXECUTED" "$_WX_TEST_ROOT/EXECUTED" > "$_WX_TEST_ROOT/bad-config/active_mode.env"
export AICONTEXT_CONFIG_DIR="$_WX_TEST_ROOT/bad-config"
wx npm install >"$_WX_TEST_ROOT/bad.stdout" 2>"$_WX_TEST_ROOT/bad.stderr"
[ ! -e "$_WX_TEST_ROOT/EXECUTED" ] || fail 'env file content was executed'
[ "$(grep -Fc 'PASS tests/widget.test.js' "$_WX_TEST_ROOT/bad.stdout")" -eq 12 ] || fail 'env file without a profile compressed output'
assert_file_contains "$_WX_TEST_ROOT/bad.stderr" 'has no profile'
export AICONTEXT_CONFIG_DIR="$_WX_SAVED_CONFIG_DIR"

# ---- RTK post-capture prototype (fake RTK from tests/fixtures/bin/rtk) ----
_WX_FIXTURES="$_WX_REPOSITORY_ROOT/tests/fixtures/bin"
_WX_RTK_ALL_LOG="$_WX_TEST_ROOT/rtk-all.log"
: > "$_WX_RTK_ALL_LOG"
"$_WX_FIXTURES/pytest" > "$_WX_TEST_ROOT/direct.pytest.out"
FIXTURE_NO_WARNING=1 "$_WX_FIXTURES/pytest" > "$_WX_TEST_ROOT/direct.pytest.nowarn.out"

# Run wx with the fake RTK. Arguments: case name, then the command. FAKE_RTK_MODE and FIXTURE_* come from the caller.
rtk_run() {
  local _WX_CASE="$1"
  shift
  export FAKE_RTK_LOG="$_WX_TEST_ROOT/rtk-$_WX_CASE.log" FAKE_RTK_RAW_LOG="$_WX_TEST_ROOT/rtk-$_WX_CASE.raw.log"
  : > "$FAKE_RTK_LOG"
  : > "$FAKE_RTK_RAW_LOG"
  wx "$@" >"$_WX_TEST_ROOT/rtk-$_WX_CASE.stdout" 2>"$_WX_TEST_ROOT/rtk-$_WX_CASE.stderr"
  _WX_RUN_EXIT=$?
  cat "$FAKE_RTK_LOG" >> "$_WX_RTK_ALL_LOG"
}
rtk_last() { jq -c -s '.[-1]' .ai-context/session.jsonl; }
rtk_calls() { grep -c . "$FAKE_RTK_LOG"; }

source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >"$_WX_TEST_ROOT/activation-rtk.out"

# 1. Mapped commands: RTK filter applied, record complete, raw capture complete before RTK ran.
for _WX_PAIR in 'pytest|pytest' 'cargo test|cargo-test' 'go test|go-test' 'go build|go-build' 'tsc|tsc' 'vitest|vitest'; do
  _WX_CMD="${_WX_PAIR%%|*}"
  _WX_FILTER="${_WX_PAIR##*|}"
  _WX_CASE="map-${_WX_FILTER}"
  # shellcheck disable=SC2086
  rtk_run "$_WX_CASE" $_WX_CMD
  [ "$_WX_RUN_EXIT" -eq 0 ] || fail "$_WX_CMD exited $_WX_RUN_EXIT through wx"
  rtk_last | jq -e --arg f "$_WX_FILTER" '
    .output_policy == "compress-rtk-v1" and .compressor == "rtk" and .compressor_version == "9.9.9"
    and .filter == $f and .fallback_reason == null
    and .visible.stdout_bytes < .raw.stdout_bytes
    and .exit_code == 0
  ' >/dev/null || fail "$_WX_CMD record is invalid: $(rtk_last)"
  assert_file_contains "$_WX_TEST_ROOT/rtk-$_WX_CASE.stdout" "[fake-rtk:$_WX_FILTER]"
  assert_file_contains "$_WX_TEST_ROOT/rtk-$_WX_CASE.stdout" 'warning: deprecated api used'
  [ "$(grep -c . "$FAKE_RTK_LOG")" -eq 2 ] || fail "$_WX_CMD: expected exactly --version and pipe calls"
  grep -qx "pipe -f $_WX_FILTER" "$FAKE_RTK_LOG" || fail "$_WX_CMD: pipe call missing"
done
# Raw capture was complete when RTK started, and it is byte-identical to the command output.
rtk_run raw-first pytest
grep -Eq '^stdin=([0-9]+) raw=\1$' "$FAKE_RTK_RAW_LOG" || fail "raw capture was not complete when RTK ran: $(cat "$FAKE_RTK_RAW_LOG")"
_WX_RAW_PATH="$(rtk_last | jq -r '.stdout.path')"
cmp -s "$_WX_RAW_PATH" "$_WX_TEST_ROOT/direct.pytest.out" || fail 'stdout.raw differs from the command output'
[ "$(rtk_last | jq -r '.visible.stdout_path')" != "$_WX_RAW_PATH" ] || fail 'visible path should differ from raw when RTK applied'
# RTK stderr never reaches the user. It is kept in the run directory.
if grep -Fq 'rtk fake notice' "$_WX_TEST_ROOT/rtk-raw-first.stderr"; then
  fail 'RTK stderr was shown to the user'
fi
grep -Fq 'rtk fake notice' "$(dirname "$_WX_RAW_PATH")/rtk.stderr" || fail 'RTK stderr was not kept'
# Command stderr stays verbatim.
FIXTURE_STDERR=1 rtk_run stderr pytest
assert_file_contains "$_WX_TEST_ROOT/rtk-stderr.stderr" 'fixture stderr line'
rtk_last | jq -e '.raw.stderr_bytes == .visible.stderr_bytes and .raw.stderr_bytes > 0' >/dev/null || fail 'stderr was changed'

# 2. Bypass: failures, protected profiles, commands without a filter, excluded filters. RTK is not called.
FIXTURE_EXIT=1 rtk_run failing pytest
[ "$_WX_RUN_EXIT" -eq 1 ] || fail 'failing command exit code was not preserved'
[ "$(rtk_calls)" -eq 0 ] || fail 'RTK was called for a failing command'
rtk_last | jq -e '.output_policy == "raw-nonzero-exit" and .compressor == null and .filter == null and .fallback_reason == null and .visible.stdout_bytes == .raw.stdout_bytes' >/dev/null || fail 'failing run record is invalid'
cmp -s "$_WX_TEST_ROOT/rtk-failing.stdout" "$_WX_TEST_ROOT/direct.pytest.out" || fail 'failing run output was changed'

for _WX_PROFILE in security db release migration raw; do
  source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" "$_WX_PROFILE" >/dev/null
  rtk_run "protected-$_WX_PROFILE" pytest
  [ "$(rtk_calls)" -eq 0 ] || fail "RTK was called in the $_WX_PROFILE profile"
  rtk_last | jq -e '.output_policy == "raw-protected-profile" and .compressor == null' >/dev/null || fail "$_WX_PROFILE record is invalid"
  cmp -s "$_WX_TEST_ROOT/rtk-protected-$_WX_PROFILE.stdout" "$_WX_TEST_ROOT/direct.pytest.out" || fail "$_WX_PROFILE output was changed"
done
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" micro >/dev/null
rtk_run micro pytest
[ "$(rtk_calls)" -eq 0 ] || fail 'RTK was called in micro (rtk_mode off)'
rtk_last | jq -e '.output_policy == "raw-compression-disabled"' >/dev/null || fail 'micro record is invalid'

# Protected command in an RTK mode: still raw. Use a settings copy that lists pytest as protected.
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >/dev/null
jq '.command_policy.preserve_raw_or_lossless += ["pytest"]' "$AICONTEXT_SETTINGS_FILE" > "$_WX_TEST_ROOT/protected-settings.json"
AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/protected-settings.json" rtk_run protected-command pytest
[ "$(rtk_calls)" -eq 0 ] || fail 'RTK was called for a protected command'
rtk_last | jq -e '.output_policy == "raw-protected-command"' >/dev/null || fail 'protected command record is invalid'

# debug is an RTK mode, so a passing debug run may use RTK. A failing one stays raw (above).
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" debug >/dev/null
rtk_run debug-pass pytest
rtk_last | jq -e '.output_policy == "compress-rtk-v1" and .compressor == "rtk"' >/dev/null || fail 'passing debug run did not use RTK'
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >/dev/null

# Commands without a mapped filter, and the excluded filters, never reach RTK.
git init -q . 2>/dev/null
rtk_run unmapped-npm npm install
[ "$(rtk_calls)" -eq 0 ] || fail 'RTK was called for an unmapped command'
rtk_last | jq -e '.output_policy == "compress-exact-repeats-v1" and .compressor == "builtin/exact-repeat-v1" and .compressor_version == "1" and .filter == null' >/dev/null || fail 'unmapped command should use the built-in reducer and be labelled that way'
for _WX_EXCLUDED in 'grep -c PASSED direct-file' 'find . -maxdepth 0' 'git status' 'git diff'; do
  cp "$_WX_TEST_ROOT/direct.pytest.out" direct-file
  # shellcheck disable=SC2086
  rtk_run excluded $_WX_EXCLUDED
  [ "$(rtk_calls)" -eq 0 ] || fail "RTK was called for: $_WX_EXCLUDED"
  rtk_last | jq -e '.compressor == null and .filter == null' >/dev/null || fail "excluded command was labelled: $_WX_EXCLUDED"
done
# A config that maps an excluded filter does not enable it.
jq '.command_policy.rtk_filters += {"grep": "grep", "git status": "git-status", "find": "find"}' "$AICONTEXT_SETTINGS_FILE" > "$_WX_TEST_ROOT/denied-settings.json"
for _WX_EXCLUDED in 'grep -c PASSED direct-file' 'git status' 'find . -maxdepth 0'; do
  # shellcheck disable=SC2086
  AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/denied-settings.json" rtk_run denied $_WX_EXCLUDED
  [ "$(rtk_calls)" -eq 0 ] || fail "RTK was called for a denied filter: $_WX_EXCLUDED"
done

# 3. Fallbacks: raw output is shown, exit code kept, the reason is recorded, compressor is null.
rtk_fallback() { # case, FAKE_RTK_MODE, reason, [extra env assignment run through env]
  local _WX_CASE="fallback-$1"
  FAKE_RTK_MODE="$2" rtk_run "$_WX_CASE" pytest
  [ "$_WX_RUN_EXIT" -eq 0 ] || fail "$1: exit code changed"
  rtk_last | jq -e --arg r "$3" '
    .output_policy == "raw-rtk-fallback" and .compressor == null and .filter == "pytest"
    and .fallback_reason == $r and .visible.stdout_bytes == .raw.stdout_bytes and .exit_code == 0
  ' >/dev/null || fail "$1: record is invalid: $(rtk_last)"
  cmp -s "$_WX_TEST_ROOT/rtk-$_WX_CASE.stdout" "$_WX_TEST_ROOT/direct.pytest.out" || fail "$1: raw output was not shown"
  if grep -Fq 'fake-rtk' "$_WX_TEST_ROOT/rtk-$_WX_CASE.stdout"; then
    fail "$1: RTK output leaked into the visible output"
  fi
}
rtk_fallback nonzero fail rtk-nonzero-exit
rtk_fallback empty empty rtk-empty-output
rtk_fallback same same rtk-not-smaller
rtk_fallback noversion noversion rtk-version-failed
rtk_last | jq -e '.compressor_version == null' >/dev/null || fail 'a failed version check should not record a version'
AICONTEXT_RTK_TIMEOUT=1 rtk_fallback timeout hang rtk-timeout
rtk_fallback guard drop-warning evidence-guard
rtk_last | jq -e '.compressor_version == "9.9.9"' >/dev/null || fail 'the RTK version should be recorded when RTK ran'
[ -f "$(dirname "$(rtk_last | jq -r '.stdout.path')")/rtk.rejected.stdout" ] || fail 'the rejected RTK output was not kept'
# RTK not installed.
AICONTEXT_RTK_BIN=/nonexistent/rtk rtk_fallback missing filter rtk-not-installed
# Without a warning in the raw output, the same dropped-warning RTK output is accepted (the guard looks at raw evidence).
FIXTURE_NO_WARNING=1 FAKE_RTK_MODE=drop-warning rtk_run guard-ok pytest
rtk_last | jq -e '.output_policy == "compress-rtk-v1" and .compressor == "rtk" and .fallback_reason == null' >/dev/null || fail 'the guard rejected output that has no evidence lines'

# 4. Evidence guard, directly.
printf 'a\nerror: boom\nb\n' > "$_WX_TEST_ROOT/g.raw"
printf 'a\nerror: boom\n' > "$_WX_TEST_ROOT/g.keep"
printf 'summary only\n' > "$_WX_TEST_ROOT/g.drop"
_wx_evidence_guard "$_WX_TEST_ROOT/g.raw" "$_WX_TEST_ROOT/g.keep" || fail 'guard rejected output that keeps the error line'
if _wx_evidence_guard "$_WX_TEST_ROOT/g.raw" "$_WX_TEST_ROOT/g.drop"; then fail 'guard accepted output without the error line'; fi
: > "$_WX_TEST_ROOT/g.empty"
if _wx_evidence_guard "$_WX_TEST_ROOT/g.raw" "$_WX_TEST_ROOT/g.empty"; then fail 'guard accepted empty output with evidence in raw'; fi
for _WX_EVIDENCE in 'Warning: low disk' 'src/a.ts(3,5): error TS2322: bad' 'x.py:3: DeprecationWarning: old' 'panic: runtime error' 'Traceback (most recent call last):' 'tests/x FAILED' 'CVE-2099-1' 'warning[W1]: x' '  error[E0308]: mismatched'; do
  printf 'ok\n%s\nok2\n' "$_WX_EVIDENCE" > "$_WX_TEST_ROOT/g2.raw"
  printf 'summary\n' > "$_WX_TEST_ROOT/g2.out"
  if _wx_evidence_guard "$_WX_TEST_ROOT/g2.raw" "$_WX_TEST_ROOT/g2.out"; then fail "guard missed evidence line: $_WX_EVIDENCE"; fi
done
printf 'errors.py::test_a PASSED\nwarnings summary is below\ntest_error_handling ... ok\n' > "$_WX_TEST_ROOT/g3.raw"
printf 'summary\n' > "$_WX_TEST_ROOT/g3.out"
_wx_evidence_guard "$_WX_TEST_ROOT/g3.raw" "$_WX_TEST_ROOT/g3.out" || fail 'guard is too broad: it flagged names that only contain error or warning'

# 5. Token Controller never runs "rtk init" (or anything except --version and pipe -f <mapped filter>).
if grep -Ev '^(--version|pipe -f (cargo-test|pytest|go-test|go-build|tsc|vitest))$' "$_WX_RTK_ALL_LOG" | grep -q .; then
  fail "unexpected RTK call: $(grep -Ev '^(--version|pipe -f (cargo-test|pytest|go-test|go-build|tsc|vitest))$' "$_WX_RTK_ALL_LOG" | head -3)"
fi
grep -q 'init' "$_WX_RTK_ALL_LOG" && fail 'rtk init was called'
unset FAKE_RTK_LOG FAKE_RTK_RAW_LOG FAKE_RTK_MODE

# 6. Real RTK, when installed. Raw evidence must be intact whatever RTK does. Output depends on the RTK version.
_WX_REAL_RTK="$(PATH="${PATH#"$_WX_FIXTURES:"}" command -v rtk 2>/dev/null || true)"
if [ -n "$_WX_REAL_RTK" ] && [ "$_WX_REAL_RTK" != "$_WX_FIXTURES/rtk" ]; then
  FIXTURE_NO_WARNING=1 AICONTEXT_RTK_BIN="$_WX_REAL_RTK" rtk_run real-clean pytest
  [ "$_WX_RUN_EXIT" -eq 0 ] || fail 'real RTK: exit code changed'
  _WX_REAL_RAW="$(rtk_last | jq -r '.stdout.path')"
  cmp -s "$_WX_REAL_RAW" "$_WX_TEST_ROOT/direct.pytest.nowarn.out" || fail 'real RTK: raw capture differs from the command output'
  rtk_last | jq -e '(.compressor == "rtk" and .compressor_version != null and .visible.stdout_bytes < .raw.stdout_bytes) or (.compressor == null and .fallback_reason != null and .visible.stdout_bytes == .raw.stdout_bytes)' >/dev/null || fail "real RTK: record is inconsistent: $(rtk_last)"
  _WX_REAL_CLEAN="$(rtk_last | jq -r '.compressor // "fallback:" + .fallback_reason')"
  AICONTEXT_RTK_BIN="$_WX_REAL_RTK" rtk_run real-warning pytest
  cmp -s "$(rtk_last | jq -r '.stdout.path')" "$_WX_TEST_ROOT/direct.pytest.out" || fail 'real RTK: raw capture differs from the command output (warning case)'
  # The warning line must be visible in the output, whether RTK kept it or the guard fell back to raw.
  assert_file_contains "$_WX_TEST_ROOT/rtk-real-warning.stdout" 'warning: deprecated api used'
  _WX_REAL_WARN="$(rtk_last | jq -r '.compressor // "fallback:" + .fallback_reason')"
  printf 'NOTE: real RTK %s: clean output -> %s; output with a warning -> %s\n' "$(rtk_last | jq -r '.compressor_version // "n/a"')" "$_WX_REAL_CLEAN" "$_WX_REAL_WARN"
else
  printf 'NOTE: real RTK not installed. Only the fake RTK was tested.\n'
fi
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >/dev/null

_WX_SUCCESS_RAW_BYTES="$(jq -r -s '.[0].raw.stdout_bytes' .ai-context/session.jsonl)"
_WX_SUCCESS_VISIBLE_BYTES="$(jq -r -s '.[0].visible.stdout_bytes' .ai-context/session.jsonl)"
printf 'PASS: wx wrapper compression, raw preservation, metadata, and exit codes (success stdout %s -> %s bytes)\n' \
  "$_WX_SUCCESS_RAW_BYTES" "$_WX_SUCCESS_VISIBLE_BYTES"
