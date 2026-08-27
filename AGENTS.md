# code-tools

Portable tooling for coding agents — skills, output styles, and statusline config that work across
Claude Code, Codex, Cursor, and anything else reading this format.

Each directory has its own `AGENTS.md`. `CLAUDE.md` is a pointer to it; edit the `AGENTS.md`.

## This repo is public

Before adding or editing anything, confirm it has none of:

- **Credentials** — keys, tokens, connection strings. Including expired ones.
- **Private infrastructure** — internal hostnames, RFC1918 addresses, company-internal URLs.
- **Machine-local paths** — no `/home/<user>/...`. Use `$HOME`, `$CLAUDE_PROJECT_DIR`, or relative.
- **Private workflow coupling** — internal ticket systems, dashboards, company processes.

`.gitignore` excludes the materialized agent config (`.claude/`, `.codex/`, `.mcp.json`), which is
credential-bearing. Never force-add it.

## Conventions

Everything must work on a stranger's machine. External dependencies are fine — name them and say
where to get them.

Cross-references must resolve. If a skill mentions `/other-skill`, it must exist here:

```bash
grep -rhoE '/[a-z][a-z0-9_-]+' skills/*/SKILL.md | sort -u
```

When you remove a tool, update everything that referenced it in the same change.
