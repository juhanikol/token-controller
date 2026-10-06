# Practical context-reduction benchmark

This small suite checks whether `wx` produces a practical byte reduction after including its mandatory raw-log pointer, while retaining authoritative raw evidence. It uses only Bash, `jq`, `awk`, `grep`, `cmp`, and standard Ubuntu utilities—no RTK, Headroom, LeanCTX, MemStack, Caveman, or AI summarization.

## Scenarios

| Fixture | Invocation | Profile | Expected result |
| --- | --- | --- | --- |
| `noisy-pass.sh` | temporary fixture-backed `npm install` | `code` | repeated successful lines compress and total emitted bytes decrease |
| `failing-stacktrace.sh` | direct executable | `debug` | exit code and complete failure evidence remain raw |
| `security-scan-output.txt` | `cat` | `security` | visible command output is byte-for-byte identical to normal shell output |
| `db-migration-warning.txt` | `cat` | `db` | visible command output is byte-for-byte identical to normal shell output |

The temporary `npm` executable is a symlink to `noisy-pass.sh`, allowing both the normal and wrapped runs to use the configured `npm install` noisy-success classification without changing production policy.

## Run on WSL2 Ubuntu

From the repository root:

```bash
bash benchmarks/run-benchmark.sh
```

To retain the generated Markdown summary:

```bash
bash benchmarks/run-benchmark.sh > /tmp/token-controller-benchmark.md
```

The script uses an isolated temporary working directory and active-mode directory, then removes them on exit. It does not modify or delete the caller's `.ai-context` data.

## Reading the result

- **Raw bytes** are the normal-shell stdout and stderr sizes, verified byte-for-byte against the `wx` raw logs.
- **Visible command bytes** come from `session.jsonl` and exclude wrapper diagnostics.
- **Emitted bytes** are captured directly from `wx` stdout and stderr and include the raw-log pointer.
- **Practical reduction** compares normal-shell raw bytes with total emitted bytes.
- **Evidence** is `PASS` only when exit codes, raw logs, and scenario-specific safety assertions all hold.

The final result says **PROVES** only if the noisy fixture gets smaller after wrapper overhead and the failure/security/database fixtures preserve required evidence. Otherwise it says **DISPROVES** and exits nonzero. This benchmark measures bytes, not model-token usage.

The emitted Markdown is formatted so it can be pasted into `docs/VALIDATION_MATRIX.md` after reviewing the environment and results.

## Validation

```bash
bash -n benchmarks/run-benchmark.sh benchmarks/fixtures/noisy-pass.sh benchmarks/fixtures/failing-stacktrace.sh
bash benchmarks/run-benchmark.sh > /tmp/token-controller-benchmark.md
```
