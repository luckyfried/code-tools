---
name: ue-lighting-lumen-nanite
description: Use when lighting a scene in Unreal Engine 5.8 — setting up Lumen, Nanite, or Virtual Shadow Maps, choosing physical light values and exposure, building an outdoor sky/atmosphere/cloud/fog rig, or diagnosing lighting artifacts such as light leaking, noise, emissive not lighting, or shadow cost.
---

# UE 5.8 lighting: Lumen, Nanite, Virtual Shadow Maps, exposure

For environment artists, cinematic lighters, and tech artists working in Unreal Engine 5.8.
Everything below is taken from Epic's UE 5.8 documentation. Setting names are shown exactly as
they appear in the editor. For console variables, show flags, and viewmodes in one place, see
`references/cvars-and-viewmodes.md`.

Performance profiling (GPU captures, `stat` commands, Unreal Insights, budgets) is out of scope.
Use the `ue-profiling-workflow` skill for that.

## 1. Project settings that must be on

All of these are in **Project Settings > Engine > Rendering**.

| Setting | Value | Notes |
|---|---|---|
| Dynamic Global Illumination Method | Lumen | New projects have this on by default. Projects converted from UE4 do not. |
| Reflection Method | Lumen | Lumen Reflections replace Screen Space Reflections. |
| Generate Mesh Distance Fields | On | Turned on automatically when Lumen is enabled. Required for Software Ray Tracing. Needs an editor restart. Adds build time, memory, and disk size. |
| Shadow Map Method (Shadows section) | Virtual Shadow Maps | Default in new projects. Pre-5.0 projects must opt in (or use `r.Shadow.Virtual.Enable`). |
| Support Hardware Ray Tracing | On only if you want HWRT | Changing it requires an engine restart. |
| Use Hardware Ray Tracing when available | On only if you want HWRT | Falls back to Software Ray Tracing where HWRT is not supported. |
| Allow Static Lighting | Off for fully dynamic projects | Lumen hides lightmaps anyway. Turning this off saves shader permutations and lets Material Ambient Occlusion work with Lumen GI. |

Other facts that follow from turning Lumen on:
- Precomputed static lighting is disabled and lightmaps are hidden. Lumen GI cannot be combined
  with lightmaps. Lumen Reflections alone can be used with baked lighting, but that needs Lumen
  Hardware Ray Tracing.
- Lights with **Static** mobility do not contribute. Use Stationary or Movable.
- Lumen does not work with Forward Shading, does not support VR, and does not run on PS4/Xbox One.
- Lumen GI replaces Distance Field Ambient Occlusion.

### Software vs hardware ray tracing

| | Software Ray Tracing (default) | Hardware Ray Tracing |
|---|---|---|
| Traces against | Mesh Distance Fields for the first 2 m, then the Global Distance Field | Actual triangles |
| Hardware | DirectX 12 with Shader Model 6; NVIDIA GTX 1070 or higher | Windows 10+ with DX12 or Linux with Vulkan; NVIDIA RTX 2000+ or AMD RX 6000+; PS5; Xbox Series S/X; Switch 2 |
| Geometry in Lumen Scene | Static Meshes, Instanced and Hierarchical Instanced Static Meshes, Landscape. No skinned meshes. | Wider range, including skinned meshes |
| World Position Offset | Not supported | Not listed as a limitation |
| Reflection lighting | Surface Cache only | Surface Cache, or Hit Lighting for Reflections |
| Best at | Scenes with many overlapping instances (the only performant option there) | High quality mirror reflections (the only way to get them) |
| Weak at | Thin walls, large single meshes, kitbashed overlap with Detail Tracing | Large scenes with many overlapping meshes; skinned meshes cost acceleration-structure updates every frame; significant update cost above ~100,000 instances |

Use HWRT when you need mirror-quality reflections, skinned meshes in GI/reflections, or accurate
thin geometry, and the target hardware supports it. Use Software Ray Tracing for broad hardware
support and heavy instance overlap.

