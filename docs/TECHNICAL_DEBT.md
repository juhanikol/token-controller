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
* **Stale terminals:** a terminal that already ran `workflow <mode>` keeps old variables. Decision open in `docs/EXTENSION_ALIGNMENT_DESIGN.md`.
* **Tracked `.vsix`:** `extensions/vscode/token-controller-ui-1.1.0.vsix` is in git and does not contain these fixes. Rebuild and bump the version when you release.

## Stale terminal safety (2026-10-07)

Fixed:
* `wx` and `workflow report` prefer `active_mode.env` over shell `AICONTEXT_*` variables. Stale shell policy variables are dropped before the file is applied. A test reproduces the old bug (shell `code`, file `security`: output was compressed) and passes now.
* The env file is parsed, not sourced. Lines that are not plain `export AICONTEXT_NAME="value"` are ignored. A file without a profile leaves output raw and warns.
* Escape hatch: `AICONTEXT_USE_SHELL_STATE=true`.
* `AICONTEXT_RAW_LOG_DIR` is now read after the policy state loads. Before, a stale shell value or the default was used even when the file set it.
* `session.jsonl` records `policy_source` and `stale_shell_profile` (additive fields, `schema_version` stays 2).
* `workflow status` shows the env-file profile and warns when the shell differs. Doctor's shell mismatch warning says `wx` uses the file.

Still open:
* Agents that read shell variables directly (not through `wx`) still see stale values until the terminal runs `workflow <mode>`. Options are in `docs/EXTENSION_ALIGNMENT_DESIGN.md`.
* There is no `status --json` yet. The text `workflow status` is the only place that shows both states.
* `wx` ignores values with `$`, backticks, or backslashes in the env file. `workflow.sh` never writes them today.
