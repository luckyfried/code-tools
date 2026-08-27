---
name: fanout-zai
description: Fan out parallel coding work to zai (GLM-5.2, headless) as backgrounded MCP tasks — no subagents, no wrapper. The main session writes precise task-spec md files ONCE, then fires one mcp__pal__clink(cli_name="zai") call per unit in a single message; the harness runs them concurrently and auto-backgrounds each, and zai edits the repo directly. Usage - /fanout-zai [count] (e.g., /fanout-zai 5 to cap at 5 parallel units). Defaults to as many units as the work decomposes into.
---

# Fan-out zai

Delegate a body of coding work to **zai** — a headless Claude Code backed by GLM-5.2, running many
units in parallel. The expensive Anthropic model (you) only orchestrates; the bulk coding runs on zai.

**No subagents, no wrapper.** Each unit is one `mcp__pal__clink` call with `cli_name: "zai"`. pal
annotates `clink` `readOnlyHint: true`, so the harness runs every clink call you emit in a single
message **concurrently**, and any call still running past the auto-background threshold is **moved to a background task** — you get
a notification when it finishes and can keep working meanwhile. That is the "backgroundable MCP task"
mechanism: N parallel zai units, zero Anthropic agents, no intermediate script.

pal's `zai` client (`conf/cli_clients/zai.json`) launches `claude` headless against the z.ai endpoint
with GLM-5.2 and `--permission-mode acceptEdits`, so zai edits the real repo directly — exactly like a
local session, just driven by a cheaper model.

## The core idea — write the spec ONCE, pass the path

zai is cheap but **literal-minded and weak**. It needs exhaustively precise instructions, and there
are many of them. Do NOT retype those instructions into each clink call's `prompt` — that multiplies
the spec's token cost in *your* context.

Instead:

1. **You** (main session) write each unit's full instructions to a **task-spec `.md` file on disk** — once.
2. You fire one `mcp__pal__clink` call per unit, passing the spec file's absolute path in
   `absolute_file_paths` and only a one-line directive in `prompt`.
3. pal hands the spec to zai; the detailed spec text never re-enters your context. zai edits the repo
   directly and its final message returns as the clink result (inline if it finished, or via the
   background-task notification if it ran long).

```
main session ──writes spec text once──> thoughts/shared/agent-comms/<slug>/task-NN.md
     │                                            │
     │ mcp__pal__clink(cli_name="zai",            │ absolute_file_paths=[task-NN.md]
     │   prompt="execute the attached spec")      │
     ▼                                            ▼
 pal clink ───────────────────────> zai / GLM-5.2 (acceptEdits) ──edits repo──> disk
     │                                                                          │
     └──> clink result / bg-task notification (zai's final message) ◄───────────┘
```

## Hard rules — learned, not optional

**1. Disjoint files per parallel unit — the cardinal rule.** zai runs with `acceptEdits` and writes
to the real repo. `clink` is annotated read-only, so the harness will happily run concurrent zai calls
that are actually editing — it will NOT serialize them for you. Two units that touch the same file WILL
clobber each other (no merge, last writer wins). When you decompose, every unit MUST own a **disjoint
set of files**. If two pieces of work genuinely share a file, put them in the SAME unit or sequence
them — never two parallel units on one file. State the file partition explicitly before launching.

**2. Bound zai's blast radius.** A weak model with acceptEdits roaming a repo is dangerous. Every
task-spec MUST list the exact files zai may edit and an explicit "do NOT touch anything else."

**3. Precision over brevity in the spec.** Treat zai as a competent-but-literal junior who will do
*exactly* what you write and nothing you imply. Exact paths, exact symbol/function/type names, exact
signatures, concrete before/after, and an unambiguous acceptance test. Ambiguity → wrong code.

**4. Launch, don't block.** Fire all the clink calls in ONE message. Each runs concurrently and
auto-backgrounds, so a unit can run for many minutes without stalling the session. Do NOT run
clink calls one message at a time waiting for each — that serializes them. Never place a zai clink call
inside a `Workflow` stage (the stall supervisor kills long agent calls and retries them).

