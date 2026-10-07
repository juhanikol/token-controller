#!/usr/bin/env bash
# Tests for scripts/install-wsl.sh and scripts/show-optional-tools.sh.
# Fake tools on the PATH log every call. The scripts must call no optional tool (only "--version" in check-tools.sh),
# and must run apt only for the basic prerequisites. Nothing real is installed and ~/.bashrc is never touched.
set -u

_T="$(mktemp -d /tmp/token-controller-install-test.XXXXXX)"
_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
trap 'rm -rf -- "$_T"' EXIT
fail() { printf 'FAIL: %s\n' "$1" >&2; exit 1; }

export HOME="$_T/home"
mkdir -p "$HOME" "$_T/bin"
_LOG="$_T/calls.log"
# Fake optional tools and installers. Each logs its name and arguments. sudo logs and runs nothing.
for _n in rtk lean-ctx headroom caveman ccusage claude npm npx pip pip3 pipx cargo curl wget sudo apt apt-get nvm; do
  printf '#!/usr/bin/env bash\nprintf "%%s %%s\\n" "%s" "$*" >> "%s"\nexit 0\n' "$_n" "$_LOG" > "$_T/bin/$_n"
  chmod +x "$_T/bin/$_n"
done
export PATH="$_T/bin:$PATH"
: > "$_LOG"
_INSTALL="$_ROOT/scripts/install-wsl.sh"
_SHOW="$_ROOT/scripts/show-optional-tools.sh"
_RC="$_T/bashrc"

# Every logged call is a harmless "--version" (check-tools.sh), or the one apt line allowed for the basic prerequisites.
only_allowed_calls() { # file
  if grep -Ev ' --version$|^sudo apt-get update$|^sudo apt-get install -y (jq git curl ca-certificates coreutils|jq git curl ca-certificates bash coreutils python3 python3-pip python3-venv pipx build-essential)$' "$1" | grep -q .; then
    fail "unexpected call: $(grep -Ev ' --version$|^sudo apt-get update$|^sudo apt-get install -y ' "$1" | head -3)"
  fi
}

# install-wsl.sh: dry run changes nothing.
bash "$_INSTALL" --dry-run --skip-apt --bashrc "$_RC" > "$_T/dry.out" 2>&1 || fail "dry run exited $?"
[ ! -e "$_RC" ] || fail 'dry run wrote the bashrc file'
grep -q 'Would add to' "$_T/dry.out" && grep -q "alias workflow='source \"$_ROOT/scripts/workflow.sh\"'" "$_T/dry.out" || fail 'dry run does not show the alias'

# The alias is added once, and a second run does not add it again.
bash "$_INSTALL" --skip-apt --bashrc "$_RC" > "$_T/run1.out" 2>&1 || fail "install exited $?"
bash "$_INSTALL" --skip-apt --bashrc "$_RC" > "$_T/run2.out" 2>&1 || fail "second install exited $?"
[ "$(grep -c "^alias workflow=" "$_RC")" -eq 1 ] || fail "the alias is not there exactly once: $(cat "$_RC")"
grep -Fq "alias workflow='source \"$_ROOT/scripts/workflow.sh\"'" "$_RC" || fail 'the alias has the wrong path'
grep -q 'A workflow alias already exists' "$_T/run2.out" || fail 'the second run does not say the alias exists'
grep -q 'Next steps' "$_T/run1.out" && grep -q 'workflow init' "$_T/run1.out" && grep -q 'show-optional-tools.sh' "$_T/run1.out" || fail 'next steps are missing'
grep -q 'AI Context Workflow tool check' "$_T/run1.out" || fail 'check-tools.sh was not run'
# The alias works (sourcing the script through the alias path gives the workflow function).
( set +u; source "$_ROOT/scripts/workflow.sh" status >/dev/null 2>&1 ) || fail 'workflow.sh from the alias path does not run'

# An existing workflow alias is not changed, and a different path gets a warning.
printf "alias workflow='source /somewhere/else/workflow.sh'\n" > "$_T/rc2"
bash "$_INSTALL" --skip-apt --bashrc "$_T/rc2" > "$_T/run3.out" 2>&1 || fail "install with an existing alias exited $?"
[ "$(cat "$_T/rc2")" = "alias workflow='source /somewhere/else/workflow.sh'" ] || fail 'an existing alias was changed'
grep -q 'does not point to this controller' "$_T/run3.out" || fail 'no warning for an alias that points elsewhere'

