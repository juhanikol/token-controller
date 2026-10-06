#!/usr/bin/env bash
# Deterministic noisy output for tests that stand in for pytest, cargo, go, tsc, and vitest.
# Usage: noisy-output.sh <tool> [args...]
# Environment: FIXTURE_EXIT (exit code, default 0), FIXTURE_STDERR=1 (write one stderr line),
#              FIXTURE_NO_WARNING=1 (leave out the warning line).
tool="${1:-tool}"
echo "============ ${tool} session starts ============"
echo "collected 40 items"
for i in $(seq 1 40); do
  echo "tests/test_a.py::test_${i} PASSED"
done
if [ "${FIXTURE_NO_WARNING:-}" != 1 ]; then
  echo "warning: deprecated api used"
fi
echo "============ 40 passed in 0.12s ============"
if [ "${FIXTURE_STDERR:-}" = 1 ]; then
  echo "fixture stderr line" >&2
fi
exit "${FIXTURE_EXIT:-0}"
