# Unity 6 profiling tools: exact paths and sources

Only paths, settings, and APIs confirmed in Unity's documentation. Manual links use the 6000.2
Manual; swap the version segment for the project's Unity version.

## Build and connect

| Action | Where |
|---|---|
| Development Build, Autoconnect Profiler, Deep Profiling Support | **File > Build Profiles**, select the platform (the last two need Development Build) |
| Open the Profiler | **Window > Analysis > Profiler** |
| Profiler in its own process | **Window > Analysis > Profiler (Standalone process)** |
| Attach to a running player | Target Selection dropdown next to Record → the player, or **<Enter IP>** (Web needs Autoconnect; no IP connection) |
| Keep collecting when the app loses focus | **Edit > Project Settings > Player**, Resolution and Presentation → **Run In Background** |
| Toggle modules | Profiler Modules dropdown in the Profiler window |

Profiler toolbar: Record, Clear, Clear on Play, **Deep Profile**, **Call Stacks** (full stacks for
`GC.Alloc`, `UnsafeUtility.Malloc`, `JobHandle.Complete`), **Load** / **Save** (`.data` files).

Modules: Highlights, CPU Usage, GPU Usage, Rendering, Memory, Audio, Video, Physics, Physics 2D, UI,
Realtime GI, Virtual Texturing, File Access, Asset Loading.

Sources:
- https://docs.unity3d.com/6000.2/Documentation/Manual/profiling-target-device.html
- https://docs.unity3d.com/6000.2/Documentation/Manual/profiling-collect-data-introduction.html
- https://docs.unity3d.com/6000.2/Documentation/Manual/profiling-play-mode.html
- https://docs.unity3d.com/6000.2/Documentation/Manual/profiler-build-settings-reference.html
- https://docs.unity3d.com/6000.2/Documentation/Manual/ProfilerWindow.html
- https://docs.unity3d.com/6000.2/Documentation/Manual/profiler-modules-activate.html
- https://docs.unity3d.com/6000.3/Documentation/Manual/profiler-standalone-process.html
- https://docs.unity3d.com/6000.2/Documentation/Manual/ProfilerHighlights.html

## Markers

Documented meanings are in the Profiler markers reference:
https://docs.unity3d.com/6000.2/Documentation/Manual/profiler-markers.html

CPU-bound vs GPU-bound reading (`Gfx.WaitForPresentOnGfxThread` on main plus `Gfx.PresentFrame` or
`<GraphicsAPI>.WaitForLastPresent` on render = GPU bound) and the mobile 35% idle guideline come from
Unity's profiling best-practices page:
https://unity.com/how-to/best-practices-for-profiling-game-performance

## Custom markers

```csharp
using Unity.Profiling;

static readonly ProfilerMarker k_Marker = new ProfilerMarker("MySystem.Work");
static readonly ProfilerMarker<int> k_Prepare =
    new ProfilerMarker<int>("MySystem.Prepare", "Objects Count");

k_Marker.Begin(); /* ... */ k_Marker.End();
using (k_Marker.Auto()) { /* ... */ }
k_Prepare.Begin(objectsCount); /* ... */ k_Prepare.End();
```

Older API: `UnityEngine.Profiling.Profiler.BeginSample("label")` / `Profiler.EndSample()`, compiled
out of non-development builds.

Sources:
- https://docs.unity3d.com/6000.2/Documentation/Manual/profiler-add-markers-code.html
- https://docs.unity3d.com/6000.2/Documentation/Manual/profiler-adding-information-code-intro.html
- https://docs.unity3d.com/ScriptReference/Profiling.Profiler.BeginSample.html
- https://docs.unity3d.com/Packages/com.unity.burst@1.8/manual/debugging-profiling-tools.html (markers in Burst code; Instruments or Superluminal on the player build)

## Deep Profiling and GC

- Deep Profiling: https://docs.unity3d.com/6000.2/Documentation/Manual/profiler-deep-profiling.html
- Tracking GC allocations: https://docs.unity3d.com/6000.2/Documentation/Manual/performance-track-garbage-collection.html
- Incremental GC (**Project Settings > Player > Configuration**; not supported on Web):
  https://docs.unity3d.com/6000.2/Documentation/Manual/performance-incremental-garbage-collection.html

