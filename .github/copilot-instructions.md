# Copilot Instructions

This repository is a WSL/Ubuntu mode switcher and orchestrator for AI context policy. `workflow <mode>` exports profile variables for proven external context tools (RTK, LeanCTX, Headroom, Caveman). The `wx` wrapper is the raw-capture, exit-code, measurement, and fallback layer. Its built-in compression is a conservative fallback, not the main token-saving mechanism. See `AGENTS.md` for project rules.

When working in this repository:

- Keep `config/workflow_settings.json` as the source of truth for profiles.
- Keep `scripts/workflow.sh` safe to source.
- Do not source `~/.bashrc` from inside `workflow.sh`.
- Preserve `workflow status` behavior even before a profile is activated.
- Preserve backward-compatible variables: `RTK_HOOK_ENABLED`, `HEADROOM_COMPRESSION_STRATEGY`, `LEANCTX_ACTIVE`, `MEMSTACK_ACTIVE` (legacy, kept for now), and `CAVEMAN_OUTPUT`.
- Do not assume RTK, Headroom, LeanCTX, MemStack, or Caveman are installed.
- High-risk profiles must preserve raw or lossless evidence. External tools may process output only after `wx` captures the raw output.
- Do not claim guaranteed token savings.
- Update tests when `wx` capture or compression behavior changes. `docs/VALIDATION_MATRIX.md` is required only after external tools are integrated.
- Validate shell and JSON changes with `bash -n scripts/workflow.sh` and `jq . config/workflow_settings.json >/dev/null`.