**5. Observe disk, never trust the summary.** zai reports a `<SUMMARY>`; that is a claim, not proof.
After fan-in you independently verify the actual repo state (build / typecheck / the unit's test) before
calling any unit done. Re-dispatch units whose verification fails.

## Arguments

`$ARGUMENTS` format: `[count]`

- **count** (optional): cap on the number of parallel units. If omitted, use as many units as the work
  naturally decomposes into (keep it sane — large fan-outs strain the box and the API).

## Step 1: Understand the work

From the conversation context (and the user's request), determine the full body of coding work to
delegate. If the scope isn't already concrete, make it concrete before decomposing — you cannot write
a precise spec for vague work.

## Step 2: Decompose into disjoint units

Break the work into independent units such that **no two units edit the same file** (Rule 1). For each
unit, note: a short slug, the exact files it owns, and the change it makes. State the partition to the
user. If `count` is set and there are more units than `count`, batch the smallest/related units together
(still keeping file sets disjoint) so you launch at most `count` units.

## Step 3: Write one task-spec file per unit

For each unit, write `${CLAUDE_PROJECT_DIR}/thoughts/shared/agent-comms/<run-slug>/task-NN.md` (create
the dir). Use absolute paths. The spec IS the prompt — zai reads it via `absolute_file_paths`, so write
it as a direct instruction. Fill every section, leave nothing implied:

```markdown
# Unit NN: <one-line objective>

## Context
<What exists now, where it lives, why this change. Cite exact files/symbols zai should read first.>

## Files you MAY edit (and NO others)
- /abs/path/to/file_a.ext
- /abs/path/to/file_b.ext
Do NOT create, delete, rename, or edit any file not listed above.

## Exact changes required
1. In `/abs/path/file_a.ext`, <precise change: function name, signature, types, behavior, before→after>.
2. ...
<Number every change. Give concrete code shapes / signatures, not descriptions of intent.>

## Out of scope — do NOT
- <e.g. do not refactor surrounding code, do not touch imports elsewhere, do not reformat unrelated lines>

## Acceptance criteria
- <Observable, checkable conditions: "function X returns Y for input Z", "module imports cleanly".>

## Verification command (run it; it must pass)
```
<exact command, e.g. the single test or typecheck scoped to this unit>
```

## Output
End your reply with `<SUMMARY>` listing every file you changed and the verification result.
```

## Step 4: Launch the units

Emit **one `mcp__pal__clink` call per unit, all in a single message** so the harness runs them
concurrently and auto-backgrounds each. For every unit:

```
mcp__pal__clink(
  cli_name = "zai",
  prompt   = "Execute the attached task-spec file exactly. It lists the only files you may edit, the
              numbered changes, the out-of-scope list, and the verification command you must run. When
              done, end with <SUMMARY> listing every file you changed and the verification result.",
  absolute_file_paths = ["${CLAUDE_PROJECT_DIR}/thoughts/shared/agent-comms/<slug>/task-NN.md"]
)
```

- `cli_name: "zai"` selects the GLM-5.2 headless client (z.ai endpoint, `acceptEdits`); pal sources its
  own env for the token and model aliases.
- Keep `prompt` to the one-line directive above — the detail lives in the spec file. Never inline the
  full spec text into `prompt` (that defeats the context firewall and costs your tokens).
- `role` defaults to `default` (coding). Use `role: "codereviewer"` only for a review-shaped unit.
- To continue an earlier zai thread (a re-dispatch or follow-up turn on the same unit), pass that
  unit's `continuation_id` from its prior clink result.

## Step 5: Confirm launch

Tell the user:

```
Launched [N] zai coding units as parallel clink tasks (specs in thoughts/shared/agent-comms/<run-slug>/).
Each runs concurrently and backgrounds if it runs long; you'll be notified as they complete.
```

Then stop. Do not wait.

## Step 6: When units return — verify disk, triage, re-dispatch

Per Rule 5, do not trust the `<SUMMARY>`. For each unit:

1. **Observe the actual disk state** — run the unit's verification command yourself, and/or read the
   changed files. Outputs don't lie; zai's summary might.
2. **Pass** → the unit is done.
3. **Fail or incomplete** → fix it on zai, not on yourself (that's the token saving). Append the failure
   output and what is still wrong to the unit's `task-NN.md`, then re-fire that unit's clink call,
   passing its `continuation_id` to continue the same thread (or a fresh call if you want a clean slate).
4. After all units pass individually, run one **aggregate** check (full build / typecheck / test suite) —
   parallel edits to disjoint files can still interact. Fix any integration breakage via a follow-up unit.

Only when the aggregate check passes is the fan-out complete.
