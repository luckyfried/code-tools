# {{GOAL_TITLE}}

Created: {{YYYY-MM-DD}}
Plan: {{path under thoughts/shared/plans/..., or "none — this file is the spec"}}
Sibling goals: {{related folders under thoughts/shared/goals/, or "none"}}

---

## Mission

{{What this goal delivers, in 2-5 sentences. Describe the end product concretely.}}

**This IS:** {{the actual deliverable}}.
**This is NOT:** {{the adjacent thing it's easy to drift into — name it so scope stays honest}}.

## Why

{{Why this matters. What's wrong today that this goal fixes.}}

## What "done" means

{{The single measurable condition that decides success.}}

Building everything without meeting that condition is not done.

**How it's measured:** {{the check that settles it, and the threshold. Lock it here, or write
"[decided at M0]" — don't guess.}}

## Scope

**IN scope:**
- {{...}}

**OUT of scope:**
- {{the follow-on work — name it so it doesn't leak in}}.
- Rewriting the plan. This goal executes it; gaps go to DECISIONS.md.

## Depends on {{(optional — delete if N/A)}}

{{The data, environment, or services this goal needs, and what to re-check before starting.}}

## Rules

1. **Nothing is done until you've seen it work.** Code existing is not evidence that it runs.
2. **Keep the files current.** Append to NOTES.md as work lands, append to DECISIONS.md when a
   decision is made, tick PHASES.md boxes as milestones pass.
3. {{project-specific rule}}
4. {{project-specific rule}}

## Issue tracker {{(optional — delete this section if you don't use one)}}

If this work is tracked externally (Jira, Linear, GitHub Issues), record the shape here and file it
at M0 — not when the goal is created.

- **Parent** — {{the epic or project that owns this goal}}.
- **Children** — {{how it breaks down: one ticket per milestone?}}.
- Ticket IDs go into PHASES.md as they're filed.

## Cadence

- **Session start:** read this file and PHASES.md, then the top of NOTES.md and DECISIONS.md.
- **During work:** append to NOTES.md — newest first, dated.
- **A decision resolves:** append to DECISIONS.md with the reasoning and what you rejected; strike
  the matching entry in OPEN_QUESTIONS.md.
- **A milestone item passes:** tick its PHASES.md box and note how you verified it.

## Definition of done

This goal is complete when:

- Every box in PHASES.md is ticked, each with a note on how it was verified.
- {{the measurable condition above is met, confirmed by running it}}.
- The tracker tickets, if any, are closed out.
- This set of files reflects the final state.
