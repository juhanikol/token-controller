<!-- ai-workflow-controller:start -->
## AI Context Policy

Before broad work, read `~/.config/ai-workflow/active_mode.env`.

Use the active profile to decide whether context-saving tools should be used. Prefer proven configured tools first:
- RTK for noisy shell/build/test/install output.
- LeanCTX for context-aware file, symbol, search, shell, and retrieval workflows.
- Headroom for proxy/MCP compression and recoverable context.
- Caveman only when output brevity is appropriate and not harmful.

Use `wx` for test/build/install/diagnostic commands when raw evidence and measurement are required. `wx` must preserve raw stdout/stderr and exit codes before any compression.

Do not use compression or terse-output modes for security, database migrations, releases, legal/compliance, precise documentation, or first failing debug evidence.

For tiny single-file or snippet tasks, prefer no context tool unless output is expected to be large.
<!-- ai-workflow-controller:end -->
