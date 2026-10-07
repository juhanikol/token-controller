# LEAN-CTX integration

## LeanCTX integration decision

Use this strategy:

>MCP-preferred, CLI-validated, no shell hooks at first.

Reason:

LeanCTX’s MCP tool surface is exactly what you want for file and code context: ctx_read, ctx_search, ctx_tree, ctx_compose, ctx_expand, ctx_retrieve, graph tools, planning tools, and session tools. The tool reference says ctx_read replaces native reads, supports modes such as auto, full, map, signatures, diff, aggressive, entropy, task, reference, and line ranges; ctx_search replaces Grep/rg for code search; ctx_tree replaces ls/find for directory maps. 


LeanCTX also has CLI commands for the same areas: lean-ctx read, lean-ctx grep, lean-ctx find, lean-ctx ls, and lean-ctx -c for shell shaping. But shell shaping overlaps with wx and RTK, so do not use LeanCTX shell compression in phase one. LeanCTX’s own docs warn that when shell hooks already route a command, you should not wrap it again. 

LeanCTX setup can mutate host/editor configuration through wrap, setup, onboard, and shell hooks. Its getting-started docs say wrap vscode, wrap claude, wrap codex, and setup modify the selected host’s configuration and require review/restart.  Token Controller should not run those automatically. It should detect, advise, and validate.

For WSL/Windows, install-location matters. LeanCTX’s platform docs say to install it where the AI tool executes: desktop, WSL, or remote Linux, not merely where the editor UI runs. Since your active development environment is WSL2, Token Controller should prefer the WSL lean-ctx binary when running in WSL. Windows lean-ctx.cmd should be treated as a separate host path for Windows-native agents.

## LeanCTX phase-one boundaries

Implement these rules from the start:

Allowed in phase one:
- detect LeanCTX installation/version
- expose mode policy
- doctor checks
- AGENTS instructions for MCP usage
- CLI validation commands
- optional extension status display later

Not allowed in phase one:
- no lean-ctx wrap
- no lean-ctx setup
- no lean-ctx init --global
- no shell hook installation
- no ctx_shell ownership
- no LeanCTX proxy
- no Headroom
- no automatic MCP config mutation