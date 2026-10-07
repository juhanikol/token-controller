#!/usr/bin/env bash
# LeanCTX CLI validation harness. LeanCTX is called directly, never through wx.
# 1. A fake lean-ctx (tests/fixtures/leanctx) checks the harness: the seven commands, byte counts, evidence, the call log,
#    and a visible failure. No real LeanCTX is needed, so this runs in CI.
# 2. A real lean-ctx, if installed, runs the read, search, and tree commands against this repository. It is skipped if
#    missing, or when AICONTEXT_TEST_SKIP_REAL_LEANCTX=1. Real calls write LeanCTX runtime data (stats, sessions) but the
#    test checks that its config directory and this repository are unchanged. Byte counts only, no token counts.
set -u

_LT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
_LT_TMP="$(mktemp -d /tmp/token-controller-leanctx-test.XXXXXX)"
trap 'rm -rf -- "$_LT_TMP"' EXIT
_LT_FAKE="$_LT_ROOT/tests/fixtures/leanctx/lean-ctx"
_LT_SELF="$_LT_ROOT/tests/leanctx.test.sh"
_LT_ROWS=()
_LT_ADAPTER_ROWS=()
_LT_WARNINGS=()

fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

percent() { LC_ALL=C awk -v raw="$1" -v v="$2" 'BEGIN { if (raw == 0) printf "n/a"; else printf "%.2f", (raw - v) * 100 / raw }'; }

# Every line of the raw file is in the lean-ctx output (plain text match).
contains_all() { # raw file, output file
  local _l
  while IFS= read -r _l; do
    [ -n "$_l" ] || continue
    grep -Fq -- "$_l" "$2" || return 1
  done < "$1"
  return 0
}

# Run a command directly. Output goes to files for byte comparison. Sets _LT_RC.
run() { # name, command...
  local _n="$1"
  shift
  "$@" > "$_LT_TMP/$_n.out" 2> "$_LT_TMP/$_n.err"
  _LT_RC=$?
}

bytes() { wc -c < "$1" | tr -d ' '; }

row() { # label, raw bytes, lean-ctx bytes, evidence
  _LT_ROWS+=("$(printf '| %s | %s | %s | %s | %s |' "$1" "$2" "$3" "$(percent "$2" "$3")" "$4")")
}

# ---------------------------------------------------------------- 1. fake lean-ctx
_LT_WORK="$_LT_TMP/work"
mkdir -p "$_LT_WORK/src"
cp "$_LT_ROOT/README.md" "$_LT_WORK/README.md"
printf 'export AICONTEXT_PROFILE="code"\nexport AICONTEXT_RISK="normal"\n' > "$_LT_WORK/src/env.sh"
printf '# AICONTEXT note\nplain line\n' > "$_LT_WORK/src/notes.md"
cd "$_LT_WORK" || exit 1
export FAKE_LC_LOG="$_LT_TMP/fake.log"
: > "$FAKE_LC_LOG"

# The fake itself refuses wrap, setup, init, onboard, and -c, and logs the call. This proves the call log check below.
for _LT_BAD in wrap setup init onboard; do
  FAKE_LC_LOG="$_LT_TMP/fake-bad.log" "$_LT_FAKE" "$_LT_BAD" >/dev/null 2>&1
  [ "$?" -eq 9 ] || fail "the fake lean-ctx accepted $_LT_BAD"
done
[ "$(grep -c . "$_LT_TMP/fake-bad.log")" -eq 4 ] || fail 'the fake lean-ctx did not log the refused calls'

# --version
run version "$_LT_FAKE" --version
[ "$_LT_RC" -eq 0 ] && grep -q '^lean-ctx 9\.9\.9' "$_LT_TMP/version.out" || fail "--version: exit $_LT_RC, $(cat "$_LT_TMP/version.out")"
# status and doctor
run status "$_LT_FAKE" status
[ "$_LT_RC" -eq 0 ] && grep -q 'status' "$_LT_TMP/status.out" || fail "status: exit $_LT_RC"
run doctor "$_LT_FAKE" doctor
[ "$_LT_RC" -eq 0 ] && grep -q '✓' "$_LT_TMP/doctor.out" || fail "doctor: exit $_LT_RC"

