# Migration

Use `csc` to inventory and migrate supported Claude/Codex configuration. Do
not run legacy pack scripts, enumerate host files, or inspect native config.

## Plan

Run only the commands this build runs: `migrate.plan`, `migrate.stage`,
`migrate.resume`, `proposal.submit`, `proposal.status`, `sync`, and the
applicable profile verification commands.

```sh
csc migrate plan --from auto --profile current --json
```

The returned plan is the only inventory. Show its target profile, recognized
categories, create/update/fork classification, redacted credential positions,
logical secret names, provider health, rewrite scope, conversion loss,
unsupported fields, conflicts, and current-session impact. Never inspect a
reported path to confirm the broker.

If credentials are present, read [secrets.md](secrets.md) before staging. The
model never receives the literal and never edits the source representation.

## Stage and approve

Staging may open trusted local provider selection and literal-lift UI. It must
not accept a secret through argv or stdout.

```sh
csc migrate stage <local-plan-id> --json
csc proposal submit <local-plan-id> --json
csc proposal status <proposal-id> --json
```

Display the immutable redacted proposal digest before asking the user to open
the trusted approval surface. Conversational assent is not approval.

## Finish and verify

After cloud apply, migration can still be locally incomplete. Resume the
broker-owned saga; do not reproduce its compare-and-swap rewrite yourself.

```sh
csc migrate resume <local-plan-id> --json
csc sync --json
csc profile show --profile current --json
```

Use the exact isolated `profile.verify` command returned by the applied result
when available. Report `cloud_applied_local_pending` or any other incomplete
state as incomplete. A failed/retried stage must not duplicate provider
entries, proposals, or source rewrites.

Migrate categories in dependency order: credential positions through the
trusted local secret flow, MCP definitions, selected content such as skills or
hooks, then profile-owned app settings. Stop on the first ambiguity, conflict,
unsupported category, or unavailable command.
