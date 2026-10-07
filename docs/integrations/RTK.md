# RTK Integration

Status: **pipe-first prototype implemented** in `scripts/lib/wx-compress.sh` and `scripts/lib/wx.sh`. Checked against RTK 0.42.4.

## Direction (2026-10-07)

- RTK is a **post-capture terminal-output filter**.
- `wx` runs the original command **exactly once**. It stores raw stdout, raw stderr, and the exit code first.
- If the command has an enabled `pipe` entry, `wx` may run `rtk pipe -f <filter>` on the captured stdout.
- `wx` never re-runs the original command through RTK (`rtk <command>`). `wx` never runs `rtk init`. `wx` never uses RTK in protected profiles (`raw`, `security`, `db`, `migration`, `release`).
- Smart file reads (`rtk read`, `rtk smart`) are deferred to a later LeanCTX/Headroom decision.
- The whole RTK surface is **not** active through `wx`. RTK documents about 65 commands ([what-rtk-covers](https://github.com/rtk-ai/rtk/blob/develop/docs/guide/resources/what-rtk-covers.md), not re-checked here). `wx` enables only filters that the installed RTK has and that tests validate.

```text
original command (once) -> stdout.raw, stderr.raw, exit_code.raw -> gates -> rtk pipe -f <filter> -> candidate -> evidence guard -> shown, or raw
```

## What `rtk pipe` can do

`rtk <command>` runs the command itself. `wx` never uses it, because it would run the command twice and bypass raw capture. `rtk pipe -f <filter>` only reads text from stdin. This is the only RTK path in `wx`.

Facts from RTK 0.42.4:
- The installed RTK has **18** pipe filters: `cargo-test pytest go-test go-build tsc vitest grep rg find fd git-log git-diff git-status log mypy ruff-check ruff-format prettier`. An unknown filter exits 1. So most documented RTK commands (`docker`, `kubectl`, `gh`, `ls`, `tree`, `npm`, ...) can never be piped.
- `rtk pipe` without `-f` passes text through unchanged. That is not compression and is never labelled as RTK.
- RTK writes notices to stderr ("No hook installed"). `wx` keeps them out of the visible output.
- Some filters drop the final newline, so compare byte counts, not text.

## Classes (`command_policy.rtk_commands`)

One entry per command prefix: `{"match": "cargo test", "class": "pipe", "filter": "cargo-test"}`. The longest matching prefix wins (the first on a tie).

| Class | Meaning | Used by `wx` |
|---|---|---|
| `pipe` | Filter the captured stdout with the named filter. Needs `command_policy.rtk_class_enabled.pipe = true` | Yes |
| `recognized-only` | Known to RTK. Never used. Smart file reading is deferred | No |
| `never` | Never use RTK for this command | No |
| `rerun` | Would run the command again through RTK. **Rejected.** `rtk_class_enabled.rerun` is `false`, and there is no code for it | No |

Resolution is strict. These all resolve to `never` (raw output): an unknown, empty, differently-cased, or non-string class; `rerun`, even when enabled; a `pipe` class that is not enabled (a missing switch means disabled); a `pipe` entry with a missing, malformed, or denied filter. A command with no entry has no class and stays raw (or uses the built-in exact-repeat reducer if it is on the existing allowlist). A missing, non-list, or old `rtk_filters` config means RTK is never used.

Entries in the repository config (18):
- **pipe (6):** `cargo test`, `pytest`, `go test`, `go build`, `tsc`, `vitest`.
- **recognized-only (5):** `cat`, `head`, `tail` (`rtk read`), `rtk read`, `rtk smart`.
- **never (7):** `grep`, `rg`, `find`, `fd`, `git status`, `git diff`, `git log`. RTK has pipe filters for these, but their output is evidence and the guard is not proven for them. The filters are also denied in code, so a config change cannot enable them.

## When RTK runs

All of these must be true:
- Profile is not `raw`, `security`, `db`, `migration`, or `release`, and `rtk_mode` is not `off` (today `code`, `rapid-prototype`, `test`, `test-full`, `debug`, `cicd`).
- Command is not in `preserve_raw_or_lossless`, and `compress_shell` is not `off`.
- The exit code is `0`. Any nonzero exit stays raw, including the first failing `debug` run.
- The command resolves to a `pipe` class.
- `stdout.raw` is non-empty text, and RTK is installed and returns a version.

Only stdout is filtered. stderr is always shown verbatim.

## Fallback and evidence guard

If RTK is called and its result is not safe to show, `wx` shows the raw output. The exit code never changes. `compressor` stays `null`, and `fallback_reason` is one of:

`rtk-not-installed`, `rtk-version-failed`, `rtk-nonzero-exit`, `rtk-timeout`, `rtk-empty-output`, `rtk-not-smaller` (the output must be smaller), `evidence-guard`.

**Evidence guard v1.1.** These lines of the raw stdout must still appear (trimmed, as plain text) in the RTK output: lines that start with `error:`, `error[`, `warning:`, `warning[`, `warn:`, `fatal:` (any case) or `panic:`; lines that start with an upper-case `WARN`, `WARNING`, `ERROR`, or `FATAL` token; and lines that contain `Traceback`, `FAILED`, `CVE-`, `: error`, `: warning`, `Warning:`, or ` error TS`. Names like `errors.py::test_a` do not match. A false alarm only shows raw output. A dropped warning would hide evidence.

A rejected RTK output stays in `rtk.rejected.stdout`, and RTK's own stderr in `rtk.stderr`, both in the run directory.

## Records

Run directory (`.ai-context/raw/<run>/`): `stdout.raw`, `stderr.raw`, and `exit_code.raw`, written right after the command ends and **before** any RTK step. If `wx` is killed during RTK, the raw output and the exit code are still on disk, and no session record exists yet.

`session.jsonl` (additive fields, `schema_version` stays 2):
- `rtk_class`: the resolved class of the command (`pipe`, `recognized-only`, `never`) or `null` with no entry. It is a classification, not proof that RTK ran.
- `compressor` (`rtk`, `builtin/exact-repeat-v1`, or `null` when the output is raw), `compressor_version`, `filter` (the filter run or tried), `fallback_reason`.
- `output_policy` is `compress-rtk-v1` or `raw-rtk-fallback` for RTK runs.

All numbers are bytes, not tokens. No savings claim is made.

Test hooks (not policy): `AICONTEXT_RTK_BIN` (default `rtk`) and `AICONTEXT_RTK_TIMEOUT` (seconds, default 10).

## Hooks and `rtk init`

Token Controller never runs `rtk init`. `rtk init` installs hooks or instructions that make agents run commands through RTK directly, so `wx` capture is skipped for those commands. `workflow doctor` warns (`policy.rtk_hook`, every mode) when it finds them.

Where `rtk init` writes (found in scratch HOME directories, RTK 0.42.4):
- **Claude:** `~/.claude/settings.json` (hook `rtk hook claude`), `RTK.md`, `CLAUDE.md` (`@RTK.md`). **Copilot:** `~/.copilot/hooks/rtk-rewrite.json`, `copilot-instructions.md`. **Gemini:** `~/.gemini/hooks/`, `settings.json`, `GEMINI.md`. **Cursor:** `~/.cursor/hooks.json`. **Codex:** `~/.codex/RTK.md`, `AGENTS.md`. **OpenCode:** `plugins/rtk.ts`. **Pi:** `~/.pi/agent/extensions/rtk.ts`. **Hermes:** `~/.hermes/plugins/rtk-rewrite/`.
- **Project scoped:** `.windsurfrules`, `.clinerules`, `CLAUDE.md` and `.rtk/filters.toml` (project-local filters, an `info`). Kilo Code and Antigravity project files were not probed.

Doctor also checks the RTK class config (`rtk.config*` findings): unsupported classes, `rerun` entries or `rerun` enabled, denied or malformed filters, a non-list `rtk_commands`, the old `rtk_filters` key, and a disabled `pipe` class.

## Tests

`tests/wx-wrapper.test.sh` (fake RTK in `tests/fixtures/bin/rtk`, plus one real-RTK check when `rtk` is installed): all six pipe commands; raw output and exit code on disk when RTK starts; kill during RTK; failing runs; every protected profile, also with every class enabled; commands without a filter or entry; `recognized-only` (`cat`, `head`, `tail`, `rtk read`, `rtk smart`) and `never`; unsupported, empty, and misspelled classes; non-list, null, and non-object config shapes; `rerun` entries with `rerun` enabled; a disabled or missing `pipe` switch; missing, malformed, and denied filters (no injection); longest prefix in either order; every fallback reason; nine evidence formats; RTK stderr never in the visible output; no RTK call except `--version` and `pipe -f`; no `rtk init`. `tests/doctor.test.sh` covers the hook locations and the class config checks.

## Open

- **Expansion:** the pipe ceiling is 18 filters. Candidates are `mypy`, `ruff-check`, `ruff-format`, `prettier`, and `log`, one at a time, each with fixtures. `grep`, `rg`, `find`, `fd`, `git-*` stay `never` until the guard is proven on them. `python -m pytest`, `npx` forms, and `npm test` have no entry.
- **Evidence guard:** a heuristic, tuned with a fake RTK and one real-RTK check. Real RTK's `pytest` filter drops `warning:` lines, so the guard falls back to raw for runs that have warnings. No real-output fixtures per tool yet.
- **Validation:** only byte counts. `docs/VALIDATION_MATRIX.md` has no RTK entry, and the benchmark has no RTK scenario.
- **Hooks:** hooked commands bypass `wx`. Doctor warns but cannot see it per command.
- **Side effects:** `rtk --version` and `rtk pipe` were checked once in a scratch HOME. A project `.rtk/filters.toml` may override built-in filters (one probe saw no effect on `rtk pipe -f`).
- **Rejected for now:** re-running a command through RTK (`rerun`). **Deferred:** smart file reading.
- GNU tools (`timeout`, `stat -c`, `awk`) are assumed.
