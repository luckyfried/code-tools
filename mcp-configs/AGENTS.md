# mcp-configs/

One JSON file per group of MCP servers that belong together, in the standard
`{"mcpServers": {…}}` container Claude Code reads from `.mcp.json`. A root `.mcp.json` is
gitignored here because it is per-machine and credential-bearing; these files are the shareable
declarations a configurator installs from.

Every entry must work on a stranger's machine:

- **Pin packages to an exact version** (`npx -y @scope/pkg@1.2.3`), never `@latest` or a bare
  name. A configurator refuses a server it cannot pin.
- **No credential values.** A server that needs a key names the environment variable it reads, and
  the value stays on the user's machine.
- **No machine-local paths.** A local `url` is allowed only for a server the user starts
  themselves on loopback, and the README says how to start it.

Each server needs a line in the root `README.md` under Requirements: what it does, what the user
installs or starts, and which platforms it runs on.
