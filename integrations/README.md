# MCP integration template

`mcp-example.json` exposes LeanCTX and Headroom as local stdio MCP servers.

- VS Code: copy it to `.vscode/mcp.json` or merge its `servers` entries into your user MCP configuration.
- Cursor: merge the same entries into `~/.cursor/mcp.json`, using `mcpServers` instead of the top-level `servers` key.

Token Controller automatically governs agent use of these servers through the active mode and generated `AGENTS.md` rules; the template only makes the MCP tools available. Reload the IDE or MCP servers after changing modes if the IDE does not inherit updated environment variables.

Both executables must be visible on the IDE's `PATH`. If either server fails to start, replace its `command` value with the absolute path reported by `command -v lean-ctx` or `command -v headroom`.