**Software Ray Tracing Mode** (project setting): **Global Tracing** (engine default, fastest,
Global Distance Field only) or **Detail Tracing** (per-mesh distance fields, highest quality,
extremely costly in kitbashed levels).

To get the best reflections with HWRT, set **Ray Lighting Mode** to **Hit Lighting for
Reflections**, either in Project Settings (whole project) or in a Post Process Volume (one shot
or area). The default is Surface Cache, which is much cheaper.

If you ship HWRT but want a Software Ray Tracing fallback without paying for both representations
at once, add `r.DistanceFields.SupportEvenIfHardwareRayTracingSupported=0` to
`DefaultEngine.ini`. With that set, *Use Hardware Ray Tracing when available* can no longer be
toggled at runtime.

## 2. Lumen quality and scalability

### Scalability levels (Global Illumination and Reflections groups)

| Level | Target |
|---|---|
| Cinematic | Movie Render Queue |
| Epic | 30 fps console budget (about 8 ms for GI and reflections at 1080p) |
| High | 60 fps console budget (about 4 ms) |
| Medium | 60 fps on Switch 2 and medium-spec PC. GI uses the cheaper Irradiance Final Gather; Lumen Reflections turn off and SSR is used on smooth surfaces. |
| Low | Lumen disabled |

Set them in the editor under the viewport **Settings > Viewport Scalability Settings**, or with
`sg.GlobalIlluminationQuality` and `sg.ReflectionQuality` (`1` = Medium, `2` = High). Consoles
target 30 fps by default; to target 60 fps set both to `2` in the console Device Profile.

### Post Process Volume: Global Illumination > Lumen Global Illumination

| Setting | What it does |
|---|---|
| Lumen Scene Lighting Quality | Fidelity of the Lumen Scene; most visible in reflections. |
| Lumen Scene Detail | Size of instances kept in the Lumen Scene. Higher keeps small objects. |
| Lumen Scene View Distance | Range Lumen maintains for tracing. Software RT covers 200 m by default, up to 800 m. |
| Final Gather Quality | GI quality and noise. |
| Screen Traces | Traces the screen first. Improves quality but hides Lumen-Scene-only changes. |
| Max Trace Distance | Too small leaks light into large spaces such as caves. |
| Scene Capture Cache Resolution | Surface Cache resolution scale; defaults to 0.5. Set on Scene Capture components. |
| Lumen Scene Lighting Update Speed (Advanced) | How fast lighting changes propagate in the Lumen Scene. |
| Final Gather Lighting Update Speed (Advanced) | How fast lighting changes propagate in the final gather. |
| Diffuse Color Boost (Advanced) | Art knob; above 1 is not physically correct. Keep below 2. |
| Skylight Leaking (Advanced) | Art knob; fraction of sky light allowed to leak so interiors are not fully black. |
| Full Skylight Leaking Distance (Advanced) | Small values give flat leaking; large values look like AO. |

### Post Process Volume: Reflections > Lumen Reflections

Quality; Ray Lighting Mode (HWRT only); Screen Traces; High Quality Translucency Reflections
(also needs the matching project setting); Max Roughness To Trace (pixels rougher than this, 0.4
by default, get reflections from Lumen GI instead of dedicated rays); Max Reflection Bounces
(default 1, up to 8; `r.Lumen.Reflections.MaxBounces` allows up to 64); Max Refraction Bounces.

Every quality control above costs GPU time when raised. Raise them per shot or per area with a
Post Process Volume, and reset temporary increases (such as update speed) afterward.

## 3. Common Lumen artifacts and fixes

