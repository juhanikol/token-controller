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
printf 'Real lean-ctx: %s. Version: %s.\n' "$_LT_REAL_RESULT" "$_LT_REAL_VERSION"
for _LT_W in "${_LT_WARNINGS[@]:-}"; do
  [ -n "$_LT_W" ] && printf 'WARN: %s\n' "$_LT_W"
done
printf 'PASS: leanctx tests\n'
