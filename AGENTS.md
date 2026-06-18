# AGENTS.md - Token Management Context & Operations Rules

## System Overview
This project runs a local pipeline powered by **RTK**, **Headroom**, **MemStack**, and **Caveman** to minimize input and output token consumption during local development sessions.

## Mandatory Behavioral Constraints
1. **Never Execute Toggles Directly**: Do not write, mutate, or invoke the system script `workflow.sh`. Toggles are exclusively handled by the human operator via external terminal commands.
2. **Read Token Controller State**: Before invoking structural operations or reading code directories, verify active configuration environmental flags (`$RTK_HOOK_ENABLED`, `$HEADROOM_COMPRESSION_STRATEGY`).
3. **Respect Memory Repositories**: When evaluating long execution loops across multiple chat windows, fetch state details from `.memstack/` structural indices instead of re-running broad file discoveries.
4. **Leverage Reversibility (CCR)**: If files loaded through the Headroom proxy layer appear truncated or missing definitions, execute the Model Context Protocol or recovery command `headroom_retrieve <target_file>` to pull the raw uncompressed content from the local proxy cache.
5. **Output Constraints**: When the `$CAVEMAN_OUTPUT` variable evaluates to `true`, alter response syntax to a direct, minimal, terse format, ignoring typical verbose formatting rules.