| Symptom | Cause | Fix |
|---|---|---|
| Light leaking through walls | Walls thinner than distance fields can represent; one-sided meshes seen from behind | Keep walls at least **10 cm** thick. Use closed geometry. Make walls, floors, and ceilings separate meshes. Check with Show > Visualize > Mesh Distance Fields. Raise **Distance Field Resolution Scale** (Static Mesh Editor > Build Settings) or **Distance Field Voxel Density** (project-wide; rebuilds all distance fields). |
| Leaking in caves and large enclosed areas | Rays stop before reaching an occluder | Raise **Lumen Scene Detail** and **Max Trace Distance** in the Post Process Volume. |
| Sky occlusion/GI missing far away | Lumen Scene only covers 200 m by default (Software RT) | Raise **Lumen Scene View Distance**. With HWRT, Far Field (`r.LumenScene.FarField=1` in `DefaultEngine.ini`, needs World Partition HLOD1) extends to 1 km. |
| Scaled-up mesh leaks or self-shadows | Distance field resolution is set from the imported scale | Import at the intended scale or raise its Distance Field Resolution Scale. |
| Small emissive meshes light the scene inconsistently | Small objects are culled from the Lumen Scene, leaving only screen traces | Enable **Emissive Light Source** on the placed instance's Details panel. |
| Noise from emissive surfaces | Emissive areas that are too small and too bright are hard for the final gather | Light key sources with placed lights rather than emissive. Make emissive areas larger or dimmer. |
| General GI noise | Low final gather quality | Raise **Final Gather Quality**. |
| Splotchy mirror reflections indoors | Multi-bounce GI uses low quality | Raise **Lumen Scene Lighting Quality**. |
| Small meshes black in mirror reflections | Culled from Lumen Scene | Raise **Lumen Scene Detail**. |
| Pink areas in Surface Cache view mode | Mesh too complex for its cards (12 by default) | Raise **Max Lumen Mesh Cards** in the Static Mesh settings, or split the mesh. |
| Lighting fades slowly after a big change | Lumen caches lighting | Raise **Final Gather Lighting Update Speed** (and Lumen Scene Lighting Update Speed), then set them back. |
| Specular highlights missing in reflections | Reflections lit from Surface Cache | Set **Ray Lighting Mode** to **Hit Lighting for Reflections** (HWRT). |
| Self-intersection on Nanite meshes with HWRT | Mismatch between Nanite mesh and its fallback mesh | Adjust the mesh's **Fallback Relative Error** (see section 5). |
| One mesh pollutes indirect lighting | — | Remove it from the Lumen Scene: untick **Affect Distance Field Lighting** (Software RT) or **Visible in Ray Tracing** (HWRT). |
| Foliage missing from Software RT Lumen | Foliage types are excluded by default | Enable **Affect Distance Field Lighting** per foliage type in the Foliage Tool. Only for types that need it; thousands of instances (grass) overflow the culling buffer. |
| WPO-animated meshes look wrong in GI | Software RT ignores World Position Offset | Accept it, or use HWRT. |
| Material override causes GI mismatch | Distance fields are built from the asset's material, not the component override | Avoid overrides that change Blend Mode or Two Sided. |

## 4. Physical light units and exposure

### Units per light type

| Light | Unit |
|---|---|
| Directional Light | Lux (lx), direct normal illuminance |
| Sky Light | cd/m² (pixel value × intensity) |
| Emissive materials | cd/m² |
| Point, Spot, Rect | Candela, Lumen, or Unitless. Candela and Lumen need **Inverse Squared Falloff** on. The project default is in Project Settings > Rendering > Default Settings. |

Conversions from Epic's docs: 1 cd = 625 unitless; 1 cd = 1 lm/sr; 1000 cd measures 1000 lux at
1 m. Candela is independent of cone angle. Lumens spread over the light's solid angle, so a
narrower Spot Light cone gives a brighter surface. Keep child lights (Blueprints, defaults) on the
same unit as their parent.

### Real-world values Epic gives

These are the only reference values in Epic's docs; they come from the Sky Atmosphere page.

| Source | Value |
|---|---|
| Sun at zenith (Directional Light) | 120000 lux, angular diameter 0.545° |
| Total on a white diffuse surface, sun at zenith | about 150000 lux, sky about 20% of that |
| Moon at zenith | 0.26 lux, angular diameter 0.568° |
| Sky Atmosphere Multiscattering | 1 |
| Earth albedo | 0.4 (linear), the Sky Atmosphere default |

Measure illuminance and luminance with **Show > Visualize > HDR (Eye Adaptation)**, which has a
lux/nit meter. Disable Ambient Occlusion while measuring.