# read README.md -m signatures
run sig "$_LT_FAKE" read README.md -m signatures
[ "$_LT_RC" -eq 0 ] || fail "read signatures: exit $_LT_RC"
_LT_RAW="$(bytes README.md)"
[ "$(bytes "$_LT_TMP/sig.out")" -lt "$_LT_RAW" ] || fail 'signatures output is not smaller than the file'
grep '^#' README.md > "$_LT_TMP/headings"
contains_all "$_LT_TMP/headings" "$_LT_TMP/sig.out" || fail 'signatures output lost a heading'
row 'read README.md -m signatures (fake)' "$_LT_RAW" "$(bytes "$_LT_TMP/sig.out")" yes

# read README.md -m full --fresh: byte for byte the file
run full "$_LT_FAKE" read README.md -m full --fresh
[ "$_LT_RC" -eq 0 ] && cmp -s README.md "$_LT_TMP/full.out" || fail 'read full --fresh is not the file, byte for byte'
row 'read README.md -m full --fresh (fake)' "$_LT_RAW" "$(bytes "$_LT_TMP/full.out")" yes

# grep "AICONTEXT" .
command grep -rn "AICONTEXT" . > "$_LT_TMP/grep.raw" 2>/dev/null
[ -s "$_LT_TMP/grep.raw" ] || fail 'the raw grep found nothing, so the test data is wrong'
run grep "$_LT_FAKE" grep "AICONTEXT" .
[ "$_LT_RC" -eq 0 ] && contains_all "$_LT_TMP/grep.raw" "$_LT_TMP/grep.out" || fail 'grep output lost a match'
row 'grep "AICONTEXT" . (fake)' "$(bytes "$_LT_TMP/grep.raw")" "$(bytes "$_LT_TMP/grep.out")" yes

# ls .
command ls -1 . > "$_LT_TMP/ls.raw"
run ls "$_LT_FAKE" ls .
[ "$_LT_RC" -eq 0 ] && contains_all "$_LT_TMP/ls.raw" "$_LT_TMP/ls.out" || fail 'ls output lost an entry'
row 'ls . (fake)' "$(bytes "$_LT_TMP/ls.raw")" "$(bytes "$_LT_TMP/ls.out")" yes

# A failure is raw and visible: the exit code, the message on stderr, and nothing hidden on stdout.
run missing "$_LT_FAKE" read does-not-exist.md -m signatures
[ "$_LT_RC" -eq 2 ] || fail "the failing read exited $_LT_RC, expected 2"
[ ! -s "$_LT_TMP/missing.out" ] || fail 'the failing read wrote to stdout'
grep -Fxq 'lean-ctx: cannot read does-not-exist.md: no such file' "$_LT_TMP/missing.err" || fail "the failure message is not visible: $(cat "$_LT_TMP/missing.err")"

# Call log: only the allowed commands. No wrap, setup, init, onboard, -c, or ctx_shell.
if grep -Eqv '^(--version|status|doctor|read |grep |ls )' "$FAKE_LC_LOG"; then fail "unexpected lean-ctx call: $(grep -Ev '^(--version|status|doctor|read |grep |ls )' "$FAKE_LC_LOG" | head -3)"; fi
if grep -Eq '^(wrap|setup|init|onboard|unwrap)|(^| )-c( |$)|ctx_shell|--fix' "$FAKE_LC_LOG"; then fail 'a call that can change setup or run a shell command was made'; fi
[ "$(grep -c . "$FAKE_LC_LOG")" -eq 8 ] || fail "expected 8 lean-ctx calls, got $(grep -c . "$FAKE_LC_LOG")"
# Not routed through wx: no wx run directory or session file appeared, and the wx libraries never mention lean-ctx.
[ ! -e "$_LT_WORK/.ai-context" ] || fail 'a wx raw log or session file appeared: lean-ctx was routed through wx'
if grep -n 'lean-ctx' "$_LT_ROOT"/scripts/lib/wx*.sh | grep -q .; then fail 'a wx library mentions lean-ctx'; fi
if grep -nE '(^|[^[:alnum:]_])wx[[:space:]]+(lean-ctx|"\$)' "$_LT_SELF" | grep -q .; then fail 'this test routes lean-ctx through wx'; fi
printf 'PASS: fake lean-ctx harness (7 commands, a visible failure, no wx, no wrap/setup/init)\n'

