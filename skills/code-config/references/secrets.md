# Secret handling

The model-facing workflow handles logical names, usage destinations, safe IDs,
provider labels, approval scope, and health only. Secret values and provider
locators remain inside the signed local broker and trusted provider UI.

## If a user pastes a value

Stop the management flow immediately. Do not repeat, classify, transform,
store, test, or place the value in a command. Say that it may now be present in
model/chat history, direct the user to the trusted local picker, and recommend
rotation when the pasted value could be live. Resume only with a logical
secret ID and safe broker status.

## Discover and bind safely

Run only the secret commands this build runs; one it does not answers
`ok: false` with `LOCAL_COMMAND_UNAVAILABLE`. Trusted
local approval is a one-use UI gesture, never an ambient cloud capability.

```sh
csc secrets providers --json
csc secrets bind <secret-id> --provider <safe-provider-instance-id> --scope profile --profile <id> --json
csc secrets verify <secret-id> --scope profile --profile <id> --json
```

Provider enumeration returns safe labels/IDs and health, never raw locators or
values. Binding must open a trusted local picker/TTY bound to the exact secret,
scope, profile, and provider. The skill requests that surface but cannot
complete it.

Never call a password-manager CLI, OS keychain command, environment dump, or
plaintext getter. Never pass a provider reference or value through a request
file or conversation.

## Consumer approval

Grant the minimum exact consumer: profile, MCP server, immutable version
digest, and destination. A grant command must cross trusted local approval.

```sh
csc secrets approvals list --profile current --json
csc secrets approvals grant <secret-id> --profile <id> --usage <usage-id> --json
csc secrets approvals revoke <secret-id> --profile <id> --usage <usage-id> --json
```

Do not infer approval from a profile attachment or prior chat confirmation.
Report safe health codes, not attempted values.

## Unbind

Show affected profiles/consumers first. Unbinding local Code Config state does
not delete the external manager item.

```sh
csc secrets unbind <secret-id> --scope profile --profile <id> --json
```

After trusted local confirmation, re-run safe verification and the affected
profile's isolated verification. An unbound required secret leaves the profile
Saved but blocked, never Ready.
