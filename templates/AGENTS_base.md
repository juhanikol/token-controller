<!-- ai-workflow-controller:start -->
## AI Context Policy

Before broad work, read `~/.config/ai-workflow/active_mode.env`. It is the source of truth for the active profile. Do not rely only on `AICONTEXT_*` shell variables: a terminal that was already open can keep stale values after the mode changes in the editor. `wx` uses `active_mode.env` by default.

Use the active profile to decide whether context-saving tools should be used. Prefer proven configured tools first:
- RTK for noisy shell/build/test/install output.
- LeanCTX for context-aware file, symbol, search, shell, and retrieval workflows.
- Headroom for proxy/MCP compression and recoverable context.
- Caveman (terse output) is off by default. Use it only if `AICONTEXT_CAVEMAN_MODE` in `active_mode.env` is `lite` or `full`. Never in docs, security, db, release, migration, or debug work. Never for first-failure evidence or for instructions a person must follow.

Read `AICONTEXT_OUTPUT_STYLE` from `active_mode.env`. When it is `ste-inspired`, write clear technical English: short direct sentences, active voice where practical, one instruction per sentence, no decorative wording, and keep required technical terms. This is inspired by simplified technical English, not strict ASD-STE100 compliance.
Keep errors, paths, line numbers, commands, code, warnings, and test output exact.

Use `wx` for test/build/install/diagnostic commands when raw evidence and measurement are required. `wx` must preserve raw stdout/stderr and exit codes before any compression.

Do not use compression or terse-output modes for security, database migrations, releases, regulated or high-risk work, or precise documentation.

For debug, test, and cicd work, preserve the first failure completely: error message, stack trace, stderr, exit code, file paths, and line numbers. Summarize only repetitive success output.

For tiny single-file or snippet tasks, prefer no context tool unless output is expected to be large.
<!-- ai-workflow-controller:end -->
