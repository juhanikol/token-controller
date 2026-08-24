<!-- ai-workflow-controller:start -->
# AI Context Workflow Rules

## Purpose
This WSL/Ubuntu shell state manager exports context-policy variables for compatible tools and VS Code agents; it does not compress content itself.

## Core rules
Correctness beats token savings; compress only tolerant evidence and preserve raw failure, security, database, release, and compliance evidence.

1. Read the active context profile from the environment or from `~/.config/ai-workflow/active_mode.env`.
2. Report it when it changes tool use; detect optional tools before relying on them.
3. Edit `AGENTS.md` only when explicitly asked; keep all edits small and scoped.

## Tool & Execution Rules
Always prefix terminal commands with `wx` (for example, `wx npm test`) unless the active mode is `security`, `db`, or `raw`.
When LeanCTX or Headroom MCP tools are available, prioritize them over standard `cat` or `grep` for codebase exploration.
Use standard exploration tools only when neither MCP option is available.

## Policy inputs
Use these variables to choose context fidelity and compression:

- Profile: `AICONTEXT_PROFILE`, `AICONTEXT_RISK`.
- Tools: `AICONTEXT_COMPRESS_SHELL`, `AICONTEXT_COMPRESS_FILES`, `AICONTEXT_CODEBASE_INDEX`, `AICONTEXT_MEMORY_LAYER`, `AICONTEXT_HEADROOM_MODE`, `AICONTEXT_LEANCTX_MODE`, `AICONTEXT_RTK_MODE`, `AICONTEXT_CAVEMAN_OUTPUT`.
- Safety: `AICONTEXT_RAW_ON_FAIL`, `AICONTEXT_KEEP_RAW_LOGS`, `AICONTEXT_AGENTS_MUTATION`.

Compatibility variables: `RTK_HOOK_ENABLED`, `HEADROOM_COMPRESSION_STRATEGY`, `LEANCTX_ACTIVE`, `MEMSTACK_ACTIVE`, `CAVEMAN_OUTPUT`.

## Fidelity policy
Preserve raw edited targets; first failures; stderr, exit codes, first errors, stack origins, paths, and lines; security findings and auth/crypto code; database changes and data-loss warnings; release artifacts and metadata; and performance measurements with sample sizes.

Compression is acceptable for repetitive successes, fetch/build boilerplate, unedited generated or vendor files, indexed structure, and duplicate warnings after preserving the first exact instance.

## Scenario behavior
- `raw`, `security`, `db`, and `release`: use raw or lossless context only.
- `scope`, `architect`, `decisions`, and `review`: use structural maps and codebase indices, then full-read selected files.
- `code` and `snippet`: full target file and nearby tests; dependency summaries are acceptable.
- `debug` and `test`: preserve the first failure exactly; compress only repeated pass/noise output.
- `cicd`: preserve workflow YAML, shell scripts, environment assumptions, exit code, and failing lines; compress fetch/install boilerplate only.
- `docs`: use normal prose. Do not use Caveman-style output for final documentation.

## AGENTS.md stability
Keep this file short and stable; put dynamic state in `TASK.md`, `PLAN.md`, `STATE.md`, `DECISIONS.md`, or `.ai-context/validation-log.md`.

## Validation requirement
When profiles, scripts, or README scenario guidance change, record the scenario, profile, commands, tool availability, raw/compressed size estimates, preserved/lost evidence, pass/fail result, and recommendation in `docs/VALIDATION_MATRIX.md`.
<!-- ai-workflow-controller:end -->
