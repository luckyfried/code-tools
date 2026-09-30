---
name: unity-profiling-workflow
description: Use when a Unity 6 (6000.x) project has low FPS, stutter, hitches, GC spikes, a memory leak, or the user says "profile this" or asks for an optimization pass — it gives the budget → device capture → locate → fix one thing → re-measure loop and which Unity tool (Profiler, Profile Analyzer, Memory Profiler, Frame Debugger, Rendering Debugger, RenderDoc) answers which question. For designing DOTS/ECS architecture itself, use unity-ecs-patterns instead.
---

# Unity profiling workflow

Performance work is a loop: pick a budget, measure a Development Build on the target device, find
which thread or unit is over budget, capture evidence, change one thing, measure again. Do not guess
and do not change several things at once. Every claim you make to the user carries a number from a
capture.

Exact menu paths, settings, API snippets, and source pages are in `references/tools.md`. Check it
before telling the user where to click.

## 0. Check which tools this session has

Before relying on a companion tool, confirm it is actually present (listed skills, listed MCP tools,
installed packages in `Packages/manifest.json`, binaries on PATH). Use what exists; fall back to the
built-in Profiler otherwise.

| Tool | Role | Needs |
|---|---|---|
| `unity-compile-and-test` skill | Produces the Development Build this loop measures, and rebuilds after each change. | Unity Editor installed |
| `renderdoc-gpu-debug` skill | Single-frame GPU capture and inspection through `rdc-cli`: passes, draws, render targets, shader inputs. Answers "why is this pass expensive or wrong", not "which frames are slow". | RenderDoc installed; a supported graphics API |
| `unity-ecs-patterns` skill | DOTS/ECS design: how systems, jobs, and Burst code should be structured once profiling shows the problem is there. | Entities package in the project |
| Profile Analyzer package (`com.unity.performance.profile-analyzer`) | Compares two sets of Profiler frames side by side (before/after). | Installed through the Package Manager |
| Memory Profiler package (`com.unity.memoryprofiler`) | Memory snapshots and snapshot comparison for leaks. | Installed through the Package Manager |
| Unity AI Assistant package (`com.unity.ai.assistant`) | Explains a selected Profiler sample or frame ("Analyze a Unity Profiler capture"). It does not record data; you capture first. | Only if the user has it enabled |
| Any Unity-Editor MCP server | May drive the Editor (enter Play mode, open windows, read logs). | Only if listed in this session |

If none of the optional tools are present, everything below still works with the Profiler window
and a Development Build.

## 1. Set a target budget

Get the target platform and frame rate from the user or project settings, then convert to ms per frame:

| Target | Budget |
|---|---|
| 30 fps | 33.3 ms |
| 60 fps | 16.7 ms |
| 90 fps | 11.1 ms |
| 120 fps | 8.3 ms |

The main thread, the render thread, and the GPU must each fit inside the budget. On mobile, Unity's
profiling guidance is to leave about 35% of the frame idle to avoid thermal throttling over long play
sessions (at 30 fps that is about 22 ms of work). For hitches, the budget is also a ceiling on any
single frame, not only the average.

## 2. Measure a Development Build on the target device

Unity's own guidance: the best timings come from profiling on the platform you ship on. Play mode
runs in the same process and thread as the Editor, so the Editor's UI, Inspectors, Scene view
rendering, and asset management distort the numbers. Editor-only behaviour also changes allocations
(for example `GetComponent` allocates in the Editor and not in a build).

1. In **File > Build Profiles**, enable **Development Build** and **Autoconnect Profiler**. Leave
   **Deep Profiling Support** off unless step 5 calls for it. Build with `unity-compile-and-test` if
   available, or **Build and Run**.
2. Open **Window > Analysis > Profiler**. With Autoconnect on, it records as soon as the player runs.
   Otherwise pick the player from the Target Selection dropdown next to Record, or choose
   **<Enter IP>** and type the device address.
3. Use a repeatable scenario: a fixed camera path, a replay, or a scripted sequence. Record
   resolution, quality level, and device with every number.
4. Turn off the Profiler modules you do not need (Profiler Modules dropdown); GPU, UI, and Audio
   collection have a large overhead. CPU Usage always records.
5. To keep the Profiler window's own cost out of the Editor, use
   **Window > Analysis > Profiler (Standalone process)**.

Use Play mode profiling only to iterate quickly on a fix you already found on device; then confirm
on the device. When you must profile Play mode, maximize the Game view to get closer to the device
resolution and close other Editor windows. Editor-only work shows up as `EditorLoop`; ignore it.

## 3. Find the bottleneck

Start with the **Highlights** module: red markers are frames where the CPU exceeded the target frame
time, yellow markers are frames where the GPU did. Set the target FPS in the module to your budget.