### Exposure (Post Process Volume > Lens > Exposure)

**Metering Mode**:
- **Auto Exposure Histogram** (default): 64-bin histogram. Starting ranges: Low Percent 70–80,
  High Percent 80–95.
- **Auto Exposure Basic**: faster, fewer controls.
- **Manual**: fixed exposure. With **Apply Physical Camera Exposure** on, EV100 comes from the
  camera's Aperture, Shutter Speed, and ISO: `EV100 = log2(Aperture² / ShutterSpeed × 100 / ISO)`.
  With it off, the camera uses ISO 100, f/1.0, 1 s. Then `Exposure = 1 / 2^(EV100 + Exposure Compensation)`
  and pixel brightness = Exposure × luminance (cd/m²).

Use Manual for cinematics and for lighting to fixed physical values, so shots do not drift. Use
auto exposure for gameplay that moves between very different light levels, clamped with Min/Max.

Setup for physical values:
1. Turn on **Extend default luminance range in Auto Exposure settings** (Project Settings >
   Rendering > Default Settings) at the start of the project. Min/Max Brightness become
   **Min EV100 / Max EV100** and the histogram limits become EV100. Turning it on later breaks
   existing exposure setups.
2. Place an unbound Post Process Volume. Default post settings apply even with no volume.
3. If the image goes white after adding a bright light, raise **Max EV100** and **Histogram Max EV100**.
4. If reflective surfaces show black patches, the scene color buffer is overflowing: enable
   **Apply Pre-exposure before writing to the scene color** or lower light brightness.
5. If auto exposure flickers, narrow the histogram range around what the scene uses (read it from
   HDR (Eye Adaptation)).
6. Set up **Local Exposure** (Lens > Local Exposure) whenever you use Lumen GI; Epic says it
   should always be set up with Lumen. Check it with the Local Exposure visualization (viewport Show > Visualization menu).

To lock exposure while lighting in the editor, use the viewport's exposure override in the View
Mode dropdown: untick Game Settings / Auto and use the EV100 slider.

## 5. Outdoor rig: Sky Atmosphere, Sky Light, Volumetric Clouds, Height Fog

1. Place a **Sky Atmosphere**.
2. Place a **Directional Light** and enable **Atmosphere Sun Light**. For sun and moon, set
   **Atmosphere Sun Light Index** 0 (sun) and 1 (moon). Move them in the viewport with
   Right Ctrl + L (index 0) and Right Ctrl + Shift + L (index 1).
3. Place a **Sky Light**, mobility Stationary or Movable, and enable **Real Time Capture**. It
   needs a Sky Atmosphere in the level. It captures Sky Atmosphere, Volumetric Clouds,
   Exponential Height Fog, and sky dome meshes whose unlit material is tagged Is Sky. It does not
   capture Volumetric Fog. Reflection quality is set by **Cubemap Resolution** (128 default).
   Avoid the `RecaptureSky` Blueprint call at runtime; it takes at least 120 ms.
4. Place a **Volumetric Cloud**. Enable **Cast Cloud Shadows** on the atmosphere light for cloud
   shadows and light shafts. Enable **Cloud Ambient Occlusion** on the Sky Light for cloud
   ambient shadowing. For ground-level views, Beer Shadow Maps are usually enough and cheaper
   than ray-marched volume shadows (toggle **Ray March Volume Shadow** on the cloud material's
   Volumetric Advanced Material Output). For games, one multiple-scattering octave is recommended.
5. Place an **Exponential Height Fog**. For the atmosphere to affect it, enable **Support Sky
   Atmosphere Affecting Height Fog** in Project Settings > Rendering. Height fog also fills the
   dark lower hemisphere. Enable **Volumetric Fog** on it if you need light shafts in fog; Lumen
   provides lower-quality GI for volumetric fog.
6. With Lumen, sky lighting and sky shadowing are solved in the final gather, so interiors stay
   darker than exteriors. Use **Skylight Leaking** only as an art knob.
7. Use **Source Angle** on the Directional Light for soft sun shadows (see section 7).

