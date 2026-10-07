<!-- ai-workflow-controller:start -->
## AI Context Policy

**Active Profile Setup**
Read the file `~/.config/ai-workflow/active_mode.env` before you start a large task.
This file contains the correct active profile.
Do not rely only on the `AICONTEXT_*` shell variables.
An open terminal can contain old variable values.
The `wx` tool reads `active_mode.env` by default.

**Tool Selection**
Read the active profile to select the correct context-saving tool.
Use the tool `RTK` for shell, build, test, and install output that contains too much text.
Use the tool `LeanCTX` for context-aware file reads, code searches, directory maps, and code graphs. See the LeanCTX rules.
Use the tool `Headroom` to compress proxy or MCP data and to recover context.

**Caveman Rules**
The tool `Caveman` is off by default.
Use `Caveman` only when `AICONTEXT_CAVEMAN_MODE` is `lite` or `full` in `active_mode.env`.
Do not use `Caveman` for documentation, security, database changes, software releases, data migrations, or debug tasks.
Do not use `Caveman` to record the first failure.
Do not use `Caveman` to write instructions for a human user.

**LeanCTX Rules**
Use `LeanCTX` only when `AICONTEXT_LEANCTX_MODE` in `active_mode.env` is not `off` and the LeanCTX MCP tools are available.
Use `ctx_tree`, `ctx_search`, `ctx_read`, and `ctx_compose` to explore the code and to read files.
Use the `map`, `signatures`, or `task` read modes first.
Use a fresh `full` or raw read before an exact edit.
Do not use `ctx_shell`. Use `wx` for terminal commands.
Do not use `LeanCTX` in the `raw`, `security`, `db`, `migration`, or `release` profiles, unless the active profile allows it.
Do not run `lean-ctx wrap`, `setup`, or `init`.

**Output Style**
Read the `AICONTEXT_OUTPUT_STYLE` value from `active_mode.env`.
If the value is `ste-inspired`, use clear technical, ASD-STE100 inspired not complied, English.
Write short and direct sentences.
Use the active voice.
Write one instruction in each sentence.
Do not use decorative words.
Do not change required technical terms.
Write the exact errors, file paths, line numbers, commands, code, warnings, and test output.

**Command Execution**
Use the tool `wx` to execute test, build, install, and diagnostic commands.
Use `wx` when you must measure data or record raw evidence.
Do not compress the raw stdout, stderr, or exit codes in `wx`.

**Task Restrictions**
Do not use data compression for security tasks, database migrations, software releases, regulated tasks, or high-risk tasks.
Do not use terse-output modes for precise documentation.

**Debug, Test, and CI/CD Tasks**
Record the first failure completely in debug, test, and CI/CD tasks.
Include the exact error message, stack trace, stderr, exit code, file paths, and line numbers.
Summarize only the repetitive success output.

**Small Tasks**
Do not use a context tool for small single-file tasks or code snippet tasks.
Use a context tool only if the expected output is large.
<!-- ai-workflow-controller:end -->
