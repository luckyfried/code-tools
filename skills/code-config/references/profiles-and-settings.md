# Profiles, settings, and Community Profiles

Use this flow for profile reads, one-at-a-time create/update/delete, local
project mapping, profile-owned Claude/Codex settings, and Community Profile
Use/Fork.

## Availability gate

After the root readiness gate, run only the exact commands needed below. A
command this build does not run makes that branch unavailable; it does not
authorize direct CRUD or a hand-built changeset.

Start with safe profile state:

```sh
csc profile current --json
csc profile list --json
csc profile show --profile current --json
```

Use only the commands relevant to the request.

## Create one profile

1. Collect only a name, optional description, explicit empty-profile choice,
   requested item names, Community creation mode, update policy, and supported
   setting choices. Never collect values for environment secrets.
2. Search for catalog candidates, then require the user to select an exact
   kind, ID, source, version, and digest. A search result is never an implicit
   selection.

```sh
csc catalog search --kind <kind> --query <user-text> --json
csc catalog resolve --kind <kind> --id <id> --digest <digest> --json
```

3. Pass only a value-free request-file path produced or explicitly validated
   by `csc`. Never author a raw `ProfileSpec` or control operation.

```sh
csc profile plan create --request-file <owner-only-value-free-path> --json
```

4. Show the returned canonical plan. Preview one explicit host in an isolated
   destination without executing generated content.

```sh
csc profile preview --changeset <id> --digest <changeset-digest> --host <host> --isolated --json
```

5. Submit, use the returned trusted approval surface, poll, then sync and
   verify the exact committed tuple.

```sh
csc proposal submit <local-plan-id> --json
csc proposal status <proposal-id> --json
csc sync --json
csc profile verify --profile <id> --revision <revision> --digest <profile-digest> --manifest <manifest-digest> --host <host> --isolated --json
```

Call the profile Saved after the committed proposal is readable. Call it Ready
only when isolated verification returns `status: "ready"`. Preserve and report
`blocked_by_secrets`, `repreview_required`, and verification failures exactly.

For several requested profiles, repeat the full flow in user-stated order.
There is no batch create or companion operation beside `profile.create`.

## Community Profile Use or Fork

Browse through closed typed filters in a value-free query file, inspect one
immutable version, and show publisher, trust, license, app compatibility,
executable/secret warnings, update policy, and exact `usedBy` count.

```sh
csc community profiles list --query-file <owner-only-value-free-path> --json
csc community profiles show <slug> --json
```

- **Use** retains the pinned upstream identity and explicit update policy.
- **Fork** creates an independent workspace-owned snapshot with provenance.

Both route through a sole `profile.create` plan. Neither browse results nor
popularity may silently activate anything. A missing broker-supported way to
produce the value-free request file means this flow is unavailable in that
build.

Publishing or unpublishing is a distinct proposal flow and never follows
from Use/Fork. Require its advertised command and exact immutable target.

```sh
csc community plan publish --profile <id> --base-digest <digest> --request-file <owner-only-value-free-path> --json
csc community plan unpublish --community-profile <id> --version <digest> --request-file <owner-only-value-free-path> --json
```

Show portable resource identities, executable/secret requirements, taxonomy,
visibility, and the exact source profile digest. Submission still uses the
root trusted-approval flow; unpublishing does not delete immutable versions or
break existing adopters.

## Update a profile

Read the exact current profile and base digest. Resolve every new catalog
selection exactly, then ask `csc` for a restricted three-way plan.

```sh
csc profile plan update --profile <id> --base-digest <digest> --request-file <owner-only-value-free-path> --json
```

Show added/removed selections, app scope, executable and secret blast radius,
affected profiles, and base digest. Then use the same preview, submit,
approval, status, sync, and isolated verify sequence as create. A stale base
routes to [conflicts.md](conflicts.md); never replace unrelated fields.

## Delete a profile

Read the profile and base digest first. Show project mappings, Community
lineage, pack/repository selections, and shared-versus-owned references.

```sh
csc profile plan delete --profile <id> --base-digest <digest> --request-file <owner-only-value-free-path> --json
```

Proceed through trusted approval only. Deletion must not delete shared content
or external provider entries. Verify by a fresh profile list and sync result.

## Capture or copy app settings

Settings are profile-owned separately for Claude and Codex. Plan from the
broker's recognized surfaces; do not inspect native settings yourself.

```sh
csc settings plan capture --from auto --app <claude-or-codex> --profile current --json
csc settings plan copy --from <claude-or-codex> --to <claude-or-codex> --profile current --json
```

Show field-level semantic changes and conversion loss. Credential-bearing or
unsupported fields never become opaque settings. Submit and verify through the
standard control flow.

## Map or launch

Map only after the selected profile is Ready. Absolute paths remain local.

```sh
csc project set --path <path> --toolkit <toolkit> --json
csc materialize --profile <id> --host <host> --destination <managed-path> --json
csc launch <host> --profile <id> --sync --json
```

Materialize only to an explicit managed destination. Preview/verify never
touch a live destination. Report honestly when launch or current-session
reconnection is unsupported by the installed build.