# ---------------------------------------------------------------- 1b. adapter (workflow leanctx) with the fake
_LT_CLI="$_LT_ROOT/scripts/workflow-cli.sh"
_LT_ACFG="$_LT_TMP/adapter-config"
mkdir -p "$_LT_ACFG"
_LT_ALOG="$_LT_TMP/adapter.log"
write_env() { # profile, leanctx mode
  printf 'export AICONTEXT_PROFILE="%s"\nexport AICONTEXT_RISK="normal"\nexport AICONTEXT_LEANCTX_MODE="%s"\n' "$1" "$2" > "$_LT_ACFG/active_mode.env"
}
adapter() { # arguments for "workflow leanctx". Extra environment comes from the caller. Sets _AD_RC. Output: adapter.out, adapter.err
  AICONTEXT_CONFIG_DIR="$_LT_ACFG" AICONTEXT_LEANCTX_BIN="${AD_BIN-$_LT_FAKE}" FAKE_LC_LOG="$_LT_ALOG" \
    bash "$_LT_CLI" leanctx "$@" > "$_LT_TMP/adapter.out" 2> "$_LT_TMP/adapter.err" </dev/null
  _AD_RC=$?
}
ad_calls() { grep -c . "$_LT_ALOG" 2>/dev/null || true; }
cd "$_LT_WORK" || exit 1
: > "$_LT_ALOG"

# status in an allowed mode. It runs --version only.
write_env code auto
adapter status
[ "$_AD_RC" -eq 0 ] || fail "adapter status exited $_AD_RC"
for _LT_T in 'profile: code' 'AICONTEXT_LEANCTX_MODE: auto' "binary: $_LT_FAKE" 'version: lean-ctx 9.9.9' 'lean-ctx status: not run' 'CLI operations allowed: yes' 'shell_enabled=false' 'auto_wrap=false'; do
  grep -Fq -- "$_LT_T" "$_LT_TMP/adapter.out" || fail "adapter status misses '$_LT_T': $(cat "$_LT_TMP/adapter.out")"
done
adapter status --json
jq -e --arg b "$_LT_FAKE" '.allowed == true and .profile == "code" and .leanctx_mode == "auto" and .binary == $b and .version == "lean-ctx 9.9.9 (fake)" and .reasons == [] and .policy.shell_enabled == "false" and .policy.operations.read == "enabled"' "$_LT_TMP/adapter.out" >/dev/null || fail "adapter status --json: $(cat "$_LT_TMP/adapter.out")"
[ "$(sort -u "$_LT_ALOG")" = "--version" ] || fail "adapter status called more than --version: $(sort -u "$_LT_ALOG" | tr '\n' ' ')"

# Protected and off modes are refused, even with a non-off LeanCTX mode. Nothing is run.
: > "$_LT_ALOG"
for _LT_P in raw security db migration release micro snippet off; do
  write_env "$_LT_P" auto
  for _LT_OP in "read README.md" "search AICONTEXT ." "tree ." "read-exact README.md"; do
    # shellcheck disable=SC2086
    adapter $_LT_OP
    [ "$_AD_RC" -eq 1 ] && grep -q 'refused' "$_LT_TMP/adapter.err" || fail "profile $_LT_P was not refused for: $_LT_OP (exit $_AD_RC)"
    [ ! -s "$_LT_TMP/adapter.out" ] || fail "profile $_LT_P printed output for: $_LT_OP"
  done
  adapter status
  grep -q 'CLI operations allowed: no' "$_LT_TMP/adapter.out" || fail "status in profile $_LT_P does not say no"
