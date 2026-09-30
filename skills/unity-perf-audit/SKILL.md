---
name: unity-perf-audit
description: Use when the user wants a static performance review of a Unity project's C# code, without running the game - scanning scripts for CPU, GPU, and memory anti-patterns (GetComponent or Find in Update, allocations and LINQ in hot paths, Camera.main, string concatenation, event leaks, runtime Instantiate, uncached WaitForSeconds) and producing a scored report with file:line locations and before/after fixes. Triggers include "perf audit", "performance audit", "audit my Unity code for performance", "optimize performance", "performance anti-patterns", "GC allocations in Update", "why is my code slow", and "code review for performance". For measuring a running game (Profiler captures, frame budgets, stutter, memory leaks) use unity-profiling-workflow instead.
---

Adapted from JulianKerignard/Unity-Skills (MIT); see LICENSE.

# Unity Perf Audit

## What this skill does

Static analysis of a Unity project's C# code to find performance anti-patterns. Nothing is run or
profiled: the source is scanned with search tools.

It produces:

- An inventory of the project's C# files (count, size, large files)
- A report of anti-patterns found, with severity and location
- The top 5 fixes, with before/after code

A static scan finds likely problems; it does not prove where the frame time goes. To measure on a
device and confirm a fix, use `unity-profiling-workflow`.

## Prerequisites

- A Unity project with C# scripts in `Assets/`
- Read access to the project folder
- No packages or external tools

## Decision tree

```
Reported symptom?
|
+-- Generally low FPS --> Full scan (steps 1-5), then confirm with unity-profiling-workflow
+-- Occasional spikes / stutter --> Focus on CPU (C1-C12) and allocations (M4, M5, M7)
+-- Memory keeps growing / out-of-memory crashes --> Focus on memory (M1-M7)
+-- Slow rendering, many draw calls --> Focus on GPU (G1-G4)
+-- No specific symptom (preventive audit) --> Full scan
```

## Quick start

1. Scan the project structure (glob `**/*.cs`)
2. Search for CPU, GPU, and memory anti-patterns
3. Score and categorize each finding
4. Write the report with file:line
5. Propose the top 5 fixes

## Step by step

### Step 1: Scan the project structure

Inventory every C# file in the project:

```
Glob: Assets/**/*.cs
```

Record:

- Total number of `.cs` files
- Files over 500 lines
- Folders with the most scripts
- Exclude `Plugins/`, `ThirdParty/`, `TextMesh Pro/` (third-party code)

Line counts:

```bash
find <project>/Assets -name "*.cs" -not -path "*/Plugins/*" -not -path "*/ThirdParty/*" -not -path "*/TextMesh Pro/*" | xargs wc -l | sort -rn | head -20
```

Summary format:

```
## Project structure
- **C# files**: 47
- **Total lines**: 12,340
- **Files > 500 lines**: PlayerManager.cs (623), GameController.cs (891)
- **Main folders**: Scripts/ (28), UI/ (12), Enemies/ (7)
```

### Step 2: Find anti-patterns

Search the C# files for CPU, GPU, and memory anti-patterns. The full table is in
`references/anti-patterns.md`. For each match, record the file, line number, and code line. Search
all project `.cs` files except the exclusions.

### Step 3: Score and categorize

Score per file and overall:

| Severity | Points | Impact |
|----------|--------|--------|
| Critical | 10 | Directly causes visible lag (every frame) |
| High | 5 | Significant degradation under load |
| Medium | 2 | Measurable in the profiler |
| Low | 1 | Good practice, minimal impact |

Overall score:

- **0-10**: Clean. No action needed.
- **11-30**: Acceptable. A few things to fix.
- **31-60**: Problematic. Fix before building.
- **61+**: Critical. Fixes required.

Score only problems actually found in the code. Never invent hypothetical ones.

### Step 4: Write the report

Report as a table with columns `#`, `Problem`, `Severity`, `File:Line`, `Description`. Group by
severity (Critical > High > Medium > Low). Add a per-severity summary (count + score) and the
overall score with its verdict (Clean / Acceptable / Problematic / Critical).

### Step 5: Propose the top 5 fixes

For each fix, show code before and after. Take problems in severity order (Critical first). Format:
title, severity, line, impact, then before/after code.

Common fixes:

| Anti-pattern | Standard fix |
|-------------|-------------|
| GetComponent in Update | Cache in Awake in a private field |
| Find at runtime | Cache in Awake, or inject via `[SerializeField]` |
| Camera.main in Update | `private Camera _cam; void Awake() => _cam = Camera.main;` |
| String concatenation in Update | `StringBuilder`, or remove the log |
| Instantiate in Update | Object pooling (`UnityEngine.Pool.ObjectPool<T>`, or a queue with activate/deactivate) |
| LINQ in Update | Plain `for` loop over a cached `List<T>` |
| SendMessage | Direct interface call or C# event |
| `.tag ==` | `.CompareTag("name")` |
| Repeated `new WaitForSeconds` | Cache a `static readonly WaitForSeconds` |
| Event without unsubscribe | Add `-=` in `OnDisable()` or `OnDestroy()` |
| Resources.Load without unload | Call `Resources.UnloadUnusedAssets()` at a loading point, or move to Addressables |

## Hard rules

**ALWAYS:**

- Report only problems found in the actual code (no speculation)
- Give the exact file and line number for each problem
- Give a concrete fix with before/after code
- Order by impact (Critical first)
- Exclude third-party code (`Plugins/`, `ThirdParty/`, `TextMesh Pro/`)
- Check context: `GetComponent` in `Start()` is fine, in `Update()` it is not
- Write fixes with current Unity 6 APIs (see `unity-current-api`)

**NEVER:**

- Suggest optimizing code that runs once (Start, Awake, initial OnEnable, loading screens)
- Invent problems that are not in the code
- Recommend large refactors (fix hot paths, not the architecture)
- Suggest external tools or paid packages
- Report a `foreach` over a fixed collection outside a hot path
- Report a match without checking it really is in the problematic context (false positives)

## Related skills

- Measure on device, find the real bottleneck, verify a fix: `unity-profiling-workflow`
- Update obsolete APIs found during the scan: `unity-current-api`
- Test after fixing: `unity-test`

## Troubleshooting

| Problem | Fix |
|----------|----------|
| Too many GetComponent false positives | Check the enclosing method. `GetComponent` in `Awake`/`Start`/`OnEnable` is fine. Search with `-B 20` to see context. |
| Match is inside a comment | Filter lines starting with `//` or inside `/* */`. Read the file to confirm. |
| File too large to read | Read in sections with offset/limit. Focus on Update, FixedUpdate, LateUpdate. |
| Project has no `Assets/` folder | Check the path. Ask the user to confirm the Unity project root. |
| Very high score on a prototype | Put it in context: a prototype does not need deep optimization. List the issues but lower the urgency. |
| Anti-pattern in disabled code | Check for `#if`, `[System.Obsolete]`, or comments marking dead code. Do not report dead code. |
| No `.cs` files found | The project may be empty or scripts live in a package. Glob `**/*.cs` without a folder filter. |
| Event leak false positive | If `+=` is in `OnEnable` and `-=` in `OnDisable`, it is correct. Watch for anonymous lambdas, which cannot be unsubscribed. |

Full anti-pattern table: `references/anti-patterns.md`
