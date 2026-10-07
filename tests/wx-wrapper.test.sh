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
grep -Eq '^stdin=([0-9]+) raw=\1 exit=0$' "$FAKE_RTK_RAW_LOG" || fail "raw capture and exit code were not on disk when RTK ran: $(cat "$FAKE_RTK_RAW_LOG")"
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
jq '.command_policy.rtk_commands = [{"match": "grep", "class": "pipe", "filter": "grep"}, {"match": "git status", "class": "pipe", "filter": "git-status"}, {"match": "find", "class": "pipe", "filter": "find"}]' "$AICONTEXT_SETTINGS_FILE" > "$_WX_TEST_ROOT/denied-settings.json"
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
for _WX_EVIDENCE in 'Warning: low disk' 'src/a.ts(3,5): error TS2322: bad' 'x.py:3: DeprecationWarning: old' 'panic: runtime error' 'Traceback (most recent call last):' 'tests/x FAILED' 'CVE-2099-1' 'warning[W1]: x' '  error[E0308]: mismatched' 'test tests::slow_path ... warning: slow path' "thread 'tests::t' panicked at src/lib.rs:21:9:" '    calc_test.go:27: warning: cache miss'; do
  printf 'ok\n%s\nok2\n' "$_WX_EVIDENCE" > "$_WX_TEST_ROOT/g2.raw"
  printf 'summary\n' > "$_WX_TEST_ROOT/g2.out"
  if _wx_evidence_guard "$_WX_TEST_ROOT/g2.raw" "$_WX_TEST_ROOT/g2.out"; then fail "guard missed evidence line: $_WX_EVIDENCE"; fi
done
printf 'errors.py::test_a PASSED\nwarnings summary is below\ntest_error_handling ... ok\n' > "$_WX_TEST_ROOT/g3.raw"
printf 'summary\n' > "$_WX_TEST_ROOT/g3.out"
_wx_evidence_guard "$_WX_TEST_ROOT/g3.raw" "$_WX_TEST_ROOT/g3.out" || fail 'guard is too broad: it flagged names that only contain error or warning'

# 3b. RTK unavailable in other ways: not on PATH by name, and a file without the execute bit.
AICONTEXT_RTK_BIN=rtk-is-not-on-the-path-xyz rtk_fallback missing-name filter rtk-not-installed
printf '#!/usr/bin/env bash\necho "rtk 9.9.9"\n' > "$_WX_TEST_ROOT/notexec-rtk"
chmod -x "$_WX_TEST_ROOT/notexec-rtk"
AICONTEXT_RTK_BIN="$_WX_TEST_ROOT/notexec-rtk" rtk_fallback notexec filter rtk-not-installed

