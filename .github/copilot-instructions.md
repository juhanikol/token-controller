# Copilot Instructions

This repository is a WSL/Ubuntu shell profile controller for AI context workflows. It exports environment variables for scenario-specific token/context behavior; it does not implement compression itself.

When working in this repository:

- Keep `config/workflow_settings.json` as the source of truth for profiles.
- Keep `scripts/workflow.sh` small, POSIX-friendly where practical, and safe to source.
- Do not source `~/.bashrc` from inside `workflow.sh`.
- Preserve `workflow status` behavior even before a profile is activated.
- Preserve backward-compatible variables: `RTK_HOOK_ENABLED`, `HEADROOM_COMPRESSION_STRATEGY`, `LEANCTX_ACTIVE`, `MEMSTACK_ACTIVE`, and `CAVEMAN_OUTPUT`.
- Do not assume RTK, Headroom, LeanCTX, MemStack, or Caveman are installed.
- High-risk profiles must preserve raw or lossless evidence.
- Update `docs/VALIDATION_MATRIX.md` when profile behavior changes.
- Validate shell and JSON changes with `bash -n scripts/workflow.sh` and `jq . config/workflow_settings.json >/dev/null`.
