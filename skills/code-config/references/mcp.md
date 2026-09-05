# MCP migration and setup

Use only immutable MCP versions and exact profile attachment. Never parse a
Claude/Codex MCP definition or launch a server directly.

## Import an existing MCP

Let `csc` parse one named server from a supported native source. Do not inspect
the source file.

```sh
csc mcp plan import --from <claude-or-codex> --server <name> --profile current --scope profile --json
```

Show the sanitized canonical definition, exact executable/package or upstream
origin, immutable version and consumer digests, destination keys, conversion
loss, affected profiles, secret requirements, and current-session impact.

## Add or update an MCP

Collect only non-secret intent. Use a trusted template or an owner-only,
value-free request file produced or explicitly validated by `csc`.

```sh
csc mcp plan add --profile current --request-file <owner-only-value-free-path> --json
csc mcp plan update --server <id> --base-version <digest> --request-file <owner-only-value-free-path> --write-mode match-head --json
csc mcp plan detach --server <id> --version <digest> --profile current --json
```

Never invent an executable path, package pin, origin policy, secret locator,
or destination key. Missing or ambiguous versions stop planning.

If a secret is required, use [secrets.md](secrets.md). Provider choice,
binding, and per-consumer approval happen through a trusted local surface; the
model sees only safe IDs and health.

## Submit and verify

Use the standard proposal flow. MCP version creation and profile attachment
must be atomic.

```sh
csc proposal submit <local-plan-id> --json
csc proposal status <proposal-id> --json
csc sync --json
csc mcp test --server <id> --profile current --json
```

`mcp.test` may verify policy, resolution health, transport, and safe status; it
must not print a secret or expose child-protocol stdout. Never invoke the
private `mcp exec` runtime entry point from a skill.

An update to a shared MCP never silently changes every profile. Show whether
the plan creates a new version, updates one attachment, forks, or detaches.
State whether the current host can reconnect or requires a new managed session.