# 3c. RTK available, but no filter for the command: the run is not labelled as RTK, and RTK is not called.
for _WX_UNMAPPED in 'cargo build' 'go vet' 'cargo check'; do
  # shellcheck disable=SC2086
  rtk_run "nofilter" $_WX_UNMAPPED
  [ "$_WX_RUN_EXIT" -eq 0 ] || fail "$_WX_UNMAPPED exited $_WX_RUN_EXIT"
  [ "$(rtk_calls)" -eq 0 ] || fail "RTK was called for a command without a filter: $_WX_UNMAPPED"
  rtk_last | jq -e '.compressor == null and .compressor_version == null and .filter == null and .fallback_reason == null and .output_policy == "raw-command-not-eligible" and .visible.stdout_bytes == .raw.stdout_bytes' >/dev/null || fail "unmapped command was labelled: $_WX_UNMAPPED: $(rtk_last)"
  # shellcheck disable=SC2086
  "$_WX_FIXTURES/${_WX_UNMAPPED%% *}" ${_WX_UNMAPPED#* } > "$_WX_TEST_ROOT/direct.nofilter.out"
  cmp -s "$_WX_TEST_ROOT/rtk-nofilter.stdout" "$_WX_TEST_ROOT/direct.nofilter.out" || fail "output of an unmapped command was changed: $_WX_UNMAPPED"
done
# A mapped command where RTK passes the text through unchanged is not labelled either (not smaller).
FAKE_RTK_MODE=same rtk_run passthrough pytest
rtk_last | jq -e '.compressor == null and .output_policy == "raw-rtk-fallback" and .fallback_reason == "rtk-not-smaller"' >/dev/null || fail 'a pass-through RTK run was labelled as compressed'

# 3d. Evidence in other formats. RTK drops the line -> raw output. RTK keeps the line -> RTK output.
for _WX_EVIDENCE in 'x.py:3: DeprecationWarning: old api' 'WARN  deprecated api' 'ERROR  something failed softly' 'src/a.ts(3,5): error TS2322: bad' 'Traceback (most recent call last):' 'tests/x.py::t FAILED' 'CVE-2099-1 found in dep' 'fatal: not a repository' 'warn: slow test'; do
  FIXTURE_NO_WARNING=1 FIXTURE_EVIDENCE="$_WX_EVIDENCE" FAKE_RTK_MODE=drop-warning rtk_run evidence pytest
  rtk_last | jq -e '.output_policy == "raw-rtk-fallback" and .fallback_reason == "evidence-guard" and .compressor == null' >/dev/null || fail "dropped evidence was not caught: $_WX_EVIDENCE"
  assert_file_contains "$_WX_TEST_ROOT/rtk-evidence.stdout" "$_WX_EVIDENCE"
  if grep -Fq 'fake-rtk' "$_WX_TEST_ROOT/rtk-evidence.stdout"; then fail "RTK output leaked after a guard fallback: $_WX_EVIDENCE"; fi
  FIXTURE_NO_WARNING=1 FIXTURE_EVIDENCE="$_WX_EVIDENCE" FAKE_RTK_MODE=keep FAKE_RTK_KEEP="$_WX_EVIDENCE" rtk_run evidence-kept pytest
  rtk_last | jq -e '.output_policy == "compress-rtk-v1" and .compressor == "rtk" and .fallback_reason == null' >/dev/null || fail "kept evidence was rejected: $_WX_EVIDENCE"
  assert_file_contains "$_WX_TEST_ROOT/rtk-evidence-kept.stdout" "$_WX_EVIDENCE"
done
# Lines that only look similar are not evidence, so RTK may drop them.
FIXTURE_NO_WARNING=1 FIXTURE_EVIDENCE='errors.py::test_a PASSED' FAKE_RTK_MODE=filter rtk_run lookalike pytest
rtk_last | jq -e '.output_policy == "compress-rtk-v1"' >/dev/null || fail 'the guard flagged a line that only starts with the word error'

# 3e. RTK stderr is captured, but never mixed into the visible command output.
FIXTURE_STDERR=1 rtk_run stderr-ok pytest
[ "$(wc -l < "$_WX_TEST_ROOT/rtk-stderr-ok.stderr")" -eq 2 ] || fail "wx stderr should be the command stderr plus the raw-log pointer: $(cat "$_WX_TEST_ROOT/rtk-stderr-ok.stderr")"
[ "$(sed -n 1p "$_WX_TEST_ROOT/rtk-stderr-ok.stderr")" = 'fixture stderr line' ] || fail 'command stderr is not first and verbatim'
sed -n 2p "$_WX_TEST_ROOT/rtk-stderr-ok.stderr" | grep -q '^\[wx\] raw logs: ' || fail 'second stderr line is not the raw-log pointer'
if grep -Fq 'rtk fake notice' "$_WX_TEST_ROOT/rtk-stderr-ok.stdout" "$_WX_TEST_ROOT/rtk-stderr-ok.stderr"; then fail 'RTK stderr was mixed into the visible output'; fi
_WX_RUN_DIR_OK="$(dirname "$(rtk_last | jq -r '.stdout.path')")"
[ "$(cat "$_WX_RUN_DIR_OK/stderr.raw")" = 'fixture stderr line' ] || fail 'stderr.raw holds more than the command stderr'
[ "$(cat "$_WX_RUN_DIR_OK/rtk.stderr")" = 'rtk fake notice' ] || fail 'the RTK notice was not captured in rtk.stderr'
for _WX_RTK_MODE in fail drop-warning same empty; do
  FIXTURE_STDERR=1 FAKE_RTK_MODE="$_WX_RTK_MODE" rtk_run stderr-fallback pytest
  [ "$(wc -l < "$_WX_TEST_ROOT/rtk-stderr-fallback.stderr")" -eq 2 ] || fail "wx stderr after an RTK fallback ($_WX_RTK_MODE) has extra lines: $(cat "$_WX_TEST_ROOT/rtk-stderr-fallback.stderr")"
  if grep -Fq 'rtk fake notice' "$_WX_TEST_ROOT/rtk-stderr-fallback.stdout" "$_WX_TEST_ROOT/rtk-stderr-fallback.stderr"; then fail "RTK stderr leaked after a fallback ($_WX_RTK_MODE)"; fi
  cmp -s "$_WX_TEST_ROOT/rtk-stderr-fallback.stdout" "$_WX_TEST_ROOT/direct.pytest.out" || fail "stdout changed after an RTK fallback ($_WX_RTK_MODE)"
done

# 3f. Caveman and failure evidence. wx records the Caveman level. When Caveman is on and a run fails, wx prints
# a reminder next to the failure output. When Caveman is off (the default), nothing is added.
export AICONTEXT_CAVEMAN_REQUEST=lite
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >/dev/null 2>&1
unset AICONTEXT_CAVEMAN_REQUEST
grep -Fq 'export AICONTEXT_CAVEMAN_MODE="lite"' "$AICONTEXT_CONFIG_DIR/active_mode.env" || fail 'Caveman lite was not set for the failure-reminder test'
FIXTURE_EXIT=1 rtk_run cave-fail pytest
[ "$_WX_RUN_EXIT" -eq 1 ] || fail 'exit code changed with Caveman on'
assert_file_contains "$_WX_TEST_ROOT/rtk-cave-fail.stderr" '[wx] Caveman is lite and this run failed (exit 1). Quote the error, stack trace, paths, and line numbers exactly.'
cmp -s "$_WX_TEST_ROOT/rtk-cave-fail.stdout" "$_WX_TEST_ROOT/direct.pytest.out" || fail 'failing output changed with Caveman on'
rtk_last | jq -e '.caveman_mode == "lite" and .exit_code == 1 and .output_policy == "raw-nonzero-exit"' >/dev/null || fail 'failing run record with Caveman on is invalid'
[ "$(grep -c 'Caveman is' "$_WX_TEST_ROOT/rtk-cave-fail.stderr")" -eq 1 ] || fail 'the reminder should appear once'
rtk_run cave-ok pytest
if grep -Fq 'Caveman is' "$_WX_TEST_ROOT/rtk-cave-ok.stderr"; then fail 'a successful run printed the Caveman reminder'; fi
rtk_last | jq -e '.caveman_mode == "lite"' >/dev/null || fail 'successful run did not record the Caveman level'
# Default (off): no reminder, the level is recorded as off.
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >/dev/null 2>&1
FIXTURE_EXIT=1 rtk_run cave-off pytest
if grep -Fq 'Caveman' "$_WX_TEST_ROOT/rtk-cave-off.stderr"; then fail 'the reminder was printed with Caveman off'; fi
rtk_last | jq -e '.caveman_mode == "off"' >/dev/null || fail 'Caveman off was not recorded'
# A blocked mode ignores the request, so no reminder is needed there.
export AICONTEXT_CAVEMAN_REQUEST=lite
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" debug >/dev/null 2>&1
unset AICONTEXT_CAVEMAN_REQUEST
FIXTURE_EXIT=1 rtk_run cave-debug pytest
if grep -Fq 'Caveman' "$_WX_TEST_ROOT/rtk-cave-debug.stderr"; then fail 'the reminder was printed in debug (Caveman is blocked there)'; fi
rtk_last | jq -e '.caveman_mode == "off"' >/dev/null || fail 'debug should record Caveman off'
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >/dev/null 2>&1

# 3g. RTK classes in command_policy.rtk_commands. RTK is a post-capture filter, so wx runs the command once.
# Only a resolved "pipe" class uses RTK. Unknown or unsupported classes resolve to never (raw output).
cp "$_WX_TEST_ROOT/direct.pytest.out" direct-file
class_run() { # case name, settings jq filter, then the command. Prints nothing. Sets _WX_RUN_EXIT.
  local _WX_CNAME="$1" _WX_CFILTER="$2"
  shift 2
  jq "$_WX_CFILTER" "$AICONTEXT_SETTINGS_FILE" > "$_WX_TEST_ROOT/class-$_WX_CNAME.json"
  AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/class-$_WX_CNAME.json" rtk_run "class-$_WX_CNAME" "$@"
}
class_expect() { # expected rtk_class (or null), expected output_policy
  rtk_last | jq -e --arg c "$1" --arg p "$2" '(.rtk_class // "null") == $c and .output_policy == $p and .compressor == null and .filter == null and .visible.stdout_bytes == .raw.stdout_bytes' >/dev/null || fail "class record is invalid (want class $1, policy $2): $(rtk_last)"
}
# recognized-only: cat, head, tail (rtk read) are known and never used.
for _WX_CMD in 'cat direct-file' 'head -n 3 direct-file' 'tail -n 3 direct-file'; do
  # shellcheck disable=SC2086
  rtk_run recognized $_WX_CMD
  [ "$(rtk_calls)" -eq 0 ] || fail "RTK was called for a recognized-only command: $_WX_CMD"
  class_expect recognized-only raw-command-not-eligible
  # shellcheck disable=SC2086
  $_WX_CMD > "$_WX_TEST_ROOT/direct.recognized.out"
  cmp -s "$_WX_TEST_ROOT/rtk-recognized.stdout" "$_WX_TEST_ROOT/direct.recognized.out" || fail "output of a recognized-only command was changed: $_WX_CMD"
done
# rtk read / rtk smart run as ordinary commands. wx only classifies them. Its own RTK calls (--version, pipe) must not appear.
for _WX_RTKCMD in 'read direct-file' 'smart direct-file'; do
  FAKE_RTK_LOG="$_WX_TEST_ROOT/rtk-usercmd.log"
  export FAKE_RTK_LOG
  : > "$FAKE_RTK_LOG"
  # shellcheck disable=SC2086
  wx rtk $_WX_RTKCMD >/dev/null 2>&1
  [ "$(cat "$FAKE_RTK_LOG")" = "$_WX_RTKCMD" ] || fail "wx called RTK itself for: rtk $_WX_RTKCMD ($(cat "$FAKE_RTK_LOG"))"
  rtk_last | jq -e '.rtk_class == "recognized-only" and .compressor == null and .filter == null' >/dev/null || fail "rtk $_WX_RTKCMD is not recognized-only: $(rtk_last)"
done
# never: explicit entries.
for _WX_CMD in 'grep -c PASSED direct-file' 'git status'; do
  # shellcheck disable=SC2086
  rtk_run never $_WX_CMD
  [ "$(rtk_calls)" -eq 0 ] || fail "RTK was called for a never command: $_WX_CMD"
  class_expect never raw-command-not-eligible
done
# No entry: no class, raw output.
rtk_run noentry ls
[ "$(rtk_calls)" -eq 0 ] || fail 'RTK was called for a command with no entry'
class_expect null raw-command-not-eligible
# Unknown, empty, or misspelled classes, a class that is not a string, and rerun all resolve to never.
for _WX_CLASS in turbo PIPE Pipe '' ' pipe' 'pipe ' 'pipe,never' rerun direct rtk recognized_only; do
  jq --arg v "$_WX_CLASS" '.command_policy.rtk_commands = [{"match": "pytest", "class": $v, "filter": "pytest"}]' "$AICONTEXT_SETTINGS_FILE" > "$_WX_TEST_ROOT/class-bad.json"
  AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/class-bad.json" rtk_run class-bad pytest
  [ "$_WX_RUN_EXIT" -eq 0 ] || fail "pytest exit code changed with class '$_WX_CLASS'"
  [ "$(rtk_calls)" -eq 0 ] || fail "RTK was called for the unsupported class '$_WX_CLASS'"
  class_expect never raw-command-not-eligible
  cmp -s "$_WX_TEST_ROOT/rtk-class-bad.stdout" "$_WX_TEST_ROOT/direct.pytest.out" || fail "output changed for the unsupported class '$_WX_CLASS'"
done
for _WX_BAD in '[{"match": "pytest", "filter": "pytest"}]' '[{"match": "pytest", "class": 5, "filter": "pytest"}]' '[{"match": "pytest", "class": null, "filter": "pytest"}]' '["pytest"]' '[null]' '{"match": "pytest", "class": "pipe", "filter": "pytest"}' '"pytest"' '7'; do
  class_run shape ".command_policy.rtk_commands = $_WX_BAD" pytest
  [ "$_WX_RUN_EXIT" -eq 0 ] || fail "pytest exit code changed for the config shape $_WX_BAD"
  [ "$(rtk_calls)" -eq 0 ] || fail "RTK was called for the config shape $_WX_BAD"
  rtk_last | jq -e '.compressor == null and .filter == null and .output_policy == "raw-command-not-eligible"' >/dev/null || fail "config shape $_WX_BAD was not raw: $(rtk_last)"
done
class_run nokey 'del(.command_policy.rtk_commands)' pytest
[ "$(rtk_calls)" -eq 0 ] || fail 'RTK was called without command_policy.rtk_commands'
class_expect null raw-command-not-eligible
class_run legacy '.command_policy.rtk_filters = {"pytest": "pytest"} | del(.command_policy.rtk_commands)' pytest
[ "$(rtk_calls)" -eq 0 ] || fail 'the old rtk_filters key was still used'
# rerun is rejected even when it is enabled in the config. There is no code for it.
class_run rerun '.command_policy.rtk_class_enabled.rerun = true | .command_policy.rtk_commands += [{"match": "ls", "class": "rerun", "rtk": "ls"}, {"match": "pytest", "class": "rerun"}]' ls
[ "$(rtk_calls)" -eq 0 ] || fail 'RTK was called for a rerun entry'
class_expect never raw-command-not-eligible
class_run rerun2 '.command_policy.rtk_class_enabled.rerun = true | .command_policy.rtk_commands = [{"match": "pytest", "class": "rerun"}]' pytest
[ "$(rtk_calls)" -eq 0 ] || fail 'RTK was called for rerun on a mapped command'
class_expect never raw-command-not-eligible
# The pipe class must be enabled. A missing switch means disabled.
class_run pipeoff '.command_policy.rtk_class_enabled.pipe = false' pytest
[ "$(rtk_calls)" -eq 0 ] || fail 'RTK was called with the pipe class disabled'
class_expect never raw-command-not-eligible
class_run pipemissing 'del(.command_policy.rtk_class_enabled)' pytest
[ "$(rtk_calls)" -eq 0 ] || fail 'RTK was called without rtk_class_enabled'
class_expect never raw-command-not-eligible
class_run pipestring '.command_policy.rtk_class_enabled.pipe = "true"' pytest
[ "$(rtk_calls)" -eq 0 ] || fail 'a string "true" enabled the pipe class'
# A pipe entry needs a plain filter name that is not denied.
for _WX_FILTER in '' 'Py Test' 'pytest; touch PIPE_INJECTED' '$(touch PIPE_INJECTED)' 'grep' 'git-diff' 'rg'; do
  jq --arg f "$_WX_FILTER" '.command_policy.rtk_commands = [{"match": "pytest", "class": "pipe", "filter": $f}]' "$AICONTEXT_SETTINGS_FILE" > "$_WX_TEST_ROOT/class-filter.json"
  AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/class-filter.json" rtk_run class-filter pytest
  [ "$(rtk_calls)" -eq 0 ] || fail "RTK was called with the filter '$_WX_FILTER'"
  class_expect never raw-command-not-eligible
done
[ ! -e PIPE_INJECTED ] || fail 'a filter name was executed'
class_run nofilter '.command_policy.rtk_commands = [{"match": "pytest", "class": "pipe"}]' pytest
[ "$(rtk_calls)" -eq 0 ] || fail 'RTK was called for a pipe entry without a filter'
# The longest matching prefix wins, in any order.
for _WX_ORDER in '[{"match": "cargo", "class": "never"}, {"match": "cargo test", "class": "pipe", "filter": "cargo-test"}]' '[{"match": "cargo test", "class": "pipe", "filter": "cargo-test"}, {"match": "cargo", "class": "never"}]'; do
  class_run longest ".command_policy.rtk_commands = $_WX_ORDER" cargo test
  rtk_last | jq -e '.rtk_class == "pipe" and .compressor == "rtk" and .filter == "cargo-test"' >/dev/null || fail "the longer prefix did not win for cargo test: $(rtk_last)"
  class_run longest2 ".command_policy.rtk_commands = $_WX_ORDER" cargo build
  [ "$(rtk_calls)" -eq 0 ] || fail 'RTK was called for cargo build, which matches only the never entry'
  rtk_last | jq -e '.rtk_class == "never" and .compressor == null' >/dev/null || fail "cargo build should resolve to never: $(rtk_last)"
done
# Protected profiles bypass RTK even when every class is enabled and pytest is a pipe command.
jq '.command_policy.rtk_class_enabled = {"pipe": true, "rerun": true, "recognized-only": true, "never": true}' "$AICONTEXT_SETTINGS_FILE" > "$_WX_TEST_ROOT/class-all.json"
for _WX_PROFILE in raw security db migration release; do
  source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" "$_WX_PROFILE" >/dev/null 2>&1
  AICONTEXT_SETTINGS_FILE="$_WX_TEST_ROOT/class-all.json" rtk_run class-protected pytest
  [ "$(rtk_calls)" -eq 0 ] || fail "RTK was called in the $_WX_PROFILE profile with every class enabled"
  rtk_last | jq -e '.output_policy == "raw-protected-profile" and .compressor == null and .filter == null' >/dev/null || fail "$_WX_PROFILE record is invalid with every class enabled: $(rtk_last)"
  cmp -s "$_WX_TEST_ROOT/rtk-class-protected.stdout" "$_WX_TEST_ROOT/direct.pytest.out" || fail "$_WX_PROFILE output changed with every class enabled"
done
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >/dev/null 2>&1

# 3h. The exit code is written to the run directory right after the command ends, before RTK runs.
FIXTURE_EXIT=3 rtk_run exitcode pytest
[ "$_WX_RUN_EXIT" -eq 3 ] || fail 'exit code 3 was not returned'
[ "$(cat "$(dirname "$(rtk_last | jq -r '.stdout.path')")/exit_code.raw")" = 3 ] || fail 'exit_code.raw does not hold the exit code of a failing run'
rtk_run exitcode-ok pytest
[ "$(cat "$(dirname "$(rtk_last | jq -r '.stdout.path')")/exit_code.raw")" = 0 ] || fail 'exit_code.raw does not hold 0 after a successful run'
# Kill wx while RTK is running. The raw output and the exit code must already be on disk. No session record exists yet.
_WX_KILL_DIR="$_WX_TEST_ROOT/kill-proj"
mkdir -p "$_WX_KILL_DIR"
export FAKE_RTK_LOG="$_WX_TEST_ROOT/rtk-kill.log" FAKE_RTK_RAW_LOG="$_WX_TEST_ROOT/rtk-kill.raw.log" FAKE_RTK_MODE=hang AICONTEXT_RTK_TIMEOUT=60
: > "$FAKE_RTK_LOG"
: > "$FAKE_RTK_RAW_LOG"
setsid bash -c 'cd "$1" && wx pytest >/dev/null 2>&1' _ "$_WX_KILL_DIR" &
_WX_KILL_PID=$!
for _WX_WAIT in $(seq 1 60); do
  grep -q '^pipe ' "$FAKE_RTK_LOG" 2>/dev/null && break
  sleep 0.2
done
grep -q '^pipe ' "$FAKE_RTK_LOG" || fail 'the kill test never reached the RTK step'
kill -9 -- "-$_WX_KILL_PID" 2>/dev/null
wait "$_WX_KILL_PID" 2>/dev/null
unset FAKE_RTK_LOG FAKE_RTK_RAW_LOG FAKE_RTK_MODE AICONTEXT_RTK_TIMEOUT
_WX_KILL_RUN="$(ls -d "$_WX_KILL_DIR"/.ai-context/raw/*/ | head -n 1)"
[ "$(cat "${_WX_KILL_RUN}exit_code.raw")" = 0 ] || fail 'exit_code.raw is missing after wx was killed during RTK'
cmp -s "${_WX_KILL_RUN}stdout.raw" "$_WX_TEST_ROOT/direct.pytest.out" || fail 'stdout.raw is incomplete after wx was killed during RTK'
[ ! -s "$_WX_KILL_DIR/.ai-context/session.jsonl" ] || fail 'a session record exists for a run that was killed'
grep -q '^stdin=\([0-9]*\) raw=\1 exit=0$' "$_WX_TEST_ROOT/rtk-kill.raw.log" || fail "RTK did not see the raw output and the exit code: $(cat "$_WX_TEST_ROOT/rtk-kill.raw.log")"

# 3i. No path runs RTK except "rtk --version" and "rtk pipe -f". There is no re-run or direct path.
# The resolved RTK path appears in a check (-x), the version call, and the pipe call. Nothing else.
_WX_RTK_USES="$(grep -n '"\$_WX_RESOLVED"' "$_WX_REPOSITORY_ROOT/scripts/lib/wx-compress.sh" | grep -v -e '-x "\$_WX_RESOLVED"')"
[ "$(printf '%s\n' "$_WX_RTK_USES" | grep -c .)" -eq 2 ] || fail "wx-compress.sh runs RTK in more than the two known places: $_WX_RTK_USES"
printf '%s\n' "$_WX_RTK_USES" | grep -q -e '--version' || fail 'the version call is missing from the RTK uses'
printf '%s\n' "$_WX_RTK_USES" | grep -q 'pipe -f' || fail 'the pipe call is missing from the RTK uses'
if grep -n '_WX_RESOLVED\|_WX_BIN' "$_WX_REPOSITORY_ROOT/scripts/lib/wx.sh" "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" | grep -q .; then fail 'RTK is run outside wx-compress.sh'; fi

# 3j. Recorded outputs of the six enabled filters, replayed through wx (tests/fixtures/rtk, see PROVENANCE.txt).
# The fake RTK keeps lines that start with warning/error/panic and the last line. The real-RTK block follows.
_WX_RTK_FIX="$_WX_REPOSITORY_ROOT/tests/fixtures/rtk"
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >/dev/null 2>&1
_WX_FIXTURE_TABLE='cargo-test/pass-noisy accepted
cargo-test/pass-nocapture guard
cargo-test/fail nonzero
go-test/pass-noisy guard
go-test/pass-quiet smaller
go-test/pass-json guard
go-test/bench accepted
go-test/fail nonzero
go-test/build-error nonzero
go-build/verbose empty
go-build/quiet empty
go-build/fail nonzero
pytest/pass-noisy accepted
pytest/pass-warnings guard
pytest/collect-only accepted
pytest/fail nonzero
tsc/pass-noisy accepted
tsc/pass-listfiles accepted
tsc/showconfig accepted
tsc/pass-quiet empty
tsc/fail nonzero
vitest/pass-default accepted
vitest/pass-verbose accepted
vitest/pass-warn accepted
vitest/fail nonzero'
# Every fixture folder is in the table, and every filter has at least a success, a warning-like or failing case.
_WX_FOUND="$(cd "$_WX_RTK_FIX" && ls -d */*/ | sed 's#/$##' | sort)"
_WX_LISTED="$(printf '%s\n' "$_WX_FIXTURE_TABLE" | cut -d' ' -f1 | sort)"
[ "$_WX_FOUND" = "$_WX_LISTED" ] || fail "fixture folders and the test table differ: $(diff <(printf '%s\n' "$_WX_FOUND") <(printf '%s\n' "$_WX_LISTED") | head -4)"
for _WX_F in cargo-test go-test go-build pytest tsc vitest; do
  printf '%s\n' "$_WX_FOUND" | grep -q "^$_WX_F/" || fail "no fixture for $_WX_F"
  jq -e --arg f "$_WX_F" '[.command_policy.rtk_commands[] | select(.class == "pipe" and .filter == $f)] | length == 1' "$AICONTEXT_SETTINGS_FILE" >/dev/null || fail "$_WX_F is not an enabled pipe filter in the config"
done

fixture_case() { # filter case outcome. Replays the recorded command through wx with the fake RTK and checks everything.
  local _WX_FF="$1" _WX_FC="$2" _WX_FW="$3"
  local _WX_FD="$_WX_RTK_FIX/$_WX_FF/$_WX_FC"
  local -a _WX_FARGV
  local _WX_FCODE _WX_FRUNLOG _WX_FREC _WX_FRUNDIR _WX_FNAME _WX_FWXERR _WX_FCALLS _WX_FSTDERR
  read -r -a _WX_FARGV < "$_WX_FD/cmd"
  _WX_FCODE="$(cat "$_WX_FD/exit")"
  _WX_FNAME="fx-$_WX_FF-$_WX_FC"
  _WX_FRUNLOG="$_WX_TEST_ROOT/$_WX_FNAME.runlog"
  : > "$_WX_FRUNLOG"
  FIXTURE_CASE="$_WX_FF/$_WX_FC" FIXTURE_RUN_LOG="$_WX_FRUNLOG" rtk_run "$_WX_FNAME" "${_WX_FARGV[@]}"
  _WX_FWXERR="$_WX_TEST_ROOT/rtk-$_WX_FNAME.stderr"
  _WX_FCALLS="$_WX_TEST_ROOT/rtk-$_WX_FNAME.log"
  _WX_FSTDERR="$_WX_FD/stderr"
  [ -f "$_WX_FSTDERR" ] || _WX_FSTDERR=/dev/null
  # 1. The original command ran once, with the recorded arguments, and wx returned its exit code.
  [ "$(wc -l < "$_WX_FRUNLOG")" -eq 1 ] && [ "$(cat "$_WX_FRUNLOG")" = "${_WX_FARGV[*]}" ] || fail "$_WX_FNAME: the command did not run exactly once: $(cat "$_WX_FRUNLOG")"
  [ "$_WX_RUN_EXIT" -eq "$_WX_FCODE" ] || fail "$_WX_FNAME: exit code $_WX_RUN_EXIT, expected $_WX_FCODE"
  # 2. Raw files: stdout.raw, stderr.raw, and exit_code.raw hold the original output.
  _WX_FREC="$(rtk_last)"
  _WX_FRUNDIR="$(dirname "$(jq -r '.stdout.path' <<< "$_WX_FREC")")"
  cmp -s "$_WX_FRUNDIR/stdout.raw" "$_WX_FD/stdout" || fail "$_WX_FNAME: stdout.raw differs from the recorded stdout"
  cmp -s "$_WX_FRUNDIR/stderr.raw" "$_WX_FSTDERR" || fail "$_WX_FNAME: stderr.raw differs from the recorded stderr"
  [ "$(cat "$_WX_FRUNDIR/exit_code.raw")" = "$_WX_FCODE" ] || fail "$_WX_FNAME: exit_code.raw is wrong"
  # 3. stderr is shown as it was: the recorded stderr plus the raw-log pointer line.
  sed '$d' "$_WX_FWXERR" | cmp -s - "$_WX_FSTDERR" || fail "$_WX_FNAME: visible stderr is not the recorded stderr plus the pointer"
  tail -n 1 "$_WX_FWXERR" | grep -q '^\[wx\] raw logs: ' || fail "$_WX_FNAME: the raw-log pointer line is missing"
  # go build writes only to stderr, so the go-build filter never gets any input through wx.
  if [ "$_WX_FF" = go-build ]; then
    jq -e '.raw.stdout_bytes == 0' <<< "$_WX_FREC" >/dev/null || fail "$_WX_FNAME: go build wrote to stdout: $_WX_FREC"
  fi
  # 4. Record fields that hold for every outcome.
  jq -e --arg f "$_WX_FF" --argjson c "$_WX_FCODE" --argjson ob "$(wc -c < "$_WX_FD/stdout")" --argjson eb "$(wc -c < "$_WX_FSTDERR")" '
    .rtk_class == "pipe" and .exit_code == $c and .raw.stdout_bytes == $ob and .raw.stderr_bytes == $eb and .visible.stderr_bytes == $eb
  ' <<< "$_WX_FREC" >/dev/null || fail "$_WX_FNAME: record fields are wrong: $_WX_FREC"
  # 5. RTK is called only as: --version, then pipe -f <filter>, and only when it can apply.
  case "$_WX_FW" in
    accepted|guard|smaller)
      [ "$(cat "$_WX_FCALLS")" = "$(printf -- '--version\npipe -f %s' "$_WX_FF")" ] || fail "$_WX_FNAME: unexpected RTK calls: $(cat "$_WX_FCALLS")"
      grep -Eq "^stdin=([0-9]+) raw=\1 exit=$_WX_FCODE\$" "$_WX_TEST_ROOT/rtk-$_WX_FNAME.raw.log" || fail "$_WX_FNAME: raw output and exit code were not on disk when RTK ran: $(cat "$_WX_TEST_ROOT/rtk-$_WX_FNAME.raw.log")"
      ;;
    *)
      [ ! -s "$_WX_FCALLS" ] || fail "$_WX_FNAME: RTK was called ($(cat "$_WX_FCALLS")) but should not be"
      ;;
  esac
  # 6. Outcome.
  case "$_WX_FW" in
    accepted)
      jq -e --arg f "$_WX_FF" '.output_policy == "compress-rtk-v1" and .compressor == "rtk" and .compressor_version == "9.9.9" and .filter == $f and .fallback_reason == null and .visible.stdout_bytes < .raw.stdout_bytes' <<< "$_WX_FREC" >/dev/null || fail "$_WX_FNAME: not accepted: $_WX_FREC"
      grep -Fq "[fake-rtk:$_WX_FF]" "$_WX_TEST_ROOT/rtk-$_WX_FNAME.stdout" || fail "$_WX_FNAME: the RTK output is not shown"
      _wx_evidence_guard "$_WX_FD/stdout" "$_WX_TEST_ROOT/rtk-$_WX_FNAME.stdout" || fail "$_WX_FNAME: accepted output does not pass the evidence guard"
      ;;
    guard)
      jq -e --arg f "$_WX_FF" '.output_policy == "raw-rtk-fallback" and .compressor == null and .fallback_reason == "evidence-guard" and .filter == $f and .visible.stdout_bytes == .raw.stdout_bytes' <<< "$_WX_FREC" >/dev/null || fail "$_WX_FNAME: guard fallback record is wrong: $_WX_FREC"
      cmp -s "$_WX_TEST_ROOT/rtk-$_WX_FNAME.stdout" "$_WX_FD/stdout" || fail "$_WX_FNAME: raw output was not shown after the guard failed"
      [ -f "$_WX_FRUNDIR/rtk.rejected.stdout" ] || fail "$_WX_FNAME: the rejected RTK output was not kept"
      if _wx_evidence_guard "$_WX_FD/stdout" "$_WX_FRUNDIR/rtk.rejected.stdout"; then fail "$_WX_FNAME: the rejected output passes the guard"; fi
      ;;
    smaller)
      jq -e --arg f "$_WX_FF" '.output_policy == "raw-rtk-fallback" and .compressor == null and .fallback_reason == "rtk-not-smaller" and .filter == $f and .visible.stdout_bytes == .raw.stdout_bytes' <<< "$_WX_FREC" >/dev/null || fail "$_WX_FNAME: not-smaller record is wrong: $_WX_FREC"
      cmp -s "$_WX_TEST_ROOT/rtk-$_WX_FNAME.stdout" "$_WX_FD/stdout" || fail "$_WX_FNAME: raw output was not shown when RTK was not smaller"
      [ "$(wc -c < "$_WX_FRUNDIR/rtk.rejected.stdout")" -ge "$(wc -c < "$_WX_FD/stdout")" ] || fail "$_WX_FNAME: the rejected output was smaller than raw"
      ;;
    nonzero)
      jq -e '.output_policy == "raw-nonzero-exit" and .compressor == null and .filter == null and .fallback_reason == null and .visible.stdout_bytes == .raw.stdout_bytes' <<< "$_WX_FREC" >/dev/null || fail "$_WX_FNAME: failing-run record is wrong: $_WX_FREC"
      cmp -s "$_WX_TEST_ROOT/rtk-$_WX_FNAME.stdout" "$_WX_FD/stdout" || fail "$_WX_FNAME: failing output was changed"
      ;;
    empty)
      jq -e '.output_policy == "raw-empty-or-binary-output" and .compressor == null and .filter == null and .fallback_reason == null and .raw.stdout_bytes == 0' <<< "$_WX_FREC" >/dev/null || fail "$_WX_FNAME: empty-stdout record is wrong: $_WX_FREC"
      ;;
    *) fail "$_WX_FNAME: unknown outcome $_WX_FW" ;;
  esac
}
while read -r _WX_FCASE _WX_FWANT; do
  fixture_case "${_WX_FCASE%%/*}" "${_WX_FCASE#*/}" "$_WX_FWANT"
