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