If the sky shows visible texels, raise `r.SkyAtmosphere.FastSkyViewLUT.SampleCountMax`; on fogged
objects, raise `r.SkyAtmosphere.AerialPerspectiveLUT.DepthResolution`.

## 6. Nanite

### Where Nanite works in 5.8

Component types: Static Mesh, Skeletal Mesh, Instanced Static Mesh, Hierarchical Instanced Static
Mesh, Spline Mesh, Geometry Collection, Foliage painter, Landscape grass. Landscapes can also use
Nanite.

Materials: **Opaque** and **Masked** blend modes only. Unsupported materials get a default
material and a warning in the Output Log. Translucent, Mesh Decals, the Wireframe checkbox, and
Morph Targets are not supported. Projected decals work. Custom UVs and Vertex Interpolators work
but are evaluated three times per pixel (except Custom UV0/1 with hardware rasterization).

World Position Offset is supported but limited: WPO splits meshes into smaller clusters with
their own bounds. Clamp it with **Max World Position Offset Displacement** (Material Details >
World Position Offset, or Material Property Overrides on an instance).

Not supported: Forward Rendering, VR stereo rendering, MSAA, Lighting Channels, Minimum Screen
Radius and distance culling. Ray tracing uses the fallback mesh; native Nanite ray tracing is
Experimental (`r.RayTracing.Nanite.Mode 1`).

Platforms: current consoles and DX12 SM6 desktop GPUs with current drivers.

Skeletal Meshes: Nanite Skeletal Meshes render in one draw call per mesh, cast VSM shadows, use
animation LODs instead of geometry LODs, and support instancing with animation banks.

Foliage:
- "Foliage using Nanite" (plain Nanite meshes as foliage) is **Beta**. Enable **Preserve Area** on
  every foliage mesh and nothing else. It stops canopies thinning with distance. Prefer real
  geometry over masked cards; masked-out pixels cost nearly as much as drawn ones.
- **Nanite Foliage** (Assemblies, Voxels, Skinning) is a separate project setting:
  Project Settings > Rendering > **Nanite Foliage**, off by default, needs a restart. Voxels are
  set per mesh with Nanite Settings > **Shape Preservation** = **Voxelize**. Nanite Skinning
  replaces WPO wind; the Dynamic Wind plugin is Experimental. Use **Animation Min Screen Size**
  on the component to stop skinning when small on screen.

Displacement: Nanite Tessellation and Static Displacement Mapping are both **Experimental**.
Tessellation needs `r.Nanite.AllowTessellation=1` in project config and `r.Nanite.Tessellation=1`.

### Enabling Nanite

- On import: tick **Build Nanite**. If you do not use baked lighting, turn off
  **Generate Lightmap UVs**.
- One mesh: open the Static or Skeletal Mesh Editor > **Nanite Settings** > **Enable Nanite Support**.
  Geometry Collections: **Enable Nanite** in the Nanite section.
- Many meshes: select them in the Content Browser, right-click > **Nanite > Enable**.

Smooth normals where possible; faceted normals make Nanite draw far more triangles.

### Fallback mesh

Nanite generates a coarse fallback mesh used on platforms without Nanite, for complex collision,
lightmaps, and Lumen HWRT reflections. Settings are in the mesh editor under Nanite Settings:
- **Fallback Target**: Auto, Fallback Triangle Percent, or Fallback Relative Error.
- **Fallback Triangle Percent** (0–100) and **Fallback Relative Error**. 100 and 0 mean no decimation.
- Toggle the fallback in the Static Mesh Editor with **Show > Nanite Fallback** or **Ctrl+N**.
- For hand-made fallbacks: set Fallback Triangle Percent to 0, import LOD1, set **Minimum LOD** to 1.
  Use **LOD for Collision** to choose the collision LOD.
- Disk trimming (not performance): **Keep Triangle Percent** and **Trim Relative Error**.
  By default Nanite keeps every source triangle.

`r.Nanite 0` turns Nanite off to emulate platforms without it.

### Nanite visualization