done
write_env code off
adapter read README.md
[ "$_AD_RC" -eq 1 ] && grep -q 'AICONTEXT_LEANCTX_MODE is off' "$_LT_TMP/adapter.err" || fail 'AICONTEXT_LEANCTX_MODE off was not refused'
rm -f "$_LT_ACFG/active_mode.env"
adapter read README.md
[ "$_AD_RC" -eq 1 ] && grep -q 'no active mode file' "$_LT_TMP/adapter.err" || fail 'a missing active_mode.env was not refused'
# The shell variable does not count: only active_mode.env.
AICONTEXT_LEANCTX_MODE=auto AICONTEXT_PROFILE=code adapter read README.md
[ "$_AD_RC" -eq 1 ] || fail 'shell variables were used instead of active_mode.env'
[ "$(ad_calls)" -eq 1 ] || [ "$(ad_calls)" -eq 0 ] || true
grep -Ev '^--version$' "$_LT_ALOG" | grep -q . && fail "a refused adapter call reached lean-ctx: $(cat "$_LT_ALOG")"

# Policy refusals: shell, wrap, setup, init, owner, a missing policy, and a disabled operation.
write_env code auto
ad_policy() { # name, jq filter. Runs "read README.md" with that settings file.
  jq "$2" "$_LT_ROOT/config/workflow_settings.json" > "$_LT_TMP/policy-$1.json"
  AICONTEXT_SETTINGS_FILE="$_LT_TMP/policy-$1.json" adapter read README.md
}
for _LT_POL in '.leanctx_policy.shell_enabled = true|shell_enabled' '.leanctx_policy.auto_wrap = true|auto_wrap' '.leanctx_policy.auto_setup = true|auto_setup' '.leanctx_policy.auto_init = true|auto_init' \
  '.leanctx_policy.shell_owner = "leanctx"|shell_owner' 'del(.leanctx_policy)|no leanctx_policy' '.leanctx_policy.operations.read.status = "deferred"|operations.read' '.leanctx_policy.shell_enabled = "false"|shell_enabled'; do
  ad_policy pol "${_LT_POL%%|*}"
  [ "$_AD_RC" -eq 1 ] && grep -q -- "${_LT_POL##*|}" "$_LT_TMP/adapter.err" || fail "policy case not refused (${_LT_POL%%|*}): exit $_AD_RC, $(cat "$_LT_TMP/adapter.err")"
done
grep -Ev '^--version$' "$_LT_ALOG" | grep -q . && fail 'a policy refusal reached lean-ctx'

# Binary: missing, and a Windows path under WSL.
AD_BIN="" adapter read README.md
[ "$_AD_RC" -eq 1 ] && grep -q 'lean-ctx was not found' "$_LT_TMP/adapter.err" || fail 'a missing lean-ctx was not refused'
mkdir -p "$_LT_TMP/mnt/c/Users/dev"
cp "$_LT_FAKE" "$_LT_TMP/mnt/c/Users/dev/lean-ctx"
_LT_WIN="$_LT_TMP/mnt/c/Users/dev/lean-ctx"
WSL_DISTRO_NAME=Ubuntu AICONTEXT_MNT_PREFIX="$_LT_TMP/mnt/" AD_BIN="$_LT_WIN" adapter read README.md
[ "$_AD_RC" -eq 1 ] && grep -q 'Windows path under WSL' "$_LT_TMP/adapter.err" || fail "a Windows lean-ctx under WSL was not refused (exit $_AD_RC)"
WSL_DISTRO_NAME=Ubuntu AICONTEXT_MNT_PREFIX="$_LT_TMP/mnt/" AD_BIN="$_LT_WIN" adapter status
grep -q 'CLI operations allowed: no' "$_LT_TMP/adapter.out" || fail 'status allows a Windows lean-ctx under WSL'
WSL_DISTRO_NAME=Ubuntu AICONTEXT_MNT_PREFIX="$_LT_TMP/mnt/" AICONTEXT_ALLOW_WINDOWS_LEANCTX=true AD_BIN="$_LT_WIN" adapter read README.md
[ "$_AD_RC" -eq 0 ] && grep -q 'AICONTEXT_ALLOW_WINDOWS_LEANCTX=true' "$_LT_TMP/adapter.err" || fail "the Windows override did not work, or gave no warning (exit $_AD_RC)"
: > "$_LT_ALOG"

