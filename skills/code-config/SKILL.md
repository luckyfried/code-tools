---
name: code-config
description: Manage Code Config from Claude Code or Codex through the signed csc broker — profiles, app settings, MCP servers, secrets, skills and hooks, repositories, and packs. Use when the user says "create a profile", "add an MCP", "migrate my existing Claude or Codex config", "bind an API key", "capture my settings", "install a pack", "attach a repository", "use a Community Profile", "sync this machine", or "launch with this profile"; when a profile is Saved but not Ready and needs a new plan; or when someone asks which Code Config management operations the installed csc build supports. Every change is a plan the user approves outside the conversation, and no secret value passes through the model.
---

# Code Config

Treat this skill as a conversational router. Treat signed `csc` as the only
implementation and source of truth.

## Start every request with the readiness gate

Run only:

```sh
csc status get --json
```

Continue only when stdout is one strict JSON envelope. Every command below
then answers for itself whether this build runs it: one this build does not
run comes back `ok: false` with `LOCAL_COMMAND_UNAVAILABLE`, and nothing has
happened.

If the gate command is missing, returns prose, returns malformed JSON, or
reports `UPGRADE_REQUIRED`, say that this operation is unavailable in the
installed `csc` build and stop. If it says this computer is not signed in,
follow the `/code-config-doctor` skill. Do not route around the gate
with an older skill, local script, raw API call, or file edit.

## Keep the broker boundary

- Invoke only documented model-facing `csc ... --json` management commands.
  Never invoke the private `csc mcp exec` runtime entry point.
- Never read, search, print, or edit native Claude/Codex configuration,
  credential-bearing files, provider stores, Code Config machine state, or
  cached manifests directly. Ask `csc` for a safe plan or read.
- Never use direct cloud CRUD, HTTP clients, provider CLIs, Git plumbing, or
  generic filesystem operations as a substitute for an unavailable command.
- Never ask for or accept a secret value. Do not place one in argv, a request
  file, a query file, stdout, or the conversation. If a value is pasted, stop
  and follow [secrets.md](references/secrets.md).
- Never approve for the user. Do not pass `--yes`, `--force`, or an equivalent.
  Request the trusted browser/local approval surface returned by `csc`.
- Treat an exit code as transport status only. Claim success only from a
  validated success envelope followed by a fresh sync/read/isolated verify.
- Use only owner-only, value-free request/query files produced or explicitly
  validated by `csc`. Never synthesize a raw control changeset or profile spec.

## Route to one direct reference

| User intent | Read |
|---|---|
| Create, update, delete, inspect, or map a profile; capture settings; browse or adopt a Community Profile | [profiles-and-settings.md](references/profiles-and-settings.md) |
| Inventory or migrate existing Claude/Codex configuration | [migration.md](references/migration.md) |
| Import, add, update, detach, or test an MCP | [mcp.md](references/mcp.md) |
| Bind, verify, approve, unbind, or recover a logical secret | [secrets.md](references/secrets.md) |
| Save skills/agents/commands/output styles/hooks; ingest or attach repositories; install/update/remove packs; clone a project repository | [repositories.md](references/repositories.md) |
| Resolve stale revisions, divergent edits, retries, rejected/expired proposals, or incomplete migration | [conflicts.md](references/conflicts.md) |

Read only the matching reference unless the flow reaches a boundary that
explicitly points to another one.

## Use one control flow

For every mutation:

1. Discover or resolve exact safe identifiers through `csc`.
2. Build a redacted plan; do not mutate during planning.
3. Display the exact target, base revision/digest, immutable selections,
   executable scope, secret requirements, losses, and affected profiles.
4. Submit the local plan and open the trusted approval URL/surface returned by
   `csc`. The user approves the exact digest outside the model conversation.
5. Poll the proposal by ID. Never infer approval from conversational wording.
6. After apply, sync and perform the workflow's fresh read or isolated verify.
7. Report canonical state as Saved and local state as Ready only when the
   returned verification envelope says so.

Process requests for multiple profiles sequentially: plan, approve, apply,
sync, and verify one profile before planning the next. Stop the sequence on
ambiguity, rejection, conflict, or failed verification.
