# Deterministic `wx` Command Wrapper Design

## Current behavior

The first mechanical layer is implemented in `scripts/lib/wx.sh` and exposed as the `wx` function. It runs the supplied command directly, stores raw stdout and stderr under `.ai-context/raw/`, appends command metadata to `.ai-context/session.jsonl`, replays the uncompressed streams, prints the raw-log location, and returns the command's exit code. `scripts/workflow.sh` now sources the wrapper while remaining responsible for profile activation. Policy-aware compression remains unimplemented.

## Proposed behavior

Keep `workflow.sh` responsible for selecting profiles, exporting policy variables, and writing `active_mode.env`. Move `wx` execution into a small runner with this contract:

1. Run the supplied argv directly without `eval` or an intermediate shell.
2. Capture stdout and stderr separately and byte-for-byte.
3. Retain both raw streams before attempting compression.
4. Resolve a deterministic output policy from the profile, command class, and exit code.
5. Emit either raw output or output from a versioned built-in compressor.
6. Append one measurement record and return the command's exact exit code.

Compression is post-processing; an optional tool must never replace the authoritative raw capture. The initial implementation should not depend on RTK for its deterministic baseline.

## File layout

The first layer keeps capture and metadata logic in `scripts/lib/wx.sh`. When policy-aware compression is added, split toward this target layout:

```text
scripts/
├── workflow.sh                 # profile activation; sources the wx frontend only
└── lib/
    ├── wx.sh                   # wx function, argument checks, runner dispatch
    ├── wx-runner.sh            # capture, lifecycle, emission, metadata, exit status
    ├── wx-policy.sh            # profile and command classification
    └── wx-compress.sh          # deterministic compressor implementations
tests/
└── wx-wrapper.test.sh          # dependency-free integration tests
```

`workflow.sh` should replace its current wrapper body with one `source` of `scripts/lib/wx.sh`. The library must be safe to source repeatedly.

## Data flow

```text
wx argv
  -> load active policy snapshot
  -> classify profile and command
  -> create private staging/run directory
  -> execute argv, capturing stdout.raw and stderr.raw
  -> record exact command status
  -> choose raw/lossless or compressible output
  -> emit stdout to stdout and stderr to stderr
  -> atomically finalize logs and append measurement JSONL
  -> return the original command status
```

The runner buffers output on disk rather than in shell variables, avoiding binary corruption and memory growth. Separate files are authoritative; no combined log should claim to preserve stdout/stderr interleaving.

## Raw log retention

- Use the existing `AICONTEXT_RAW_LOG_DIR`, defaulting to `.ai-context/raw` under the command's starting directory.
- Store each invocation in a unique directory such as `YYYYMMDD/<UTC timestamp>-<pid>-<counter>/` with `stdout.raw`, `stderr.raw`, and `run.json`.
- Create directories with mode `0700` and files with mode `0600`; reject symlinked run directories and never overwrite an existing run.
- Retain raw logs for successes, failures, compression failures, and interrupted commands. Do not delete logs automatically in the first implementation.
- Document that raw logs may contain secrets and should be gitignored. A future explicit prune command may implement age/size retention without changing capture semantics.

## Compression rules

Policy resolution is ordered and first-match wins:

1. Emit raw output for `raw`, `security`, `db`, `release`, and `migration` profiles.
2. Emit raw output for commands in `command_policy.preserve_raw_or_lossless`.
3. When `AICONTEXT_RAW_ON_FAIL=true`, emit the complete raw stdout and stderr for any nonzero exit. This guarantees that the first failing `debug` output is not destructively compressed.
4. Emit stderr verbatim whenever `AICONTEXT_PRESERVE_STDERR=true`, including successful commands that produced warnings.
5. Emit raw output when shell compression is `off` or policy resolution is unknown.
6. Otherwise, apply only a versioned built-in reducer to stdout. Version 1 may collapse consecutive identical lines and excess blank lines, inserting an explicit count marker. It must not truncate unknown content or rewrite numbers, paths, diagnostics, warning/error lines, or command summaries.

Command-specific reducers may be added only with fixtures proving their preserved fields. An optional RTK adapter can remain experimental, but its output and version must be recorded and it must operate only after the direct command output has been captured.

## Measurement format

Append one JSON object per invocation to `.ai-context/measurements.jsonl` using an atomic lock. Suggested schema:

```json
{
  "schema_version": 1,
  "run_id": "20261006T120000.123Z-1234-1",
  "started_at": "2026-10-06T12:00:00.123Z",
  "duration_ms": 842,
  "cwd": "/workspace/project",
  "command": "npm",
  "argv_sha256": "sha256:...",
  "profile": "code",
  "risk": "normal",
  "exit_code": 0,
  "decision": "compress-exact-repeats",
  "compressor": "builtin/exact-repeat-v1",
  "raw": {"stdout_bytes": 12000, "stderr_bytes": 0, "stdout_lines": 400},
  "emitted": {"stdout_bytes": 1800, "stderr_bytes": 0, "stdout_lines": 42},
  "raw_log_dir": ".ai-context/raw/20261006/...",
  "wrapper_error": null
}
```

Byte and line counts are exact. Token fields should be absent or `null` unless a named tokenizer and version actually calculate them; byte reduction must not be labeled token savings. Store only the executable name and an argv hash by default so measurements do not duplicate secret arguments.

## Failure behavior

- If the log directory cannot be safely created before execution, do not run the command; print a wrapper error and return `125`.
- Once the command starts, always return its exit code, including `126`, `127`, and signal-derived statuses.
- If compression fails, emit the captured raw streams, record `compression-fallback-raw`, and preserve the command status.
- If metadata append or final log rename fails after execution, warn on stderr, keep any staged raw files, and preserve the command status.
- Trap interruption signals, forward them to the child, wait for it, finalize available evidence, and return the child's signal-derived status.
- Never allow a wrapper error to hide existing raw evidence or replace a command failure with a successful status.

## Backward compatibility

- Preserve `wx <command> [args...]`, argument boundaries, working directory, environment, stdout/stderr destinations, and the command's exit status.
- Keep `workflow <mode>`, `workflow init`, profile names, and `active_mode.env` compatible.
- Continue reading current `AICONTEXT_*` variables and existing configuration defaults; add only optional wrapper/measurement settings.
- Output becomes completion-buffered for compressible commands. Raw/lossless profiles may stream through `tee` only if tests prove capture and status fidelity; otherwise document the buffering change.
- Replace RTK command delegation with the built-in deterministic path. If retained, RTK is an explicit post-capture experimental compressor, not the command executor.

## Validation commands

Future implementation validation should include:

```bash
bash -n scripts/workflow.sh scripts/lib/wx.sh scripts/lib/wx-runner.sh scripts/lib/wx-policy.sh scripts/lib/wx-compress.sh
jq . config/workflow_settings.json >/dev/null
bash tests/wx-wrapper.test.sh
git diff --check
```

The integration test must cover separate stdout/stderr capture, exact exit codes `0`, `1`, `126`, and `127`, spaces and shell metacharacters in argv, large output, signals, unwritable/symlinked log paths, atomic concurrent JSONL appends, compressor failure fallback, and byte-count/hash agreement. It must also prove byte-for-byte raw emission for `security`, `db`, `release`, and `migration`, plus complete raw output for a failing `debug` command.
