---
name: create-goal
description: Turn the current work into a long-horizon autonomous "goal". First analyze what we're working on in maximum depth, then scaffold a dated goal workspace under thoughts/shared/goals/ (GOAL.md, goal_prompt.txt, PHASES.md, DECISIONS.md, NOTES.md, OPEN_QUESTIONS.md), then return a compact (≤3000-char) launch prompt to pass to the built-in /goal. Use when the user says "create a goal", "start a new goal", "set up a goal folder", "scaffold a goal", "make this a goal", or wants to run the current work as a persistent, evidence-gated program (not a one-off plan or a single ticket).
allowed-tools: [Bash, Read, Write, Edit]
---

# Create a Goal Workspace

Three jobs, in order:

1. **Analyze the work** — in maximum depth, before any file exists (Step 1).
2. **Make the files** — scaffold + fill the goal folder from that analysis (Steps 2–5).
3. **Hand back a launch prompt** — return a ≤3000-char prompt the user runs as `/goal <prompt>` (Step 6).

A goal folder is the durable, file-based "mission control" for one long-horizon program: what
an agent reads on session start to re-orient, appends outcomes and decisions to as it works, and
treats as the source of truth for where the program stands across many sessions. `/goal` is the
**built-in** runner that executes/resumes a goal from the prompt this skill emits — this skill
does NOT run the goal, it sets it up.

## When to use

A **multi-session, evidence-gated program** — spans days/weeks, runs as many steps (often many
parallel runs), needs durable state that survives context loss.

**Do NOT use for:**
- A **one-off plan** → that's a `thoughts/shared/plans/...` doc. A plan is the *spec*; a goal
  *executes* a spec (and usually points at one).
- A **single unit of work** → one ticket in whatever tracker you use.
- A quick task you'll finish this session → just do it.

## The model

```
plans/<date>-<name>/     →  the spec. What to build. Often pre-exists.
goals/<date>-<slug>/     →  where it stands. The execution state. (this skill makes it)
<your issue tracker>     →  optional. Where the work is tracked formally.
/goal <prompt>           →  built-in runner that executes/resumes the goal.
```

The goal folder is the memory that survives between sessions. It does NOT duplicate the plan — it
points at it and records progress, decisions, outcomes, open questions.

### The file set (one folder, six files — each a distinct role)

| File | Role |
|---|---|
| `goal_prompt.txt` | The **launch prompt** (≤3000 chars) — pasted into `/goal` to start or resume. A pointer, not the spec. |
| `GOAL.md` | The contract: mission, why, what "done" means, in/out scope, rules, tracker shape, cadence. |
| `PHASES.md` | **Milestone tracker** — a checklist per milestone, plus ticket slots and an Outcome line. Tick a box only once you've seen it work. |
| `DECISIONS.md` | **Decision log, newest at top** — what was chosen, why, and what was rejected. |
| `NOTES.md` | **Running log, newest first** — every outcome, review, decision, and failure. |
| `OPEN_QUESTIONS.md` | **Unknowns still open** — each with the milestone that owns it and how it gets settled. |

## Procedure

### 1. Analyze what we're working on (NO files yet)

**Stop and think this through fully before touching the filesystem.** The quality of the whole
goal — the files and the launch prompt — is set here. First **observe, then reason**:

