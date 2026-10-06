# Claude Code hook example

This directory contains an **opt-in example** for routing selected Claude Code Bash commands through `wx`. Nothing in Token Controller installs or enables this hook automatically.

The example follows Claude Code's documented `PreToolUse` command-hook interface: JSON arrives on stdin, and a JSON `permissionDecision` of `deny` blocks the tool call while explaining how the agent should retry. See the official [Claude Code hooks reference](https://code.claude.com/docs/en/hooks).

## What it does

The hook inspects `.tool_name` and `.tool_input.command`:

- Non-`Bash` tool calls pass without output.
- Commands whose first shell word is `wx` pass without output.
- Common direct test, build, install, and Docker commands are denied with a message telling the agent to retry as `wx <command>`.
- Other Bash commands pass without output.

Matching is deterministic and intentionally conservative. It recognizes common direct commands, including package-manager install/test/build commands, `pytest`, `go test`, Cargo and .NET build/test commands, Make/CMake/Gradle/Maven commands, and Docker commands. It does not parse arbitrary nested shell programs such as command strings passed to another `bash -c`.

The hook does **not** mutate `tool_input`, print an `updatedInput`, or silently rewrite the command. Command mutation is out of scope until a supported hook response is deliberately implemented and documented.

## Opt-in setup

Requirements:

- Claude Code with command hooks enabled.
- `jq` available on `PATH`.
- Token Controller's `workflow` setup loaded so `wx` is available to Bash commands.

Review both example files first. Then merge the contents of `settings.example.json` into either:

- `.claude/settings.local.json` for a local, uncommitted project setting; or
- `.claude/settings.json` for a deliberately shared project setting.

Make the hook executable:

```bash
chmod +x integrations/claude-code/hooks/pretooluse-bash-policy.sh
```

Claude Code expands `${CLAUDE_PROJECT_DIR}` in the example settings, so the command path remains project-relative. Restart Claude Code or inspect `/hooks` after changing settings.

## Example: blocked command

Input:

```json
{"tool_name":"Bash","tool_input":{"command":"npm test"}}
```

Manual check:

```bash
printf '%s\n' '{"tool_name":"Bash","tool_input":{"command":"npm test"}}' \
  | integrations/claude-code/hooks/pretooluse-bash-policy.sh
echo "$?"
```

Expected stdout is a JSON object equivalent to:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PreToolUse",
    "permissionDecision": "deny",
    "permissionDecisionReason": "Token Controller policy: run test, build, install, and Docker commands through the deterministic wrapper. Rerun as: wx npm test"
  }
}
```

Expected exit code: `0`. Claude Code interprets the JSON decision and blocks the original Bash tool call.

## Example: already wrapped command

Input:

```json
{"tool_name":"Bash","tool_input":{"command":"wx npm test"}}
```

Expected output: none. Expected exit code: `0`.

## Validation

```bash
bash -n integrations/claude-code/hooks/pretooluse-bash-policy.sh
jq . integrations/claude-code/settings.example.json >/dev/null
```