## Profile Analyzer (`com.unity.performance.profile-analyzer`)

**Window > Analysis > Profile Analyzer**. **Single** mode analyzes one data set; **Compare** mode
loads two. **Pull Data** takes the frames currently in the Profiler; drag on the frame chart to limit
the range. **Save** writes a `.pdata` file, which does not contain the original Profiler data, so keep
the `.data` file beside it. The Compare view's **Ratio** dropdown switches between **Normalised** and
**Longest**.

- https://docs.unity3d.com/Packages/com.unity.performance.profile-analyzer@1.2/manual/index.html
- https://docs.unity3d.com/Packages/com.unity.performance.profile-analyzer@1.2/manual/profile-analyzer-window.html

## Memory Profiler (`com.unity.memoryprofiler`)

**Window > Analysis > Memory Profiler**. Attach to a running player from the Attach to Player
dropdown and capture snapshots there; Unity recommends target-platform captures over Editor ones.
Compare mode shows both values and the difference per row; **Show Unchanged** reveals identical rows.

- https://docs.unity3d.com/Packages/com.unity.memoryprofiler@1.1/manual/memory-profiler-introduction.html
- https://docs.unity3d.com/Packages/com.unity.memoryprofiler@1.1/manual/find-memory-leaks.html
- https://docs.unity3d.com/Packages/com.unity.memoryprofiler@1.1/manual/snapshots-comparison.html

## Frame Debugger

**Window > Analysis > Frame Debugger**. Choose the target (Editor or a Development Build player that
supports multithreaded rendering; not Web), then **Enable**. The event's **Batch cause** explains why
the SRP Batcher did not batch it with the previous event.

- https://docs.unity3d.com/6000.2/Documentation/Manual/FrameDebugger.html
- https://docs.unity3d.com/6000.3/Documentation/Manual/FrameDebugger-attach.html
- https://docs.unity3d.com/6000.2/Documentation/Manual/frame-debugger-window-event-information.html

## Rendering Debugger (URP)

Editor: **Window > Analysis > Rendering Debugger**. Development Build player: LeftCtrl+Backspace
(LeftCtrl+Delete on macOS), L3+R3 on console, three-finger double tap on mobile. Only Display Stats
works in a player unless **Strip Debug Variants** is off in **Project Settings > Graphics > URP Global
Settings**. HDRP has its own Rendering Debugger; check the HDRP docs for its panels.

- https://docs.unity3d.com/6000.2/Documentation/Manual/urp/features/rendering-debugger-use.html
- https://docs.unity3d.com/6000.2/Documentation/Manual/urp/features/rendering-debugger-reference.html

## Batching fixes

- SRP Batcher: https://docs.unity3d.com/6000.2/Documentation/Manual/SRPBatcher.html
- GPU Resident Drawer (URP): https://docs.unity3d.com/6000.2/Documentation/Manual/urp/gpu-resident-drawer.html
- GPU instancing: https://docs.unity3d.com/6000.2/Documentation/Manual/GPUInstancing.html

## RenderDoc and platform tools

RenderDoc: right-click the Game or Scene view tab → **Load RenderDoc**, or start the Editor with
`-load-renderdoc`. Loading reloads the graphics device, so save first. A capture button then appears
on the Game and Scene view toolbars. Needs RenderDoc 0.26 or later and a platform and API RenderDoc
supports. For D3D11 shader debug symbols add `#pragma enable_d3d11_debug_symbols`.

- https://docs.unity3d.com/6000.2/Documentation/Manual/RenderDocIntegration.html
- Platform tool list (Xcode Instruments, Metal Debugger, Android GPU Inspector, Arm Performance
  Studio, Snapdragon Profiler, PIX, NVIDIA Nsight Graphics, and others):
  https://docs.unity3d.com/6000.2/Documentation/Manual/performance-profiling-tools.html
- GPU Usage module support table: https://docs.unity3d.com/6000.2/Documentation/Manual/ProfilerGPU.html

## Unity AI Assistant

Open the Profiler, load or record a session, switch to a supported view such as **Timeline**, select
a sample or frame, choose **Ask Assistant**. It analyzes saved or active sessions and does not record.

- https://docs.unity3d.com/Packages/com.unity.ai.assistant@2.7/manual/analyze/use-profiler.html
