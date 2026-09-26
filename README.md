# code-tools

Portable tooling for coding agents — skills, output styles, and statusline config that work across
Claude Code, Codex, Cursor, and anything else that reads these formats.

Nothing here is a framework. Each piece is a plain file you can copy into your own agent config, or
install with a configurator that understands the layout below.

## Layout

`skills/` holds one directory per skill, `output-styles/` one Markdown file per style,
`mcp-configs/` one JSON file per group of MCP servers, and `statusline/` the ccstatusline preset. Each directory carries its own `AGENTS.md` describing how to
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

- **Unreal Engine 5.8** — required by the `ue-*` skills. They pair with community skills that
  cover the rest of the engine, and name them where the topics meet:
  [quodsoler/unreal-engine-skills](https://github.com/quodsoler/unreal-engine-skills),
  [JetBrains/rider-skills](https://github.com/JetBrains/rider-skills), the `unreal-mcp`,
  `create-toolset` and `unreal-skill` skills from
  [EpicGames/unreal-engine-skills-for-claude-code-plugin](https://github.com/EpicGames/unreal-engine-skills-for-claude-code-plugin),
  `unreal-pcg-python` from [maystudios/claude-skills](https://github.com/maystudios/claude-skills),
  `renderdoc-gpu-debug` from [rudybear/renderdoc-skill](https://github.com/rudybear/renderdoc-skill)
  and `cli-anything-unrealinsights` from [HKUDS/cli-anything](https://github.com/HKUDS/cli-anything).
  Each `ue-*` skill works without them.
- **`mcp-configs/unreal-profiling.json`** declares two profiling servers used by
  `ue-profiling-workflow`:
  - **ue-trace** reads Unreal Insights `.utrace` files and reports slow functions, spike frames and
    frame-time percentiles. It runs through `npx` (Node.js required) and downloads its analysis
    program on first use. Windows and Linux; no macOS build yet.
  - **tracy** connects to the [Tracy](https://github.com/wolfpld/tracy) profiler's MCP server, for
    projects that use Tracy. Build Tracy's Python bindings, then start the server from your Tracy
    checkout with `extra/mcp/start_mcp.sh`; it listens on `http://127.0.0.1:47380/mcp`.

- **Three.js** — `threejs-current-api` and `threejs-visual-check` pair with community skills
  that cover the rest of the library, and name them where the topics meet:
  [CloudAI-X/threejs-skills](https://github.com/CloudAI-X/threejs-skills),
  [OpenAEC-Foundation/Three.js-Claude-Skill-Package](https://github.com/OpenAEC-Foundation/Three.js-Claude-Skill-Package),
  [EnzeD/r3f-skills](https://github.com/EnzeD/r3f-skills),
  [dgreenheck/webgpu-claude-skill](https://github.com/dgreenheck/webgpu-claude-skill),
  [linegel/threejs-complete-set-of-skill](https://github.com/linegel/threejs-complete-set-of-skill),
  [majidmanzarpour/threejs-game-skills](https://github.com/majidmanzarpour/threejs-game-skills)
  and the `gltf-transform` skill from [rawwerks/VibeCAD](https://github.com/rawwerks/VibeCAD).
- **`mcp-configs/threejs.json`** declares three servers used by `threejs-visual-check` and the
  React Three Fiber skills:
  - **threejs-devtools** reads and edits a running Three.js or React Three Fiber scene: objects,
    materials, shaders, draw calls, memory. Runs through `npx` (Node.js required) and opens a
    browser against your dev server.
  - **chrome-devtools** is Google's Chrome DevTools server: screenshots, console messages,
    performance traces. Runs through `npx`; needs Chrome.
  - **pmndrs-docs** serves current documentation for React Three Fiber, Drei, Zustand and
    React Postprocessing. Hosted by Poimandres; nothing to install.

- **Unity 6** — required by the `unity-*` skills. They pair with Unity's official skills
  ([Unity-Technologies/skills](https://github.com/Unity-Technologies/skills), also shipped as the
  `unity` plugin for Claude Code and Codex) and name them where the topics meet, such as `unity-cli`,
  `ui-uitk` and `setup-multiplayer-services`. Also paired: `unity-ecs-patterns` from
  [wshobson/agents](https://github.com/wshobson/agents) and `renderdoc-gpu-debug` from
  [rudybear/renderdoc-skill](https://github.com/rudybear/renderdoc-skill). The editor connection is
  Unity's own MCP server (`unity mcp` in the [Unity CLI](https://docs.unity.com/en-us/unity-cli/unity-cli));
  `unity-compile-and-test` covers setting it up.
- **Adapted skills** — `unity-2d`, `unity-addressables`, `unity-animation`, `unity-editor-tools`,
  `unity-multiplayer`, `unity-perf-audit`, `unity-save`, `unity-shader-gen` and `unity-test` are
  adapted from [JulianKerignard/Unity-Skills](https://github.com/JulianKerignard/Unity-Skills) under
  its MIT license, which each folder carries in its own `LICENSE`.

`review-packet` needs nothing beyond bash, and `implement_task` nothing beyond your agent's own
edit and test tools.

## License

MIT — see [LICENSE](LICENSE).
