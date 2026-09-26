---
name: ue-profiling-workflow
description: Use when an Unreal Engine 5 project has low frame rate, hitches or stutters, or needs a profiling or optimization pass — it gives the measure → locate → capture → analyze → fix → re-measure loop and which tool answers which question. For setting up lighting, Lumen, or Nanite themselves, use ue-lighting-lumen-nanite instead.
---

# UE profiling workflow

Performance work is a loop: pick a budget, measure the right build, find which thread or unit is over
budget, capture evidence, change one thing, measure again. Do not guess and do not change several
things at once. Every claim you make to the user carries a number from a capture.

Exact command syntax lives in `references/commands.md`. Check it before typing a command.

## 0. Check which tools this session has

Before relying on a companion tool, confirm it is actually present (listed skills, listed MCP tools,
binaries on PATH). Use what exists; fall back to the engine's built-in commands otherwise.

| Tool | Role | Needs |
|---|---|---|
| `renderdoc-gpu-debug` skill | Single-frame GPU capture and inspection through `rdc-cli`: draw calls, passes, render targets, shader inputs. Answers "why is this pass expensive / wrong", not "which frames are slow". | RenderDoc installed; UE launched with `-AttachRenderDoc` or the RenderDoc plugin enabled |
| `cli-anything-unrealinsights` skill | Headless Unreal Insights: capture a trace and export timing data without the GUI. | Windows |
| `ue-trace` MCP server | Reads `.utrace` files and reports bottleneck functions, spike frames, and frame-time percentiles. Use it to compare before/after traces. | A `.utrace` file |
| Tracy MCP server | Queries Tracy captures. | Only if the project integrates Tracy. If it does not, ignore this tool. |

If none are present, everything below still works with the engine console and the Unreal Insights GUI.

## 1. Set a target budget

Get the target platform and frame rate from the user or project settings, then convert to ms per frame:

| Target | Budget |
|---|---|
| 30 fps | 33.3 ms |
| 60 fps | 16.7 ms |
| 90 fps | 11.1 ms |
| 120 fps | 8.3 ms |

Each of Game, Draw, RHI, and GPU must fit inside the budget, because they run in parallel on
different frames. Leave headroom for hardware variance and content growth. For hitches, the budget
is also a ceiling on any single frame, not only the average.

## 2. Measure a packaged build, not the editor

Profile a packaged (cooked) build in the **Development** or **Test** configuration, on the target
hardware, with a repeatable scenario (a fixed camera path, a replay, or a scripted test).

Why not PIE or the editor:
- The editor process ticks its own UI, viewports, and tools, which inflates Game and Draw times.
- The editor uses uncooked assets and can compile shaders on demand, which adds hitches the
  shipped game will not have — and hides ones it will.
- Numbers from the editor do not transfer to the target platform.

