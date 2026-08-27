# Statusline

A [ccstatusline](https://www.npmjs.com/package/ccstatusline) preset tuned for long agent sessions —
it surfaces context headroom, which output style is live, and how long you've been going.

```
Opus 5 | Ctx(u) Used: 20.0% | f580dbeb-ef56-4981-8fa6-c218bb5a86e0 - Structured Engineering - Opus 5 | 3hr 55m
```

## Use it

Point your Claude Code `statusLine` setting at the preset:

```json
{
  "statusLine": {
    "type": "command",
    "command": "npx -y ccstatusline@latest --config /path/to/code-tools/statusline/ccstatusline.json",
    "padding": 0
  }
}
```

## Widgets

| Widget | Renders | Why |
|---|---|---|
| `model` | `Opus 5` | which model is answering |
| `context-percentage-usable` | `Ctx(u) Used: 20.0%` | headroom before auto-compact — the number that matters most on long runs |
| `claude-session-id` | `f580dbeb-…` | copy/paste target for resuming or pulling logs |
| `session-name` | your session name | blank unless you've named the session |
| `output-style` | `Structured Engineering - Opus 5` | easy to forget which style is active; this makes it obvious |
| `reset-timer` | `3hr 55m` | time since the last usage-window reset |

Widgets with no value are skipped along with their separator, so an unnamed session collapses cleanly
rather than leaving a dangling `-`.
