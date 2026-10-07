# Technical Debt

## Open issues (quick view)

Last reviewed: 2026-10-07. This table is the **current state**. The sections below are the detailed history and findings. Their "Open" lists are not kept up to date, so use this table.

How to keep it:

* **Add a row** when a new debt, decision, missing feature, risk, or contradiction is found. Use the next free ID (never reuse an ID). Add the details as a section below, in the same style as now.
* **Remove the row** when the issue is fixed. Do not mark it "done" in the table. Say what was fixed in the details section.
* **Change the Status** when it moves (Open, Mitigated, Decision needed). Update "Last reviewed".
* Types: **Debt** (code or doc that should change), **Contradiction** (text says something false), **Not implemented** (planned, not built), **Decision** (needs an owner decision), **Risk** (known and accepted or unresolved exposure).
* Severity: **High** (blocks the product direction or can hide evidence), **Medium** (limits a release or weakens a guarantee), **Low** (tidy-up).

| ID   | Type            | Severity    | Area            | Issue                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Status                                             | Details                                                                               |
| ---- | --------------- | ----------- | --------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------- | ------------------------------------------------------------------------------------- |
| D-01 | Not implemented | Medium      | Orchestration   | LeanCTX phase one is implemented as a controller adapter:`workflow leanctx` (`scripts/leanctx-cli.sh`) reads `active_mode.env` and `leanctx_policy`, refuses off and protected modes (raw, security, db, migration, release, micro, snippet, off), refuses a project-local, relative-path, or Windows-under-WSL lean-ctx binary, and runs only bounded CLI operations (`read`, `grep`, `ls`, `--version`) on explicit request. It never runs wrap, setup, init, a shell, or `wx`. Exact reads are controller-verified only (`workflow leanctx read-exact`), and `templates/AGENTS_base.md` points agents to the adapter (policy only, depends on agent compliance). Open: there is no automatic orchestration (no mode or agent starts LeanCTX by itself), and MCP behavior (`ctx_read`, `ctx_search`, `ctx_tree`, `ctx_compose`) is unverified, including whether `ctx_read` is exact.                                                                                                                                                                                                                                       | Mitigated (phase one). Open for automation and MCP | LeanCTX adapter (this file)                                                           |
| D-02 | Decision        | Low         | Orchestration   | Headroom is deferred. It is not the next tool.`headroom_mode` is exported state only, and there is no design doc and no code. The current plan has three layers: RTK (terminal output through `wx`), LeanCTX (controlled file, search, and tree exploration), and Caveman (terse output, off by default). Revisit Headroom after a working release of those three. No release blocker.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Deferred                                           | Plan: RTK + LeanCTX + Caveman                                                         |
| D-03 | Not implemented | Low         | Config          | `leanctx_mode` is consumed: `workflow leanctx` gates on `AICONTEXT_LEANCTX_MODE` from `active_mode.env`, and its values are tested for all 22 modes. `compress_shell` and `rtk_mode` are consumed by `wx`, and `caveman_mode` by `wx` and `doctor`. Still exported with no consumer: `compress_files`, `memory_layer`, `codebase_index`, `headroom_mode`, `keep_raw_logs`, and `raw_on_fail`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Open (narrowed)                                    | Foundation debt status                                                                |
| D-04 | Decision        | Medium      | Config          | MemStack is legacy and is not the planned next integration.`MEMSTACK_ACTIVE` and `memory_layer` stay as exported state until a decision removes them. Decision note: evaluate `claude-skills` (alirezarezvani/claude-skills) or selected skill and persona packages as a skills and personas layer, not as a runtime memory layer.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Decision needed                                    | Skills/personas evaluation (this file)                                                |
| D-06 | Decision        | Low         | Validation      | RTK has a benchmark (`benchmarks/run-rtk-benchmark.sh`) and validation matrix entries, but only as byte counts on 59 fixtures (42 in the benchmark, 17 demoted-command regressions) with one RTK version (0.42.4), hand-written input for 8 filters (`cargo-test`, `mypy`, `ruff-check`, `ruff-format`, `prettier`, `rg`, `fd`, `log`), and no tokenizer. The RTK benchmark is not in CI. The validation matrix becomes the required record for every mode or policy change after a second tool is integrated.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | Decision needed                                    | RTK benchmark expansion is needed only after first release and bigger audience tests. |
| D-07 | Debt            | Low         | RTK             | The installed RTK has 18 pipe filters. 14 are enabled (16`pipe` entries) and have fixtures; `tsc`, `go-test`, `ruff-format`, `prettier` are `recognized-only` (D-38) in `tests/fixtures/rtk/MATRIX` (success, evidence or failing case, protected profiles, fake and real outcomes pinned). Fixtures are small: no per-tool variants (flags, big repositories), and `mypy`, `ruff-*`, `prettier`, `rg`, `fd`, `log` input is hand-written. The other 46 documented commands are `recognized-only` and cannot be piped. Measured with real RTK 0.42.4 on the benchmark: of 7 runs that reached RTK, 4 were accepted (70.74% to 99.41% fewer bytes) and 3 fell back to raw with `evidence-guard` (0%), all 3 with warning lines in stdout. The built-in exact-repeat reducer gave 0.00% on 13 of the 15 successful recordings. The guard is still a heuristic and cannot see wrong or lossy summaries (D-38).                                                                                                                                                                                                                     | Open                                               | RTK benchmark (this file)                                                             |
| D-08 | Risk            | Medium      | RTK             | An RTK global hook rewrites commands and skips`wx` capture. Doctor now warns about the hook or instructions that `rtk init` writes for Claude, Copilot, Gemini, Cursor, Codex, OpenCode, Pi, Hermes, `.windsurfrules`, and `.clinerules`. Hooks still bypass `wx`, per-command detection is impossible, and Kilo Code, Antigravity, and other project layouts were not probed.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Open                                               | RTK hardening (this file)                                                             |
| D-09 | Risk            | Low         | RTK             | Side effects of`rtk --version` and `rtk pipe` (tracking, telemetry) were checked once, in one scratch `HOME`. `rtk init` was seen to write `~/.config/rtk/filters.toml` and `~/.local/share/rtk/.hook_warn_last`. Project-local `.rtk/filters.toml` may override built-in filters (one probe saw no effect on `rtk pipe -f`).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Open                                               | RTK hardening (this file)                                                             |
| D-10 | Not implemented | Medium      | Caveman         | Prompt guards are not applied (the phrases are stored only). Failure evidence is partly mechanical:`debug` and the other blocked modes cannot have Caveman on, failing `wx` output is always raw, `wx` records the Caveman level and prints a reminder on a failed run when Caveman is on, and doctor warns when Caveman is active after a failed run. Whether the agent obeys is policy only. The plugin's own state cannot be changed by Token Controller.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Open                                               | Caveman safety (this file)                                                            |
| D-11 | Not implemented | Medium      | Caveman         | Shrink and proxy are not implemented (`caveman_shrink` has no effect). Upstream questions are open: state file format, session-start hook, `caveman-compress` vs the managed block, gateway data flow.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Open                                               | `docs/integrations/CAVEMAN.md`                                                      |
| D-13 | Risk            | Medium      | Stale terminals | Already-open terminals keep old`AICONTEXT_*` variables. `wx` and `report` are protected. A person, script, or agent that reads the variables directly can see the wrong profile. The extension cannot inspect terminals.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Mitigated                                          | Stale terminal safety                                                                 |
| D-14 | Debt            | Medium      | `workflow.sh` | `workflow setup` writes the same instruction to several user-level files without a conflict check.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Open                                               | Foundation debt status                                                                |
| D-15 | Debt            | Low         | `workflow.sh` | `workflow.sh` runs `mkdir -p ~/.config/ai-workflow` before any command, so `doctor`, `status`, and `help` are not read-only through it. Documented, not fixed.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      | Open                                               | Workflow --doctor                                                                     |
| D-16 | Debt            | Low         | `workflow.sh` | `workflow help` mode list and `Aliases:` lines are hand-written, a fourth copy of the mode list.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          | Open                                               | `workflow modes --json`                                                             |
| D-17 | Debt            | Low         | `workflow.sh` | `off-*` labels: `workflow.sh` treats only exact `off` as RTK off, `wx` treats `off` and `off-*` as off. No config value triggers it today.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Open                                               | Foundation debt status                                                                |
| D-18 | Debt            | Low         | Config          | The Caveman level rules exist twice (bash and jq). The blocked list exists in four places (`workflow.sh` twice, `doctor.sh`, config). Tests guard them.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                   | Open                                               | Caveman policy state                                                                  |
| D-19 | Debt            | Low         | Config          | Legacy`caveman_output` key stays in config defaults but is not read. Kept so the validation matrix entry stays true.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        | Open                                               | Foundation debt status                                                                |
| D-20 | Contradiction   | Low         | Scripts         | `scripts/check-tools.sh` prints that `wx` does not invoke RTK. `wx` now calls `rtk pipe` for six commands.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            | Open                                               | Debt review (this file)                                                               |
| D-21 | Debt            | Low         | Scripts         | `ccusage` is checked by doctor but not by `check-tools.sh` or `install-optional-tools.sh`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                              | Open                                               | Debt review (this file)                                                               |
| D-22 | Debt            | Low         | Docs            | README does not document`AICONTEXT_USE_SHELL_STATE`, `AICONTEXT_CAVEMAN_REQUEST`, `AICONTEXT_RTK_BIN`, `AICONTEXT_RTK_TIMEOUT`. README is long (475 lines).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           | Open                                               | Debt review (this file)                                                               |
| D-23 | Contradiction   | Low         | Docs            | `docs/MODE_SWITCHER_AND_ORCHESTRATOR_PLAN.md` "Documents to revise" table and work packages are out of date.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Open                                               | Debt review (this file)                                                               |
| D-24 | Debt            | Low         | Doctor          | MCP config checks are text matches only: doctor lists known config files that mention`lean-ctx` and does not parse them or check that the server works. RTK setup detection is a text match on known Claude Code locations. `.caveman-active` format is assumed to be a level name. LeanCTX hook detection is a text match on shell startup files. Doctor warns about a lean-ctx inside the project and does not run it.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  | Open                                               | Doctor improvements                                                                   |
| D-25 | Not implemented | Medium      | CLI             | No`set --json`. `wx` is not reachable through `workflow-cli.sh`. `status --json` has no `description` or `caveman_shrink`. The extension does not call `version --json` yet: it checks only the `schema_version` of each reply.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Open                                               | `workflow report --json` (this file)                                                |
| D-26 | Not implemented | Medium      | Extension       | The extension does not show the report summary (the CLI side,`report --json`, now exists), the doctor summary, or tool availability. The extension shows the LeanCTX adapter status through one command (`Token Controller: Show LeanCTX Status`, output channel, cached one-line tooltip), and nothing else from LeanCTX. No Caveman toggle. `caveman_requested` is not shown.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         | Open                                               | `workflow report --json` (this file)                                                |
| D-27 | Not implemented | Medium      | Windows         | No Windows or WSL backend, no environment check (`remoteName`, distro), no Windows CI. The CLI uses GNU tools (`timeout`, `stat -c`, `awk`) and Bash.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Open                                               | Extension alignment design                                                            |
| D-28 | Debt            | Medium      | Extension       | Not tested in a real VS Code or WSL window.`vscode-test` was not run. The status bar, picker, and watcher code has no automated test. Manifest scope, `inspect()`, and `isTrusted` behavior are untested.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Open                                               | Extension configuration and trust hardening                                           |
| D-29 | Decision        | Low         | Extension       | Release of extension 2.0.0 is deferred on purpose. Version, changelog, and packaging are prepared, and the built VSIX is no longer tracked. It is not published, not tagged, and not smoke-tested (D-28). There is no release process, and CI does not upload the VSIX.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Deferred                                           | Extension package metadata (this file)                                                |
| D-30 | Risk            | Medium      | Extension       | The configured script is trusted code with no check of content or owner. A trusted workspace may contain the controller. The CLI inherits the host environment. Multi-root and virtual workspaces are only partly covered.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                    | Risk accepted                                      | Extension configuration and trust hardening                                           |
| D-31 | Debt            | Low         | Extension       | Missing`jq` or an old controller shows "unavailable" with no install help. `stale_shell` describes the VS Code environment, not a terminal.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               | Open                                               | Extension uses the CLI JSON interface                                                 |
| D-32 | Not implemented | Low         | Research        | Research candidates are not evaluated: ccusage, Aider repo map, token-optimizer, token-savior.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                | Open                                               | Plan, "External tools"                                                                |
| D-33 | Debt            | Low         | Config          | The flags`raw_on_fail`, `keep_raw_logs`, `preserve_*`, `target_files_full`, and `compress_files` are exported but read by nothing. `wx` hard-wires the safe behavior, so setting them to `false` has no effect. Keeping target files full is policy only.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Open                                               | Profile/state manager review in`VALIDATION_MATRIX.md` (F2)                          |
| D-35 | Debt | Low | CI | `cli-ci.yml` runs on GitHub and is green on `lean-ctx-integration`: run [37664150827](https://github.com/juhanikol/token-controller/actions/runs/37664150827) (push, commit 7003268, 2026-10-07) passed all steps (executable bits, syntax, JSON, wx, session, doctor, LeanCTX harness, benchmark) in about 85 seconds. Two earlier pushes on the branch (f927284, 4eef122) also passed. Triggers: every branch push, pull requests to `main`, and `workflow_dispatch`. Not covered: `workflow_dispatch` and a pull request run have not been triggered yet, the real RTK and real lean-ctx are not used (the LeanCTX harness skips the real part), the RTK benchmark (`benchmarks/run-rtk-benchmark.sh`) is not a CI step, and the runner is Ubuntu 24.04 only. `vscode-extension-ci.yml` runs only for `main` and extension paths, so it did not run on this branch. | Open (green, limits remain) | CLI CI (this file) |
| D-36 | Decision        | Low         | RTK             | Re-running a command through RTK (`rtk <command>`, class `rerun`) is rejected for now. The class exists in the config as a name only, `rtk_class_enabled.rerun` is `false`, no code path exists, and any `rerun` entry resolves to `never`. It could return only for an explicit read-only list, if measurements show a gap that `rtk pipe` cannot cover.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                       | Rejected / deferred                                | RTK pipe-first (this file)                                                            |
| D-37 | Not implemented | Low         | RTK             | Smart file reading is deferred in RTK:`cat`, `head`, `tail` (`rtk read`), `rtk read`, and `rtk smart` are `recognized-only` and never used. Boundary now: RTK owns terminal output through `wx`. LeanCTX owns controlled file, search, and tree exploration through `workflow leanctx`. Exact reads are guarded: `workflow leanctx read-exact` prints LeanCTX output only if it equals the file byte for byte (D-39). Open: MCP exact-read behavior is unverified, and Headroom's boundary is undefined (D-02, deferred).                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 | Deferred                                           | RTK pipe-first (this file)                                                            |
| D-38 | Debt            | Medium      | RTK             | Narrowed. The matrix found 12 shown RTK outputs that lost evidence (RTK 0.42.4). Fixed: the guard now rejects an RTK output that says it left something out (`+10 more dirs`, `[+24 lines omitted]`) unless raw has the text, so `find`, `fd`, `git log` fall back to raw. Moved to `recognized-only` (RTK states something wrong or loses names, and the guard cannot see it): `tsc` (informational runs became "TypeScript compilation completed", quiet runs have no stdout), `go test` (plain output became "No tests found"), `ruff format`, `prettier`, and `pytest --collect-only`. Open: the guard still cannot see a summary that changes counts or names without an omission marker, so any new filter or RTK version needs the matrix. `go build` stays: its stdout is empty, so it is harmless. Fixtures of the moved commands are kept (group X in `MATRIX`) and must stay raw.                                                                                                                                                                                                                                        | Open (narrowed)                                    | RTK matrix (this file)                                                                |
| D-39 | Risk            | Medium-High | LeanCTX         | The real lean-ctx 3.9.19 CLI exact read is not trusted: in this environment`read -m full --fresh` and `-m raw` returned headings plus "526 lines filtered by triage" (2032 of 31175 bytes), 44 bytes in a clean environment, and `grep "AICONTEXT" .` returned no matches. Mitigated: the controller adapter fails closed. `workflow leanctx read-exact` prints nothing and exits 3 unless the output equals the file byte for byte, and `workflow leanctx search` exits 3 when a raw grep finds files that LeanCTX output never names. Both fired with the real tool. The agent rules now match this: exact edits use a raw read or `workflow leanctx read-exact`, LeanCTX output is not exact unless verified, output that says it was filtered or shortened is not trusted, agents must not call `lean-ctx` directly, and MCP tools are for exploration only. Open: the MCP `ctx_read` is untested, and nothing in code stops an agent from calling lean-ctx directly (the rule depends on agent compliance). Real calls also write LeanCTX data and start its daemon.                                                                     | Mitigated                                          | LeanCTX adapter (this file)                                                           |

## Remaining contradictions (fixing these changes code or behavior, so I left them)

* **[extension.ts](vscode-webview://1d92r06pf6r5i5e0tlt3ud5jsfuc048p2sdg47044c8hftprks6p/extensions/vscode/src/extension.ts):** its mode list is hard-coded and partial. The new extension README lists this as a limitation.
* **[workflow.sh](vscode-webview://1d92r06pf6r5i5e0tlt3ud5jsfuc048p2sdg47044c8hftprks6p/scripts/workflow.sh):**
  * `setup` writes the same instruction to several user-level files without checking for conflicts.
  * The mode list in the header comment is out of date (missing `data-analysis` and `rapid-prototype`). You said not to change scripts here.
* **Tool scripts:** `check-tools.sh` and `install-optional-tools.sh` have no Caveman entries.
* **[workflow\_settings.json](vscode-webview://1d92r06pf6r5i5e0tlt3ud5jsfuc048p2sdg47044c8hftprks6p/config/workflow_settings.json):**
  * The `rtk_mode` values are our own labels, not real RTK options.
  * The `micro`, `caveman_output` and `default_output_style` keys don't exist yet.
* **README:** it is still long. Its repository layout section is missing `tests/`, `extensions/` and the newer docs. It also repeats the extension install steps that are now in the extension README.
* **[templates/AGENTS\_base.md](vscode-webview://1d92r06pf6r5i5e0tlt3ud5jsfuc048p2sdg47044c8hftprks6p/templates/AGENTS_base.md)** (from the earlier review, out of scope here): it mentions "legal/compliance", but no such mode exists. It also dropped the rule to keep the stack trace and file:line details of the first failure in `debug`/`test`.

## MICRO

True mode or alias

`micro` is a true mode, a copy of `snippet`. An alias would have needed a code change in `workflow.sh`, and `snippet` stays exactly as it was.

## Compatibility concerns

* **`default_output_style` is not read by anything yet.** `workflow.sh` doesn't export it, so it has no effect until we add an `AICONTEXT_OUTPUT_STYLE` export. That is a script change, which you said to leave out.
* **`caveman_output` stays `false`.** `workflow.sh` only reads `caveman_output` per mode, not from `defaults`, so Caveman can't activate through this key yet. The `defaults` entry is a declaration only.
* **RTK in `micro` is plain `off`.** Any `rtk_mode` other than `off` sets `RTK_HOOK_ENABLED=true`, so I couldn't express "RTK only when output is noisy" without a script change. The tiny-task rule in `templates/AGENTS_base.md` still covers that case in prose.
* **Unknown top-level key.** `legacy_notes` is new. Nothing in the scripts, `wx` or the extension iterates over top-level keys, so it is harmless.
* **Extension picker.** The mode list in [extension.ts](vscode-webview://1d92r06pf6r5i5e0tlt3ud5jsfuc048p2sdg47044c8hftprks6p/extensions/vscode/src/extension.ts) is hard-coded and does not include `micro`, so it can't be selected from the status bar yet. `workflow micro` works from the terminal.

## Workflow --doctor

**Things to know**

* **Missing `scriptPath`:** if the user never set it, a missing default path is a `warn`. If the user set it explicitly, a missing path is an `error`.
* **Duplicate policy is a `warn`:** the documented `workflow init` plus `workflow setup` flow puts the policy text in more than one place by design. Expect this warning for users who ran both.
* **Hook mismatch check:** the check for "RTK mentioned in Claude settings while the mode sets rtk off" is a plain text match. It won't parse the hook structure.
* **Not checked:** MCP config files are skipped. They were in the design doc but not in your list for this task, and I kept doctor's scope to your list.
* **`mkdir`:** `workflow.sh` runs `mkdir -p` on `~/.config/ai-workflow` before it reaches any command. So `workflow doctor` can create that empty directory on a fresh machine. `doctor.sh` run directly never writes anything.
* **JSON paths:** the JSON `paths` entries for the duplicate alias include a line number (`~/.bashrc:128`). This differs slightly from the design doc's separate `path` and `line` fields.

## RTK PLAN

### Findings from the probe

* **Coverage is small.**
  * `rtk pipe` has only 18 filters: cargo-test, pytest, go-test, go-build, tsc, vitest, grep, rg, find, fd, git-log, git-diff, git-status, log, mypy, ruff-check, ruff-format and prettier.
  * There is none for `npm install`, `docker build`, `pip install`, `npm test` or `dotnet test`. Those are the commands the current allowlist treats as noisy.
  * Keeping raw capture first means we lose RTK's per-command wrappers for them. The doc states this as a cost.
* **No filter means no compression.**
  * `rtk pipe` without `-f` passes input through unchanged, so `wx` must not label that run as RTK compression.
* **RTK prints notices to stderr.**
  * It prints "No hook installed" on stderr. The design keeps that out of the visible output and saves it in a file in the run directory.
* **The `cargo-test` filter drops the final newline.**
  * This is why the design records byte counts and doesn't assume the text is identical.

### Decisions for you

1. **RTK hook conflict.**
   * `rtk init -g` installs a hook that rewrites commands to run through RTK directly. For those commands `wx` never sees the raw output.
   * I propose that `workflow doctor` warn about any RTK hook, not only when the mode has RTK off, and that Token Controller never runs `rtk init`.
2. **Initial filter map.**
   * I limited it to `cargo-test`, `pytest`, `go-test`, `go-build`, `tsc` and `vitest`.
   * I excluded the search and diff filters (`grep`, `rg`, `find`, `fd`, `git-*`) because their output is evidence. The generic `log` filter is a candidate for install and build logs once fixtures pass.
3. **`debug` mode and `rtk_mode`.**
   * `debug` has `rtk_mode: "off-first-failure"`. The code already treats any value starting with `off` as off, so RTK would never run in `debug`.
   * Since failures stay raw anyway, I suggest simplifying the values to `off` and `success-only`. This is the first implementation step in the doc.
4. **Evidence guard.**
   * It is a proposal of mine, not something you asked for. After RTK runs, lines starting with `error`, `warning` or `panic:`, and lines containing `Traceback`, `FAILED` or `CVE-`, must still appear in the output. Otherwise `wx` shows the raw output.
   * False fallbacks are safe. A missed warning is not. The exact pattern needs tuning against fixtures.

**Unverified:** RTK has `[tracking] enabled = true` in its config. I did not check whether `rtk pipe` writes usage history. The doc says to check before implementing, and `wx` must never edit `~/.config/rtk`.

## Caveman policy

### What I could and couldn't verify

* **Verified from the Caveman quickstart:**
  * the levels `lite`, `full`, `ultra` and `wenyan`
  * the `/caveman` switch and the "stop caveman" phrase
  * the state file `~/.claude/.caveman-active`
  * the skill's input cost of about 1,650 tokens
  * the warning that one-line questions can cost more than they save
* **Not verified:** the `shrink`, `proxy` and `stats` commands. The quickstart doesn't describe them and my search found no usable docs. The doc keeps shrink/proxy as an opt-in experiment with constraints that hold whatever the real design is. Those constraints are never on raw evidence, never in place on a user file, and recorded in `session.jsonl` like RTK. It says to read the upstream docs first.
* **Savings numbers:** sources disagree (about 65% in project text, 8.5% in one JetBrains test). The doc quotes no number and requires an A/B measurement before any claim.

### Decisions for you

1. **Policy, not enforcement.** The prompt guards and "first failure" rules depend on the agent. The CLI can't read prompts, so I labelled them as policy. A Claude Code `UserPromptSubmit` hook example is the only mechanical option I proposed, and only as an opt-in example.
2. **No automatic token-pressure detection.** The user opts in. This is simpler, but it differs from "high token pressure" as a trigger.
3. **Opt-in input.** I suggested an env var such as `AICONTEXT_CAVEMAN_REQUEST=lite workflow code`, but the name and shape are open.
4. **STE and Caveman are mutually exclusive.** Caveman drops articles and STE keeps them, so the output style is one or the other.
5. **Doctor follow-up.** Doctor should read `.caveman-active`. Active in a hard-blocked mode is an `error`, above `caveman_max` or without opt-in is a `warn`, and not installed is an `info`.
6. **`ultra` and `wenyan` unsupported.** `ultra` loses clarity. `wenyan` isn't English.

## Extension alignment design

### Problems in the current extension

* **Shell injection:** `exec("bash -c \"source \\\"${scriptPath}\\\" ${mode}\"")` builds a shell string from the `scriptPath` setting.
* **Security hole:** `tokenController.scriptPath` has the default `window` scope, so a repository's `.vscode/settings.json` can set it. A cloned repo could make the extension run an arbitrary script. The manifest has no Workspace Trust restriction either.
* **Mode drift:** the `MODES` list is hard-coded and misses 9 of the 22 profiles, including `micro`, `docs` and `release`.
* **Fragile parsing:** the active profile is read by regex from `active_mode.env`, and risk isn't shown at all.

### What should wait

* **Report summary in the tooltip:** needs `report --json`, `--project`, and a watcher on `session.jsonl`. This is phase 2, directly after the first implementation.
* **Windows backend:** `WslBackend` or a native one, and a Windows CI job.
* **Bundling the CLI in the VSIX:** this removes the dependency on the repo path, but it makes the extension ship the controller too. It is a release decision, not a first-step one.
* **Doctor webview:** and any quick fixes, which need a separate `--fix` design.
* **Caveman opt-in toggle and per-tool toggles:** these depend on the policy implementation.
* **Multi-root workspaces:** one profile per folder.
* **Marketplace publishing.**

### Decisions for you

1. **Stale terminals.**
   * The extension can only write `active_mode.env`. A terminal that already sourced `workflow <mode>` keeps its old `AICONTEXT_*` variables.
   * `wx` reads the env file only when `AICONTEXT_PROFILE` is unset (`wx.sh`). So after a switch from the status bar, an old terminal can still apply the old profile, including in protected modes.
   * Options:
     * a CLI change so `wx` prefers the file
     * VS Code's `environmentVariableCollection` for new terminals
     * a "restart terminals" prompt
   * I'd pick the first, since `wx` is the safety layer.
2. **`status` source.** `status --json` reads the env file, not the calling shell. This differs from the current `workflow status`, which prints shell variables. I'd keep both and name the difference.
3. **Config `description` field.** Each mode needs one. It would also let `workflow help` be generated from config, removing a second copy of the mode list.

## Foundation debt status (2026-10-07)

Fixed:

* `integrations/README.md` no longer claims automatic governance of MCP servers
* Docs and help text: `workflow.sh` header lists all modes, help lists `rapid-prototype`, README extension install detail points to `extensions/vscode/README.md`, README layout and command table are current, template first-failure rule restored, "legal/compliance" removed from the template.
* Tool scripts: `check-tools.sh` and `install-optional-tools.sh` have Caveman entries. Nothing is installed automatically. MemStack is labelled legacy.
* `micro` is a true mode (not an alias).
* `default_output_style` is `"ste-inspired"` in config and exported as `AICONTEXT_OUTPUT_STYLE`.
* Caveman policy keys exist in config (`caveman_mode`, `caveman_max`, `caveman_shrink`, `caveman_policy`). All default to `off`. `workflow.sh` exports the resolved state only (`AICONTEXT_CAVEMAN_MODE`, `AICONTEXT_CAVEMAN_MAX`, `AICONTEXT_CAVEMAN_SHRINK`). Levels other than `off`, `lite`, `full` (for example `ultra`, `wenyan`) resolve to `off` with a warning. Nothing calls Caveman.
* Every mode has a `description` in config.
* `rtk_mode` labels are `off` or `success-only`. Old labels (`noisy-success-only`, `aggressive-success-only`, `tests-safe`, `off-first-failure`, `install-build-noise`) are gone. `RTK_HOOK_ENABLED` is unchanged for every mode.

Open:

* **`workflow setup` conflict:** it writes the same instruction to several user-level files without a conflict check.
* **Extension hard-coded modes:** `extension.ts` has its own partial mode list.
* **Extension security:** `exec` with a shell string, and a workspace-settable script path.
* **RTK implementation:** `rtk_mode` is only exported as state. `wx` does not call RTK. See `docs/integrations/RTK.md`. The `aggressive` vs `safe` distinction is dropped until RTK is implemented. Add a separate key then, if needed.
* **Caveman execution:** not implemented. There is no opt-in input (`AICONTEXT_CAVEMAN_REQUEST` is a proposal), no prompt guards, no doctor check for `.caveman-active`. `prompt_guards`, `blocked_tasks`, `supported_levels`, `unsupported_levels`, and `opt_in_required` in `caveman_policy` are stored, not read.
* **Output style is state only:** nothing consumes `AICONTEXT_OUTPUT_STYLE` yet (the template does not mention it).
* **Help text is hand-written:** `workflow help` is not generated from the config `description` fields.
* **`off-*` labels:** `workflow.sh` treats only the exact value `off` as RTK off. `wx` treats `off` and `off-*` as off for `compress_shell`. No config value triggers the mismatch today.
* **Legacy `caveman_output` key:** still in config defaults, but no longer read. The export is derived from the resolved level. It stays so the existing validation matrix entry (every `caveman_output` is `false`) remains true.
* **Stale `.vscode/settings.json`:** a tracked legacy file with an old `modes` object (including `caveman_output: true`). Nothing reads it.
* **`docs/integrations/CAVEMAN.md`:** keeps "legal and compliance-like work" as a blocked task type. It is a task guard, not a mode.

## Doctor improvements (2026-10-07)

Fixed:

* RTK hook or setup is a `warn` in every mode (`policy.rtk_hook`). Doctor never runs `rtk init` and never touches `~/.config/rtk`. The only tool command it runs is `--version`.
* Caveman checks: installed (command or Claude Code skill), `.caveman-active` level, `error` in hard-blocked profiles, `warn` for no opt-in, above Token Controller level, and `ultra`/`wenyan`.
* Duplicate policy text is a `warn`. Tests assert it.
* Side effect of `workflow.sh` (`mkdir -p ~/.config/ai-workflow`) is stated in help text and as an `info` finding.
* JSON `paths` entries are `{path, line}` everywhere.

Still open for doctor:

* **MCP config checks** are not implemented.
* **`workflow.sh` still creates `~/.config/ai-workflow`** before it dispatches `doctor` (and `status`, `help`). Moving the `mkdir` after the early commands would make doctor truly read-only through `workflow.sh`. It is a behavior change, so it was not done.
* **Caveman opt-in** is the env file value only. There is no request input yet.
* **RTK setup detection** is a text match on known Claude Code locations. Other hosts (Copilot, Cursor) are not checked.
* **`.caveman-active` format** is assumed to hold the level name. Unknown values give a `warn`.
* **Doctor JSON has no consumer yet.** `schema_version` stays `1` until the extension uses it.

## Extension security and mode drift (2026-10-07)

Fixed in `extensions/vscode` (not yet released, the tracked `.vsix` is still 1.1.0):

* Shell string removed. `execFile('bash', ['-c', 'source "$1" "$2"', 'bash', script, mode])` passes values as arguments. A test shows the old string form ran an injected `touch` from a crafted path, and the new code does not.
* `tokenController.scriptPath` has `machine` scope. Workspace values are ignored and the user gets one warning. The path must be absolute (or `~/`), exist, and be named `workflow.sh`.
* `capabilities.untrustedWorkspaces`: `limited`, with the setting restricted. Mode switching works in untrusted workspaces because it uses only user-level settings.
* Mode ids are validated (`^[a-z0-9][a-z0-9-]*$`) and must be in the loaded list before they reach the shell.
* The mode list is read from `config/workflow_settings.json` beside the script. The built-in fallback has all 22 modes and is marked temporary. A unit test fails if the fallback differs from the repository config.
* Risk is shown in the status bar and picker (`AICONTEXT_RISK` for the active mode, `risk` from config for the list).

Still open:

* **Dynamic mode loading:** the extension parses the config itself. The planned `workflow-cli.sh modes --json` is not built. The fallback list can drift when the extension runs without the repository config. `AICONTEXT_SETTINGS_FILE` is not honored.
* **Windows:** `runModeSwitch` needs Bash and returns an error on `win32`. No backend interface yet (`docs/EXTENSION_ALIGNMENT_DESIGN.md`).
* **Not verified in a real VS Code host:** `npm test` (`vscode-test`) was not run. The unit tests ran with plain mocha. `inspect().globalValue` behavior in a WSL remote window is untested.
* **Stale terminals:** mitigated, not solved. `wx` and `workflow report` use `active_mode.env`, and the AGENTS template tells agents to read it. A terminal that already ran `workflow <mode>` still keeps old shell variables. See "Stale terminal safety" below.
* **Tracked `.vsix`:** `extensions/vscode/token-controller-ui-1.1.0.vsix` is in git and does not contain these fixes. Rebuild and bump the version when you release.

## Stale terminal safety (2026-10-07)

Fixed:

* `wx` and `workflow report` prefer `active_mode.env` over shell `AICONTEXT_*` variables. Stale shell policy variables are dropped before the file is applied. A test reproduces the old bug (shell `code`, file `security`: output was compressed) and passes now.
* The env file is parsed, not sourced. Lines that are not plain `export AICONTEXT_NAME="value"` are ignored. A file without a profile leaves output raw and warns.
* Escape hatch: `AICONTEXT_USE_SHELL_STATE=true`.
* `AICONTEXT_RAW_LOG_DIR` is now read after the policy state loads. Before, a stale shell value or the default was used even when the file set it.
* `session.jsonl` records `policy_source` and `stale_shell_profile` (additive fields, `schema_version` stays 2).
* `workflow status` shows the env-file profile and warns when the shell differs. Doctor's shell mismatch warning says `wx` uses the file.

Mitigated (not fully solved):

* `templates/AGENTS_base.md` tells agents that `active_mode.env` is the source of truth, not to rely only on `AICONTEXT_*` shell variables, that open terminals can be stale, and that `wx` uses the file by default. This is policy text. It depends on agent compliance, and projects that ran `workflow init` earlier keep the old block until it is updated.

Still open:

* Shell variables in an already-open terminal stay stale until it runs `workflow <mode>`. Anything that reads them directly (a person, a script, an agent that ignores the template) can see the wrong profile. `wx` and `workflow report` are protected. Options are in `docs/EXTENSION_ALIGNMENT_DESIGN.md`.
* `status --json` now exists (see below).
* `wx` ignores values with `$`, backticks, or backslashes in the env file. `workflow.sh` never writes them today.

## `workflow status --json` (2026-10-07)

Fixed: tools and agents can read controller state without parsing text. It reads `active_mode.env` the way `wx` does (parsed, not sourced, in a subshell), so it never changes the caller's shell. The text `workflow status` is unchanged for the shell-visible variables, plus the env-file lines added earlier. Needs `jq`. Unknown option returns 2.

Schema (`schema_version` 1). Strings are `null` when not set. Booleans are `true`, `false`, or `null`.

| Field                                                 | Meaning                                                                                                                                                                                                  |
| ----------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `profile`, `risk`                                 | Active profile and its risk from the env file                                                                                                                                                            |
| `output_style`                                      | `AICONTEXT_OUTPUT_STYLE`                                                                                                                                                                               |
| `raw_on_fail`, `keep_raw_logs`                    | Booleans                                                                                                                                                                                                 |
| `compress_shell`, `compress_files`                | Policy labels                                                                                                                                                                                            |
| `rtk_mode`, `leanctx_mode`, `headroom_mode`     | Tool modes as exported state                                                                                                                                                                             |
| `caveman_mode`, `caveman_max`, `caveman_output` | Effective Caveman state.`caveman_output` is a boolean                                                                                                                                                  |
| `source`                                            | `active_env_file` (file has a profile), `shell_fallback` (no usable file, shell has a profile), `unset` (nothing usable). A file without a profile gives `unset`, like `wx` (output stays raw) |
| `active_env_file`                                   | Path that was checked                                                                                                                                                                                    |
| `shell_profile`                                     | The shell's profile when it differs from`profile`, else `null`                                                                                                                                       |
| `stale_shell`                                       | `true` when the shell has a profile, the source is not `shell_fallback`, and the profiles differ                                                                                                     |
| `use_shell_state`                                   | `true` when `AICONTEXT_USE_SHELL_STATE=true` is set. `wx` then uses shell variables, but this JSON still describes the file                                                                        |

Still open:

* The extension does not call `status --json` yet. It still parses `active_mode.env` by regex.
* No `set --json` or `report --json` (see `docs/EXTENSION_ALIGNMENT_DESIGN.md`). `modes --json` exists (see below).
* `status --json` does not include `description`, `caveman_shrink`, or the other exported variables. Add fields only with a `schema_version` rule: new fields are additive, removed or renamed fields bump the version.

## Non-sourced entry point (2026-10-07)

Fixed: **"no non-sourced entry point"**. `scripts/workflow-cli.sh` (executable) runs `scripts/workflow.sh` in its own Bash process. Tools no longer need `bash -c "source ..."`.

* Locates `workflow.sh` beside itself (follows symlinks, works from any directory). Arguments go to `workflow.sh` as they are, with no `eval`.
* A separate process, so it never changes the caller's shell. A test compares the caller's `AICONTEXT_*` variables before and after.
* Supports every `workflow.sh` mode and command: `status`, `status --json`, `<mode>` (`code`, `micro`, ...), `doctor [--json]`, `report`, `reset-session`, `init`, `setup`, `help`. Mode switches write `active_mode.env`.
* Exit codes are the command's: `0` ok, `1` failed (for example an unknown mode), `2` usage error (for example `status --bogus`).
* Refuses to be sourced (returns 2).
* Hardening in `workflow.sh`: a mode id must be lowercase letters, digits, and hyphens. Anything else is rejected as "not found" before it reaches a jq program. Valid ids are unchanged.
* The usage text names the entry point that was used.

Still open:

* The VS Code extension still runs `bash -c 'source "$1" "$2"'`. Switch it to `workflow-cli.sh` (resolve it beside `scriptPath`, call `execFile` with an argument array).
* `wx` is not exposed. Tools cannot run `workflow-cli.sh wx <command>`.
* No `version`, `modes --json`, or `report --json` commands. Compatibility between extension and CLI versions is undecided.
* The executable bit must survive checkout and packaging. Check it when the CLI is bundled or installed on Windows/WSL paths such as `/mnt/c`.
* `status` (text) through the CLI shows the variables of the CLI's own process, which inherits the caller's exported variables. Use `status --json` for controller state.

## `workflow modes --json` (2026-10-07)

Fixed: tools can list modes from the settings file instead of keeping their own copy. Works as `workflow modes`, `workflow modes --json`, and `scripts/workflow-cli.sh modes --json`. Needs `jq`. Unknown option returns 2. Missing settings file returns 1.

Schema (`schema_version` 1):

```json
{
  "schema_version": 1,
  "modes": [{
    "name": "micro", "description": "Very small task. ...", "risk": "normal",
    "compress_shell": "off", "compress_files": "off-for-target",
    "rtk_mode": "off", "leanctx_mode": "off", "headroom_mode": "off",
    "caveman_mode": "off", "caveman_max": "off", "caveman_output": false,
    "output_style": "ste-inspired"
  }],
  "aliases": [{"alias": "plan", "target": "architect"}, {"alias": "ci", "target": "cicd"}]
}
```

* Modes are in config order. `description` is `null` if a mode has none (none are missing today: 22 modes, 22 descriptions).
* Defaults match activation: `risk` `normal`, `compress_*` `safe`, tool modes `off`.
* `caveman_mode` is the **effective** level and `caveman_max` the cap, with the same rules as activation (hard-blocked profiles are `off`, levels other than `off`, `lite`, `full` become `off`). `caveman_output` is `caveman_mode != "off"`.
* Aliases are now a top-level `aliases` object in `config/workflow_settings.json` (`plan` to `architect`, `ci` to `cicd`). `workflow.sh` resolves aliases from it. If a settings file has no `aliases` key, the two built-in aliases still work and are still listed.
* `workflow modes` (text) prints name, risk, description, and the alias line.
* Tests compare the list with the variables each mode exports, on the repository config and on a config that requests Caveman levels in blocked and capped modes. A mutation of the blocked list makes the test fail.

Still open:

* ~~The extension still keeps its own parse of the config and a fallback list.~~ Done, see "Extension uses the CLI JSON interface".
* The `workflow help` mode list and the `Aliases:` lines are still hand-written. They can be generated from `modes --json`.
* The Caveman effective-level rules exist twice (activation in bash, listing in jq). The parity test guards them. A shared jq function would remove the copy.
* Mode order is config order (`raw` first, `off` last). The extension decides how to sort or group.
* No `version` command and no schema compatibility rule yet.

## Extension uses the CLI JSON interface (2026-10-07)

Fixed in `extensions/vscode` (still not released; the tracked `.vsix` is 1.1.0):

* **One adapter:** `src/cli.ts` is the only code that runs the CLI. It calls `bash <cliPath> <args...>` with `execFile` (no shell string). The CLI is `workflow-cli.sh` in the folder of the configured `workflow.sh`.
* **CLI calls:** `status --json`, `modes --json`, `<mode>`. Nothing else.
* **No regex parsing of `active_mode.env`.** The extension watches the file and calls `status --json` when it changes. It does not read the file.
* **No hard-coded mode list.** The built-in fallback list and the config reader are deleted. If `modes --json` fails, the picker shows the error (Open Settings, Show Log) and does not fall back.
* **Contract checks:** only `schema_version` 1 is accepted. Output is validated (`source`, `stale_shell`, ids, risk). Ids shown in the UI must be plain ids. A mode id sent back must be in the list the CLI just returned.
* **Status bar:** profile, risk, `(shell)` for `shell_fallback`, a warning icon and background for `stale_shell`, a warning background for `critical` risk, an error state when the CLI is unavailable. The tooltip shows source and tool modes.
* **Tests:** 12 adapter tests (plain mocha). Three run against the real `workflow-cli.sh` with an isolated config dir: `modes --json` matches the settings file, `setMode` writes the mode file and `status` follows it (and reports a stale shell), an unknown mode fails without changing the mode.

Still open:

* **`stale_shell` means the environment of VS Code (the extension host), not a terminal.** Already-open terminals can have their own old `AICONTEXT_*` variables. The extension cannot inspect them. The tooltip says so.
* **Windows/WSL:** `runCli` needs Bash and returns an error on `win32`. There is no backend interface or `wsl.exe` path translation. No Windows CI job. A local Windows window with a WSL folder is not handled. Environment checks (`remoteName`, distro) from the design doc are not built.
* **Report summary tooltip, doctor summary, tool availability** are not shown yet (`doctor --json` and `report --json` are not called; `report --json` does not exist).
* **No `version` command.** Compatibility is only `schema_version`. A newer controller with a new schema shows "unavailable".
* **`vscode-test` was not run** (needs a VS Code download). The status bar, picker, and watcher code in `extension.ts` has no automated test. Only the adapter does.
* **Tracked `.vsix` is stale.** Rebuild and bump the version when you release.
* **Missing `jq` or an old controller** shows "unavailable". There is no install help in the UI.

## Extension configuration and trust hardening (2026-10-07)

The earlier fix closed the main hole (workspace settings could set the script path). One gap was left: the user-level path can still point **inside** the open workspace, for example the default path when the workspace is the controller clone. In an untrusted workspace the workspace would then control the code that runs.

Fixed in `extensions/vscode`:

* **Workspace Trust check:** in an untrusted workspace the extension does not run a controller whose `workflow.sh` or `workflow-cli.sh` is inside any `file:` workspace folder. The check (`src/trust.ts`) tests the path as given and its real path, in both symlink directions, and handles prefix folders (`ws` vs `ws2`). The status bar shows `AI Context: restricted`. The picker shows a warning with **Manage Workspace Trust**. The extension refreshes when trust is granted or the folders change.
* A controller outside the workspace still runs in an untrusted workspace.
* The manifest description for `untrustedWorkspaces` now states this exact behavior.
* Resolution is documented: user or machine setting only (`machine` scope), workspace and workspace-folder values ignored at run time with one warning, then `workflow-cli.sh` beside `workflow.sh`.
* Tests (plain mocha): 7 path-logic cases, a manifest check (`machine` scope, restricted configuration, `limited` support), and a source scan that fails on `exec(`, `spawn`, `shell:` options, or `-c` strings. I checked that the scan fails when an `exec(` call is added.
* README has a "Security model" section.

Still open:

* **The configured script is trusted code.** It and every file in its folder run with user rights. The extension does not verify content, owner, or permissions of the controller.
* **A trusted workspace can contain the controller.** Trusting the workspace trusts that code.
* **User settings are trusted.** Anything that can write them can change the script.
* **The CLI inherits the extension host environment.** `AICONTEXT_SETTINGS_FILE` or `PATH` set there change what runs.
* **Not tested in a real VS Code or WSL window:** the manifest `scope`, `inspect()` values for remote machine settings, `isTrusted`, `onDidGrantWorkspaceTrust`, and the status bar text. `vscode-test` was not run.
* **Multi-root and virtual workspaces:** only `file:` folders are checked. Remote `vscode-vfs` folders cannot contain a local script, but this is not tested.
* **Windows paths:** the path check is written for POSIX paths. A Windows backend needs its own check (case-insensitive paths, drive letters, `wsl.exe` path translation).

## RTK post-capture prototype (2026-10-07)

Fixed / added (details in `docs/integrations/RTK.md`, "Prototype status"):

* `wx` can run `rtk pipe -f <filter>` after raw capture for six mapped commands. Raw files are complete first (tested). Only `--version` and `pipe -f` are ever called, never `rtk init` (tested).
* Gates: protected profiles and commands, nonzero exit (so first and later failures), `compress_shell` off, `rtk_mode` off, and denied filters (`grep rg find fd git-*`) all keep RTK out. Tested with the fake RTK logging every call.
* Fallbacks with recorded reasons: not installed, version failed, nonzero exit, timeout, empty, not smaller, evidence guard. Raw output and exit code are kept.
* `session.jsonl` has `compressor`, `compressor_version`, `filter`, `fallback_reason`. A run is labelled RTK only when RTK output was shown.
* Tests: fake RTK (`tests/fixtures/bin/rtk`) and noisy command fixtures in `tests/wx-wrapper.test.sh`; a real-RTK check runs when `rtk` is installed. Mutation checks (guard disabled, deny list removed, not-smaller check removed, nonzero gate removed) each make the tests fail.
* Doctor already warns about an RTK hook or setup (`policy.rtk_hook`) and never runs `rtk init`.

Still open (RTK):

* **Guard tuning:** v1 patterns. Real RTK 0.42.4 drops `warning:` lines from pytest-like output, so the guard falls back in that case. Needs fixtures from real tool output.
* **Coverage:** `python -m pytest`, `npx` forms, `npm test`, `dotnet test`, install/build logs (`log` filter) are not mapped.
* **Hook bypass:** commands rewritten by an RTK hook skip `wx`. Doctor warns only.
* **Measurement:** bytes only. `docs/VALIDATION_MATRIX.md` and any README savings claim wait for more data and a second tool.
* **Env knobs** `AICONTEXT_RTK_BIN` and `AICONTEXT_RTK_TIMEOUT` are not in `workflow doctor` or the README.
* **Tracking:** `rtk pipe` wrote no files in one scratch-`HOME` check. `rtk --version` was not checked for side effects.
* **Windows:** GNU tools (`timeout`, `stat -c`, `awk`) assumed.

## Caveman policy state (2026-10-07)

Fixed (state only, Caveman is never run):

* **Opt-in:** `AICONTEXT_CAVEMAN_REQUEST=off|lite|full`, per activation, not saved. Shape and rules in `docs/integrations/CAVEMAN.md` ("Implemented policy state"). `workflow.sh` and `workflow-cli.sh` both honor it.
* **Values:** `off`, `lite`, `full`. `ultra` and `wenyan` (or any other value) become `off` with a warning. Default `off`.
* **Cap:** effective level is the lower of the request (or config level) and the mode's `caveman_max`. Notices say when a request is ignored or lowered.
* **Hard blocks in code and config:** `raw`, `security`, `db`, `release`, `migration`, `docs`, `debug` (new: `debug`), plus `micro`, `snippet`, `off`. A test removes the config list and checks that the code list alone blocks them, in activation and in `modes --json`.
* **State:** `AICONTEXT_CAVEMAN_REQUESTED` is exported and in `active_mode.env`. `status --json` has `caveman_requested`.
* **Doctor:** reads `.caveman-active`. Error in hard-blocked profiles (now includes `debug`), warn for no opt-in (the warning shows the opt-in shape), above-policy level, and `ultra`/`wenyan`. A `caveman.policy` line shows level, request, and limit. Doctor never edits the file.
* **Template:** Caveman off by default, use only if `AICONTEXT_CAVEMAN_MODE` is `lite` or `full`, blocked work and first-failure evidence excluded.
* **Tests:** default off in all 22 modes, request values, capping, blocked modes, unsupported values, per-activation scope, config opt-in, request overriding config, hard blocks without the config list, doctor cases.

Still open:

* **Not implemented:** prompt guards, shrink/proxy (`caveman_shrink` has no effect), activating or deactivating the plugin, a per-turn "first failure" rule (only `debug` is blocked in code; failing `test`/`cicd` runs rely on template text).
* **Upstream questions** (state file format and lifetime, level names, session-start hook, `caveman-compress` vs the managed block, the Caveman gateway data flow, shrink/proxy/stats, auto-clarity): listed in `docs/integrations/CAVEMAN.md`.
* **Exported `AICONTEXT_CAVEMAN_REQUEST` in a shell profile** opts in on every activation. Doctor does not check for it.
* The Caveman level rules still exist twice (bash and jq). The parity test guards them. The blocked list exists in four places (`workflow.sh` twice, `doctor.sh`, config). Tests cover the code lists.
* Extension: no Caveman toggle, and it does not show `caveman_requested`.

## Debt review (2026-10-07)

Every "Open" item in the sections above was checked against the current code, config, tests, and docs. The test suites (`wx-wrapper`, `workflow-session`, `doctor`, the extension adapter and security tests) passed at the time of the review.

**Confirmed fixed** (these were listed as open in older sections, and are not in the table):

* Extension hard-coded and partial mode list. The extension uses `modes --json`. It has no fallback list.
* Extension security: the `exec` shell string is gone (`execFile` with an argument array), `scriptPath` has `machine` scope and workspace values are ignored, and an untrusted workspace cannot run a controller that is inside it.
* No non-sourced entry point (`scripts/workflow-cli.sh`), no `modes --json`, no `status --json`, and the extension parsing `active_mode.env` by regex.
* RTK was "only exported as state". `wx` now runs `rtk pipe` after raw capture for six commands, with fallbacks and an evidence guard.
* Caveman: the opt-in input (`AICONTEXT_CAVEMAN_REQUEST`) exists, `debug` is hard-blocked, and doctor reads `.caveman-active` (errors in blocked profiles, warnings for no opt-in).
* Doctor JSON `paths` entries are `{path, line}` everywhere.
* Stale `.vscode/settings.json`: it is no longer tracked in git (the folder is empty).
* `integrations/README.md` overclaim: reworded (by the user).
* Earlier foundation items (header mode list, README layout, template wording, `micro`, descriptions, `rtk_mode` labels, `AICONTEXT_OUTPUT_STYLE` export, Caveman config keys, tool script entries): fixed, as listed above.

**Accepted, not debt** (removed from the list):

* `docs/integrations/CAVEMAN.md` keeps "legal and compliance-like work" as a blocked task type. It is a task guard for agents, not a mode, and the template no longer uses that wording.

**New findings in this review** (added to the table):

* **D-20:** `scripts/check-tools.sh` still prints that `wx` does not invoke RTK. That became false when the RTK prototype was added.
* **D-21:** `ccusage` is checked by doctor, but not by `check-tools.sh` or `install-optional-tools.sh`.
* **D-22:** The README documents none of `AICONTEXT_USE_SHELL_STATE`, `AICONTEXT_CAVEMAN_REQUEST`, `AICONTEXT_RTK_BIN`, `AICONTEXT_RTK_TIMEOUT`.
* **D-23:** The "Documents to revise" table and the work packages in the plan document describe work that is now done.
* **D-01 to D-03, D-05:** These are the largest gaps against the product direction, and they were not on any earlier list. LeanCTX and Headroom have no design doc and no code. Their config values (`leanctx_mode`, `headroom_mode`), and `compress_files`, `memory_layer`, and `codebase_index`, are exported as state and read by nothing. `compress_shell` and `rtk_mode` are the only labels that `wx` interprets. `AICONTEXT_OUTPUT_STYLE` is exported and used by nothing.

**Still open:** see the table. Counts at this review: 32 rows. By type: Not implemented 10, Debt 13, Risk 5, Decision 2, Contradiction 2. By status: Open 28, Decision needed 2 (D-04, D-06), Mitigated 1 (D-13), Risk accepted 1 (D-30). By severity: High 2, Medium 15, Low 15.

## Applied from the profile review (2026-10-07)

Fixed (details of the findings are in `docs/VALIDATION_MATRIX.md`, "profile/state manager review"):

* **F1 / D-34:** the README policy rules now list `raw`, `security`, `db`, `migration`, and `release` as raw or lossless. D-34 is closed.
* **F4:** the README defines the risk levels in one bullet: `normal` routine work, `high` evidence-sensitive work that is not necessarily raw, `critical` raw or lossless work with protected evidence.
* **F3:** `leanctx_mode` is `off` in all critical modes (`raw`, `security`, `db`, `migration`, `release`). It was `guarded` (`security`, `release`), `diagnostic` (`db`), and `graph-read` (`migration`). This is intent only: no code reads `leanctx_mode` yet, so nothing changed at run time. D-01 and D-03 are revised, not closed. Re-enabling LeanCTX in a critical mode needs its own design and tests.

Still open from the same review:

* **D-33 (F2):** the protection flags are exported and read by nothing.
* **D-03:** `memory_layer` and `codebase_index` are still on for `security`, `db`, and `migration`. They are state only today.
* **Scenario table:** the `migration` row says "Use a global map and full active files". It does not say "raw or lossless", although the mode is `critical`. The wording was left as it is.

## RTK hardening (2026-10-07)

Confirmed (no change needed):

* Token Controller never runs `rtk init`. A static scan of the scripts and the fake-RTK call log in the `wx` test both check it. The filter map is still the six filters (`cargo-test`, `pytest`, `go-test`, `go-build`, `tsc`, `vitest`). `grep`, `rg`, `find`, `fd`, and `git-*` are refused in code even if a config maps them.

Fixed or improved:

* **Doctor (D-08, improved, still open):** detection now covers the global files that `rtk init` writes for Claude, Copilot, Gemini, Cursor, Codex, OpenCode, Pi, and Hermes, and the project files `.windsurfrules` and `.clinerules`. The layout comes from running `rtk init` in scratch HOME directories (research only, RTK 0.42.4). Project-local `.rtk/filters.toml` is an `info`.
* **Install script text:** the printed `rtk init` lines are commented out with a warning that they skip `wx` capture.
* **Evidence guard (D-07, improved, still open):** `warn:`, `fatal:`, and upper-case `WARN`/`WARNING`/`ERROR`/`FATAL` lines are now evidence. Tests with those formats failed with the old guard. A look-alike line (`errors.py::test_a PASSED`) is still not evidence.
* **Tests:** RTK not found by name or without the execute bit, a command without a filter is not labelled and RTK is not called, a pass-through is not labelled, nine evidence formats dropped or kept by RTK, RTK stderr never in the visible output after success or any of four fallbacks, 15 doctor artifacts and no false warnings.

Still open (RTK): D-07, D-08, D-09 as revised in the table. Real-tool fixtures for each of the six filters are still missing, and `docs/VALIDATION_MATRIX.md` has no RTK entry (D-06).

## Caveman safety (2026-10-07)

Confirmed (no change needed):

* Supported levels are `off`, `lite`, `full`. `ultra` and `wenyan` stay unsupported. Caveman is off by default in every mode (a new test checks the config: defaults and every mode `off`, only `cicd`, `code`, `rapid-prototype`, and `test-full` have a limit, no `ultra` or `wenyan` as a value). Hard-blocked in code and config: `raw`, `security`, `db`, `release`, `migration`, `docs`, `debug` (plus `micro`, `snippet`, `off`).

Fixed:

* **D-12 closed:** doctor warns when `AICONTEXT_CAVEMAN_REQUEST` stands in the environment, in a shell startup file, or in a VS Code settings file (`caveman.request_standing`, with file and line). Tests cover the environment, six startup files, comments and aliases (not reported), a settings file, and an unsupported value. Limit: a variable that is set but not exported in the current shell cannot be seen.
* **Doctor:** `caveman.active_after_failure` warns when Caveman is active and the latest `wx` run in the project failed. Doctor already checked `.caveman-active`, unsupported active levels (`ultra`, `wenyan*`), and active Caveman in blocked modes.
* **Failure evidence (D-10, partly):** `wx` records `caveman_mode` in `session.jsonl` and prints a one-line reminder on stderr after a failed run when Caveman is `lite` or `full`. Nothing is printed when Caveman is off, so default `wx` output and the benchmark are unchanged. Tests check the reminder after a failure, no reminder after a success, with Caveman off, and in `debug` (where a request is ignored).

Still open:

* **D-10:** prompt guards are not applied. Agent compliance with the reminder, the template rule, and "stop caveman" is policy only. Token Controller cannot write or clear the plugin's `.caveman-active`. Commands outside `wx` get no reminder.
* **D-11:** shrink and proxy are not implemented. The upstream questions in `docs/integrations/CAVEMAN.md` are still open. No design until they are answered.

## CLI version and schema basics (2026-10-07)

Fixed (part of D-25):

* **`workflow version` and `workflow version --json`** (also `--version`, `-V`, and `scripts/workflow-cli.sh version`). Unknown option returns 2. Text prints the CLI version, the schema numbers, and the git commit and branch when the controller folder is a git checkout.
* **JSON fields** (`schema_version` 1 for this output): `cli_version`, `config_schema_version` (read from the settings file in use, `null` if missing or not a number), `status_schema_version`, `modes_schema_version`, `doctor_schema_version`, `session_schema_version`, `git_commit` (12 characters), `git_branch`. The git fields are `null` outside a git checkout or when git does not answer. They come from `git rev-parse` and `git branch --show-current` only, with a 3 second limit. A `GIT_DIR` or `GIT_WORK_TREE` in the caller's environment is ignored.
* **One place for the numbers:** `scripts/lib/versions.sh` holds `AIW_CLI_VERSION` (`0.1.0`, changed by hand) and the schema numbers. `status --json`, `modes --json`, `doctor --json`, `version --json`, and the `session.jsonl` records now take their `schema_version` from it. Tests check that each number in `version --json` equals the number the matching output really carries, so they cannot drift.
* **Compatibility rule** (written in `versions.sh`, summarized in the README): adding a field does not change the schema number, and a consumer ignores unknown fields. Renaming or removing a field, or changing its type or meaning, bumps that number. A consumer checks the number it needs and refuses any other. `cli_version` is not used to decide compatibility.
* No package or release automation was added.

Still open (D-25, smaller):

* `set --json` and `report --json` do not exist. `wx` is not reachable through `workflow-cli.sh`. `status --json` lacks `description` and `caveman_shrink`.
* The extension does not call `version --json`. It accepts only `schema_version` 1 of each reply and shows "unavailable" for anything else. A minimum `cli_version` or per-output check is not defined.
* `AIW_CLI_VERSION` is bumped by hand and has no release process. There is no changelog for the CLI.
* The settings file schema (`config_schema_version` 2) has no migration or rejection logic. A different number is only reported.

## `workflow report --json` (2026-10-07)

Fixed (part of D-25, and the CLI side of D-26): `workflow report --json` and `scripts/workflow-cli.sh report --json [--project <dir>]`. The text report is unchanged (a test compares its numbers with the JSON). Unknown option and a missing `--project` directory return 2. A broken session file returns 1 with the error on stderr and nothing on stdout. `report` reads the session file and never writes.

Schema (`schema_version` 1, version number in `scripts/lib/versions.sh` as `AIW_REPORT_SCHEMA_VERSION`, also shown by `version --json` as `report_schema_version`). **All numbers are byte counts from `.ai-context/session.jsonl`. They are not token counts, and `byte_reduction_percent` is not a token saving.**

| Field                                                          | Meaning                                                                                                         |
| -------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `schema_version`                                             | 1                                                                                                               |
| `available`                                                  | `true` when the session file has records, `false` when there is no session (then the counts are 0)          |
| `profile`                                                    | Active profile from the mode file or the shell,`null` if none                                                 |
| `command_count`                                              | Number of wrapped commands                                                                                      |
| `failure_count`                                              | Commands with a nonzero exit code                                                                               |
| `raw_stdout_bytes_total`, `raw_stderr_bytes_total`         | Captured raw bytes                                                                                              |
| `visible_stdout_bytes_total`, `visible_stderr_bytes_total` | Bytes`wx` showed (not counting the raw-log pointer line)                                                      |
| `raw_bytes_total`, `visible_bytes_total`                   | The sums of the two lines above                                                                                 |
| `byte_reduction_percent`                                     | `(raw - visible) / raw * 100`, rounded to 2 decimals. `null` when `raw_bytes_total` is 0. Can be negative |
| `session_file`                                               | Absolute path of`session.jsonl`                                                                               |
| `raw_log_dir`                                                | Absolute path of the raw log directory (`AICONTEXT_RAW_LOG_DIR` or the default)                               |
| `last_run_at`                                                | `completed_at` of the last record (else `started_at`), `null` if the record has neither                   |

Notes:

* `--project <dir>` selects the project. Without it the current directory is used. The extension should pass the workspace folder.
* Old records without `raw` or `visible` fields use `stdout.bytes` and `stderr.bytes`, as the text report does.
* The text report prints `0.00%` when raw bytes are 0. The JSON uses `null`, because "no data" is not "no reduction".
* Tests: no session, one command, mixed success and failure with a compressed run (totals, percent, and last run time are checked against a separate sum of the records), old records, a broken file, zero raw bytes, options, the sourced form, the CLI form, and that `report` does not create or change files.

Still open:

* The extension does not call `report --json` or watch `session.jsonl` yet (D-26).
* `report` is per project folder. Multi-root workspaces need one call per folder.
* No per-command list, no per-profile split, and no compressor totals (for example how many runs used RTK). Add fields only with the rule in `scripts/lib/versions.sh`.
* `last_run_at` is the last record in file order, not the latest time.

## CLI CI (2026-10-07)

Added `.github/workflows/cli-ci.yml` (name "CLI CI"). It runs on pull requests to `main` and on pushes to `main`, with no path filter, on `ubuntu-24.04` with a 25 minute limit. It has read-only permissions and cancels an older run of the same ref.

Steps:

* Show tool versions, and list which optional tools are on the runner (information only).
* Check that `scripts/workflow-cli.sh` and `tests/fixtures/bin/*` are executable. The tests run them directly, and a lost execute bit would otherwise fail in a confusing way.
* `bash -n` on `scripts/workflow.sh`, `scripts/workflow-cli.sh`, every `scripts/lib/*.sh`, every script under `scripts`, and the test and benchmark scripts.
* `jq . config/workflow_settings.json >/dev/null`.
* `bash tests/wx-wrapper.test.sh`, `bash tests/workflow-session.test.sh`, `bash tests/doctor.test.sh` (not on your list, added because it needs no tool), and `bash benchmarks/run-benchmark.sh` (exits 1 if failure, security, or database evidence is not preserved).

Not installed or required: RTK, LeanCTX, Headroom, Caveman, ccusage, Node. The RTK tests use the fake `tests/fixtures/bin/rtk` and the noisy command fixtures. The real-RTK check in `tests/wx-wrapper.test.sh` runs only if a real `rtk` is on the `PATH` (it prints a note otherwise).

Closes no debt ID. It adds a safety net for D-07, D-10, D-13, D-14, and D-25 (their behavior is covered by these tests), but none of those items is fixed by it. The extension build stays in `vscode-extension-ci.yml`.

Checked locally before the first run on GitHub: all four commands pass in a CI-like environment (`env -i` with an empty `HOME`, none of RTK, LeanCTX, Headroom, Caveman, ccusage on the `PATH`, `mawk` as `awk`, and system `jq` 1.7 as on the runner image). The tests also passed with `gawk` and `jq` 1.8.2, and with a real RTK present.

Still open: D-35, and `git diff --check` is not part of CI (it is a local step).

## Extension package metadata (2026-10-07)

Checked: `package.json` said 1.1.0 and the tracked `.vsix` was 1.1.0 (git tag `v1.1.0`). Neither matched the current extension: the CLI adapter, `status`/`modes` JSON, the trust model, and the `restricted` state were added after 1.1.0.

Done (nothing published, no tag created):

* **Version 2.0.0** in `package.json` and `package-lock.json` (the lock root version was stale at 0.0.1). A major bump, because the extension now needs a controller with `workflow-cli.sh` and schema 1 JSON, and an older controller shows "unavailable". The number is easy to change before a release.
* **CHANGELOG** has an `[Unreleased]` section with "Planned version: 2.0.0", a Breaking list, and a Packaging note. The heading stays `[Unreleased]` until a release.
* **VSIX not tracked:** the 1.1.0 file was removed from the git index (`git rm --cached`, `*.vsix` is already in `.gitignore`). Reasons: it is a generated binary, every version would add one more to history, and a stale 1.1.0 file next to the source misleads. It stays in history and under `v1.1.0`. The extension README now says to build it (`npx vsce package`).
* The local 1.1.0 file in `extensions/vscode/` was left on disk (ignored by git).

Still open or deferred:

* **D-29 (deferred):** publishing, tagging, a release process, and a CI artifact upload. Do the manual smoke test (README) first.
* A user who relied on the tracked VSIX for a quick install now has to build it, or use the `v1.1.0` file. GitHub release assets are not set up.
* `vsce package` warns about nothing today. No icon or Marketplace metadata (categories, keywords, gallery banner) has been reviewed.

## RTK pipe-first (2026-10-07)

Direction: RTK is a post-capture terminal-output filter. `wx` runs the command once, stores raw stdout, raw stderr, and the exit code, and only for a `pipe` entry runs `rtk pipe -f <filter>` on the captured stdout. Details in `docs/integrations/RTK.md`.

Done (each point has tests, see `tests/wx-wrapper.test.sh` and `tests/doctor.test.sh`):

* **Classes in the config:** `command_policy.rtk_commands` (one entry per command prefix) and `command_policy.rtk_class_enabled`. Classes: `pipe`, `rerun`, `recognized-only`, `never`. The old flat `rtk_filters` map is gone. Entries: 6 `pipe`, 5 `recognized-only` (`cat`, `head`, `tail`, `rtk read`, `rtk smart`), 7 `never` (`grep`, `rg`, `find`, `fd`, `git status`, `git diff`, `git log`).
* **Strict resolution:** the longest prefix wins. An unknown, empty, misspelled, or non-string class, `rerun` (even when enabled), a disabled or missing `pipe` switch, and a `pipe` entry with a missing, malformed, or denied filter all resolve to `never` (raw). Non-list, null, and non-object config shapes and the old `rtk_filters` key mean no RTK. Filter names with shell syntax are never run.
* **`rerun` is disabled globally and has no code.** A static test counts the places that run RTK: `--version` and `pipe -f` only.
* **Protected profiles** (`raw`, `security`, `db`, `migration`, `release`) bypass RTK, also when every class is enabled in the config.
* **Exit code on disk early:** `exit_code.raw` is written right after the command ends, before RTK. A test kills `wx` while RTK runs and finds the raw output and the exit code on disk and no session record.
* **`session.jsonl`** has `rtk_class` (additive, `schema_version` stays 2).
* **Doctor** checks the class config (`rtk.config*`): unsupported classes, `rerun` entries or switch, denied or malformed filters, non-list or skipped entries, the old key, a disabled `pipe` class.
* **Docs:** `RTK.md` was rewritten to this direction. The README RTK paragraph no longer reads as full RTK support.
* Mutation checks (each makes the wx test fail): the `pipe` switch ignored, denied filters allowed, first match instead of longest, no early exit code file, an unknown class resolving to `pipe`.

Still open: D-07 (expansion, guard, real-output fixtures), D-06 (no RTK entry in the validation matrix, no benchmark scenario), D-08 (hooks bypass `wx`), D-09, D-36 (rerun, rejected/deferred), D-37 (smart file reading, deferred).

## RTK fixture validation (2026-10-07)

Done (`tests/fixtures/rtk`, `tests/fixtures/replay-case.sh`, `tests/wx-wrapper.test.sh`; no new mapping, no config change):

* **25 recorded runs for the six enabled filters.** Real recordings from go 1.27.0, pytest 9.1.1, TypeScript 7.0.2, and vitest 5.0.3 (`PROVENANCE.txt`). The three `cargo-test` runs are hand-written because cargo is not installed here, so they are the least reliable. Cases: noisy success, warning-like, failure, and informational runs.
* **Every run goes through `wx` with the fake RTK.** Checked each time: the command ran once with the recorded arguments, `stdout.raw`/`stderr.raw`/`exit_code.raw` equal the recording, `exit_code.raw` and the full raw output were on disk when RTK started, RTK was called only as `--version` and `pipe -f <filter>` and only when it can apply, stderr is shown as recorded, and the record has the right `rtk_class`, `output_policy`, `compressor`, `filter`, and `fallback_reason` (accepted, `evidence-guard`, `rtk-not-smaller`, failing run, empty stdout).
* **Real RTK:** 18 of the runs also go through a spy script that logs every call and runs the real `rtk`. A missing RTK is a SKIP (checked in a CI-like environment). Outcomes are pinned for 0.42.4 only. Other versions get a NOTE.
* **Evidence guard widened** because a fixture showed a gap: `cargo test --nocapture` puts test output after `test name ... `, and RTK's summary dropped `warning:` lines that the guard accepted. The guard now treats `warning:`, `error:`, `fatal:`, and `panicked at` anywhere in a line as evidence.
* **Findings (D-38):** wrong or lossy accepted output for plain `go test`, `go test -bench/-cover`, `pytest --collect-only`, `tsc --listFiles/--showConfig`. `go-build` never receives input. `tsc` only sees informational runs. The tests print a WARN line for each; they do not pin these outcomes as correct.
* **Validation matrix:** a short entry was added. D-06 stays open (no benchmark scenario, no measured reduction beyond the recordings).

Still open: D-38 (decide which filters to narrow or disable), D-07 (expansion, a guard that cannot see wrong summaries), D-06, D-08, D-09, D-36, D-37. Hand-written `cargo-test` fixtures should be replaced by a real recording.

## RTK benchmark (2026-10-07)

Added `benchmarks/run-rtk-benchmark.sh`, with a short section in `benchmarks/README.md`. No mapping, config, or wx behavior was changed. It uses the recorded runs in `tests/fixtures/rtk` and the fake RTK in `tests/fixtures/bin`.

Measured (byte counts, not token counts; see the `docs/VALIDATION_MATRIX.md` entry for the table):

* **Fake RTK:** every row matched its expected outcome. Its byte counts only test the pipeline.
* **Real RTK 0.42.4:** every row matched the pinned outcome. Four runs were accepted (cargo-test, pytest, tsc, vitest), three fell back with `evidence-guard`, one had empty stdout (`go build`, RTK not called), one failing run stayed raw. Over the 7 runs that reached RTK, 15701 bytes were shown as 7124 (54.63%). The 4 accepted runs alone went from 9182 to 605 bytes (93.41%).
* **Protected profiles** (`raw`, `security`, `db`, `migration`, `release`): raw output, no compressor, 0 RTK calls, in both sections.
* **Built-in exact-repeat reducer:** 69.64% on its own `npm install` fixture. On the raw stdout of the RTK recordings, 0.00% for 13 of 15 and a small increase for two.
* Mutation checks: letting a protected profile reach RTK, a guard that accepts everything, and showing the rejected RTK output after a fallback each make the benchmark exit 1.

D-06 and D-07 were updated from these numbers only. Still open: D-06 (one RTK version, hand-written cargo recordings, not in CI, no second tool), D-07 (expansion, the heuristic guard), D-38 (wrong or lossy output for informational runs, which this benchmark does not include).

## RTK command table completed (2026-10-07)

`command_policy.rtk_commands` now has 66 entries: 20 `pipe` (all 18 filters of RTK 0.42.4, including `python -m pytest` and `python3 -m pytest`), 46 `recognized-only`, 0 `never`. `rtk_class_enabled` is `pipe` true, `rerun`, `recognized-only`, and `never` false. `cat`, `head`, `tail` (`rtk read`), `rtk read`, and `rtk smart` stay `recognized-only` (D-37).

* **Code:** the filter deny list in `wx-compress.sh` and `doctor.sh` is removed, so a valid `pipe` entry with the class enabled uses RTK. Resolution is otherwise unchanged: unknown or missing class, `rerun`, `recognized-only`, and `never` stay raw. Protected profiles still bypass RTK.
* **Tests:** `wx-wrapper.test.sh` has a table section (class, filter names, no duplicates, every documented command present, every entry resolved, pipe off, all classes on, every pipe entry blocked in the five protected profiles). The old tests for denied filters and the `grep`/`find`/`git` exclusions were rewritten. `doctor.test.sh` has the new counts, and a malformed filter is still a warn. No per-command fixtures were added.
* **Risk:** `grep`, `rg`, `find`, `fd`, `git-*`, `log`, `mypy`, `ruff-*`, and `prettier` are enabled without fixtures or a measured guard (D-07, D-38). `ast-grep` is in RTK's coverage page but not in the `rtk --help` of 0.42.4.

Debt IDs changed: D-07, D-38. D-06, D-36, and D-37 are unchanged.

## RTK test matrix for all 18 pipe filters (2026-10-07)

Added `tests/fixtures/rtk/MATRIX` (59 fixtures, one row each: group, kind, fake outcome, real 0.42.4 outcome, real evidence result) and `markers` files (text that must stay visible). The wx test (sections 3j and 3k) and `benchmarks/run-rtk-benchmark.sh` both read it. The command table is unchanged.

* **Fixtures:** groups A (existing six), B (`mypy`, `ruff-check`, `ruff-format`, `prettier`), C (`grep`, `rg`, `find`, `fd`, `git-log`, `git-status`, `git-diff`), D (`log`). `git`, `grep`, `find` were recorded from real runs (`tests/fixtures/record-live-fixtures.sh`). The tools for `mypy`, `ruff`, `prettier`, `rg`, `fd` are not installed here, so those and `log` are hand-written, as is `cargo-test`. Commands replay through `tests/fixtures/shim-command.sh`, which only answers the exact recorded command line.
* **Tests:** every filter has a success case and an evidence or failing case. Every row is checked with the fake RTK (one command run, raw files and exit code first, one RTK call, outcome) and with the real RTK (pinned outcome and evidence). Every filter runs in all five protected profiles and stays raw with no RTK call. The matrix and the config pipe filters must be the same set.
* **Benchmark:** 81 rows per section. Raw capture, exit codes, stderr, and protected profiles are hard checks. Shown RTK output that lacks marked text is a pinned known loss (12 rows), listed in the output and in the validation matrix.
* **Mutation checks:** an evidence pin changed from `no` to `yes` makes the benchmark exit 1.
* **Guard issues:** the guard accepted all 12 lossy outputs. It sees error and warning lines, not omitted files, commits, or counts (D-38).

Debt IDs changed: D-06, D-07, D-38. Still open: D-38 (decision on the lossy filters), D-06 (one RTK version, not in CI), D-08, D-36, D-37.

## RTK matrix issues fixed (2026-10-07)

Source of truth: the matrix benchmark (12 known losses, 12 of 24 shown real-RTK outputs). Table now 69 entries: 16 `pipe`, 53 `recognized-only`, 0 `never`.

* **Guard (too weak):** one rule added in `_wx_evidence_guard`: an RTK line matching `+N more <word>` or `+N line(s) omitted` is rejected unless raw contains that text. Regression: `find/many`, `fd/many`, `git-log/history`, `git-log/oneline` are now `guard` fallbacks with real RTK, plus direct guard tests (a look-alike such as `a +1 more than b` in raw is accepted).
* **Config (RTK behavior the guard cannot see):** `tsc`, `go test`, `ruff format`, `prettier` moved to `recognized-only`, and `pytest --collect-only` (three forms) added as `recognized-only` (longest prefix beats `pytest`). Their fixtures stay as group X rows that must resolve to `recognized-only` and stay raw. `go-test`, `tsc`, `ruff-format`, `prettier` are no longer pipe filters.
* **Kept:** `go build` (no stdout, harmless), `ruff check` and `grep`/`rg` (RTK output is usually larger, so raw is shown), `git status`, `git diff`, `log`, `mypy`, `cargo test`, `pytest`, `vitest`.
* **Result:** wx tests and the benchmark pass with 0 known losses. Real RTK, 42 code rows: 11 RTK outputs shown (13728 to 2783 bytes), 18 raw fallbacks (10 not smaller, 7 evidence guard, 1 empty RTK output).

Debt IDs changed: D-06, D-07, D-38.

## D-05 closed (2026-10-07)

`templates/AGENTS_base.md` now tells agents to read `AICONTEXT_OUTPUT_STYLE` from `active_mode.env` and, for `ste-inspired`, write short direct technical English while keeping errors, paths, commands, code, warnings, and test output exact. This is policy only: it depends on agent compliance, and no code interprets the value. Nothing else needed the variable, so the row is removed.

## LeanCTX policy scaffold (2026-10-07)

Added top-level `leanctx_policy` to `config/workflow_settings.json`: `transport_preference` `mcp-preferred-cli-validated`, `shell_owner` `wx`, `shell_enabled`, `auto_wrap`, `auto_setup`, `auto_init` all `false`, `smart_file_owner` `leanctx`, and `operations` (read, search, tree, compose, graph enabled; shell disabled and reserved; edit and memory deferred). Doctor validates it (`leanctx.policy`, `leanctx.policy_unsafe`, `leanctx.policy_invalid`, `leanctx.policy_missing`), with tests in `tests/doctor.test.sh`. Nothing else reads it. LeanCTX was not run. Debt ID changed: D-01 (revised, still open).

## LeanCTX doctor checks (2026-10-07)

`workflow doctor` reports LeanCTX (text and JSON). New JSON object `leanctx` (found, path, platform_path, version, version_ok, status, doctor, shell_hook_paths, mcp_config_paths). Findings: `leanctx.missing`, `leanctx.version_failed`, `leanctx.windows_binary` (WSL and the path is under /mnt/<drive></drive>), `leanctx.linux_binary`, `leanctx.status`, `leanctx.doctor`, `leanctx.doctor_problems`, `leanctx.doctor_failed`, `leanctx.doctor_timeout`, `leanctx.doctor_skipped`, `leanctx.shell_hook` (warn: wx owns terminal output), `leanctx.mcp`.

* **Safe calls only:** `--version` (3 s) and `doctor` (15 s, `AICONTEXT_LEANCTX_TIMEOUT`, output cut at 20000 bytes). `lean-ctx status` is not run: with 3.9.19 it writes `status/latest.json` in the LeanCTX data directory. `lean-ctx doctor` changed no file in a check on this machine. Never `wrap`, `setup`, `init`, `onboard`, or `doctor --fix`.
* **Cost:** about 3 seconds more per doctor run when lean-ctx is installed.
* **Tests:** fake lean-ctx in `tests/doctor.test.sh` (missing, ok, problems, nonzero without report, version failure, timeout, WSL with a Windows-mount path, WSL with a Linux path, hook and MCP markers with a no-change snapshot, and no change-capable call in the call log). Test hooks: `AICONTEXT_LEANCTX_BIN`, `AICONTEXT_DOCTOR_MNT_PREFIX`.

Debt IDs changed: D-01 (text), D-24 (narrowed: LeanCTX hook and MCP detection added as text matches).

## LeanCTX CLI harness (2026-10-07)

Added `tests/leanctx.test.sh` and `tests/fixtures/leanctx/lean-ctx` (fake), and a CI step (fake only, the real run is skipped when lean-ctx is missing or `AICONTEXT_TEST_SKIP_REAL_LEANCTX=1`). Asserts: the seven commands, byte-identical full read, a visible failure, the call log (no wrap, setup, init, onboard, `-c`, `ctx_shell`, `--fix`), no wx files, no wx library mention. Real part: config directory and repository unchanged, a started daemon is stopped. It prints a byte table (raw, LeanCTX, reduction, evidence preserved).

* **Finding:** real evidence results are warnings, not failures: `read -m full --fresh`, `grep`, and `ls` lose text (D-39).
* Debt IDs changed: D-39 (new), D-01 (text).

## LeanCTX CLI adapter (2026-10-07)

Added `scripts/leanctx-cli.sh`, called as `workflow leanctx status|read|read-exact|search|tree` (sourced or through `workflow-cli.sh`). It is not run through `wx`, and never runs wrap, setup, init, onboard, `status`, `doctor`, `-c`, `ctx_shell`, or `--fix`.

* **Reads:** `active_mode.env` (profile, `AICONTEXT_LEANCTX_MODE`; shell variables are ignored), and `leanctx_policy` (`shell_enabled`, `shell_owner`, `auto_wrap`, `auto_setup`, `auto_init` must be strict booleans false and `wx`; `operations.read|search|tree.status` must be `enabled`).
* **Refuses (exit 1):** `off` mode, the profiles raw, security, db, migration, release, micro, snippet, off (even with a non-off mode), no mode file, a policy that is missing or turns shell/wrap/setup/init on, lean-ctx missing, a Windows path under WSL (override `AICONTEXT_ALLOW_WINDOWS_LEANCTX=true`, with a warning), paths outside the current directory, files over 5 MB for an exact read.
* **Exit codes:** 0 ok, 1 refused, 2 usage, 3 verification failed (fail closed), 4 lean-ctx failed.
* **Not done:** `find`, MCP calls, edit, memory, shell. Agent instructions in `templates/AGENTS_base.md` do not yet point to the adapter.
* **Tests:** `tests/leanctx.test.sh` (fake lean-ctx with the D-39 behaviors; real lean-ctx optional). Mutation checks: the search guard, the exact-read compare, and the protected-profile gate each make the test fail.
* Debt IDs changed: D-01 (text), D-39 (mitigated).

## LeanCTX adapter hardening (2026-10-07)

* **Binary:** `AICONTEXT_LEANCTX_BIN` must be an absolute path. A binary inside the project (current directory or git root), as given or after `readlink -f`, is refused unless `AICONTEXT_ALLOW_PROJECT_LEANCTX=true` (warning). A relative PATH entry is made absolute first. The home directory and `/` do not count as a project. A symlink to the WSL Windows mount is refused as a Windows binary (`AICONTEXT_ALLOW_WINDOWS_LEANCTX=true` overrides). A refused binary is never run, not even for `--version`.
* **Search:** the pattern must have no control characters (newline, CR, tab, ESC, DEL) and at most 512 bytes. It still cannot start with `-`. The raw verifier is `grep -rlIE -e <pattern>` with a 10 s timeout, because LeanCTX grep is a regex (it accepts `a|b`). Limit: a pattern that LeanCTX reads but POSIX ERE rejects fails closed (exit 3, "cannot verify"). A raw grep also sees files that LeanCTX may skip on purpose, so it can fail closed with a false alarm.
* **Doctor:** warns `leanctx.project_binary` and does not run a project-local lean-ctx (also skipped for `tool.lean-ctx`). A symlink to the Windows mount is reported as a Windows binary.
* **Exit codes:** unchanged (0 ok, 1 refused, 2 usage, 3 verification failed, 4 lean-ctx failed). Newly refused inputs use the existing codes (project-local and relative binary: 1; bad pattern: 2).
* **Tests:** `tests/leanctx.test.sh` (project-local PATH and relative PATH entry, override, relative and bare `AICONTEXT_LEANCTX_BIN`, absolute outside, symlinks both ways, Windows symlink, 7 bad patterns, 512-byte limit, non-ASCII pattern, alternation, ERE limitation) and `tests/doctor.test.sh`. Mutation checks: the project gate and the length limit each make the test fail.
* Debt IDs changed: D-01 (text), D-24 (text).