Then read the **CPU Usage** module in **Timeline** view, which shows the main thread, render thread,
and job worker threads on one time axis. Read markers only as Unity documents them:

| What you see | Meaning | Verdict |
|---|---|---|
| Main thread busy the whole frame, no wait markers | Main thread did not finish in time | Main-thread (CPU) bound |
| `WaitForTargetFPS` on the main thread | Time spent waiting for `Application.targetFrameRate`; the CPU finished early | Not CPU bound; frame is capped. Remove the cap or VSync to measure real cost |
| `Gfx.WaitForPresentOnGfxThread` on the main thread, with `Gfx.PresentFrame` or `<GraphicsAPI>.WaitForLastPresent` on the render thread | Main thread was ready but the render thread was still waiting for the GPU | GPU bound |
| `Gfx.WaitForCommands` on the render thread | Render thread was ready for new commands | Main thread is the bottleneck |
| `Gfx.WaitForRenderThread` on the main thread | Main thread waited for the render thread to drain its commands | Render-thread bound |
| `Gfx.PresentFrame` | Waiting for the GPU to render and present, including VSync | GPU or VSync; disable VSync to tell apart |
| `GC.Collect` in a spike frame | Garbage collection paused execution | GC hitch (see step 6) |
| `JobHandle.Complete`, `WaitForJobGroupID`, `Semaphore.WaitForSignal` | Sync points: a thread waited for jobs or another thread | Job scheduling or dependency problem |
| `Physics.Processing` large | Main thread waited for the physics simulation to finish | Physics bound |

In **Hierarchy** view, sort by **Self ms** to find the most expensive samples on the selected thread,
and read the **GC Alloc** column for per-frame managed allocations. **Inverted Hierarchy** groups by
marker and shows widespread costs spread across many callers.

The URP **Rendering Debugger** (**Window > Analysis > Rendering Debugger**, or LeftCtrl+Backspace /
LeftCtrl+Delete on macOS in a Development Build) has a **Display Stats** panel showing CPU main
thread, CPU render thread, present wait, and GPU frame times, a bottleneck split over the last 60
frames, and per-pass CPU and GPU timings. It is a quick second opinion on device.

## 4. Capture and save evidence

- **Profiler capture**: select a frame range and **Save** from the Profiler toolbar; it writes a
  `.data` file. **Load** reopens it. Keep the baseline `.data` file; the after-fix capture is compared
  against it.
- **Custom markers**: when the Hierarchy shows only a big `BehaviourUpdate` or one script method,
  wrap the suspect code in markers instead of turning on Deep Profiling:

  ```csharp
  using Unity.Profiling;
  static readonly ProfilerMarker k_Pathfind = new ProfilerMarker("AI.Pathfind");
  void Update() { using (k_Pathfind.Auto()) { /* suspect code */ } }
  ```

  `Begin()`/`End()` and `Profiler.BeginSample`/`EndSample` compile out of non-development builds;
  `Auto()` does not fully compile out but its cost there is negligible. Do not put `/` in marker
  names, and do not span `await` or `yield` inside a marker. Markers also work inside Burst code.
- **Deep Profiling** instruments every C# method. Unity warns it is resource-intensive, uses a lot
  of memory, and makes the app run much slower, so its timings are distorted and large projects may
  not run at all. Use it only for a short, targeted capture when markers cannot narrow the cost, and
  never report its absolute ms as the real cost.
- **Allocation call stacks**: enable **Call Stacks** in the Profiler toolbar to record full stacks
  for `GC.Alloc`, `UnsafeUtility.Malloc`, and `JobHandle.Complete` samples, at much less cost than
  Deep Profiling.
