# Content, hooks, repositories, and packs

Treat every local or remote member as untrusted until `csc` admits immutable
selected bytes. Do not inspect repositories or content to reproduce its plan,
and never run setup scripts, hooks, commands, installers, or MCP executables
during planning or import.

## Save selected local content

Use for explicitly named skills, agents, commands, output styles, and hooks.
The broker discovers, parses, scans, hashes, and classifies only the requested
paths. A hook is executable content and must remain inactive until its exact
digest and scope are approved.

```sh
csc content plan push <explicit-path> --attach-profile current --write-mode create-only --json
csc content stage <local-plan-id> --json
csc content plan detach --content <id> --version <digest> --profile current --request-file <owner-only-value-free-path> --json
```

Show kind, canonical name, classification, selected file count/bytes, lineage,
executable members, findings, write precondition, and target profile. Upload is
limited to admitted member-relative file blobs; never upload a project archive,
repository checkout, unrelated files, local paths, or version-control metadata.

Use `match-head` only with the exact expected head returned by a fresh read.
Use `force-replace` only after [conflicts.md](conflicts.md) produces the
required conflict receipt and a new trusted digest-bound approval. Never add a
generic force flag.

Then submit, approve, sync, and verify through the root control flow.

## Ingest and attach a source repository

For a listed/admitted source, resolve the exact immutable version and selected
members. For an unknown public source, ingestion and attachment are two
separately reviewed stages.

```sh
csc repository plan ingest <source> --request-file <owner-only-value-free-path> --json
csc repository plan attach <admitted-source> --profile current --request-file <owner-only-value-free-path> --json
csc repository plan update <source-id> --profile current --request-file <owner-only-value-free-path> --json
csc repository plan detach <source-id> --profile current --request-file <owner-only-value-free-path> --json
```

Show publisher, trust, license, revision, scan verdict, every selected member,
executable/hook/MCP behavior, secret requirements, conversion loss, and update
policy. Never use a local transport, option-like URL, or direct Git command.
Private-source authentication stays in the user's existing local Git/SSH
mechanism; only selected admitted blobs may leave the machine.

## Install, update, or remove a pack

Packs retain identity, exact version/digest, member list, and update policy.
Manual activation is the default. Signed first-party policy may stage a
verified update but cannot select or activate it.

```sh
csc pack plan install <source> --profile current --request-file <owner-only-value-free-path> --json
csc pack plan update <pack-selection-id> --profile current --request-file <owner-only-value-free-path> --json
csc pack plan remove <pack-selection-id> --profile current --request-file <owner-only-value-free-path> --json
```

Show the member-level diff and affected profiles. Any new executable, scope
change, digest change, downgrade, unknown/revoked key, or signature failure
must stop before activation. Removal detaches the selection and respects
reference counts; it does not delete shared content or external secrets.

## Clone a project repository

This is separate from installing repository content. Preview the source,
resolved revision, destination, profile, and mapping scope through `csc`.

```sh
csc project clone <source> --profile current --destination <path> --json
```

The absolute mapping stays local. Do not handle Git credentials or clone the
repository outside this broker command.

To propose a cloud project identity mapping, use the exact owner-only request
document. This is separate from the owner-local `project use` override and
never contains a path, machine identity, or inferred commit.

```sh
csc project plan map --profile <id> --repository <repository-identity> --request-file <owner-only-value-free-path> --json
```

The CLI profile and repository selectors must exactly match the single
`project_identity_mapping.upsert` operation in the request document.
