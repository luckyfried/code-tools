# Cheat sheet: viewmodes, show flags, console variables (UE 5.8)

Only names that appear in Epic's UE 5.8 documentation are listed. "Config" means the value
must go in an .ini file (for example `DefaultEngine.ini` or a Device Profile) rather than being
typed at runtime.

## Viewport menus

| Where | Entry | Use it for |
|---|---|---|
| View Modes > Lumen | Overview | Three Lumen visualizations as tiles over the scene |
| View Modes > Lumen | Lumen Scene | Lumen's version of the scene (Surface Cache or HWRT) |
| View Modes > Lumen | Surface Cache | Like Lumen Scene; uncovered areas pink |
| View Modes > Lumen | Geometry Normals | Global distance field (SWRT) or Nanite fallback (HWRT) problems |
| View Modes > Lumen | Reflection View | The scene as Lumen Reflections see it |
| Show > Visualize | Mesh Distance Fields | Per-mesh distance field quality, thin walls |
| Show > Visualize | Global Distance Field | Merged distance field used after the first 2 m |
| Show > Lumen | Screen Traces (untick) | See the Lumen Scene without screen-trace help |
| Show > Advanced | Nanite Meshes | Nanite fallback meshes in the level viewport |
| View Modes > Nanite Visualization | Overview, Mask, Triangles, Patches, Clusters, Primitives, Instances, Overdraw, Lightmap UV, Evaluate WPO, Pixel Programmable, Tessellation, Raster Bins, Shading Bins | Nanite coverage, overdraw, WPO use |
| Show > Nanite | Streaming Geometry | Nanite streaming (off = only always-resident quality) |
| Static Mesh Editor: Show | Nanite Fallback (Ctrl+N) | Toggle full Nanite mesh vs fallback |
| View Modes > Virtual Shadow Map | Shadow Mask, Clipmap/Mip Level, Virtual Page, Cached Page, Nanite Overdraw, Shadow Casters | VSM pages and invalidation |
| Show > Visualize | HDR (Eye Adaptation) | Exposure histogram, lux/nit meter |
| Show > Visualization | Local Exposure | Where local exposure is applied |
| View Mode dropdown | Exposure override (untick Game Settings / Auto) | Fixed EV100 while lighting in the editor |
| Settings | Viewport Scalability Settings | Preview scalability levels in the editor |

## Lumen

| Command | Effect |
|---|---|
| `sg.GlobalIlluminationQuality` | GI scalability group (`1` Medium, `2` High) |
| `sg.ReflectionQuality` | Reflection scalability group (`1` Medium: Lumen Reflections off, SSR used) |
| `r.Lumen.Visualize.CardPlacement 1` | Show Lumen card placement |
| `r.Lumen.Reflections.MaxBounces` | Overrides Max Reflection Bounces, up to 64 |
| `r.Lumen.Reflections.Allow=0` | Replace Lumen Reflections with SSR |
| `r.Lumen.Reflections.MaxRoughnessToTraceClamp` | Clamp Max Roughness To Trace from scalability |
| `r.Lumen.Reflections.DownsampleFactor` | Reflection resolution (1 or 2) |
| `r.Lumen.FinalGatherMethod 0` | Irradiance Final Gather (used by Medium GI) |
| `r.LumenScene.Lighting.AsyncCompute=1` | Run Lumen Scene lighting on async compute |
| `r.LumenScene.FarField=1` | Config. HWRT Far Field traces; needs World Partition HLOD1 |
| `r.LumenScene.FarField.MaxtraceDistance` | Far Field range (default 1 km) |
| `r.RayTracing.Culling.Radius` | Ray tracing culling radius (keep it compatible with Far Field) |
| `r.DistanceFields.SupportEvenIfHardwareRayTracingSupported=0` | Config. Skip distance fields when HWRT is available |
| `r.DistanceFields.LogAtlasStats 1` | Log distance field atlas stats |
| `r.MeshCardRepresentation.SkeletalMesh` | Surface Cache for skeletal meshes (on by default) |

## Nanite

