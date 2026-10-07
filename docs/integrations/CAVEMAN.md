# Caveman Return Policy

Status: **policy state implemented** (see "Implemented policy state" at the end): config keys, the opt-in variable `AICONTEXT_CAVEMAN_REQUEST`, hard blocks, state exports, and doctor checks. Caveman is off by default. Nothing calls Caveman. Prompt guards, shrink/proxy, and any activation of the plugin are not implemented.

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

1. Profile is hard-blocked → `off`. Hard-blocked: `raw`, `security`, `db`, `release`, `migration`, `docs`, `debug`. This is enforced in code, not only in config.
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
- Opt-in input: `AICONTEXT_CAVEMAN_REQUEST=off|lite|full`, read at mode switch (decided, see "Implemented policy state"). The extension may add a toggle later.
- Output style is one value at a time. When Caveman is effective, the style is Caveman. Otherwise it is `ste-inspired`. Caveman drops articles. STE does not. Do not mix them.

## Mode mapping

`caveman_mode` is `off` for every mode in v1. Only `caveman_max` differs.

| Mode | `caveman_max` | Reason |
|---|---|---|
| `raw`, `security`, `db`, `release`, `migration` | `off` (hard block) | Protected evidence |
| `docs` | `off` (hard block) | Documentation |
| `scope`, `architect`, `decisions`, `review` | `off` | Precise, human-facing prose and findings |
| `debug` | `off` (hard block) | First-failure evidence and its analysis must be exact |
| `test` | `off` | First-failure analysis must be exact |
| `data-analysis`, `perf` | `off` | Numbers must be exact |
| `agent` | `off` | Instruction governance |
| `micro`, `snippet`, `off` | `off` | Skill cost is larger than the gain |
| `code` | `lite` | Internal status and summaries |
| `cicd` | `lite` | Repetitive non-final build status |
| `test-full` | `lite` | Long runs of repetitive status |
| `rapid-prototype` | `full` | Highest allowed. High volume, fast iteration |

Only four modes allow Caveman. Everything else needs a config change to allow it, and the hard-blocked set (`raw`, `security`, `db`, `release`, `migration`, `docs`, `debug`, plus `micro`, `snippet`, `off`) cannot be allowed by config.

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

## Implemented policy state

Values: `off`, `lite`, `full`. `ultra` and `wenyan` are not supported anywhere: a request, a config level, or a cap with another value becomes `off` with a warning. Default is `off` in every mode.

**Opt-in shape (decided).** `AICONTEXT_CAVEMAN_REQUEST=off|lite|full`, read when a mode is activated:

```bash
AICONTEXT_CAVEMAN_REQUEST=lite workflow code
AICONTEXT_CAVEMAN_REQUEST=lite scripts/workflow-cli.sh code
```

- It applies to **that activation only**. It is not saved. The next activation without it uses the config level (default `off`). A user who exports the variable in their shell opts in on every activation.
- It replaces the config level for that activation, including `off`. A non-`off` `caveman_mode` in config is a standing opt-in.
- The effective level is the lower of the request and the mode's `caveman_max`. The request cannot raise a cap.
- Blocked modes ignore it. A notice says why (`ignored. Mode 'security' does not allow Caveman`, or `lowered to 'lite'`). Activation still succeeds.
- Exported state (all in `active_mode.env`): `AICONTEXT_CAVEMAN_REQUESTED` (validated request), `AICONTEXT_CAVEMAN_MODE` (effective), `AICONTEXT_CAVEMAN_MAX` (cap), `AICONTEXT_CAVEMAN_SHRINK`, and the derived `AICONTEXT_CAVEMAN_OUTPUT`. `status --json` shows `caveman_requested`, `caveman_mode`, `caveman_max`, `caveman_output`. `modes --json` shows the config policy (no request).

**Hard-blocked** (code and config): `raw`, `security`, `db`, `release`, `migration`, `docs`, `debug`. No-Caveman by code too: `micro`, `snippet`, `off`. Config can add profiles (`caveman_policy.hard_blocked_profiles`) but cannot remove these. `debug` is the first-failure evidence mode. For a failing run in a mode that allows Caveman (`code`, `cicd`, `test-full`, `rapid-prototype`), see "Failure evidence" below.