done <<< "$_WX_FIXTURE_TABLE"
# The warning in vitest stays visible: it is on stderr, so RTK never sees it.
assert_file_contains "$_WX_TEST_ROOT/rtk-fx-vitest-pass-warn.stderr" 'Warning: cache is cold, results may be slow'

# 3k. Real RTK on the same recordings. A missing RTK is a SKIP. A spy script logs every call and runs the real RTK.
_WX_REAL_RTK_FX="$(PATH="${PATH#"$_WX_FIXTURES:"}" command -v rtk 2>/dev/null || true)"
if [ -n "$_WX_REAL_RTK_FX" ] && [ "$_WX_REAL_RTK_FX" != "$_WX_FIXTURES/rtk" ]; then
  _WX_SPY="$_WX_TEST_ROOT/spy-rtk"
  printf '#!/usr/bin/env bash\nprintf "%%s\\n" "$*" >> "$SPY_LOG"\nexec "%s" "$@"\n' "$_WX_REAL_RTK_FX" > "$_WX_SPY"
  chmod +x "$_WX_SPY"
  _WX_REAL_VERSION="$("$_WX_REAL_RTK_FX" --version 2>/dev/null | head -n 1)"
  # Pinned outcomes for RTK 0.42.4. Cases where real RTK gives a wrong or lossy summary are warned about, not pinned.
  _WX_PINNED='cargo-test/pass-noisy accepted
cargo-test/pass-nocapture guard
go-test/pass-noisy guard
go-test/pass-json guard
pytest/pass-noisy accepted
pytest/pass-warnings guard
tsc/pass-noisy accepted
vitest/pass-default accepted
vitest/pass-verbose accepted
vitest/pass-warn accepted'
  _WX_REAL_COUNT=0
  real_case() { # case, outcome from the fake table (accepted, guard, smaller, empty)
    local _WX_RC="$1" _WX_RW="$2" _WX_RF="${1%%/*}" _WX_RD _WX_RLOG _WX_RREC _WX_RRUN _WX_REXIT _WX_RPIN _WX_RRES
    local -a _WX_RARGV
    _WX_RD="$_WX_RTK_FIX/$_WX_RC"
    read -r -a _WX_RARGV < "$_WX_RD/cmd"
    _WX_RLOG="$_WX_TEST_ROOT/real-${_WX_RC//\//-}.spy"
    : > "$_WX_RLOG"
    SPY_LOG="$_WX_RLOG" AICONTEXT_RTK_BIN="$_WX_SPY" FIXTURE_CASE="$_WX_RC" FIXTURE_RUN_LOG="$_WX_TEST_ROOT/real-run.log" \
      wx "${_WX_RARGV[@]}" >"$_WX_TEST_ROOT/real-out" 2>"$_WX_TEST_ROOT/real-err"
    _WX_REXIT=$?
    _WX_RREC="$(jq -c -s '.[-1]' .ai-context/session.jsonl)"
    _WX_RRUN="$(dirname "$(jq -r '.stdout.path' <<< "$_WX_RREC")")"
    [ "$_WX_REXIT" -eq 0 ] || fail "real RTK $_WX_RC: exit code $_WX_REXIT"
    cmp -s "$_WX_RRUN/stdout.raw" "$_WX_RD/stdout" || fail "real RTK $_WX_RC: stdout.raw differs from the recording"
    [ "$(cat "$_WX_RRUN/exit_code.raw")" = 0 ] || fail "real RTK $_WX_RC: exit_code.raw is wrong"
    if [ -f "$_WX_RD/stderr" ]; then cmp -s "$_WX_RRUN/stderr.raw" "$_WX_RD/stderr" || fail "real RTK $_WX_RC: stderr.raw differs"; fi
    jq -e '.rtk_class == "pipe"' <<< "$_WX_RREC" >/dev/null || fail "real RTK $_WX_RC: wrong class"
    if [ "$_WX_RW" = empty ]; then
      [ ! -s "$_WX_RLOG" ] || fail "real RTK $_WX_RC: RTK was called for empty stdout: $(cat "$_WX_RLOG")"
      printf 'NOTE: real RTK %s: no stdout, RTK not called\n' "$_WX_RC"
    else
      [ "$(cat "$_WX_RLOG")" = "$(printf -- '--version\npipe -f %s' "$_WX_RF")" ] || fail "real RTK $_WX_RC: unexpected RTK calls: $(cat "$_WX_RLOG")"
      # Either the real RTK output is shown (smaller, guard passes), or raw is shown with a valid reason.
      if jq -e '.compressor == "rtk"' <<< "$_WX_RREC" >/dev/null; then
        jq -e '.output_policy == "compress-rtk-v1" and .compressor_version != null and .fallback_reason == null and .visible.stdout_bytes < .raw.stdout_bytes' <<< "$_WX_RREC" >/dev/null || fail "real RTK $_WX_RC: accepted record is inconsistent: $_WX_RREC"
        _wx_evidence_guard "$_WX_RD/stdout" "$_WX_TEST_ROOT/real-out" || fail "real RTK $_WX_RC: accepted output fails the evidence guard"
        _WX_RRES=accepted
      else
        jq -e '.output_policy == "raw-rtk-fallback" and .compressor == null and (.fallback_reason | IN("evidence-guard", "rtk-not-smaller", "rtk-empty-output", "rtk-nonzero-exit", "rtk-timeout")) and .visible.stdout_bytes == .raw.stdout_bytes' <<< "$_WX_RREC" >/dev/null || fail "real RTK $_WX_RC: fallback record is inconsistent: $_WX_RREC"
        cmp -s "$_WX_TEST_ROOT/real-out" "$_WX_RD/stdout" || fail "real RTK $_WX_RC: raw output was not shown after a fallback"
        _WX_RRES="$(jq -r '.fallback_reason' <<< "$_WX_RREC")"
        [ "$_WX_RRES" = evidence-guard ] && _WX_RRES=guard
      fi
      _WX_RPIN="$(printf '%s\n' "$_WX_PINNED" | awk -v c="$_WX_RC" '$1 == c { print $2 }')"
      case "$_WX_REAL_VERSION" in
        *0.42.4*)
          if [ -n "$_WX_RPIN" ]; then
            [ "$_WX_RRES" = "$_WX_RPIN" ] || fail "real RTK $_WX_RC: expected $_WX_RPIN, got $_WX_RRES"
          elif [ "$_WX_RRES" = accepted ]; then
            printf 'WARN: real RTK %s accepted %s: %s raw bytes became %s bytes: "%s"\n' "$_WX_REAL_VERSION" "$_WX_RC" "$(jq -r '.raw.stdout_bytes' <<< "$_WX_RREC")" "$(jq -r '.visible.stdout_bytes' <<< "$_WX_RREC")" "$(head -n 1 "$_WX_TEST_ROOT/real-out" | cut -c1-60)"
          fi
          ;;
        *) printf 'NOTE: real RTK %s on %s: %s (outcomes are pinned for 0.42.4 only)\n' "$_WX_REAL_VERSION" "$_WX_RC" "$_WX_RRES" ;;
      esac
    fi
    _WX_REAL_COUNT=$((_WX_REAL_COUNT + 1))
  }
  # Every success case and every empty-stdout case. Failing cases never reach RTK, so they are not repeated here.
  while read -r _WX_RCASE _WX_RWANT; do
    case "$_WX_RWANT" in accepted|guard|smaller|empty) real_case "$_WX_RCASE" "$_WX_RWANT" ;; esac
  done <<< "$_WX_FIXTURE_TABLE"
  for _WX_F in cargo-test go-test go-build pytest tsc vitest; do
    printf '%s\n' "$_WX_FIXTURE_TABLE" | grep -q "^$_WX_F/" || fail "no real-RTK check for $_WX_F"
  done
  printf 'NOTE: real RTK %s checked on %s recorded runs (cargo-test, go-test, go-build, pytest, tsc, vitest)\n' "$_WX_REAL_VERSION" "$_WX_REAL_COUNT"
