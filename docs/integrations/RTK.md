# RTK Integration Design

Status: **prototype implemented** in `scripts/lib/wx-compress.sh` and `scripts/lib/wx.sh` (see "Prototype status" at the end). Checked against RTK 0.42.4.

## Goal

RTK is the first external compressor. It processes output that `wx` has already captured. It never runs the user's command, and it never replaces the raw capture.

```text
wx argv -> run command -> stdout.raw / stderr.raw (authoritative) -> gates -> rtk pipe -> visible output
```

## Integration point: `rtk pipe`

RTK has two ways to work:

| Mode | Runs the command? | Use in `wx` |
|---|---|---|
| `rtk <cmd> ...` (for example `rtk git`, `rtk test`) | Yes | **Never.** It would bypass raw capture. Running the command twice is also wrong. |
| `rtk pipe -f <filter>` | No. Reads stdin, writes stdout | **Only this.** |

Facts from RTK 0.42.4:
- `rtk pipe` without `-f` passes input through unchanged (exit 0). That is not compression. `wx` must not record `compressor: rtk` for it.
- Available filters: `cargo-test pytest go-test go-build tsc vitest grep rg find fd git-log git-diff git-status log mypy ruff-check ruff-format prettier`. An unknown filter exits 1.
- RTK writes its own notices to stderr (for example "No hook installed"). `wx` must keep this out of the visible output.
- One filter (`cargo-test`) dropped the final newline. Record byte counts. Do not assume text is identical.
- Coverage is smaller than the `rtk <cmd>` wrappers. There is no filter for `npm install`, `docker build`, `pip install`, `npm test`, or `dotnet test`. This is a cost of keeping raw capture first.

## Install and version check

Run only after the gates below pass, and only for a command that has a mapped filter.

1. `command -v rtk`. Missing → fallback `rtk-not-installed`.
2. `timeout 3 rtk --version` → parse `rtk X.Y.Z`. Failure → fallback `rtk-version-failed`.
3. Record the version string in every run that calls RTK.
4. "Tested with" version is kept in one place (config). A different version is allowed. `workflow doctor` shows an `info` finding.

`workflow doctor` reports RTK path and version, and warns about any RTK hook or setup (`policy.rtk_hook`) in every mode. It never runs `rtk init`.

## When RTK may be used

All must be true:
- Exit code is `0`.
- Profile is not protected and its `rtk_mode` is not `off`.
- Command is not in `preserve_raw_or_lossless`.
- `compress_shell` is not `off`.
- Command matches an entry in the RTK filter map (see Config).
- `stdout.raw` is non-empty text (not binary).
- RTK is installed and returns a version.

Only stdout is processed. stderr is always shown verbatim.

Initial filter map: `cargo-test`, `pytest`, `go-test`, `go-build`, `tsc`, `vitest`. Search and diff filters (`grep`, `rg`, `find`, `fd`, `git-*`) are excluded at first, because their output is evidence. `log` is a candidate for install and build logs. Add it only after fixtures pass.

## When RTK must be bypassed

`wx` decides this before it calls RTK. The existing policy order stays first-match-wins and RTK is added after the existing gates:

1. Profiles `raw`, `security`, `db`, `release`, `migration` → raw. This is enforced in `wx`, not only by config (`rtk_mode: off`).
2. Commands in `preserve_raw_or_lossless` → raw.
3. Any nonzero exit → raw. This covers the first failing `debug` and `test` output, and every later failure too. It is stricter than "first failure" on purpose.
4. `compress_shell` is `off` → raw.
5. `rtk_mode` is `off` → built-in reducer or raw.
6. No mapped filter → built-in reducer or raw.

`rtk_mode` is `off` or `success-only` in the config. `debug` is `success-only`: because rule 3 already keeps failures raw, RTK may run on a passing `debug` command. The old `aggressive` distinction was dropped. Add a separate key if it is needed.

## Fallback behavior

Fallback means: RTK was called or needed, and the result was not safe to show. `wx` then shows the raw output. It tries the built-in exact-repeat reducer only if the command is on the existing allowlist. Otherwise it shows raw.

| `fallback_reason` | Trigger |
|---|---|
| `rtk-not-installed` | Not on `PATH` |
| `rtk-version-failed` | `--version` fails or times out |
| `rtk-nonzero-exit` | `rtk pipe` exits nonzero |
| `rtk-timeout` | No result in 10 s |
| `rtk-empty-output` | Input was non-empty, output is empty |
| `rtk-not-smaller` | Visible bytes are not smaller than raw bytes |
| `evidence-guard` | A guard line from raw is missing in the RTK output (see below) |