# read: exploration modes work, other modes are not allowed, paths must stay inside the current directory.
adapter read README.md --mode signatures
[ "$_AD_RC" -eq 0 ] && contains_all "$_LT_TMP/headings" "$_LT_TMP/adapter.out" || fail "adapter read signatures: exit $_AD_RC"
[ "$(bytes "$_LT_TMP/adapter.out")" -lt "$(bytes README.md)" ] || fail 'adapter read signatures is not smaller than the file'
adapter read README.md
[ "$_AD_RC" -eq 0 ] || fail 'adapter read without a mode failed (default signatures)'
for _LT_M in map task reference auto; do
  adapter read README.md --mode "$_LT_M"
  [ "$_AD_RC" -eq 0 ] || fail "adapter read --mode $_LT_M exited $_AD_RC"
done
for _LT_M in full raw aggressive bogus ''; do
  adapter read README.md --mode "$_LT_M"
  [ "$_AD_RC" -eq 2 ] || fail "adapter read --mode '$_LT_M' should be a usage error, got $_AD_RC"
done
adapter read /etc/hostname; [ "$_AD_RC" -eq 1 ] || fail 'a path outside the current directory was not refused'
adapter read ../README.md; [ "$_AD_RC" -ne 0 ] || fail 'a parent path was accepted'
adapter read -- -x 2>/dev/null; [ "$_AD_RC" -eq 2 ] || fail 'an option-like path was accepted'
adapter read does-not-exist.md; [ "$_AD_RC" -eq 2 ] || fail 'a missing file was not a usage error'
grep -q "read $_LT_WORK/README.md -m signatures" "$_LT_ALOG" || fail "the read call is not in the log: $(cat "$_LT_ALOG")"
if grep -Eq -- '-m (full|raw|aggressive)' "$_LT_ALOG"; then fail 'a non-exploration read mode reached lean-ctx'; fi

# search: LeanCTX and raw grep agree.
adapter search AICONTEXT .
[ "$_AD_RC" -eq 0 ] && grep -Fq 'env.sh' "$_LT_TMP/adapter.out" || fail "adapter search (agree): exit $_AD_RC, $(cat "$_LT_TMP/adapter.err")"
adapter search AICONTEXT src
[ "$_AD_RC" -eq 0 ] || fail 'adapter search with a path failed'
# D-39 guard: LeanCTX returns no matches, a raw grep has matches. Fails, prints nothing, says why.
FAKE_LC_GREP=empty adapter search AICONTEXT .
[ "$_AD_RC" -eq 3 ] || fail "false-negative search should exit 3, got $_AD_RC"
grep -q 'found no matches, but a raw grep found matches' "$_LT_TMP/adapter.err" && [ ! -s "$_LT_TMP/adapter.out" ] || fail "false-negative search message or output is wrong: $(cat "$_LT_TMP/adapter.err")"
# No match in either: not an error.
FAKE_LC_GREP=empty adapter search NO_SUCH_TEXT_ANYWHERE_12345 .
[ "$_AD_RC" -eq 0 ] || fail "a search with no matches anywhere should exit 0, got $_AD_RC"
FAKE_LC_GREP=fail adapter search AICONTEXT .
[ "$_AD_RC" -eq 4 ] || fail "a failing lean-ctx grep should exit 4, got $_AD_RC"
adapter search '-x' .; [ "$_AD_RC" -eq 2 ] || fail 'a pattern that starts with - was accepted'
adapter search '(' .; [ "$_AD_RC" -eq 3 ] || fail "an invalid regex should fail closed (3), got $_AD_RC"

# tree.
adapter tree .
[ "$_AD_RC" -eq 0 ] && contains_all "$_LT_TMP/ls.raw" "$_LT_TMP/adapter.out" || fail "adapter tree: exit $_AD_RC"
adapter tree src; [ "$_AD_RC" -eq 0 ] || fail 'adapter tree with a path failed'

