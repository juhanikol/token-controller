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
