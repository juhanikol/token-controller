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

## Decisions for you

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
