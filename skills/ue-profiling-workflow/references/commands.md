# UE 5.8 profiling command cheat-sheet

Only commands and flags confirmed in Epic's documentation. Console commands are typed in the in-game
console (the ` key). Command-line flags go after the executable or project path.

## Trace (Unreal Insights)

Command line:

| Flag | Effect |
|---|---|
| `-trace` / `-trace=<channel,channel,...>` | Enable tracing with the given channels or channel sets |
| `-trace=default` | Default set: Cpu, Gpu, Frame, Log, Bookmark (plus a few others such as Screenshot) |
| `-trace=default,memory,metadata,assetmetadata` | Default set plus memory data for Memory Insights |
| `-tracehost=<ip>` | Send the trace to a trace server at that address (defaults to local host) |
| `-tracefile` / `-tracefile=<path>` | Write the trace straight to a file |
| `-tracetailmb=<N>` | Size of the in-memory tail buffer used by snapshots |
| `-statnamedevents` | Emit stat named events as extra CPU timers (adds overhead) |

Other channels named in the Insights reference, useful for specific questions: `Counter`,
`LoadTime`, `AssetLoadTime`, `Task`, `ContextSwitch`, `StackSampling`, `RDG`, `RenderCommands`,
`RHICommands`, `Stats`, `Net`, `Animation`, `Physics`, `Niagara`, `Object`, `MemAlloc`, `MemTag`,
`Callstack`, `Module`.

Console:

| Command | Effect |
|---|---|
| `Trace.File [file] [channels]` | Start tracing to a file (no path → `<Project>/Saved/Profiling`) |
| `Trace.Send <host> [channels]` | Start tracing to a trace server |
| `Trace.Start [channels]` | Deprecated; use `Trace.File` |
| `Trace.Stop` | Stop tracing |
| `Trace.Status` | Print connection and enabled channels |
| `Trace.Enable <channels>` / `Trace.Disable <channels>` | Toggle channels while tracing |
| `Trace.Pause` / `Trace.Resume` | Pause and resume all channels |
| `Trace.Bookmark <name>` | Vertical marker in Timing Insights |
| `Trace.Screenshot <name> <bIncludeUI>` | Screenshot stored in the trace |
| `Trace.SnapshotFile [file]` | Write the in-memory trace buffer to a file without stopping |
| `Trace.SnapshotSend <host> <port>` | Send that snapshot to a server |

Unreal Insights ships as `Engine/Binaries/<Platform>/UnrealInsights[.exe]`. Trace files are `.utrace`.

## Stat commands

| Command | Shows |
|---|---|
| `stat fps` | Frames per second |
| `stat unit` | Frame, Game, Draw, RHIT, GPU times (and DynRes if enabled) |
| `stat unitgraph` | `stat unit` values as a graph over time |
| `stat game` | Gameplay tick costs |
| `stat gpu` | Per-pass GPU timings for the frame |
| `stat rhi` | RHI memory and performance statistics |
| `stat SceneRendering` | General rendering statistics |
| `stat InitViews` | Visibility culling time and effectiveness |
| `stat memory` | Memory used by engine subsystems |
| `stat streaming` | Streaming asset statistics |
| `stat PSOPrecache` | PSO precaching statistics (needs `r.PSOPrecache.Validation` 1 or 2) |

## GPU

| Command | Effect |
|---|---|
| `ProfileGPU` (Ctrl+Shift+Comma) | One-frame GPU pass breakdown in the GPU Visualizer and the log |
| `r.Lumen.AsyncCompute 0` | Run Lumen synchronously so its passes can be measured alone |
| `r.Shadow.Virtual.Visualize cache` | Show Virtual Shadow Map cached (green) vs uncached (red) pages |
| `r.ShaderPrintEnable 1` then `r.Shadow.Virtual.Stats 1` | On-screen VSM stats including invalidated pages |
| `-AttachRenderDoc` | Attach RenderDoc at launch (the RenderDoc plugin is included and enabled by default) |

## CSV profiler

| Command | Effect |
|---|---|
| `-csvCaptureFrames=N` | Capture N frames from startup |
| `csvprofile start` / `csvprofile stop` | Start and stop a capture at runtime |
| `csvprofile frames=N` | Capture a fixed number of frames |
| `-csvcategories="A,B"` | Limit capture to these categories |
| `-csvGpuStats` | Include GPU stats (off by default, adds overhead) |
| `CsvCategory` | Toggle whether a category is included in captures |

Output: `<Project>/Saved/Profiling/CSV`.

## Memory and objects

| Command | Effect |
|---|---|
| `memreport -full` | Text memory snapshot in `Saved/Profiling/Memreports` |
| `obj list` | List UObjects currently in memory |
| `DumpLLM` | Current and peak sizes of tracked LLM tags |
| `gc.DumpMemoryStats` | Garbage-collector memory usage |
| `dumpticks` | Log every registered tick function |

## PSO precaching

| Variable | Meaning |
|---|---|
| `r.PSOPrecaching` | Global switch for PSO precaching (on by default) |
| `r.PSOPrecache.Validation` | 0 off, 1 lightweight, 2 detailed tracking |
| `r.PSO.RuntimeCreationHitchThreshold` | ms above which a runtime PSO compile counts as a hitch (default 20) |
| `r.PSOPrecache.GlobalShaders` | Precache global shader PSOs at startup (on by default) |
| `r.PSOPrecache.ProxyCreationWhenPSOReady` | Delay proxy creation until its PSOs are compiled (on by default) |

## Sources

- Unreal Insights Reference, Trace, Trace Quick Start Guide, Memory Insights
- Stat Commands; Console Commands Reference; Build Configurations Reference
- PSO Precaching; Virtual Shadow Maps; Lumen Performance Guide; Using RenderDoc with Unreal Engine
- CSV Profiler (Epic's page is the 4.27 version; `CsvProfile` and `CsvCategory` are listed in the 5.8 console command reference)