Bypass (rules 1-6) is not a fallback. It is recorded in `output_policy` only, and `compressor` stays `null`.

**Evidence guard v1.** After RTK runs, check that these raw stdout lines are still present in the output: lines that start with `error`, `warning`, or `panic:`, lines with `Traceback`, `FAILED`, or `CVE-`. RTK may reformat a line, so tune the pattern with fixtures. A false fallback is safe. A missed warning is not. If the guard fails, show raw.

Fallbacks never change the exit code. The raw files are already on disk before RTK starts.

## `session.jsonl` record

Additive change to the current `schema_version: 2` record. Old records and `workflow report` keep working because `.raw` and `.visible` do not move.

```json
{
  "schema_version": 2,
  "profile": "test",
  "exit_code": 0,
  "output_policy": "compress-rtk-v1",
  "raw":     {"stdout_bytes": 48210, "stderr_bytes": 0},
  "visible": {"stdout_bytes": 1930,  "stderr_bytes": 0, "stdout_path": ".../stdout.visible"},
  "compressor": {
    "name": "rtk",
    "version": "0.42.4",
    "filter": "pytest",
    "applied": true,
    "fallback_reason": null
  }
}
```

On fallback: `output_policy: "raw-rtk-fallback"`, `compressor.applied: false`, `fallback_reason` set, `visible` equal to `raw`. For the built-in reducer: `compressor.name: "builtin/exact-repeat-v1"`, `version: 1`. For bypass or no compressor: `compressor: null`.

Do not call these token savings. The record holds bytes. Token counts need a named tokenizer.

