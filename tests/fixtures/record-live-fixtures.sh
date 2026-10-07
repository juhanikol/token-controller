#!/usr/bin/env bash
# Records the grep, find, and git fixtures in tests/fixtures/rtk from real commands on a small generated project.
# Not run by the tests. Run it by hand to re-record, then check the diff. Usage: bash tests/fixtures/record-live-fixtures.sh
# Needs git, grep, find. The project is generated with fixed dates, so the git hashes are stable.
set -eu

_RL_OUT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/rtk"
_RL_TMP="$(mktemp -d /tmp/token-controller-record.XXXXXX)"
trap 'rm -rf -- "$_RL_TMP"' EXIT
export TZ=UTC LC_ALL=C GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=Dev GIT_AUTHOR_EMAIL=dev@example.com GIT_COMMITTER_NAME=Dev GIT_COMMITTER_EMAIL=dev@example.com

mkdir "$_RL_TMP/proj"
cd "$_RL_TMP/proj"
git init -q -b main .
mkdir -p src tests logs
for m in parser lexer render cache config; do
  cat > "src/$m.py" <<EOF
"""Module $m."""
import os

# TODO: handle empty input in $m
def run_$m(data):
    if not data:
        raise ValueError("empty input")
    return len(data)

def helper_$m(x):
    # TODO: remove after migration
    return x * 2
EOF
done
printf 'def test_ok():\n    assert True\n' > tests/test_a.py
printf 'def test_two():\n    assert 1 == 1\n' > tests/test_b.py
for i in 1 2 3 4 5 6; do
  _RL_DATE="2026-01-0${i}T10:00:00"
  echo "line $i" >> README.md
  git add -A
  GIT_AUTHOR_DATE="$_RL_DATE" GIT_COMMITTER_DATE="$_RL_DATE" git commit -q -m "Change $i: update docs and sources"
done
# Log files with evidence-like lines.
{
  for i in $(seq 1 12); do echo "2026-01-06 10:00:0$((i % 10)) INFO worker started job $i"; done
  echo "src/parser.py:7: error: empty input rejected"
  echo "src/cache.py:3: warning: cache is cold"
  echo "2026-01-06 10:01:00 INFO done"
} > logs/app.log
git add logs && GIT_AUTHOR_DATE="2026-01-07T10:00:00" GIT_COMMITTER_DATE="2026-01-07T10:00:00" git commit -q -m "Add app log"
# Working tree changes.
sed -i 's/handle empty input in parser/handle empty and None input in parser/' src/parser.py
sed -i 's/return x \* 2/return x * 3/' src/lexer.py
echo 'print("debug")' >> src/render.py
echo 'x = 1' > src/new_file.py
mkdir -p build && echo junk > build/out.bin

record() { # filter case command...   (run in the project; stdout, stderr, exit, cmd are saved)
  local _RL_F="$1" _RL_C="$2" _RL_D _RL_CODE
  shift 2
  _RL_D="$_RL_OUT/$_RL_F/$_RL_C"
  mkdir -p "$_RL_D"
  set +e
  "$@" > "$_RL_D/stdout" 2> "$_RL_D/stderr"
  _RL_CODE=$?
  set -e
  [ -s "$_RL_D/stderr" ] || rm -f "$_RL_D/stderr"
  printf '%s\n' "$_RL_CODE" > "$_RL_D/exit"
  printf '%s\n' "$*" > "$_RL_D/cmd"
}

record git-status dirty git status
record git-log history git log
record git-log oneline git log --oneline
record git-diff changes git diff
record git-diff stat git diff --stat
record grep todo grep -rn TODO src
record grep evidence grep -rn -e 'error:' -e 'warning:' logs
record grep nomatch grep -rn FIXME src
record find sources find src -type f
record find none find tests -name '*.rs'
# A larger tree: 30 packages with 4 modules each, one TODO in every module.
for i in $(seq -w 1 30); do
  mkdir -p "pkgs/pkg$i"
  for n in a b c d; do
    printf '"""Module %s of package %s."""\nimport os\n# TODO: review mod_%s in pkg%s\n' "$n" "$i" "$n" "$i" > "pkgs/pkg$i/mod_$n.py"
  done
done
record grep many grep -rn TODO pkgs
record find many find pkgs -type f
# A clean tree and a folder that is not a repository.
git add -A && GIT_AUTHOR_DATE="2026-01-08T10:00:00" GIT_COMMITTER_DATE="2026-01-08T10:00:00" git commit -q -m "Commit everything"
record git-status clean git status
mkdir "$_RL_TMP/plain" && cd "$_RL_TMP/plain"
record git-status not-a-repo git status
