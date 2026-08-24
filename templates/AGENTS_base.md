<!-- ai-workflow-controller:start -->
# AI Context Policy

## Active Profile
Before executing tasks, check `~/.config/ai-workflow/active_mode.env` for `AICONTEXT_PROFILE` and `AICONTEXT_RISK`. Correctness and safety strictly supersede token reduction.

## Execution Rules
- **Terminal Execution:** Prefix terminal test, build, and package commands with `wx` (e.g., `wx npm test`).
- **Tool Routing:** `wx` directly intercepts commands only for RTK. LeanCTX, Headroom, and MemStack are integration-driven; use them only when they are installed, exposed through the IDE or MCP, and enabled by `AICONTEXT_LEANCTX_MODE`, `AICONTEXT_HEADROOM_MODE`, `AICONTEXT_CODEBASE_INDEX`, or `AICONTEXT_MEMORY_LAYER` as applicable.
- **Code Exploration:** If LeanCTX or Headroom MCP tools are available, prioritize them over standard `cat` or `grep` for codebase exploration. Use raw file reads when the active profile requires full fidelity or when those MCP tools are unavailable.

## Behavioral Guardrails (Default & Tool-Free)
- If no optional tool is available, use standard tools and apply these guardrails manually.
- **`raw` / `security` / `db` / `release`:** 100% lossless. Read target files completely; preserve all SQL, auth code, CVE findings, and data warnings.
- **`debug` / `test` / `cicd`:** Preserve the first failure, stack trace, line numbers, stderr, and exit code. Summarize repetitive passing noise.
- **`code` / `architect` / `scope`:** Read target files being edited in full; summarize broad dependency trees and boilerplate.
<!-- ai-workflow-controller:end -->