Extra run files: `rtk.stderr` (RTK's own stderr, never shown) next to `stdout.raw`.

## Config

Add a filter map to `command_policy`, not to code:

```json
"rtk_filters": {
  "cargo test": "cargo-test",
  "pytest": "pytest",
  "go test": "go-test",
  "go build": "go-build",
  "tsc": "tsc",
  "vitest": "vitest"
}
```

Matching uses the same argv-prefix rule as the existing policy lists. Nothing is added until its fixture passes.

## Conflicts to handle

- **RTK hook** (`rtk init -g`): in hosts like Claude Code, the hook rewrites commands to run through `rtk <cmd>` directly. Then `wx` never sees the raw output, so raw evidence is not authoritative for those commands. `workflow doctor` should warn when an RTK hook exists, whatever the mode. Do not run `rtk init` from Token Controller. Choose one route per command.
- **RTK tracking:** RTK config has `[tracking] enabled = true`. It is unverified whether `rtk pipe` writes history. Check before implementing. `wx` must never edit `~/.config/rtk`.

## Validation scenarios

Use a fake `rtk` in `tests/fixtures/bin` (the pattern already used by the session test). It logs each call, so a test can prove that RTK was **not** called. Run real-RTK scenarios only when `rtk` is installed.

| # | Scenario | Expect |
|---|---|---|
| 1 | RTK missing, mapped command, exit 0 | Fallback `rtk-not-installed`. Exit code and raw files intact |
| 2 | Passing mapped command (`pytest` or `cargo test` fixture) | `compressor.name=rtk`, version recorded, visible < raw, `stdout.raw` byte-identical to the command output (sha256) |
| 3 | Failing mapped command | Raw. Fake RTK was **not** called. Exit code kept |
| 4 | Each of `security`, `db`, `release`, `migration`, with a mapped command | Raw. Fake RTK not called |
| 5 | Protected command (`trivy`, `psql`) | Raw. Fake RTK not called |
| 6 | `debug`: failing run, then passing run | Failing: raw. Passing: RTK allowed |
| 7 | RTK exits 1 / hangs / returns empty output | Fallback with the matching reason. Output is raw. Exit code kept |
| 8 | RTK output not smaller | Raw. `rtk-not-smaller` |
| 9 | Success run with a warning line that the fake RTK drops | Fallback `evidence-guard` |
| 10 | stderr present, RTK on | stderr verbatim. RTK's own stderr is not in visible output |
| 11 | Empty or binary stdout | RTK skipped. Policy recorded |
| 12 | Exit codes `0`, `1`, `126`, `127` | Unchanged with RTK on and off |
| 13 | Unmapped command (`npm install`) | Built-in reducer or raw. No RTK call. `compressor` matches |
| 14 | `rtk_mode: off` and `compress_shell: off` | RTK not called |
| 15 | Old `session.jsonl` records plus new ones | `workflow report` sums both correctly |
| 16 | Real RTK on pinned fixtures | Raw and visible bytes recorded. Add to the validation matrix with the RTK version |

Run before committing the implementation:

```bash
bash -n scripts/workflow.sh
for f in scripts/lib/*.sh; do bash -n "$f"; done
jq . config/workflow_settings.json >/dev/null
bash tests/wx-wrapper.test.sh
bash tests/workflow-session.test.sh
git diff --check
```

## Implementation order

1. Config: add `rtk_filters`. (`rtk_mode` values are already `off` or `success-only`.)
2. `wx-compress.sh`: add the RTK step after the existing gates. Keep one function per compressor.
3. `wx.sh`: write the `compressor` object. No other record fields move.
4. Tests 1-15 with the fake RTK.
5. `workflow doctor`: RTK hook warning.
6. Scenario 16, then update `docs/VALIDATION_MATRIX.md` and the README claim, with measured bytes only.

## Prototype status

Implemented:
- **Order:** `wx` runs the command, writes `stdout.raw` and `stderr.raw`, then applies the existing gates, then (only for a mapped command) RTK. Tests prove the raw file is complete when RTK starts (the fake RTK compares its stdin size with `stdout.raw`).
- **Calls:** only `rtk --version` (3 s) and `rtk pipe -f <filter>` (default 10 s). Never `rtk init`. RTK's own stderr goes to `<run dir>/rtk.stderr` and is not shown. A test fails on any other RTK call.
- **Filter map** (`command_policy.rtk_filters`, matched like the other command lists by argv prefix): `cargo test` -> `cargo-test`, `pytest` -> `pytest`, `go test` -> `go-test`, `go build` -> `go-build`, `tsc` -> `tsc`, `vitest` -> `vitest`. `python -m pytest`, `npx vitest`, and `npm test` are not mapped.
- **Denied filters:** `grep rg find fd git-diff git-status git-log` are refused in code, even if a config maps them.
- **When it runs:** exit code 0, profile not protected, command not in `preserve_raw_or_lossless`, `compress_shell` not off, `rtk_mode` not `off` (today: `code`, `rapid-prototype`, `test`, `test-full`, `debug`, `cicd`), stdout non-empty text.
- **Fallback (raw output shown, exit code kept):** `rtk-not-installed`, `rtk-version-failed`, `rtk-nonzero-exit`, `rtk-timeout`, `rtk-empty-output`, `rtk-not-smaller`, `evidence-guard`. The rejected RTK output stays in `rtk.rejected.stdout`. A fallback does not try the built-in reducer. Mapped commands are not on the built-in allowlist anyway.
- **Evidence guard v1.1:** these raw stdout lines must appear (trimmed, as plain text) in the RTK output: lines that start with `error:`, `error[`, `warning:`, `warning[`, `warn:`, `fatal:` (any case) or `panic:`; lines that start with an upper-case `WARN`, `WARNING`, `ERROR`, or `FATAL` token; and lines that contain `Traceback`, `FAILED`, `CVE-`, `: error`, `: warning`, `Warning:`, or ` error TS`. Names like `errors.py::test_a` do not match. A false alarm only shows raw output. The `warn:`, `fatal:`, and upper-case token patterns were added after a test with those formats showed the v1 guard accepted RTK output that had dropped them.
- **`session.jsonl` (additive, `schema_version` stays 2):** flat fields `compressor` (`rtk`, `builtin/exact-repeat-v1`, or `null` when the output is raw), `compressor_version`, `filter` (the RTK filter that was run or tried), `fallback_reason`. `output_policy` is `compress-rtk-v1` or `raw-rtk-fallback`. A fallback has `compressor: null`, so a run is never labelled RTK-compressed unless the RTK output was shown. The built-in reducer now fills `compressor` and `compressor_version` (`1`) too. This replaces the nested `compressor` object sketched above.
- **Test hooks:** `AICONTEXT_RTK_BIN` (path or name, default `rtk`) and `AICONTEXT_RTK_TIMEOUT` (seconds, default 10). They are not policy: `wx` keeps them when it drops stale `AICONTEXT_*` variables.

Observed with real RTK 0.42.4 (test run on this machine):
- For a pytest-like fixture without a warning line, RTK printed one line (`Pytest: N passed`, no trailing newline) and the output was accepted.
- With a `warning:` line in the raw output, RTK's pytest filter dropped it. The evidence guard rejected the output and `wx` showed raw. So for noisy runs that include warnings, the guard decides, and the saving is lost on purpose.
- `rtk pipe` created no files in a scratch `HOME` (checked once, not a guarantee for other versions).

Not done / open:
- `python -m pytest`, `npx` forms, and `npm test` are not mapped. Adding keys needs a fixture each.
- No `log` filter for install and build logs.
- The guard patterns are v1 and need tuning on real runs of each tool. Warning formats that do not match a pattern are not protected. Example: `pytest` warning summaries that do not contain `Warning:`.
- Only byte counts are recorded. No tokenizer, no savings claim.
- `docs/VALIDATION_MATRIX.md` is not updated (one external tool only).
- No Windows path handling. `timeout`, `stat -c`, and `awk` are GNU/Linux tools.
- If RTK's own hook is installed, hooked commands bypass `wx`. Doctor warns (`policy.rtk_hook`). `wx` cannot detect it per command.

## Hardening (2026-10-07)

- **Never `rtk init`:** a test scans the scripts. No script runs it. The text that `install-optional-tools.sh` prints now has the `rtk init` lines commented out, with a note that `rtk init` installs hooks or instructions that skip `wx` capture. Token Controller does not run it. Doctor does not run it.
- **What `rtk init` writes** (found by running it in scratch HOME directories, never in a real one, RTK 0.42.4):
  - Claude (`-g`): `~/.claude/settings.json` (hook `rtk hook claude`), `~/.claude/RTK.md`, `~/.claude/CLAUDE.md` (`@RTK.md`), `~/.config/rtk/filters.toml`, `~/.local/share/rtk/.hook_warn_last`.
  - Copilot (`-g --copilot`): `~/.copilot/hooks/rtk-rewrite.json` (hook `rtk hook copilot`), `~/.copilot/copilot-instructions.md`.
  - Gemini (`-g --gemini`): `~/.gemini/hooks/rtk-hook-gemini.sh`, `settings.json`, `GEMINI.md`.
  - Cursor: `~/.cursor/hooks.json`. Codex (`--codex`): `~/.codex/RTK.md` and `AGENTS.md` (instructions, no hook). OpenCode: `~/.config/opencode/plugins/rtk.ts`. Pi: `~/.pi/agent/extensions/rtk.ts`. Hermes: `~/.hermes/plugins/rtk-rewrite/` and `config.yaml`.
  - Project scoped: Windsurf `.windsurfrules`, Cline `.clinerules`, `rtk init` without `-g` writes `CLAUDE.md` and `.rtk/filters.toml`. Kilo Code and Antigravity refuse `-g` (project scoped). Their project files were not probed.
- **Doctor detection:** `policy.rtk_hook` (warn, in every mode) now covers all the locations above that were probed, by file or folder existence or a word match for `rtk`. A project `.rtk/filters.toml` is a separate `info` (`policy.rtk_project_filters`). Doctor never runs `rtk trust`.
- **Project-local RTK filters:** the generated file says "Filters here override user-global and built-in filters". One probe with a catch-all filter added to `.rtk/filters.toml` did not change the output of `rtk pipe -f pytest`. This is one probe on one version, not a guarantee.
- **Tests added:** RTK not on `PATH` by name, a file without the execute bit, a command without a filter (`cargo build`, `go vet`, `cargo check`: not labelled, RTK not called), a pass-through RTK run (not labelled), nine evidence formats dropped by RTK (fallback to raw) and kept by RTK (accepted), a look-alike line that is not evidence, `wx` stderr after success and after four kinds of fallback (exactly the command stderr plus the raw-log pointer, the RTK notice only in `rtk.stderr`), the static `rtk init` scan, and doctor detection for 15 RTK artifacts, plus no false warning for similar words.
- **Still open:** hooks still bypass `wx` and cannot be detected per command. Project files of Kilo Code and Antigravity, and any `rtk init` layout without `-g` other than Claude, were not probed. The detection is a text and existence check. The guard patterns are still a heuristic: they were tuned with a fake RTK and one real-RTK check, and not with real runs of each of the six tools.