| Command | Effect |
|---|---|
| `r.Nanite 0` | Turn Nanite off (emulate non-Nanite platforms) |
| `r.Nanite.ProxyRenderMode` | 0 draw fallbacks (default), 1 draw nothing, 2 like 1 but Static Mesh Editor fallback view still works |
| `r.Nanite.Visualize.Advanced 1` | Extra programmer visualizations |
| `NaniteStats` | Culling stats overlay; `NaniteStats List`, `NaniteStats VirtualShadowMaps` |
| `r.Nanite.Streaming.StreamingPoolSize` | Streaming pool size |
| `r.Nanite.MaxCandidateClusters`, `r.Nanite.MaxVisibleClusters` | Config. Buffer sizes; too small shows as missing or blinking geometry |
| `r.Nanite.AllowTessellation=1` | Config. Allow Nanite tessellation (Experimental) |
| `r.Nanite.Tessellation=1` | Toggle Nanite tessellation at runtime |
| `r.RayTracing.Nanite.Mode 1` | Experimental native ray tracing of Nanite meshes |
| `r.Nanite.VSMInvalidateOnLODDelta` | Invalidate VSM pages when Nanite LOD streaming changes |
| `r.Skinning.DefaultAnimationMinScreenSize` | Global default for Animation Min Screen Size (Nanite Skinning) |

## Virtual Shadow Maps

| Command | Effect |
|---|---|
| `r.Shadow.Virtual.Enable` | Opt in to VSMs (pre-5.0 projects) |
| `r.Shadow.Virtual.Cache 0` | Disable page caching (debugging only) |
| `r.Shadow.Virtual.Visualize <mode>` | `mask`, `mip`, `vpage`, `cache`, `naniteoverdraw`, `raycount`, `clipmapvirtual`, `none` |
| `ShowFlag.VisualizeVirtualShadowMap` | Enable VSM visualization when a mode is set |
| `ShowFlag.VisualizeShadowCasters` | Shadow Casters visualization |
| `r.Shadow.Virtual.Visualize.Layout` | 0 full screen, 1 thumbnail, 2 split screen |
| `r.Shadow.Virtual.Visualize.LightName <name>` | Visualize one light (partial names match) |
| `r.Shadow.Virtual.Visualize.DumpLightNames` | List lights with VSMs |
| `r.Shadow.Virtual.Visualize.NextLight` / `PrevLight` | Step through lights |
| `r.Shadow.Virtual.Visualize.ShadowCachedPagesOnly` | Show only cached pages |
| `r.ShaderPrintEnable 1`, then `r.Shadow.Virtual.Stats 1` | On-screen VSM stats (`basic` for page stats only) |
| `r.Shadow.Virtual.MaxPhysicalPages` | Page pool size (overflow = checkerboard or missing shadows) |
| `r.Shadow.Virtual.NormalBias` | Default 0.5; last resort for shadow terminator artifacts |
| `r.Shadow.Virtual.SMRT.RayCountLocal` / `RayCountDirectional` | Soft shadow ray count; 0 = hard shadows |
| `r.Shadow.Virtual.SMRT.SamplesPerRayLocal` / `SamplesPerRayDirectional` | Samples per ray; 4–8 works well |
| `r.Shadow.Virtual.ResolutionLodBiasDirectional` / `ResolutionLodBiasLocal` | Resolution bias |
| `r.Shadow.Virtual.ResolutionLodBiasDirectionalMoving` / `ResolutionLodBiasLocalMoving` | Resolution bias for moving geometry |
| `r.Shadow.Virtual.MarkCoarsePagesLocal` / `MarkCoarsePagesDirectional` | Toggle coarse pages |
| `r.Shadow.Virtual.MaxDOFResolutionBias` | Lower shadow resolution in out-of-focus areas (cinematics) |
| `r.Shadow.Virtual.UseFarShadowCulling 0` | Make non-Nanite geometry render to VSM at any distance |
| `r.Shadow.RadiusThreshold` | CPU culling of small non-Nanite casters |

## Exposure and sky

| Command | Effect |
|---|---|
| `r.EyeAdaptation.VisualizeDebugType 1` | Histogram debug colors (needs HDR (Eye Adaptation) on) |
| `r.EyeAdaptation.ExponentialTransitionDistance` | Where adaptation switches from linear to exponential (default 1.5 stops) |
| `r.SkyAtmosphere.FastSkyViewLUT.SampleCountMax` | Fix texels visible on the sky |
| `r.SkyAtmosphere.AerialPerspectiveLUT.DepthResolution` | Fix texels on fogged objects |
