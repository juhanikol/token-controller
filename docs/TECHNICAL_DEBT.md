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