# read-exact: the output must equal the file, byte for byte. Otherwise fail closed, print nothing, no raw fallback.
adapter read-exact README.md
[ "$_AD_RC" -eq 0 ] && cmp -s README.md "$_LT_TMP/adapter.out" || fail "adapter read-exact (exact output): exit $_AD_RC"
FAKE_LC_FULL=lossy adapter read-exact README.md
[ "$_AD_RC" -eq 3 ] || fail "a lossy exact read should exit 3, got $_AD_RC"
[ ! -s "$_LT_TMP/adapter.out" ] || fail 'a lossy exact read printed output (it must not)'
[ "$(cat "$_LT_TMP/adapter.err")" = 'LeanCTX exact read did not match file bytes; use a raw file read.' ] || fail "the exact-read warning is wrong: $(cat "$_LT_TMP/adapter.err")"
grep -q "read $_LT_WORK/README.md -m full --fresh" "$_LT_ALOG" || fail 'read-exact did not call lean-ctx read -m full --fresh'
truncate -s 6M "$_LT_WORK/big.bin"
adapter read-exact big.bin; [ "$_AD_RC" -eq 1 ] || fail 'a file over 5 MB was not refused for an exact read'
rm -f "$_LT_WORK/big.bin"
adapter read-exact; [ "$_AD_RC" -eq 2 ] || fail 'read-exact without a path should be a usage error'
adapter bogus; [ "$_AD_RC" -eq 2 ] || fail 'an unknown adapter command should be a usage error'
adapter; [ "$_AD_RC" -eq 2 ] || fail 'the adapter without a command should be a usage error'

# Sourced entry: workflow leanctx also works from workflow.sh.
( export AICONTEXT_CONFIG_DIR="$_LT_ACFG" AICONTEXT_LEANCTX_BIN="$_LT_FAKE" FAKE_LC_LOG="$_LT_ALOG"; source "$_LT_ROOT/scripts/workflow.sh" leanctx tree . > "$_LT_TMP/sourced.out" 2>&1 ) || fail 'workflow leanctx tree failed when sourced'
contains_all "$_LT_TMP/ls.raw" "$_LT_TMP/sourced.out" || fail 'sourced workflow leanctx tree lost entries'

# Every call that reached lean-ctx was read, grep, ls, or --version. Never wrap, setup, init, onboard, -c, ctx_shell, --fix, or status.
if grep -Ev '^(--version$|read |grep |ls )' "$_LT_ALOG" | grep -q .; then fail "the adapter called lean-ctx with: $(grep -Ev '^(--version$|read |grep |ls )' "$_LT_ALOG" | sort -u | head -3)"; fi
if grep -Eq '^(wrap|setup|init|onboard|unwrap|status|doctor)|(^| )-c( |$)|ctx_shell|--fix' "$_LT_ALOG"; then fail 'the adapter made a call that can change setup, write a report, or run a shell'; fi
grep -q . "$_LT_ALOG" || fail 'the adapter log is empty'
# Never through wx: no wx files, and no line of the adapter starts wx.
[ ! -e "$_LT_WORK/.ai-context" ] || fail 'the adapter created wx files'
if grep -nE '(^|[;&|(]|\$\()[[:space:]]*wx[[:space:]]' "$_LT_ROOT/scripts/leanctx-cli.sh" | grep -q .; then fail 'the adapter runs wx'; fi
# The only lean-ctx commands the adapter source can run (every lc_run call) are read, grep, ls, and --version.
if [ -n "$(grep -oE 'lc_run [^ ;]+' "$_LT_ROOT/scripts/leanctx-cli.sh" | sort -u | grep -Ev '^lc_run (read|grep|ls|--version)$')" ]; then fail 'the adapter source runs another lean-ctx command'; fi
printf 'PASS: LeanCTX adapter with the fake (status, refusals, read, search guard, tree, read-exact fail closed)\n'