# Options.
bash "$_INSTALL" --bogus >/dev/null 2>&1; [ "$?" -eq 2 ] || fail 'an unknown option should exit 2'
bash "$_INSTALL" --bashrc >/dev/null 2>&1; [ "$?" -eq 2 ] || fail '--bashrc without a file should exit 2'
bash "$_INSTALL" --help | grep -q 'never installs RTK\|never installs' || fail '--help does not say that no optional tool is installed'

# apt: only the basic prerequisites (skipped when the tests run as root, because then no sudo is used).
if [ "$(id -u)" -ne 0 ]; then
  : > "$_LOG"
  bash "$_INSTALL" --bashrc "$_T/rc3" > "$_T/apt.out" 2>&1 || fail "install with apt exited $?"
  grep -qx 'sudo apt-get update' "$_LOG" && grep -qx 'sudo apt-get install -y jq git curl ca-certificates coreutils' "$_LOG" || fail "apt calls are wrong: $(cat "$_LOG")"
fi
# No optional tool and no installer was called by the whole install: only --version and the apt lines.
only_allowed_calls "$_LOG"
for _n in rtk lean-ctx headroom caveman ccusage claude npm npx pip pip3 pipx cargo wget nvm; do
  grep -E "^$_n " "$_LOG" | grep -Ev ' --version$' | grep -q . && fail "install-wsl.sh called $_n"
done

# show-optional-tools.sh --print-only: no apt, no tool, prints the commands as text.
: > "$_LOG"
bash "$_SHOW" --print-only > "$_T/show.out" 2>&1 || fail "show-optional-tools.sh --print-only exited $?"
[ ! -s "$_LOG" ] || fail "--print-only called something: $(cat "$_LOG")"
for _t in 'does NOT install' 'RTK:' 'LeanCTX' 'Caveman' 'ccusage' 'Claude Code'; do
  grep -q -- "$_t" "$_T/show.out" || fail "show-optional-tools.sh output misses: $_t"
done
bash "$_SHOW" --bogus >/dev/null 2>&1; [ "$?" -eq 2 ] || fail 'show-optional-tools.sh: an unknown option should exit 2'
# Without the flag: apt for the basic prerequisites only.
if [ "$(id -u)" -ne 0 ]; then
  : > "$_LOG"
  bash "$_SHOW" > "$_T/show2.out" 2>&1 || fail "show-optional-tools.sh exited $?"
  only_allowed_calls "$_LOG"
  grep -q '^sudo apt-get install -y' "$_LOG" || fail 'the prerequisites were not installed without --print-only'
fi
# The scripts never run optional tools. The commands appear only as printed text (heredocs) or comments.
# Executed code (outside the heredocs and comments): no optional tool name as a command.
for _f in "$_INSTALL" "$_SHOW"; do
  _code="$(awk '/<<.?(TOOLS|INTRO|NEXT).?$/ { skip = 1; next } skip && /^(TOOLS|INTRO|NEXT)$/ { skip = 0; next } !skip { print }' "$_f" | grep -v '^[[:space:]]*#')"
  if printf '%s\n' "$_code" | grep -Eq '(^|[;&|(`] *)(rtk|lean-ctx|headroom|caveman|ccusage|claude|npm|npx|pip3?|pipx|cargo|nvm)( |$)'; then
    fail "$(basename "$_f") runs an optional tool or installer: $(printf '%s\n' "$_code" | grep -E '(^|[;&|(`] *)(rtk|lean-ctx|headroom|caveman|ccusage|claude|npm|npx|pip3?|pipx|cargo|nvm)( |$)' | head -2)"
  fi
done

