---
name: code-config-doctor
description: Diagnose a Code Config installation from Claude Code or Codex using signed csc safe JSON, without reading secret-bearing files. Use when csc is missing or answers with prose instead of strict JSON, this machine is not enrolled, the /code-config management skill cannot be discovered or used, a sync or materialization is stale, local broker or provider health is in question, or a profile reads as Saved but not Ready. Trigger phrases - "csc is broken", "csc says upgrade required", "I am not signed in", "my profile will not apply", "check my Code Config setup".
---

# Code Config Doctor

Work before profile materialization and when the full `/code-config`
management skill is missing or unusable. Use signed `csc` safe JSON as the
only diagnostic authority.

## Probe without assumptions

Run:

```sh
csc status get --json
```

Accept only one strict JSON envelope. If the command is missing, emits prose,
returns malformed JSON, or reports `UPGRADE_REQUIRED`, state that this
installed `csc` build does not expose the management protocol. Recommend the
official Code Config installer or launcher update path and stop. Do not
download a replacement, inspect installation files, or invoke legacy helpers.

Report only safe structured fields: enrollment state, workspace/profile IDs,
onboarding state, sync/cache freshness, supported protocol/client versions,
host readiness, and value-free provider/binding health. Never inspect machine
state, manifests, native configuration, environment variables, logs that are
not declared safe, or provider stores directly.

## Route the result

- Not enrolled: explain that enrollment must use the official device flow.
  Run an enrollment command only if this build declares one; otherwise say it
  is unavailable.
- `profile_required`: direct the user to the explicit Create profile or Choose
  Community Profile onboarding surface. Create nothing silently.
- Stale or missing cache: run sync only when supported.

```sh
csc sync --json
```

- Saved but not Ready: use the returned safe reason. For missing bindings,
  hand off to the `/code-config` skill's trusted secret flow; for renderer
  or version drift, require re-preview or upgrade; for conflicts, require a
  new plan.
- Healthy profile: optionally perform the exact isolated verify command
  returned by status. Never construct missing IDs/digests.

Do not claim repair from an exit code. Re-run `status get --json` and require the
expected safe state. Never use direct cloud CRUD, generic file edits, secret
input, provider CLIs, or a compatibility pack as a fallback.
