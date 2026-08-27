# skills/

One directory per skill, named as it's invoked (`/fanout-codex` → `fanout-codex/`), containing a
`SKILL.md` plus any helper scripts.

```yaml
---
name: skill-name          # matches the directory
description: <when this skill applies>
---
```

`name` is optional — it defaults to the directory name — but set it anyway. Being explicit keeps the
file self-describing and doesn't rely on every agent tool inferring it the same way.

**`description` is the entire basis for selection** — nothing else is in context when an agent picks a
skill. Write when to use it, including trigger phrases a user would say, and the `/usage` form if it
takes arguments. A description that only says what the skill *is* will never fire.

Keep the body skimmable; it loads in full once selected. Put long reference material in
`references/` and link to it.

Helper scripts live beside `SKILL.md`, are executable, take parameters as CLI arguments rather than
hardcoded values, and print only relative or `$HOME`-derived paths.

## settings.json — the settings a skill needs to work

A skill may sit beside a `settings.json` declaring the host settings it depends on.

**Claude Code does not read this file.** Nothing loads it at runtime, and a skill that needs a
setting cannot apply it mid-session — env vars are read once when the process starts. It exists so
the setting travels with the skill that needs it, and so a configurator can pair the two on install.

Write it as a settings *fragment in the host's own schema* — for Claude Code that's a partial
`settings.json` — so a consumer merges it as an overlay rather than translating a bespoke format:

```json
{
  "env": {
    "CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS": "5000"
  }
}
```

Declare only what the skill's own body actually depends on, and omit the file entirely when a skill
needs nothing — an empty fragment implies a requirement that isn't there. A skill that spawns
subagents and one that fires concurrent MCP calls have different needs; don't give them a shared
default.

Where the value has a number in it, `SKILL.md` prose must not restate that number — describe the
behavior instead ("past the auto-background threshold"), since the fragment is what sets it and a
copied literal goes stale silently.

Before committing: cross-referenced skills exist here, any `settings.json` is valid JSON that agrees
with its `SKILL.md`, and scripts pass `bash -n` and run outside their author's home directory.
