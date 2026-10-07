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
printf 'PASS: install scripts (alias added once, no optional tool installed, apt for the basic prerequisites only)\n'
