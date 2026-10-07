# Technical Debt

## Open issues (quick view)

Last reviewed: 2026-10-07. This table is the **current state**. The sections below are the detailed history and findings. Their "Open" lists are not kept up to date, so use this table.

How to keep it:
* **Add a row** when a new debt, decision, missing feature, risk, or contradiction is found. Use the next free ID (never reuse an ID). Add the details as a section below, in the same style as now.
* **Remove the row** when the issue is fixed. Do not mark it "done" in the table. Say what was fixed in the details section.
* **Change the Status** when it moves (Open, Mitigated, Decision needed). Update "Last reviewed".
* Types: **Debt** (code or doc that should change), **Contradiction** (text says something false), **Not implemented** (planned, not built), **Decision** (needs an owner decision), **Risk** (known and accepted or unresolved exposure).
* Severity: **High** (blocks the product direction or can hide evidence), **Medium** (limits a release or weakens a guarantee), **Low** (tidy-up).

| ID | Type | Severity | Area | Issue | Status | Details |
|---|---|---|---|---|---|---|
| D-01 | Not implemented | High | Orchestration | LeanCTX is not orchestrated. `leanctx_mode` is exported state only. There is no design doc and no code. The critical modes have `leanctx_mode` `off` until LeanCTX has its own design and tests. | Open | Plan work package 7 |
| D-02 | Not implemented | High | Orchestration | Headroom is not orchestrated. `headroom_mode` is exported state only. No design doc, no code. | Open | Plan work package 7 |
| D-03 | Not implemented | Medium | Config | Mode to tool mapping uses free-text labels. Only `off` or not-`off` is read. `compress_files`, `memory_layer`, `codebase_index`, `leanctx_mode`, `headroom_mode` have no consumer. `memory_layer` and `codebase_index` are still on for `security`, `db`, and `migration`. | Open | Plan work package 4 |
| D-04 | Decision | Medium | Config | MemStack is legacy. `MEMSTACK_ACTIVE` and `memory_layer` are kept until the tool shape is clear. | Decision needed | Plan, "LeanCTX/Headroom" |
| D-05 | Not implemented | Medium | Output style | `AICONTEXT_OUTPUT_STYLE` (`ste-inspired`) is exported but nothing uses it. The template does not mention it. | Open | Foundation debt status |
| D-06 | Decision | Medium | Validation | `docs/VALIDATION_MATRIX.md` has no entry for the RTK prototype. The benchmark has no RTK scenario, so no measured RTK reduction exists. Required after a second tool is integrated. | Decision needed | RTK post-capture prototype |
| D-07 | Debt | Medium | RTK | Evidence guard v1 needs tuning. Real RTK 0.42.4 drops `warning:` lines from pytest-like output, so the guard falls back to raw. Coverage is six filters (no `python -m pytest`, `npx`, `npm test`, `dotnet test`, `log`). | Open | RTK post-capture prototype |
| D-08 | Risk | Medium | RTK | An RTK global hook rewrites commands and skips `wx` capture. Doctor only warns. Other hosts (Copilot, Cursor) are not checked. | Open | RTK post-capture prototype |
| D-09 | Risk | Low | RTK | Side effects of `rtk --version` and `rtk pipe` (tracking, telemetry) were checked once, in one scratch `HOME`. | Open | RTK PLAN |
| D-10 | Not implemented | Medium | Caveman | Prompt guards are not implemented. Caveman rules for first-failure evidence are policy text. Only `debug` is blocked in code, so failing `test` and `cicd` runs rely on the template. | Open | Caveman policy state |
| D-11 | Not implemented | Medium | Caveman | Shrink and proxy are not implemented (`caveman_shrink` has no effect). Upstream questions are open: state file format, session-start hook, `caveman-compress` vs the managed block, gateway data flow. | Open | `docs/integrations/CAVEMAN.md` |
| D-12 | Risk | Low | Caveman | `AICONTEXT_CAVEMAN_REQUEST` exported in a shell profile opts in on every activation. Doctor does not check it. | Open | Caveman policy state |
| D-13 | Risk | Medium | Stale terminals | Already-open terminals keep old `AICONTEXT_*` variables. `wx` and `report` are protected. A person, script, or agent that reads the variables directly can see the wrong profile. The extension cannot inspect terminals. | Mitigated | Stale terminal safety |
| D-14 | Debt | Medium | `workflow.sh` | `workflow setup` writes the same instruction to several user-level files without a conflict check. | Open | Foundation debt status |
| D-15 | Debt | Low | `workflow.sh` | `workflow.sh` runs `mkdir -p ~/.config/ai-workflow` before any command, so `doctor`, `status`, and `help` are not read-only through it. Documented, not fixed. | Open | Workflow --doctor |
| D-16 | Debt | Low | `workflow.sh` | `workflow help` mode list and `Aliases:` lines are hand-written, a fourth copy of the mode list. | Open | `workflow modes --json` |
| D-17 | Debt | Low | `workflow.sh` | `off-*` labels: `workflow.sh` treats only exact `off` as RTK off, `wx` treats `off` and `off-*` as off. No config value triggers it today. | Open | Foundation debt status |
| D-18 | Debt | Low | Config | The Caveman level rules exist twice (bash and jq). The blocked list exists in four places (`workflow.sh` twice, `doctor.sh`, config). Tests guard them. | Open | Caveman policy state |
| D-19 | Debt | Low | Config | Legacy `caveman_output` key stays in config defaults but is not read. Kept so the validation matrix entry stays true. | Open | Foundation debt status |
| D-20 | Contradiction | Low | Scripts | `scripts/check-tools.sh` prints that `wx` does not invoke RTK. `wx` now calls `rtk pipe` for six commands. | Open | Debt review (this file) |
| D-21 | Debt | Low | Scripts | `ccusage` is checked by doctor but not by `check-tools.sh` or `install-optional-tools.sh`. | Open | Debt review (this file) |
| D-22 | Debt | Low | Docs | README does not document `AICONTEXT_USE_SHELL_STATE`, `AICONTEXT_CAVEMAN_REQUEST`, `AICONTEXT_RTK_BIN`, `AICONTEXT_RTK_TIMEOUT`. README is long (475 lines). | Open | Debt review (this file) |
| D-23 | Contradiction | Low | Docs | `docs/MODE_SWITCHER_AND_ORCHESTRATOR_PLAN.md` "Documents to revise" table and work packages are out of date. | Open | Debt review (this file) |
| D-24 | Debt | Low | Doctor | MCP config checks are not implemented. RTK setup detection is a text match on known Claude Code locations. `.caveman-active` format is assumed to be a level name. | Open | Doctor improvements |
| D-25 | Not implemented | Medium | CLI | No `version` command or schema compatibility rule. No `set --json` or `report --json`. `wx` is not reachable through `workflow-cli.sh`. `status --json` has no `description` or `caveman_shrink`. | Open | Non-sourced entry point |
| D-26 | Not implemented | Medium | Extension | Report summary, doctor summary, and tool availability are not shown. No Caveman toggle. `caveman_requested` is not shown. | Open | Extension uses the CLI JSON interface |
| D-27 | Not implemented | Medium | Windows | No Windows or WSL backend, no environment check (`remoteName`, distro), no Windows CI. The CLI uses GNU tools (`timeout`, `stat -c`, `awk`) and Bash. | Open | Extension alignment design |
| D-28 | Debt | Medium | Extension | Not tested in a real VS Code or WSL window. `vscode-test` was not run. The status bar, picker, and watcher code has no automated test. Manifest scope, `inspect()`, and `isTrusted` behavior are untested. | Open | Extension configuration and trust hardening |
| D-29 | Debt | Low | Extension | The tracked `.vsix` is 1.1.0 and does not contain the fixes. Version and CHANGELOG are "Unreleased". | Open | Extension uses the CLI JSON interface |
| D-30 | Risk | Medium | Extension | The configured script is trusted code with no check of content or owner. A trusted workspace may contain the controller. The CLI inherits the host environment. Multi-root and virtual workspaces are only partly covered. | Risk accepted | Extension configuration and trust hardening |
| D-31 | Debt | Low | Extension | Missing `jq` or an old controller shows "unavailable" with no install help. `stale_shell` describes the VS Code environment, not a terminal. | Open | Extension uses the CLI JSON interface |
| D-32 | Not implemented | Low | Research | Research candidates are not evaluated: ccusage, Aider repo map, token-optimizer, token-savior. | Open | Plan, "External tools" |
| D-33 | Debt | Low | Config | The flags `raw_on_fail`, `keep_raw_logs`, `preserve_*`, `target_files_full`, and `compress_files` are exported but read by nothing. `wx` hard-wires the safe behavior, so setting them to `false` has no effect. Keeping target files full is policy only. | Open | Profile/state manager review in `VALIDATION_MATRIX.md` (F2) |

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

| Field | Meaning |
|---|---|
| `profile`, `risk` | Active profile and its risk from the env file |
| `output_style` | `AICONTEXT_OUTPUT_STYLE` |
| `raw_on_fail`, `keep_raw_logs` | Booleans |
| `compress_shell`, `compress_files` | Policy labels |
| `rtk_mode`, `leanctx_mode`, `headroom_mode` | Tool modes as exported state |
| `caveman_mode`, `caveman_max`, `caveman_output` | Effective Caveman state. `caveman_output` is a boolean |
| `source` | `active_env_file` (file has a profile), `shell_fallback` (no usable file, shell has a profile), `unset` (nothing usable). A file without a profile gives `unset`, like `wx` (output stays raw) |
| `active_env_file` | Path that was checked |
| `shell_profile` | The shell's profile when it differs from `profile`, else `null` |
| `stale_shell` | `true` when the shell has a profile, the source is not `shell_fallback`, and the profiles differ |
| `use_shell_state` | `true` when `AICONTEXT_USE_SHELL_STATE=true` is set. `wx` then uses shell variables, but this JSON still describes the file |

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