Configuration choice (from Epic's build-configuration reference):
- **Development**: most optimizations, full console, stats, and profiling tools. The default choice.
- **Test**: the Shipping configuration with some console commands, stats, and profiling tools kept.
  Closest to what players get. Confirm the tool you need works there (for tracing, run `Trace.Status`).
- **Shipping**: strips console commands, stats, and profiling tools. Not usable for this loop.

Turn off frame-rate caps and VSync for measurement so frame time shows the actual work. Record
resolution and scalability level with every number.

## 3. Find the bottleneck with `stat unit`

Run `stat unit` (add `stat unitgraph` to see the values over time) in the running build:

| Row | Meaning | If Frame ≈ this row |
|---|---|---|
| Frame | Total time to produce one frame | — |
| Game | Game thread: gameplay, ticks, Blueprints, animation, physics sync | Game-thread bound |
| Draw | Render thread: visibility, culling, building draw commands | Render-thread bound |
| RHIT | RHI thread: submitting commands to the graphics API | RHI bound (usually tracks Frame) |
| GPU | Time the GPU takes to render the frame | GPU bound |

Rules of thumb:
- Frame close to Game → CPU game thread. Go to Insights (`cpu` channel) and `stat game`.
- Frame close to Draw → render thread. Look at draw call and primitive counts, `stat SceneRendering`,
  `stat InitViews`.
- Frame close to GPU → GPU. Go to `stat gpu` and `ProfileGPU`.
- A quick GPU test: lower the screen resolution. If frame time drops a lot, the cost is per-pixel
  (GPU); if not, it is CPU or per-vertex.
- Hitches (single long frames) are a separate problem from a high average. Capture a trace; do not
  diagnose hitches from `stat unit` alone.

## 4. Capture

Pick the capture that answers the question from step 3. Always capture the same scenario you will
re-run after the fix.

**Unreal Insights trace** — the main CPU and frame-timing capture.
- Launch the packaged game with `-trace=default` (default channels are Cpu, Gpu, Frame, Log, Bookmark,
  plus a few others). Add channels as needed, e.g. `-trace=default,memory,metadata,assetmetadata` for
  memory work. Add `-statnamedevents` for more CPU timers (costs overhead).
- Send to a running Insights / trace server on another machine with `-tracehost=<ip>`, or write
  straight to disk with `-tracefile=<path>`.
- At runtime: `Trace.File [file] [channels]` starts a file trace (`Trace.Start` is deprecated),
  `Trace.Send <host> [channels]` streams to a trace server, `Trace.Stop` ends it, `Trace.Status`
  shows what is on. With no path, `Trace.File` writes to `<Project>/Saved/Profiling`.
- Mark scenario steps with `Trace.Bookmark <name>` so before/after traces line up.
- If Unreal Insights is already running on the same machine when the game starts, it connects to
  the local trace server automatically.

**GPU** — `stat gpu` for live per-pass GPU timings (includes individual Lumen passes);
`ProfileGPU` (or Ctrl+Shift+Comma) for a one-frame pass tree in the GPU Visualizer and log. For a
single pass you need to open up, use the `renderdoc-gpu-debug` skill.

**CSV profiler** — lightweight per-frame stats over a long run, good for soak tests and
comparing runs. `-csvCaptureFrames=N` from the command line, or `csvprofile start` /
`csvprofile stop` / `csvprofile frames=N` at runtime. Output goes to `Saved/Profiling/CSV`.
Add `-csvGpuStats` for GPU stats (off by default because of its overhead).

**Memory** — `memreport -full` writes a text snapshot to `Saved/Profiling/Memreports`
(levels loaded, RHI stats, render targets, scene info, and more). `obj list` lists the UObjects in
memory. For allocation-level detail over time use Memory Insights (`-trace=default,memory,...`).

## 5. Analyze: which tool answers which question

| Question | Tool |
|---|---|
| Which unit is over budget? | `stat unit`, `stat unitgraph` |
| Which game-thread functions cost the most, and in which frames? | Insights Timing view (Frames, Timing, Timers, Callers/Callees); `ue-trace` MCP for bottleneck functions and percentiles |
| Which frames spike, and what ran in them? | Insights Frames panel; `ue-trace` MCP spike-frame report |
| Which tick functions exist, and how long do they take? | `stat game`; `dumpticks` lists every registered tick function |
| Which GPU pass is expensive? | `stat gpu`, `ProfileGPU` |
| Why is that pass expensive (draws, overdraw, shader)? | RenderDoc via `renderdoc-gpu-debug` |
| How does performance hold over minutes or across builds? | CSV profiler captures compared side by side |
| What is using memory right now? | `memreport -full`, `obj list`, `stat memory` |
| Where did memory get allocated, and is it leaking? | Memory Insights |
| Are PSO compiles causing hitches? | `stat PSOPrecache` with `r.PSOPrecache.Validation` set; Insights around the hitch |

## 6. Common bottlenecks

| Symptom | Likely cause | Next check |
|---|---|---|
| Game high, steady | Too many actors ticking, heavy Blueprint ticks, expensive per-frame logic | `stat game`, `dumpticks`, Insights `cpu` timers; reduce tick rate or disable ticks that do nothing |
| Draw high | Too many draw calls or primitives; poor culling | `stat SceneRendering`, `stat InitViews`, `stat RHI`; merge or instance meshes, check culling distances |
| GPU: shadow depth passes large | Many shadow-casting lights, large shadow radii, too many casters | `ProfileGPU` shadow depth entries; reduce casting lights and casters |
| GPU: Lumen passes large | Lumen Scene Lighting, Screen Probe Gather, or Reflections cost | `stat gpu` Lumen entries; set `r.Lumen.AsyncCompute 0` to measure Lumen alone; lower `sg.GlobalIlluminationQuality` / `sg.ReflectionQuality`. Lighting setup itself belongs in `ue-lighting-lumen-nanite` |
| GPU: Nanite cost high in foliage or dense areas | Overdraw from aggregate geometry (layers of geometry with holes, stacked surfaces) | Nanite Overdraw visualization; simplify or restructure the aggregate geometry |
| GPU: translucency passes large | Large or layered translucent surfaces, particles covering the screen | `ProfileGPU` translucency entries; RenderDoc on the pass; reduce translucent screen coverage and layers |
| GPU: Virtual Shadow Maps high every frame | Cache invalidation from moving lights, moving casters, World Position Offset or Pixel Depth Offset materials, skeletal meshes | `r.Shadow.Virtual.Visualize cache` or the Cached Page view mode; `r.ShaderPrintEnable 1` + `r.Shadow.Virtual.Stats 1` for invalidated page counts; set the primitive's Shadow Cache Invalidation Behavior (Rigid / Static) where it is safe |
| Periodic hitches, CPU side | Garbage collection | Insights: look for GC timers in the spike frames; `gc.DumpMemoryStats`; reduce UObject churn |
| Hitch the first time something appears | PSO / shader compilation at runtime | `r.PSOPrecache.Validation` + `stat PSOPrecache`; confirm `r.PSOPrecaching` is on; `r.PSO.RuntimeCreationHitchThreshold` sets what counts as a hitch (default 20 ms). Epic still recommends a bundled PSO cache alongside precaching |

## 7. Fix one thing, then re-measure

1. Change one thing only. Write down what and why.
2. Rebuild and repackage the same configuration.
3. Run the same scenario, same resolution, same scalability, same hardware, same bookmarks.
4. Capture the same way as the baseline.
5. Compare before and after: `stat unit` averages, and trace percentiles and spike frames (the
   `ue-trace` MCP server does this directly from two `.utrace` files when available).
6. Keep the change only if the number moved in the right direction by more than run-to-run noise
   (run each capture at least twice to see the noise).

## Report format

Report to the user in numbers:

- Target: platform, fps, budget in ms.
- Build: configuration, resolution, scalability, hardware, scenario.
- Bottleneck: which unit, with its ms value from `stat unit`.
- Evidence: the capture (file name) and the top timers or passes with their ms.
- Change: the one thing changed.
- Result: before → after for the bottleneck unit, average frame time, and a high percentile
  (for example p95 or p99), plus spike count if hitches were the issue.
- Next: the next biggest item, or "within budget".