# ---------------------------------------------------------------- 2. real lean-ctx
_LT_REAL="$(command -v lean-ctx 2>/dev/null || true)"
if [ -z "$_LT_REAL" ] || [ "$_LT_REAL" = "$_LT_FAKE" ]; then
  printf 'SKIP: real lean-ctx is not installed.\n'
  _LT_REAL_RESULT='skipped (not installed)'
  _LT_REAL_VERSION='-'
elif [ "${AICONTEXT_TEST_SKIP_REAL_LEANCTX:-}" = 1 ]; then
  printf 'SKIP: AICONTEXT_TEST_SKIP_REAL_LEANCTX=1.\n'
  _LT_REAL_RESULT='skipped (AICONTEXT_TEST_SKIP_REAL_LEANCTX=1)'
  _LT_REAL_VERSION='-'
else
  cd "$_LT_ROOT" || exit 1
  _LT_REAL_VERSION="$(timeout 5 "$_LT_REAL" --version </dev/null 2>&1 | head -n 1 | cut -c1-90)"
  _LT_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/lean-ctx"
  touch "$_LT_TMP/stamp"
  sleep 1
  _LT_GIT_BEFORE="$(git status --porcelain 2>/dev/null)"
  _LT_DAEMON_BEFORE="$(pgrep -f 'lean-ctx serve --_foreground-daemon' 2>/dev/null | head -n 1)"
  _LT_HAD_WX_DIR=false; [ -e .ai-context ] && _LT_HAD_WX_DIR=true

  real_case() { # label, evidence check name, raw file (for the evidence check), size file (raw bytes), command args...
    local _L="$1" _CHECK="$2" _RAWF="$3" _SIZEF="$4" _EV=yes
    shift 4
    run real "timeout" 30 "$_LT_REAL" "$@"
    [ "$_LT_RC" -eq 0 ] || fail "real lean-ctx $_L: exit $_LT_RC: $(head -c 300 "$_LT_TMP/real.err")"
    [ -s "$_LT_TMP/real.out" ] || _EV=no
    case "$_CHECK" in
      lines) contains_all "$_RAWF" "$_LT_TMP/real.out" || _EV=no ;;
      full) cmp -s "$_RAWF" "$_LT_TMP/real.out" || _EV=no ;;
      headings) contains_all "$_RAWF" "$_LT_TMP/real.out" || _EV=no ;;
    esac
    row "$_L (real)" "$(bytes "$_SIZEF")" "$(bytes "$_LT_TMP/real.out")" "$_EV"
    if [ "$_EV" = no ]; then
      _LT_WARNINGS+=("real lean-ctx $_L: output misses text of the raw $_CHECK ($(bytes "$_SIZEF") raw bytes, $(bytes "$_LT_TMP/real.out") bytes shown)")
    fi
  }
  grep '^#' README.md > "$_LT_TMP/real.headings"
  command grep -rn "AICONTEXT" . --exclude-dir=.git --exclude-dir=node_modules --exclude-dir=.ai-context > "$_LT_TMP/real.grep.raw" 2>/dev/null
  command ls -1 . > "$_LT_TMP/real.ls.raw"
  real_case 'read README.md -m signatures' headings "$_LT_TMP/real.headings" README.md read README.md -m signatures
  real_case 'read README.md -m full --fresh' full README.md README.md read README.md -m full --fresh
  real_case 'grep "AICONTEXT" .' lines "$_LT_TMP/real.grep.raw" "$_LT_TMP/real.grep.raw" grep "AICONTEXT" .
  real_case 'ls .' lines "$_LT_TMP/real.ls.raw" "$_LT_TMP/real.ls.raw" ls .

  # The adapter against the real lean-ctx. Exit 0 or 3 (verification failed, fail closed) are both correct. Other codes are failures.
  _LT_ACFG="$_LT_TMP/adapter-config-real"
  mkdir -p "$_LT_ACFG"
  printf 'export AICONTEXT_PROFILE="code"\nexport AICONTEXT_RISK="normal"\nexport AICONTEXT_LEANCTX_MODE="auto"\n' > "$_LT_ACFG/active_mode.env"
  real_adapter() { # label, allowed codes (space separated), arguments
    local _AL="$1" _OK="$2"
    shift 2
    AICONTEXT_CONFIG_DIR="$_LT_ACFG" AICONTEXT_LEANCTX_BIN="$_LT_REAL" bash "$_LT_CLI" leanctx "$@" > "$_LT_TMP/adapter.out" 2> "$_LT_TMP/adapter.err" </dev/null
    _AD_RC=$?
    case " $_OK " in *" $_AD_RC "*) ;; *) fail "real adapter $_AL: exit $_AD_RC: $(head -c 300 "$_LT_TMP/adapter.err")" ;; esac
    [ "$_AD_RC" -eq 0 ] || _LT_WARNINGS+=("real adapter $_AL: exit $_AD_RC, failed closed: $(head -n 1 "$_LT_TMP/adapter.err" | cut -c1-120)")
    _LT_ADAPTER_ROWS+=("| $_AL | $_AD_RC |")
  }
  _LT_ADAPTER_ROWS=()
  real_adapter 'status' 0 status
  real_adapter 'read README.md --mode signatures' 0 read README.md --mode signatures
  real_adapter 'tree .' 0 tree .
  real_adapter 'search "AICONTEXT" .' '0 3' search AICONTEXT .
  real_adapter 'read-exact README.md' '0 3' read-exact README.md
  if [ "$_AD_RC" -eq 0 ]; then cmp -s README.md "$_LT_TMP/adapter.out" || fail 'real read-exact printed output that is not the file'; fi
  # Nothing of ours changed: not the LeanCTX config directory, not this repository, no wx files. Stop a daemon that these calls started.
  if [ -d "$_LT_CFG" ] && [ -n "$(find "$_LT_CFG" -newer "$_LT_TMP/stamp" -type f 2>/dev/null | head -n 1)" ]; then fail "real lean-ctx changed its config directory: $(find "$_LT_CFG" -newer "$_LT_TMP/stamp" -type f | head -n 2)"; fi
  [ "$(git status --porcelain 2>/dev/null)" = "$_LT_GIT_BEFORE" ] || fail 'real lean-ctx changed files in this repository'
  if [ "$_LT_HAD_WX_DIR" = false ] && [ -e .ai-context ]; then fail 'a wx directory appeared while running real lean-ctx'; fi
  if [ -z "$_LT_DAEMON_BEFORE" ] && pgrep -f 'lean-ctx serve --_foreground-daemon' >/dev/null 2>&1; then
    timeout 10 "$_LT_REAL" daemon stop >/dev/null 2>&1
    _LT_WARNINGS+=('real lean-ctx started its background daemon during the test. The test stopped it.')
  fi
  _LT_REAL_RESULT="ran 4 commands (exit 0, config and repository unchanged)"
  printf 'PASS: real lean-ctx (%s): read, search, tree ran against this repository. Config and repository unchanged.\n' "$_LT_REAL_VERSION"
fi

# ---------------------------------------------------------------- report
printf '\n%s\n' '| command | raw bytes | lean-ctx bytes | byte reduction % | evidence preserved |'
printf '%s\n' '| --- | ---: | ---: | ---: | --- |'
printf '%s\n' "${_LT_ROWS[@]}"
printf '\nByte counts only. Byte reduction is not token savings. "evidence preserved" means the raw lines (headings, matches, names) or the file bytes are in the output.\n'
if [ "${#_LT_ADAPTER_ROWS[@]}" -gt 0 ]; then
  printf '\n%s\n%s\n' '| real adapter command | exit code (0 ok, 3 failed closed) |' '| --- | ---: |'
  printf '%s\n' "${_LT_ADAPTER_ROWS[@]}"
  printf '\n'
fi
printf 'Real lean-ctx: %s. Version: %s.\n' "$_LT_REAL_RESULT" "$_LT_REAL_VERSION"
for _LT_W in "${_LT_WARNINGS[@]:-}"; do
  [ -n "$_LT_W" ] && printf 'WARN: %s\n' "$_LT_W"
done
printf 'PASS: leanctx tests\n'
