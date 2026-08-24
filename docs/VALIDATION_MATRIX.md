# Validation Matrix - Context Profiles and Tool Effects

Use this file to collect real observations. Do not treat tool claims as proof. Measure your own repository and record what evidence was preserved or hidden.

## Decision rule

A profile is acceptable only if it preserves the evidence needed to make the correct engineering decision.

Token savings are useful only after this condition is satisfied:

```text
correctness >= reproducibility >= debuggability >= token savings
```

## Baseline validation without optional tools

| Date | Scenario | Profile | Command | Expected | Result | Notes |
|---|---|---|---|---|---|---|
| 2026-06-18 | shell syntax | n/a | `bash -n scripts/workflow.sh` | no syntax errors | PASS | validated in sandbox |
| 2026-06-18 | JSON syntax | n/a | `jq . config/workflow_settings.json >/dev/null` | valid JSON | PASS | validated in sandbox |
| 2026-06-18 | default status | status | `source scripts/workflow.sh status` | status prints even before profile activation | PASS | validated in sandbox |
| 2026-06-18 | coding profile | code | `source scripts/workflow.sh code && source scripts/workflow.sh status` | code exports safe defaults | PASS | validated in sandbox |
| 2026-06-18 | security profile | security | `source scripts/workflow.sh security && source scripts/workflow.sh status` | raw/lossless policy visible | PASS | validated in sandbox |

## Tool availability validation

| Date | Tool | Command | Installed? | Version | Notes |
|---|---|---|---|---|---|
| TODO | jq | `jq --version` | TODO | TODO | required |
| TODO | RTK | `rtk --version` | TODO | TODO | optional |
| TODO | Headroom | `headroom --help` | TODO | TODO | optional |
| TODO | LeanCTX | `lean-ctx doctor` | TODO | TODO | optional |
| TODO | MemStack | `python -m memstack_skill_loader --help` | TODO | TODO | optional / Claude Code focused |
| TODO | Caveman | `caveman --help` or agent trigger | TODO | TODO | optional output brevity |

## Scenario validation template

Copy this block for each experiment.

```markdown
### Experiment: <short name>

- Date:
- Repository / branch:
- Scenario:
- Profile:
- Active env file:
- Tools installed:
- Tools missing:
- Command(s):
- Raw output location:
- Compressed output location:
- Raw size / estimated tokens:
- Compressed size / estimated tokens:
- Evidence preserved:
  - command:
  - working directory:
  - exit code:
  - stderr:
  - first error:
  - last relevant lines:
  - file paths:
  - line numbers:
  - versions/environment:
- Evidence lost or possibly hidden:
- Did the agent reach the same conclusion with compressed context?
- Pass/fail:
- Recommended profile change:
```

## Scenario expectations

| Scenario | Profile | Compression allowed | Must preserve | Fail condition |
|---|---|---|---|---|
| Requirements | scope | low | exact user constraints, open questions, acceptance criteria | compression changes meaning |
| Architecture | architect | medium | interfaces, module boundaries, data flow, ADR rationale | agent misses critical dependency |
| Domain models/types | decisions | low-medium | schemas, type definitions, invariants | agent invents or drops field/constraint |
| Coding | code | medium | edited file, nearby tests, compile errors | agent edits based on incomplete target file |
| Rapid prototyping | rapid-prototype | high for successful builds only | backend API integration errors, stderr, exit code, database migration warnings, raw logs | an API error or migration warning is compressed away |
| Snippet review | snippet | none/low | complete snippet/method/file | any omitted line affects judgment |
| Agent governance | agent | low | AGENTS.md and dynamic task-state separation | agent mutates stable instructions unnecessarily |
| Unit tests | test | medium after baseline | failing test name, assertion, stack trace origin, exit code | failure reason hidden |
| Full app tests | test-full | high only after baseline | first failure and final summary | full failure only exists in compressed form |
| Debugging | debug | low-medium | first failure raw, stderr, paths, line numbers | repeated compression hides root cause |
| CI/CD | cicd | medium | YAML/scripts/env/exit/failing lines | hidden env mismatch or runner detail |
| Documentation | docs | medium for inputs, none for final | accurate project behavior and final prose | final docs become terse or inaccurate |
| Security | security | none/lossless | CVEs, secrets, auth, crypto, license findings | any finding dropped or normalized |
| Database migration | db | none/lossless | SQL, constraints, migration order, data-loss warnings | warning hidden |
| Performance | perf | low | numbers, units, sample size, environment | metric rounded/removed |
| Release | release | none/lossless | version, changelog, artifact names, hashes, signing output | artifact or version mismatch hidden |

## Example validation notes

### Example: repeated passing unit tests

- Scenario: full app test routine
- Profile: `test-full`
- Observation: 4,000 lines of repeated pass output were compressed to a test summary.
- Evidence preserved: command, exit code, number of tests, failing tests = none.
- Evidence lost: individual pass lines.
- Decision: acceptable if raw log is retained.

### Example: first failing unit test

- Scenario: bug fixing
- Profile: `debug`
- Observation: first failing assertion shown raw.
- Evidence preserved: stderr, exit code, failing test name, assertion, stack trace origin, line numbers.
- Decision: acceptable.

### Example: vulnerability scan

- Scenario: security review
- Profile: `security`
- Observation: scan output kept raw/lossless.
- Evidence preserved: package names, versions, CVE IDs, severity, remediation advice.
- Decision: required. Do not use destructive compression.

### Experiment: rapid prototype profile activation

- Date: 2026-08-24
- Repository / branch: token-controller / main
- Scenario: aggressive compression for successful prototype builds with guarded backend API and database migration evidence
- Profile: `rapid-prototype`
- Active env file: isolated temporary `active_mode.env`, removed after validation
- Tools installed: jq 1.8.2, RTK 0.42.4, Headroom 0.25.0
- Tools missing: LeanCTX, MemStack, Caveman
- Commands:
  - `jq . config/workflow_settings.json >/dev/null`
  - `source scripts/workflow.sh rapid-prototype`
  - `source scripts/workflow.sh status`
- Raw output location: isolated temporary validation file, removed after measuring
- Compressed output location: not applicable; no build output was compressed during profile activation validation
- Raw size / estimated tokens: 998 bytes / 18 lines
- Compressed size / estimated tokens: not applicable
- Evidence preserved:
  - command: profile activation and status output retained
  - working directory: repository root
  - exit code: JSON parse, activation, and status all returned 0
  - stderr: `AICONTEXT_PRESERVE_STDERR=true`
  - first error: `AICONTEXT_PRESERVE_FIRST_ERROR=true`
  - last relevant lines: full status and active environment cache inspected
  - file paths: backend API targets and migrations selected for full file context
  - line numbers: not applicable; no error was generated
  - versions/environment: jq and optional tool availability recorded above
  - warnings: `AICONTEXT_PRESERVE_WARNINGS=true`
  - raw logs: `AICONTEXT_KEEP_RAW_LOGS=true`
- Evidence lost or possibly hidden: none during activation; end-to-end build compression remains unmeasured
- Did the agent reach the same conclusion with compressed context? Not applicable; compression tools were not invoked
- Pass/fail: PASS for JSON validity, profile activation, exported safeguards, and cache persistence
- Recommended profile change: none; run a representative successful build, failing backend integration, and warning-producing migration before approving end-to-end compression behavior
