# Caveman Return Policy

Status: design. Only the config keys (`caveman_mode`, `caveman_max`, `caveman_shrink`, `caveman_policy`) and the state exports (`AICONTEXT_CAVEMAN_MODE`, `AICONTEXT_CAVEMAN_MAX`, `AICONTEXT_CAVEMAN_SHRINK`) exist. All default to `off`. Nothing calls Caveman, and no prompt guard or opt-in is implemented.

## What Caveman is (as far as verified)

Caveman is a skill/plugin that makes an agent answer in terse language. It removes preamble and filler. Code, commands, paths, and error strings stay as they are. Source: the Caveman quickstart (https://docs.caveman.so/docs/quickstart).

- Levels: `lite`, `full` (default), `ultra`, `wenyan`. Switched in-session with `/caveman [level]`. "stop caveman" or "normal mode" turns it off.
- Plugin state file: `${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.caveman-active`.
- Cost: the skill adds about 1,650 input tokens (about 2,131 compiled in Claude Code). Docs say a one-line question can cost more than it saves.
- Savings are **output tokens**. `wx` byte counts cannot measure them. Claimed reductions differ between sources (about 65% in project text, 8.5% in one JetBrains test). Do not quote any number in this repository.
- **Not verified:** `shrink`, `proxy`, `stats`, and `setup` commands. The quickstart does not describe them. Read the upstream docs before designing them.

## Two roles, two keys

| Role | Effect | Status in this design |
|---|---|---|
| Output style (skill) | Shorter agent replies | Main design. Opt-in only |
| Shrink/proxy | Shorter input or tool output | Experiment only. See last section |

Caveman is **off by default in every mode**. It turns on only when the user asks for it and the policy allows it.

## Policy resolution

Deterministic, first match wins. The result is the effective level.

1. Profile is hard-blocked → `off`. Hard-blocked: `raw`, `security`, `db`, `release`, `migration`, `docs`. This is enforced in code, not only in config.
2. Mode is `off`, `micro`, or `snippet` → `off`. The skill costs more than it saves on small tasks.
3. No user opt-in → `off`.
4. Otherwise: the lower of the requested level and the mode's `caveman_max`.

Then, at run time, these override the result to `off`:

5. A prompt guard phrase is in the user's request (below).
6. The task is a blocked task (below).
7. The agent is reporting first-failure evidence (any nonzero `wx` exit).

Rules 5-7 depend on the agent. Mode switching can export the level. It cannot read prompts. These rules are **policy**, not mechanical enforcement. Say so in any user-facing text.

## Must stay off

- Documentation writing, README, user-facing instructions, release notes, changelogs.
- Precise step-by-step instructions.
- `security`, `db`, `release`, `migration`, and `raw` work.
- First failing `debug` or `test` evidence, and the analysis of it.
- Legal and compliance-like work.
- Anything written to a file: code, comments, commit messages, PR text, docs. Caveman applies to chat replies only.
- Final answers that the user will follow as instructions.

## May be allowed

- Internal terse summaries.
- High token pressure, when the user asks for it. Token pressure is **not detected automatically** in v1. The user opts in.
- Repetitive non-final diagnostic output (long runs of passing tests, repeated build status).
- Shrink/proxy experiments (last section).

## Prompt phrase guards

If the request contains any of these, Caveman stays off for that request and its final answer:

`detailed`, `exact`, `exactly`, `carefully`, `full explanation`, `documentation`, `README`, `instructions`, `step-by-step`

Matching rules:
- Case-insensitive. Whole word or whole phrase. `exactly` is listed on its own because `exact` does not match it.
- A hit turns Caveman off for that request. A later request without a hit may use the opted-in level again.
- The list is data in config. Users may add phrases. They may not remove the original seven (`detailed`, `exact`, `carefully`, `full explanation`, `documentation`, `README`, `instructions`) from the shipped default. `exactly` and `step-by-step` are my additions.

Enforcement options, in order of effort:
1. Agent instruction text (policy only).
2. A Claude Code `UserPromptSubmit` hook example in `integrations/`. It checks the phrases and tells the agent "normal mode". It is an opt-in example, not installed behavior.
3. Extension-side check before sending a prompt. Later, if at all.

## Config

Keys (added to `config/workflow_settings.json`). `workflow.sh` reads `caveman_mode`, `caveman_max`, `caveman_shrink`, and `caveman_policy.hard_blocked_profiles`. The rest of `caveman_policy` is stored only.

```json
"defaults": {
  "caveman_mode": "off",
  "caveman_max": "off",
  "caveman_shrink": "off"
},
"caveman_policy": {
  "supported_levels": ["lite", "full"],
  "unsupported_levels": ["ultra", "wenyan"],
  "hard_blocked_profiles": ["raw", "security", "db", "release", "migration", "docs"],
  "prompt_guards": ["detailed", "exact", "exactly", "carefully", "full explanation",
                    "documentation", "README", "instructions", "step-by-step"],
  "blocked_tasks": ["documentation", "readme", "user-facing-instructions",
                    "step-by-step-instructions", "release-notes", "legal-compliance",
                    "first-failure-evidence", "file-content"],
  "opt_in_required": true
}
```

Per-mode keys (only where a mode differs from `defaults`):

| Key | Values | Meaning |
|---|---|---|
| `caveman_mode` | `off`, `lite`, `full` | Level the mode starts with. All `off` in v1 |
| `caveman_max` | `off`, `lite`, `full` | Highest level a user may opt in to |
| `caveman_shrink` | `off`, `experiment` | Shrink/proxy gate. `off` everywhere in v1 |

Why `ultra` and `wenyan` are unsupported: `ultra` drops too much clarity. `wenyan` is not English, and the default output style is English.

Compatibility:
- Keep `caveman_output` (boolean) in config defaults as a legacy key. `workflow.sh` no longer reads it. The export is derived: `true` only when the effective level is not `off`.
- Keep `CAVEMAN_OUTPUT` and `AICONTEXT_CAVEMAN_OUTPUT`.
- Add exports `AICONTEXT_CAVEMAN_MODE` (effective level) and `AICONTEXT_CAVEMAN_MAX`.
- If `caveman_mode` and the legacy `caveman_output` disagree, `caveman_mode` wins.
- Opt-in input: an env var read at mode switch, for example `AICONTEXT_CAVEMAN_REQUEST=lite workflow code`. The extension may add a toggle later. Name and shape are open.
- Output style is one value at a time. When Caveman is effective, the style is Caveman. Otherwise it is `ste-inspired`. Caveman drops articles. STE does not. Do not mix them.

## Mode mapping

`caveman_mode` is `off` for every mode in v1. Only `caveman_max` differs.

| Mode | `caveman_max` | Reason |
|---|---|---|
| `raw`, `security`, `db`, `release`, `migration` | `off` (hard block) | Protected evidence |
| `docs` | `off` (hard block) | Documentation |
| `scope`, `architect`, `decisions`, `review` | `off` | Precise, human-facing prose and findings |
| `debug`, `test` | `off` | First-failure analysis must be exact |
| `data-analysis`, `perf` | `off` | Numbers must be exact |
| `agent` | `off` | Instruction governance |
| `micro`, `snippet`, `off` | `off` | Skill cost is larger than the gain |
| `code` | `lite` | Internal status and summaries |
| `cicd` | `lite` | Repetitive non-final build status |
| `test-full` | `lite` | Long runs of repetitive status |
| `rapid-prototype` | `full` | Highest allowed. High volume, fast iteration |

Only four modes allow Caveman. Everything else needs a config change to allow it, and the hard-blocked set cannot be allowed by config.

## Conflicts

- **Caveman starts itself.** The plugin can keep its own active level (`.caveman-active`, default `full`). That ignores the Token Controller mode. `workflow doctor` reads that file and reports:
  - `error`: Caveman active while the mode is hard-blocked.
  - `warn`: Caveman active above `caveman_max`, or while no opt-in exists.
  - `info`: Caveman plugin not installed.
- Token Controller does not edit `.caveman-active` in v1. A later version may write it, with a backup and a doctor check.
- `workflow off` must set the effective level to `off`.

## Shrink/proxy (experiment only)

Gate: `caveman_shrink: experiment`, opt-in, never in a hard-blocked mode. Constraints that hold whatever Caveman's real design is:

- Never on raw evidence, tool output from a failing run, or protected profiles.
- `wx` raw capture stays authoritative. Shrink runs after capture, like RTK, and falls back to raw.
- Never edit a user file in place. Write a copy.
- Record it in `session.jsonl` as a compressor with name, version, raw bytes, visible bytes, and fallback reason (same shape as `docs/integrations/RTK.md`).
- Do not enable it until the upstream commands are read and verified.

## Validation scenarios

Policy resolution is a pure function. Test it without Caveman installed.

| # | Scenario | Expect |
|---|---|---|
| 1 | Default config, any mode, no opt-in | `off` |
| 2 | Opt-in `full` in `code` | `lite` (capped by `caveman_max`) |
| 3 | Opt-in `full` in `rapid-prototype` | `full` |
| 4 | Opt-in `lite` in each hard-blocked mode, including with a config edit that allows it | `off` |
| 5 | Opt-in in `micro`, `snippet`, `off` | `off` |
| 6 | Opt-in `ultra` or `wenyan` | Rejected. `off` |
| 7 | Each guard phrase, lower and upper case | Guard hit |
| 8 | `exactly` and `README.md`; `inexact` | Hit, hit, no hit |
| 9 | Legacy `caveman_output: true` with `caveman_mode: off` | `off`. `AICONTEXT_CAVEMAN_OUTPUT=false` |
| 10 | `workflow code`, then `workflow security` | Level resets to `off` |
| 11 | Doctor: `.caveman-active` present in `security` | `error` |
| 12 | Doctor: `.caveman-active` present, no opt-in | `warn` |
| 13 | Doctor: no Caveman installed | `info` only. Exit 0 |
| 14 | Agent run (manual): "write the README" with Caveman opted in | Full prose. Record the result |
| 15 | Agent run (manual): repeated status output with Caveman on | Shorter reply. Correctness checklist passes |

Scenarios 14-15 test agent compliance and cannot be automated. Record them as manual results and do not present them as enforcement.

## Measurement before any claim

Caveman changes output tokens, not bytes. Before any savings claim:
1. Run a fixed set of prompts with Caveman off and on, same model.
2. Record output tokens from the provider usage data or from `ccusage` (research candidate), with the tool version.
3. Record a correctness checklist for each answer.
4. Include the skill's input cost. Report net tokens, not output tokens alone.

Until then the README says only that Token Controller "manages context policy" for Caveman.

## Implementation order

1. Config: add the keys above. No behavior change.
2. `workflow.sh`: resolve the effective level, export the new variables, keep the old ones.
3. Table-driven test for scenarios 1-10.
4. Doctor: `.caveman-active` checks (scenarios 11-13). Done in `scripts/doctor.sh`.
5. Agent instruction text and the optional prompt-guard hook example.
6. Measurement run, then the validation matrix entry.
7. Shrink/proxy: read upstream docs first. Then a separate design.