**Observe (ground the analysis in reality, don't theorize):** read the live context — this
conversation's work, the plan doc if one exists (`thoughts/shared/plans/...`), the relevant
code/configs in play, and any sibling goals under `thoughts/shared/goals/`. Run cheap probes if
they sharpen the picture (what exists, what's wired, what it runs on).

**Then reason, deeply, through all of these — write the answers down (they become the files):**
- **Objective.** What outcome are we actually after? State what it IS and, pointedly, what it is
  NOT (the adjacent thing it's easy to drift into).
- **What "done" means.** The single *measurable* condition that decides success, and how it gets
  checked. Building everything without meeting it is not done.
- **Scope.** In vs out — especially the successor work that must NOT leak in.
- **Dependencies.** What data, environment, or services it stands on, and what to re-check first.
- **Milestones.** M0 → … → done, the critical path, what can run in parallel. Each milestone needs
  a concrete checklist — things you could actually run or read to prove them.
- **Rules.** The constraints that matter for THIS work.
- **Tracker shape (skip if you don't use one).** How the tickets break down (filed at M0, not now).
- **What goes where.** Outcomes → NOTES, resolved decisions → DECISIONS, checked boxes → PHASES,
  unknowns → OPEN_QUESTIONS.
- **Open unknowns.** What's genuinely unknown, which milestone settles it, and how.

Do not proceed to scaffolding until you can answer these. Thin analysis here produces a thin
goal that wastes every session that later runs it.

### 2. Confirm scope + gather any missing seed

Confirm it warrants a goal (per *When to use*). Pull everything you can from Step 1; ask the user
only for what's genuinely unresolvable, in one tight batch (title, the measurable gate, a plan
path if any, the parent objective). Imperative + enough context → execute; vague → ask first.

### 3. Resolve the template dir and the destination

```bash
# templates/ sits beside this SKILL.md — wherever your agent loaded this skill from.
TPL="<path to this skill's templates/ directory>"
[ -d "$TPL" ] || { echo "create-goal: templates dir not found: $TPL"; exit 1; }

# Goals live in thoughts/shared/goals/. Walk up to find the thoughts/ tree.
ROOT="$PWD"
d="$PWD"; while [ "$d" != "/" ]; do [ -d "$d/thoughts/shared" ] && ROOT="$d" && break; d="$(dirname "$d")"; done
GOALS="$ROOT/thoughts/shared/goals"

DATE="$(date +%F)"                      # NEVER hardcode the date
SLUG="$DATE-<short-kebab-descriptor>"   # e.g. 2026-06-07-payments-retry-policy
DEST="$GOALS/$SLUG"
echo "Will create: $DEST"
```

If `$ROOT/thoughts/shared` doesn't exist up-tree, the cwd may be the wrong project — confirm the
location with the user before creating it.

### 4. Scaffold, then fill every placeholder from the Step 1 analysis

```bash
mkdir -p "$DEST"
cp "$TPL"/goal_prompt.txt "$TPL"/GOAL.md "$TPL"/PHASES.md \
   "$TPL"/DECISIONS.md "$TPL"/NOTES.md "$TPL"/OPEN_QUESTIONS.md "$DEST"/
```

Read each file and replace **every** `{{PLACEHOLDER}}` with the Step-1 analysis, in place.
Fill it like a contract, not a form:
- `GOAL.md` — mission, why, what "done" means, scope, rules, tracker shape, cadence. Add project rules to the list.
- `PHASES.md` — seed M0 (including tracker filing, if used) and the first milestone(s) with concrete checklists; later milestones as stubs.
- `DECISIONS.md` / `NOTES.md` — leave the "newest entry goes below" skeleton; do NOT invent history.
- `OPEN_QUESTIONS.md` — seed the real unknowns (each with its owning milestone and how it gets settled).
- `goal_prompt.txt` — fill last (Step 6); it summarizes everything above.

No `{{...}}` may remain in the non-prompt files:

```bash
grep -rn '{{' "$DEST"/GOAL.md "$DEST"/PHASES.md "$DEST"/DECISIONS.md "$DEST"/NOTES.md "$DEST"/OPEN_QUESTIONS.md \
  && echo "UNFILLED — fill them" || echo "clean"
```

### 5. Do NOT file tracker tickets here

If you track work in an external system, filing is the runner's first job — an M0 checklist
item, not part of creation. GOAL.md records the shape; the running session files the tickets and
writes their IDs into PHASES.md. Skip this entirely if you don't use a tracker.

### 6. Emit the ≤3000-char launch prompt for `/goal`

Fill `goal_prompt.txt` (the template is already shaped for this) so it is **self-contained and
≤3000 characters**: what we're doing, the goal-folder path, the six files + how to maintain each,
the objective, what "done" means, the rules that matter, and the BEGIN steps. Then check the size
and **return it verbatim in the chat**:

```bash
# wc -m counts characters, not bytes — needs a UTF-8 locale, or em-dashes/arrows inflate the count.
chars=$(wc -m < "$DEST/goal_prompt.txt")
echo "goal_prompt.txt = $chars chars (must be <= 3000)"
[ "$chars" -le 3000 ] || echo ">>> OVER BUDGET — tighten goal_prompt.txt and re-check"
grep -n '{{' "$DEST/goal_prompt.txt" && echo "UNFILLED placeholders in prompt" || echo "prompt clean"
```

If over 3000, trim (the prompt is a pointer — push detail into GOAL.md, keep the prompt lean) and
re-check. Then print the full contents in a fenced block with the usage line:

> Run this in a fresh session to start the goal: `/goal <paste the block below>`

The same text lives in `goal_prompt.txt` for re-launch later.

## Disciplines this scaffold encodes (preserve them when filling)

- **Nothing is done until you've seen it work.** Tick a PHASES box only with something concrete
  behind it — a file:line, a command and its output, a run or ticket ID. Code existing is not
  evidence that it runs.
- **Append-only, newest-first logs.** NOTES.md and DECISIONS.md grow at the top.
- **The measurable condition is what counts, not how much got built.**

## Anti-patterns

| Bad | Good |
|-----|------|
| Scaffolding before analyzing | Do Step 1's analysis first; the files are its output |
| Theorizing the objective from the prompt alone | Read the live work/plan/code first, then reason |
| Using a goal for a one-off task | Goal = multi-session program; one-off → file a ticket or just do it |
| Duplicating the plan into the goal folder | Point at the plan; the goal tracks execution |
| Hardcoding today's date | `date +%F` |
| Leaving `{{placeholders}}` in the files | `grep -rn '{{'` comes back clean |
| A launch prompt > 3000 chars | Trim to a pointer; detail lives in GOAL.md (`wc -m` ≤ 3000) |
| Vague success condition ("make it better") | Something measurable, and how you'd check it |
| Inventing fake NOTES/DECISIONS history | Leave the newest-entry skeleton; entries accrue at run time |

## Reference

- `/goal` — **built-in** runner that executes/resumes a goal from the emitted prompt.
- Goals to model: any sibling folder under `thoughts/shared/goals/` in the target project.
- Sibling skill: `/implement_plan` — executes a plan doc, which a goal often points at as its spec.
- Templates: `skills/create-goal/templates/` (the six files this skill instantiates).
