# code-tools

Portable tooling for coding agents — skills, output styles, and statusline config that work across
Claude Code, Codex, Cursor, and anything else that reads these formats.

Nothing here is a framework. Each piece is a plain file you can copy into your own agent config, or
install with a configurator that understands the layout below.

## Layout

`skills/` holds one directory per skill, `output-styles/` one Markdown file per style, and
`statusline/` the ccstatusline preset. Each directory carries its own `AGENTS.md` describing how to
work in it; `CLAUDE.md` is a one-line `@AGENTS.md` import of it.

## Designed for code-config.com

The directory structure is a contract, not just an arrangement. It's built so
[code-config.com](https://code-config.com) can install a piece of tooling *and the configuration it
needs* as one unit, without a separate manifest to keep in sync.

The rules a consumer can rely on:

**A skill is a directory that directly contains `SKILL.md`.** The directory name is the skill name
and how it's invoked (`skills/fanout-codex/` → `/fanout-codex`). Everything under that directory
belongs to that skill — helper scripts, `references/`, and its settings.

**A `settings.json` beside a `SKILL.md` declares the host settings that skill needs to work.** This
is the "this skill, this setting" pairing: install `fanout-codex` and you also want its concurrency
settings, or the skill's own instructions won't hold. The file is a settings *fragment in the host's
own schema* — for Claude Code, a partial `settings.json` — so it merges as an overlay instead of
needing a bespoke format translated:

```json
{
  "env": {
    "CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS": "600000",
    "CLAUDE_CODE_MCP_AUTO_BACKGROUND_MS": "5000"
  }
}
```

**Silence means "no requirement."** A skill that needs no settings has no `settings.json` at all,
rather than an empty one. Only settings the skill actually depends on are declared, so a consumer
never has to guess which of them matter.

Note that **Claude Code does not read these files itself.** Nothing loads them at runtime, and a
skill cannot apply a setting mid-session — environment variables are read once when the process
starts. They exist so the requirement travels with the thing that requires it, and so a configurator
can apply both together at install time.

## Requirements

Most skills here are thin orchestration over tools you supply yourself:

- **`pal` MCP server**, providing the `clink` tool — required by every `fanout-*` skill and by
  `implement_plan`. Available at
  [BeehiveInnovations/pal-mcp-server](https://github.com/BeehiveInnovations/pal-mcp-server).
  Each `fanout-*` skill drives a specific pal client (`conf/cli_clients/<name>.json`), so the
  client for the tier you want has to be configured there.
- **The `codex` CLI** — used by pal's `codex` client, which `fanout-codex` and `implement_plan`
  drive.
- **A z.ai or Kimi endpoint** (plus credentials) — `fanout-zai` and `fanout-kimi` run `claude`
  headless against a third-party provider rather than a separate CLI.
- **The `csc` CLI**, which ships with Code Config — `code-config` and `code-config-doctor` drive it
  and treat it as their only implementation. Get it from
  [code-config.com](https://code-config.com); the download page installs `csc` alongside the
  launcher.
- **[ccstatusline](https://www.npmjs.com/package/ccstatusline)** — required only by
  `statusline/`. Run via `npx`; see `statusline/README.md`.

- **A built-in `/goal` command** (Claude Code and Codex both ship one) — required only by
  `create-goal`, which doesn't run a goal, it scaffolds one and hands back the prompt you pass to
  `/goal`. It writes to `thoughts/shared/goals/` in the target project, and expects plans in
  `thoughts/shared/plans/`.

`review-packet` needs nothing beyond bash, and `implement_task` nothing beyond your agent's own
edit and test tools.

## License

MIT — see [LICENSE](LICENSE).