# ---- scripts/install-tools/*.sh: optional tool helpers. Fake curl, cargo, and claude; a fake installer creates the fake tool.
_H="$_ROOT/scripts/install-tools"
_B2="$_T/bin2"
_HLOG="$_T/helper.log"
mkdir -p "$_B2"
cat > "$_B2/curl" <<'FAKE'
#!/usr/bin/env bash
# fake curl: -fsSL URL -o FILE. Writes a harmless "installer" that logs and creates a fake tool.
url=""; out=""
while [ "$#" -gt 0 ]; do case "$1" in -o) out="$2"; shift ;; -*) ;; *) url="$1" ;; esac; shift; done
printf 'curl %s\n' "$url" >> "$HLOG"
case "$url" in *rtk-ai*) tool=rtk ;; *leanctx.com*) tool=lean-ctx ;; *) tool=other ;; esac
cat > "$out" <<STUB
echo "installer-ran $tool NO_ONBOARD=\${LEAN_CTX_NO_ONBOARD:-} NO_PATH_FIX=\${LEAN_CTX_NO_PATH_FIX:-}" >> "$HLOG"
printf '#!/bin/sh\necho "$tool \$*" >> "$HLOG"\necho "$tool 1.0"\n' > "$BIN2/$tool"
chmod +x "$BIN2/$tool"
STUB
FAKE
cat > "$_B2/cargo" <<'FAKE'
#!/usr/bin/env bash
printf 'cargo %s\n' "$*" >> "$HLOG"
printf '#!/bin/sh\necho "lean-ctx $*" >> "%s"\necho "lean-ctx 1.0"\n' "$HLOG" > "$BIN2/lean-ctx"; chmod +x "$BIN2/lean-ctx"
FAKE
cat > "$_B2/claude" <<'FAKE'
#!/usr/bin/env bash
printf 'claude %s\n' "$*" >> "$HLOG"
FAKE
chmod +x "$_B2/curl" "$_B2/cargo" "$_B2/claude"
export HLOG="$_HLOG" BIN2="$_B2"
_HPATH="$_B2:/usr/bin:/bin"
helper() { # helper name, stdin text, args...  Runs with the fake tools only. Sets _HRC. Output in $_T/helper.out
  local _n="$1" _in="$2"
  shift 2
  : > "$_HLOG"
  rm -f "$_B2/rtk" "$_B2/lean-ctx"
  printf '%s' "$_in" | PATH="$_HPATH" bash "$_H/$_n.sh" "$@" > "$_T/helper.out" 2>&1
  _HRC=$?
}
no_forbidden_calls() { # no init, setup, wrap, onboard, install-hook call by any fake tool
  if grep -Eq '^(rtk|lean-ctx) (init|setup|wrap|onboard|hook|trust)' "$_HLOG"; then fail "a forbidden tool command was run: $(grep -E '^(rtk|lean-ctx) ' "$_HLOG" | head -3)"; fi
  if grep -Ev '^(rtk|lean-ctx) --version$' "$_HLOG" | grep -E '^(rtk|lean-ctx) ' | grep -q .; then fail "a tool was called with more than --version: $(cat "$_HLOG")"; fi
}
for _tool in rtk leanctx caveman; do
  helper "$_tool" "" --dry-run
  [ "$_HRC" -eq 0 ] || [ "$_tool" = caveman ] || fail "$_tool.sh --dry-run exited $_HRC"
  grep -q 'Upstream: https://github.com/' "$_T/helper.out" || fail "$_tool.sh does not print the upstream source"
  grep -q 'may become outdated' "$_T/helper.out" || fail "$_tool.sh does not say it may be outdated"
  [ ! -s "$_HLOG" ] || fail "$_tool.sh --dry-run called something: $(cat "$_HLOG")"
  helper "$_tool" "" --bogus; [ "$_HRC" -eq 2 ] || fail "$_tool.sh: an unknown option should exit 2"