Viewport **View Modes > Nanite Visualization**: Overview, Mask (Nanite green, non-Nanite red),
Triangles, Patches, Clusters, Primitives, Instances, Overdraw, Lightmap UV, Evaluate WPO (WPO
green), Pixel Programmable, Tessellation, Raster Bins, Shading Bins. `r.Nanite.Visualize.Advanced 1`
adds programmer modes. **Overdraw** is the main tool for finding stacked or aggregate geometry
that makes Nanite expensive. `NaniteStats` shows culling stats (`NaniteStats List` for views,
e.g. `NaniteStats VirtualShadowMaps`).

## 7. Virtual Shadow Maps

VSMs are built for Nanite. If a project does not use Nanite, VSMs are likely a poor fit. Nanite
geometry renders into VSMs far more cheaply than non-Nanite geometry, so enable Nanite on every
supported mesh, especially large shadow casters like buildings.

### What invalidates cached pages

Caching is on by default and is what keeps VSMs fast. Pages are redrawn when:
- a light moves or rotates (all pages for that light),
- a shadow caster moves, is added, or removed (pages overlapping its bounds), including Blueprints
  that set properties which trigger a render-state update,
- a material uses World Position Offset or Pixel Depth Offset,
- a mesh is skeletally animated (every frame).

Reduce invalidations:
- **World Position Offset Disable Distance** on the primitive stops WPO in the distance.
- **Shadow Cache Invalidation Behavior** on the primitive: Auto (default), Always, Rigid (ignore
  WPO), Static (ignore WPO and transform changes; moving it gives undefined results).
- Replace WPO wind with skeletal animation or instance transforms where you can.
- Keep bounds tight; use LODs that swap to non-WPO materials in the distance; for grass, Contact
  Shadows alone may be enough.
- Static and dynamic geometry cache separately. A Movable mesh that never updates moves to the
  static cache. In stats, invalidated static pages should be near 0.
- Non-Nanite meshes need full LOD chains. `r.Shadow.RadiusThreshold` culls small distant
  non-Nanite casters. Beyond the Directional Light's Dynamic Shadow Distance, non-Nanite geometry
  switches to Distance Field Shadows.

### Soft shadows (SMRT)

Softness comes from **Source Radius** (local lights; 0 by default) and **Source Angle**
(Directional Light). Softer shadows cost more. Lower Source Radius/Angle before lowering ray or
sample counts.

### VSM visualization

Viewport **View Modes > Virtual Shadow Map**: Shadow Mask, Clipmap/Mip Level, Virtual Page,
Cached Page (green cached, red new or invalidated, blue static-only cached), Nanite Overdraw,
Shadow Casters. Select a light in the Outliner to see only that light. Start with **Cached
Page** with the camera still, then use **Shadow Casters** to find the objects and bounds causing
invalidations. Turn visualization off before measuring performance.

A checkerboard or missing/corrupt shadows with an on-screen warning means the page pool
overflowed: raise `r.Shadow.Virtual.MaxPhysicalPages`, lower shadow resolution, or reduce
shadow-casting lights.

Shadow acne on low-poly curved meshes (the shadow terminator problem): add polygons first; only
then raise `r.Shadow.Virtual.NormalBias` (default 0.5).

## 8. Diagnosis order

1. **Lumen Scene** view mode: does Lumen's version of the scene match what you see? Missing
   objects, black areas, or wrong materials here explain most GI problems.
2. **Surface Cache** view mode: pink = not covered.
3. **Show > Visualize > Mesh Distance Fields / Global Distance Field** (Software RT): thin walls,
   holes, low resolution.
4. **Geometry Normals** (Lumen view mode): global distance field or Nanite fallback problems.
5. **Reflection View**: how Lumen Reflections see the scene.
6. **Nanite Visualization > Mask / Overdraw / Evaluate WPO**: non-Nanite stragglers and costly WPO.
7. **Virtual Shadow Map > Cached Page / Shadow Casters**: shadow invalidation.
8. **HDR (Eye Adaptation)**: exposure range and measured lux.
9. Timing and budgets: hand off to `ue-profiling-workflow`.

Menu paths and console equivalents: `references/cvars-and-viewmodes.md`.