else
  printf 'SKIP: real RTK is not installed. The 6 real-RTK filter checks were skipped. The fake RTK matrix ran.\n'
fi
source "$_WX_REPOSITORY_ROOT/scripts/workflow.sh" code >/dev/null 2>&1

# 5. Token Controller never runs "rtk init" (or anything except --version and pipe -f <mapped filter>).
if grep -Ev '^(--version|pipe -f (cargo-test|pytest|go-test|go-build|tsc|vitest))$' "$_WX_RTK_ALL_LOG" | grep -q .; then
  fail "unexpected RTK call: $(grep -Ev '^(--version|pipe -f (cargo-test|pytest|go-test|go-build|tsc|vitest))$' "$_WX_RTK_ALL_LOG" | head -3)"
fi
grep -q 'init' "$_WX_RTK_ALL_LOG" && fail 'rtk init was called'
# Static scan: no script runs "rtk init". The only matches outside comments and messages are in the text that
# install-optional-tools.sh prints, and those lines are commented out there.
_WX_INIT_LINES="$(grep -rn 'rtk[[:space:]]\{1,\}init' "$_WX_REPOSITORY_ROOT/scripts" | grep -v 'install-optional-tools.sh' || true)"
if [ -n "$_WX_INIT_LINES" ]; then
  _WX_BAD_INIT="$(printf '%s\n' "$_WX_INIT_LINES" | grep -Ev '^[^:]+:[0-9]+:[[:space:]]*#|never runs|does not run|Never "rtk init"|Doctor never' || true)"
  [ -z "$_WX_BAD_INIT" ] || fail "a script mentions rtk init outside a comment or a 'does not run' message: $_WX_BAD_INIT"
fi
_WX_INSTALL_INIT="$(grep -n 'rtk[[:space:]]\{1,\}init' "$_WX_REPOSITORY_ROOT/scripts/install-optional-tools.sh" || true)"
if [ -n "$_WX_INSTALL_INIT" ]; then
  printf '%s\n' "$_WX_INSTALL_INIT" | grep -Ev '^[0-9]+:[[:space:]]*#' | grep -q . && fail 'install-optional-tools.sh has an uncommented rtk init line'
fi
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