done
# RTK: no answer, "n", and EOF install nothing. "y" runs the upstream installer file, then only "rtk --version".
helper rtk "n
"; [ ! -s "$_HLOG" ] || fail "rtk.sh installed after the answer n: $(cat "$_HLOG")"
helper rtk ""; [ ! -s "$_HLOG" ] || fail 'rtk.sh installed without an answer'
helper rtk "maybe
"; [ ! -s "$_HLOG" ] || fail 'rtk.sh installed after an unclear answer'
helper rtk "y
"
[ "$_HRC" -eq 0 ] || fail "rtk.sh exited $_HRC: $(tail -3 "$_T/helper.out")"
grep -q '^curl https://raw.githubusercontent.com/rtk-ai/rtk/' "$_HLOG" && grep -q '^installer-ran rtk' "$_HLOG" || fail "rtk.sh did not run the downloaded installer: $(cat "$_HLOG")"
no_forbidden_calls
grep -q 'never runs "rtk init", and you should not either' "$_T/helper.out" || fail 'rtk.sh does not warn about rtk init'
# LeanCTX: the upstream installer runs with onboarding and the PATH edit turned off.
helper leanctx "n
" --method script; [ ! -s "$_HLOG" ] || fail 'leanctx.sh installed after n'
helper leanctx "y
" --method script
[ "$_HRC" -eq 0 ] || fail "leanctx.sh exited $_HRC: $(tail -3 "$_T/helper.out")"
grep -q '^installer-ran lean-ctx NO_ONBOARD=1 NO_PATH_FIX=1$' "$_HLOG" || fail "leanctx.sh did not turn off onboarding and the PATH edit: $(cat "$_HLOG")"
no_forbidden_calls
helper leanctx "y
" --method cargo
[ "$_HRC" -eq 0 ] && grep -qx 'cargo install lean-ctx' "$_HLOG" || fail "leanctx.sh --method cargo: $(cat "$_HLOG")"
! grep -q '^curl' "$_HLOG" || fail 'leanctx.sh --method cargo used curl'
no_forbidden_calls
helper leanctx "y
"; [ "$_HRC" -eq 0 ] && grep -qx 'cargo install lean-ctx' "$_HLOG" || fail 'leanctx.sh should use cargo when cargo exists'
mv "$_B2/cargo" "$_B2/cargo.off"
helper leanctx "y
"; [ "$_HRC" -eq 0 ] && grep -q '^installer-ran lean-ctx NO_ONBOARD=1' "$_HLOG" || fail 'leanctx.sh should use the script when cargo is missing'
helper leanctx "y
" --method cargo; [ "$_HRC" -eq 1 ] || fail 'leanctx.sh --method cargo without cargo should exit 1'
mv "$_B2/cargo.off" "$_B2/cargo"
helper leanctx "" --method; [ "$_HRC" -eq 2 ] || fail 'leanctx.sh --method without a value should exit 2'
helper leanctx "" --method bogus; [ "$_HRC" -eq 2 ] || fail 'leanctx.sh --method bogus should exit 2'
# Caveman: only the two plugin commands, only after "y", and only when claude exists.
helper caveman "n
"; [ ! -s "$_HLOG" ] || fail 'caveman.sh installed after n'
helper caveman "y
"
[ "$_HRC" -eq 0 ] || fail "caveman.sh exited $_HRC"
[ "$(cat "$_HLOG")" = "$(printf 'claude plugin marketplace add JuliusBrussee/caveman\nclaude plugin install caveman@caveman')" ] || fail "caveman.sh calls are wrong: $(cat "$_HLOG")"
mv "$_B2/claude" "$_B2/claude.off"
helper caveman "y
"; [ "$_HRC" -eq 1 ] && [ ! -s "$_HLOG" ] || fail 'caveman.sh without claude should exit 1 and install nothing'
grep -q 'does not install it' "$_T/helper.out" || fail 'caveman.sh does not say that it does not install Claude Code'
mv "$_B2/claude.off" "$_B2/claude"
# Static: no forbidden command as code (outside the printed heredocs and comments), and no startup file or MCP edit.
for _f in "$_H"/*.sh; do
  _code="$(awk 'skip { if ($0 == w) skip = 0; next } match($0, /<<-?[ ]*\x27?[A-Za-z]+\x27?/) { w = substr($0, RSTART, RLENGTH); gsub(/<<-?[ ]*|\x27/, "", w); skip = 1; next } { print }' "$_f" | grep -v '^[[:space:]]*#')"
  if printf '%s\n' "$_code" | grep -Eq '(rtk|lean-ctx)[[:space:]]+(init|setup|wrap|onboard|hook|trust)|>>[[:space:]]*[^ ]*(bashrc|profile|zshrc)|mcp|settings\.json|npm |pip |sudo '; then
    fail "$(basename "$_f") has a forbidden command: $(printf '%s\n' "$_code" | grep -E '(rtk|lean-ctx)[[:space:]]+(init|setup|wrap|onboard|hook|trust)|>>.*(bashrc|profile|zshrc)|mcp|settings\.json|npm |pip |sudo ' | head -2)"
  fi
done
_wsl_code="$(awk 'skip { if ($0 == w) skip = 0; next } match($0, /<<-?[ ]*\x27?[A-Za-z]+\x27?/) { w = substr($0, RSTART, RLENGTH); gsub(/<<-?[ ]*|\x27/, "", w); skip = 1; next } { print }' "$_ROOT/scripts/install-wsl.sh" | grep -v '^[[:space:]]*#')"
if printf '%s\n' "$_wsl_code" | grep -q 'install-tools'; then fail 'install-wsl.sh runs an optional tool helper'; fi

printf 'PASS: install scripts (alias added once, no optional tool installed, apt for the basic prerequisites only)\n'
