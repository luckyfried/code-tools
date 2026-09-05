# Conflicts, retries, and recovery

Never turn a conflict into last-write-wins. Preserve the returned safe IDs,
base/local/remote digests, proposal ID, local plan ID, and conflict receipt;
never inspect native files or cloud records to reconstruct them.

## Stale profile or selection base

On `WORKSPACE_REVISION_CONFLICT`, `BASE_DIGEST_CONFLICT`, or an attachment head
conflict:

1. Stop the current proposal.
2. Run a fresh safe read for the target and sync if directed by `csc`.
3. Show the three-way semantic differences and affected profiles.
4. Ask the user to choose keep-remote, re-plan selected local intent, or cancel.
5. Build a new plan against the new base. A changed plan has a new digest and
   requires new trusted approval.

Never reuse approval from the stale digest.

## Proposal lifecycle

Poll an existing proposal rather than resubmitting it blindly.

```sh
csc proposal status <proposal-id> --json
```

- `pending_approval`: reopen only the trusted surface returned by `csc`.
- `approved` or `applied`: continue with the exact returned receipt and verify.
- `rejected`, `expired`, or `failed`: report it and stop; a retry is a new plan
  unless `csc` explicitly returns the stored idempotent result.
- `UPGRADE_REQUIRED`: stop and require a supported client; no old route exists.

## Incomplete migration

Use the broker's journaled resume command. Do not repeat provider writes,
proposal submission, or source rewriting yourself.

```sh
csc migrate resume <local-plan-id> --json
```

Preserve `cloud_applied_local_pending` until source sanitization, sync, and
verification all succeed.

## Content force replacement

Do not use a force-replace write mode from a plain user confirmation. Require
the exact overwritten head, a broker-issued conflict receipt, an updated plan
showing who/what is displaced, and a new trusted approval bound to that plan
digest. If any field is unavailable, keep the conflict unresolved.