**Doctor** also warns when `AICONTEXT_CAVEMAN_REQUEST` stands in the environment of the doctor process, in a shell startup file (`~/.bashrc`, `~/.bash_profile`, `~/.profile`, `~/.bash_aliases`, `~/.zshrc`, `~/.zprofile`), or in a VS Code settings file (`caveman.request_standing`, a `warn`, with file and line). A comment or a per-command use in an alias is not reported. A variable that is set but not exported in the current shell cannot be seen. It also warns when Caveman is active and the latest `wx` run in the project failed (`caveman.active_after_failure`).

**Doctor** reads `${CLAUDE_CONFIG_DIR:-~/.claude}/.caveman-active`:
- `error`: active in a hard-blocked profile.
- `warn`: active level `ultra` or `wenyan*`; active with no Token Controller opt-in (the message shows the opt-in shape); active above the Token Controller level.
- `ok`: active within policy, or inactive. A `caveman.policy` line shows level, request, and limit.
- Doctor never edits the state file.

**Template** (`templates/AGENTS_base.md`): Caveman is off by default, use it only if `AICONTEXT_CAVEMAN_MODE` is `lite` or `full`, never in the blocked work, never for first-failure evidence or instructions a person must follow. This is policy text and depends on agent compliance.

Not implemented: prompt guards, activating or deactivating the plugin from Token Controller, shrink/proxy (`caveman_shrink` stays `off` and has no effect), any savings claim.

## Upstream questions (not verified from official docs)

Facts below come from skill files installed on this machine, not from official documentation.

1. **State file.** Where is `.caveman-active` written (plugin hook?), when is it cleared, and what exactly does it hold (only the level, or more)? Does "stop caveman" remove it or write `off`? Doctor assumes a level name.
2. **Level names.** The installed `caveman` skill says `/caveman ultra` and `/caveman wenyan` hand over to separate skills (`ultracave`, `megacave`). Are the state values `ultra` and `wenyan`, or something like `wenyan-lite`? Doctor treats `ultra` and any `wenyan*` as unsupported.
3. **Hook behavior.** The skill refers to a hook that reports `Caveman mode: <mode>`. Does the plugin turn itself on at session start (default `full`)? That would bypass Token Controller's opt-in. Doctor can only warn.
4. **`caveman-compress`.** It overwrites memory files such as `CLAUDE.md` with a compressed version and keeps a backup elsewhere. Would it damage the Token Controller managed block (`<!-- ai-workflow-controller:start/end -->`) or the policy text in `AGENTS.md`? Doctor does not check this.
5. **`caveman-setup` and the "Caveman gateway".** It is described as a byte-preserving LLM proxy that measures requests and cost. Where does the data go? Is it a hosted service? This must be answered before any shrink/proxy design, and before Token Controller mentions it.
6. **Shrink, proxy, stats.** Their commands and behavior are not documented in the quickstart. No design until upstream docs are read.
7. **Auto-clarity.** Does Caveman switch itself off for security warnings or destructive steps by itself? Token Controller does not rely on it.
8. **Measured savings.** There is no agreed number. A fixed prompt set with output-token counts is still needed.

## Failure evidence (what is enforced and what is not)

Caveman changes how an agent writes. Token Controller cannot change that. These parts are mechanical:
- `debug` and the other hard-blocked modes cannot have Caveman on in `active_mode.env` (code and config).
- `wx` never changes failing output: a nonzero exit always shows the complete raw stdout and stderr.
- `wx` records the Caveman level of every run in `session.jsonl` (`caveman_mode`).
- When Caveman is `lite` or `full` and a run fails, `wx` prints one line on stderr next to the failure output: `[wx] Caveman is <level> and this run failed (exit N). Quote the error, stack trace, paths, and line numbers exactly. Do not shorten them.` With Caveman off (the default) nothing is printed, so default output is unchanged.
- Doctor warns when Caveman is active (the plugin's own state file) and the latest `wx` run failed.

These parts are **policy only**:
- Whether the agent follows the reminder, the template rule, or "stop caveman".
- The plugin's own state (`.caveman-active`). Token Controller never writes it, so it cannot turn Caveman off.
- Failures of commands that do not run through `wx`.
- Prompt guards (the phrases in `caveman_policy.prompt_guards`) are stored, not applied.
