<!-- ai-workflow-controller:start -->
# AGENTS.md - AI Context Workflow Rules

## Project purpose
This repository is a local WSL/Ubuntu shell state manager for AI coding sessions. It does not perform compression by itself. It exports environment variables that tell compatible tools and VS Code agents what context strategy should be used for the current engineering scenario.

## Prime directive
Correctness beats token savings. Use compression only when the evidence type can tolerate it. Preserve raw evidence for failures, security, database migration, release, and compliance-sensitive work.

## Before touching files or running commands
1. Read the active context profile from the environment or from `~/.config/ai-workflow/active_mode.env`.
2. Report the active profile in your plan when it affects tool usage.
3. Do not assume RTK, Headroom, LeanCTX, MemStack, or Caveman are installed. Detect tools before relying on them.
4. Never modify `AGENTS.md` silently. Propose changes first unless the human explicitly asks you to edit it.
5. Prefer small, incremental changes. Do not rewrite unrelated features.

## Active profile variables
Use these variables when deciding how much context to read or compress:

- `AICONTEXT_PROFILE`
- `AICONTEXT_RISK`
- `AICONTEXT_COMPRESS_SHELL`
- `AICONTEXT_COMPRESS_FILES`
- `AICONTEXT_CODEBASE_INDEX`
- `AICONTEXT_MEMORY_LAYER`
- `AICONTEXT_HEADROOM_MODE`
- `AICONTEXT_LEANCTX_MODE`
- `AICONTEXT_RTK_MODE`
- `AICONTEXT_CAVEMAN_OUTPUT`
- `AICONTEXT_RAW_ON_FAIL`
- `AICONTEXT_KEEP_RAW_LOGS`
- `AICONTEXT_AGENTS_MUTATION`

Backward-compatible variables may also exist:

- `RTK_HOOK_ENABLED`
- `HEADROOM_COMPRESSION_STRATEGY`
- `LEANCTX_ACTIVE`
- `MEMSTACK_ACTIVE`
- `CAVEMAN_OUTPUT`

## Fidelity policy
Always preserve or request raw content for:

- edited target files
- first failing test output
- stderr, exit code, first error, stack trace origin
- line numbers and file paths
- security scans and vulnerability identifiers
- secrets/auth/crypto code
- database migrations, schema changes, and data-loss warnings
- release artifacts, checksums, signing, changelog, and versioning
- performance numbers, percentiles, memory measurements, and sample sizes

Compression is acceptable for:

- successful repetitive test output
- package manager fetch logs
- Docker build boilerplate
- generated files not being edited
- vendor directories
- previously indexed structure
- duplicate warnings after the first exact instance is preserved

## Scenario behavior
- `raw`, `security`, `db`, and `release`: use raw or lossless context only.
- `scope`, `architect`, `decisions`, and `review`: use structural maps and codebase indices, then full-read selected files.
- `code` and `snippet`: full target file and nearby tests; dependency summaries are acceptable.
- `debug` and `test`: preserve the first failure exactly; compress only repeated pass/noise output.
- `cicd`: preserve workflow YAML, shell scripts, environment assumptions, exit code, and failing lines; compress fetch/install boilerplate only.
- `docs`: use normal prose. Do not use Caveman-style output for final documentation.

## AGENTS.md stability
Keep this file short and stable. Dynamic task state belongs in files such as:

- `TASK.md`
- `PLAN.md`
- `STATE.md`
- `DECISIONS.md`
- `.ai-context/validation-log.md`

## Validation requirement
When changing profiles, scripts, or README scenario guidance, update `docs/VALIDATION_MATRIX.md` with:

- scenario tested
- profile used
- commands run
- tools installed or missing
- raw token estimate or size
- compressed token estimate or size
- evidence preserved
- evidence lost or possibly hidden
- pass/fail decision
- recommended profile change
<!-- ai-workflow-controller:end -->