- **GPU Usage module**: off by default, not supported with Graphics Jobs, Vulkan, or Metal (use
  Xcode's GPU tools on Apple platforms). For real GPU timing on device, use the platform tools in
  step 5.

## 5. Analyze: which tool answers which question

| Question | Tool |
|---|---|
| CPU or GPU bound, and in which frames? | Highlights module; CPU Usage Timeline wait markers; Rendering Debugger Display Stats |
| Which scripts or systems cost the most? | CPU Usage Hierarchy sorted by Self ms; custom `ProfilerMarker`s |
| Did my change help, over many frames? | Profile Analyzer (**Window > Analysis > Profile Analyzer**) in **Compare** mode: load the baseline and the new capture, compare marker medians and the top markers of both |
| Where do per-frame allocations come from? | GC Alloc column; `GC.Alloc` samples (magenta) in Timeline; Call Stacks toggle |
| What uses memory, and is it leaking? | Memory Profiler package (**Window > Analysis > Memory Profiler**): snapshots from the player, compared |
| Why so many draw calls, why is batching broken? | Rendering module (Batches, SetPass Calls, Triangles, Vertices) → **Open Frame Debugger**; the event's **Batch cause** says why the SRP Batcher did not batch it with the previous one |
| Why is one GPU pass expensive or wrong? | RenderDoc: `renderdoc-gpu-debug` skill, loaded into Unity via **Load RenderDoc** on the Game or Scene view tab, or the `-load-renderdoc` Editor command-line option |
| Real GPU counters on device | Xcode Instruments / Metal Debugger (Apple), Android GPU Inspector, Arm Performance Studio, Snapdragon Profiler (Android), PIX, NVIDIA Nsight Graphics (Windows) |
| What does this sample mean? | Unity AI Assistant, if installed: select a sample in Timeline and choose **Ask Assistant** |

**Memory leak check** (Memory Profiler package's documented workflow): attach to the running player,
load an empty scene and take a snapshot, load the test scene and play partway, unload it or switch to
an empty scene (call `Resources.UnloadUnusedAssets` or load two scenes in a row), take a second
snapshot, then compare the two. Growth in the second snapshot is a leak candidate; the comparison
tables hide unchanged rows by default.

## 6. Common bottlenecks

| Symptom | Likely cause | Next check |
|---|---|---|
| Main thread high, `BehaviourUpdate` dominates | Expensive per-frame script work | Hierarchy by Self ms; add `ProfilerMarker`s; move work off `Update` or spread it over frames |
| Periodic spikes with `GC.Collect` | Managed allocations every frame | GC Alloc column + Call Stacks; remove per-frame allocations. Incremental GC (**Project Settings > Player > Configuration**, on by default in Unity 6) spreads collection over frames but does not make it faster and adds write-barrier cost |
| Render thread high, or `Gfx.WaitForRenderThread` on main | Too many draw calls or state changes | Rendering module Batches and SetPass Calls; Frame Debugger **Batch cause** |
| Many SetPass calls in URP/HDRP | SRP Batcher off or shaders incompatible | Confirm **SRP Batcher** is on in the URP Asset and materials show as SRP Batcher compatible; look for SRP Batch events in the Frame Debugger. Fewer shader variants help |
| Many identical meshes drawn one by one (URP, Forward+) | GPU Resident Drawer not enabled | Set **BatchRendererGroup Variants** to **Keep All**, enable **SRP Batcher**, set **GPU Resident Drawer** to **Instanced Drawing**, renderer on **Forward+**; verify "Hybrid Batch Group" draws in the Frame Debugger. Needs compute shader support; not OpenGL ES |
| Many identical meshes, custom shader, SRP pipeline | GPU instancing not applying | GPU instancing on custom shaders only works when the shader is not SRP Batcher compatible or the SRP Batcher is off; choose one path, measure both |
| GPU bound (`Gfx.WaitForPresentOnGfxThread`) | Fill rate, overdraw, expensive passes or shaders | Lower resolution; if frame time drops a lot, the cost is per-pixel. Rendering Debugger per-pass GPU times; RenderDoc or the platform GPU tool on the worst pass |
| `Physics.Processing` or `Physics.Simulate` large | Too many bodies, contacts, or a small fixed timestep | Physics module; count of `FixedBehaviourUpdate` calls per frame |
| Workers idle while main thread waits in `JobHandle.Complete` | Jobs completed too early or scheduled too late | Timeline worker threads; schedule earlier, complete later. DOTS structure belongs in `unity-ecs-patterns` |
| Burst job slower than expected | Code not Burst-compiled, or hot loop in managed code | Markers inside the job; native profilers (Instruments, Superluminal) on the player build |
| Memory grows across scene loads | Retained assets or references | Memory Profiler two-snapshot comparison (step 5) |
| Hitch when content first appears | Loading or deserialization on the main thread | Look for `SerializedFile::ReadObject` in the spike frame; Asset Loading and File Access modules |

## 7. Fix one thing, then re-measure

1. Change one thing only. Write down what and why.
2. Rebuild the same Development Build configuration (`unity-compile-and-test` if available).
3. Run the same scenario, same scene, device, resolution, and quality level.
4. Capture the same frame range the same way as the baseline and save the `.data` file.
5. Compare before and after in Profile Analyzer (Compare mode), and in the Memory Profiler for
   memory changes.
6. Keep the change only if the number moved by more than run-to-run noise (capture each state at
   least twice to see the noise).

## Report format

Report to the user in numbers:

- Target: platform, device, fps, budget in ms.
- Build: Development Build, Deep Profiling on or off, resolution, quality level, scenario.
- Bottleneck: main thread, render thread, or GPU, with the ms and the marker that showed it.
- Evidence: the capture files (`.data`, memory snapshots) and the top markers with their ms or bytes.
- Change: the one thing changed.
- Result: before → after for the bottleneck, median and a high percentile of frame time, GC Alloc per
  frame or memory delta where relevant, and spike count if hitches were the issue.
- Next: the next biggest item, or "within budget".
