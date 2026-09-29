---
name: ue-landscape-foliage
description: Use for Unreal Engine 5.8 terrain and vegetation work — creating or sizing Landscapes, importing heightmaps and weightmaps, Edit Layers, landscape materials and layer info objects, Landscape Grass, Foliage mode painting and foliage types, and their performance. For rule-based PCG scatter use the ue-pcg-graphs skill; for lighting, Lumen, shadows, and general Nanite setup use ue-lighting-lumen-nanite.
---

# UE 5.8 Landscape and Foliage

Environment-artist workflows for the Landscape system, Foliage mode, and Landscape Grass in Unreal Engine 5.8.
Everything here follows Epic's 5.8 documentation. If a setting is not named here, check the editor or the
docs before stating it as fact.

Related skills:
- `ue-pcg-graphs` for procedural scatter with PCG graphs.
- `ue-lighting-lumen-nanite` for lighting, Lumen, Virtual Shadow Map setup, and general Nanite mesh setup.

## If Unreal MCP is connected

Epic's Unreal MCP plugin (Experimental in 5.8) runs an MCP server inside the editor. In its default
tool-search mode it exposes only three meta-tools: `list_toolsets`, `describe_toolset`, and `call_tool`.

1. Call `list_toolsets` and read the names and descriptions. Look for anything about landscape, foliage,
   actors, assets, materials, or Python.
2. Call `describe_toolset` on the candidates to get the exact tool names and parameter schemas.
3. Invoke through `call_tool` with the names exactly as described. Never guess a toolset or tool name.
4. Make one call at a time. The server runs tool calls serially on the game thread, so don't overlap them.
5. If no toolset covers the task, use the Editor Python in `references/editor-python.md` (if a toolset can
   run Python) or give the user the manual editor steps.

Which toolsets exist depends on the plugins the user has enabled (All Toolsets or individual toolset plugins).

## 1. Creating a Landscape

Open Landscape mode with **Shift+2** (or Select Mode > Landscape). Manage mode > **New Landscape** has
**Create New** and **Import from File**.

Key settings:
- **Section Size**: quads per section. A section is the unit of LOD and each section is a draw call.
- **Sections Per Component**: 1x1 or 2x2. A component is the unit of rendering, culling, and collision.
- **Number of Components**: capped at 32x32 in the UI. Epic recommends at most 1024 components.
- **Overall Resolution** (vertices) and **Total Components** are read-only results.
- **Scale**: the X/Y value sets the distance between vertices (100 = 1 m per quad).

Defaults are 63x63 quads, 1x1 section, 8x8 components, 505x505 vertices. Epic calls 63x63 quads per section
"generally recommended." Fewer, larger components cost less CPU than many small ones. 2x2 sections give the
same heightmap size as four times as many 1-section components, and perform better.

Size formula: `vertices per axis = components_per_axis * quads_per_component + 1`.
Quads per component = section quads (1 section) or 2 x section quads (2x2 sections).
For the full table of recommended sizes (127 up to 8129), see `references/landscape-sizing.md`.

Edit Layers are enabled automatically when you create a new landscape.

## 2. Importing heightmaps and weightmaps

Heightmap formats: **16-bit grayscale PNG**, **16-bit grayscale .r16**, **8-bit grayscale .r8**.
A `.raw` file also works if a JSON sidecar with the same name sits next to it, giving `width`, `height`, and
bit depth. The native heightmap format is single-channel 16-bit grayscale, so prefer 16-bit sources.

Black is the lowest point and white the highest. The imported file resolution must be a valid landscape
size; the import UI reads it from the file.

**Z scale math.** Heights are stored in 16 bits as -256 to +256 units, multiplied by Z scale in centimeters.
Z scale 100 (default) spans -256 m to +256 m, a 512 m range. To fit a known range:

```
Z scale = total height range in meters * 100 * 0.001953125     (0.001953125 = 1/512)
```

Example from Epic: 4207 m -> Z scale 821.6796875, which spans -2103.5 m to +2103.5 m around the actor's Z.
Raise or lower the actor, or add headroom to the range, if you need space below "sea level." X/Y scale may
need adjusting to match the terrain tool's output; check that tool's documentation.

**New landscape from file:** Landscape mode > Import from File > pick the heightmap (tiled heightmaps
are detected and offered) > set Z scale > Import. In a World Partition level, also set
**World Partition Grid Size** (how components are grouped into streaming proxies) and **World Partition
Region Size** (components per region on each axis).

**Existing landscape:** Manage mode > Import tool. Pick an **Import Type**: Original, Expand, Resample,
or Subregion. Use **Subregion** on World Partition landscapes. Set **Mode** to All to cover unloaded regions,
not only loaded ones. **Flip Y Axis** fixes tiled heightmaps that don't line up.

**Weightmaps (target layers):** single-channel 8-bit grayscale PNG or RAW, at the same resolution as the
landscape's Overall Resolution. Target layers need layer info objects first (section 4). RGB images import,
but lose color and may lose precision.

**Export:** Manage mode > Import tool > Export. Output is 16-bit grayscale PNG or .r16, as a single file or
tiles (tiles need World Partition). You can export one edit layer or the blended result.

## 3. Edit Layers (non-destructive editing)

- Each landscape starts with one layer. Add layers with **+**. Separate data by purpose, for example: Base,
  Sculpt Details, Paint Details, Splines, Patches.
- The default maximum is 8 layers. Change it in Project Settings > Landscape > **Max Number of Layers**.
- Each layer has two alphas: a heightmap alpha (Sculpt mode; negative values subtract) and a weightmap alpha
  (Paint mode). Layers can also be locked, hidden, and reordered by dragging.
- The Erase tool on a layer returns it to default height. Lit > Visualizers > **Layer Contribution**
  highlights what a layer contributes.
- **Collapse** merges a layer into the one below it. **Collapse All Layers** is destructive and removes
  Blueprint brushes.
- The special **Splines** and **Patches** edit layers take procedural data only; you can't sculpt or paint
  on them.
- Landscape Blueprint Brushes need the **Landmass** plugin.
- Water bodies carve terrain through a landscape brush, which needs Edit Layers enabled.

## 4. Landscape materials

**Nodes** (in the Material Editor):
- `LandscapeLayerBlend`: holds a list of named layers, each with a blend type:
  - **LB Weight Blend**: weighted and order-independent.
  - **LB Alpha Blend**: an ordered overlay, such as snow over everything.
  - **LB Height Blend**: a weight blend with a height-driven transition. Wire the height texture to the
    layer's Height input.
- `LandscapeLayerCoords`: landscape UVs. Mapping types are Auto/XY, XZ, and YZ; use XZ/YZ for
  side-projected cliffs. It also sets Mapping Scale, Rotation, and Pan.
- `LandscapeLayerSample`: returns a layer's weight, 0 to 1. Use it to drive grass output or masks.
- `LandscapeLayerWeight`: returns Base + Layer * weight. Chain these nodes for a custom blend.
- `LandscapeLayerSwitch`: skips work where a layer has no weight.
- `LandscapeVisibilityMask`: for holes. Leave the material **Opaque** and still connect Opacity Mask; the
  system switches to masked only in components that have holes. Nanite landscape has no masked cost.

**Rules that prevent common bugs:**
- Layer names must be unique. The landscape matches them case-insensitively to target layers.
- A material layer with no target layer on the landscape reads a weight of 0.
- If every layer at a spot uses Height Blend, you can get black spots where all heights are 0. Fix it by
  setting one base layer (for example soil) to **LB Alpha Blend**.
- Each component compiles its own material instance and drops unused layer branches, so a master material
  can hold many layers.
- On mobile (ES3.1) there is a 16-sampler limit, and every 4 target layers add another weightmap texture.
  Keep the layer count low there. Epic recommends three layers for mobile.

**Layer info objects** (Paint mode > Target Layers > **+** on each layer):
- Choose **Weight-Blended Layer (normal)**, where painting one layer reduces the others, or **Non
  Weight-Blended Layer**, which is independent, for example snow over any base.
- Every target layer needs its own layer info object, or you can't paint. A new material usually shows a
  black landscape until they exist.
- A layer info object is a reusable asset, but only for a layer with the same name.
- Properties include Phys Material (used where the layer is dominant), Hardness (for the Erosion tool), and
  Minimum Collision Relevance Weight. In 5.8 the asset also has a **Blend Method** property.
- If you remove a layer from the material, it shows as **orphaned** (?) and keeps its painted data until
  you delete it.

**Auto-material pattern (slope and height).** Build masks in the material instead of painting everything:
- Slope: the `WorldAlignedBlend` material function compares the surface normal to a vector. With (0,0,1),
  flat ground reads 1 and steep ground reads 0. Tune **Blend Sharpness** and **Blend Bias**, then use the
  result to lerp rock onto cliffs.
- Height: take the Z of the `WorldPosition` expression, remap it into a 0 to 1 mask, and use it to blend
  snow or shoreline materials.
- Combine these masks with painted layers, for example by multiplying an auto mask by a
  `LandscapeLayerSample` "override" layer. Keep this procedural logic inside the part of the graph that
  writes to RVT when RVT is used.

**Runtime Virtual Texturing (RVT):**
- *When it helps:* a complex layered landscape material whose camera-independent shading can be cached, and
  decal-like blending such as roads from splines, meshes, or foliage. Also blending non-landscape meshes
  into the terrain through the same RVT.
- *Setup:*
  1. Project Settings > Engine > Rendering > Virtual Textures > **Enable virtual texture support**, then
     restart.
  2. Create a Runtime Virtual Texture asset. Pick its material type (Base Color, Normal, Roughness,
     Specular is the common landscape choice; also World Height, Displacement, and others).
  3. Place a **Runtime Virtual Texture Volume** and use **Set Bounds** with the landscape as the source.
  4. In the landscape material, enable **Use Material Attributes**. Write the blended result to a
     `Runtime Virtual Texture Output` node and read it back with a `Runtime Virtual Texture Sample` node.
     Use a `Virtual Texture Feature Switch` for fallback.
  5. Add the RVT asset to the landscape's **Render to Virtual Textures** array (`runtime_virtual_textures`).
- *Tuning:*
  - Landscape **Virtual Texture Num LODs** of 0 renders each component as a single quad, which is best for
    the GPU.
  - For large worlds, bake low mips with **Streaming Levels** plus **Build** on the volume.
  - Debug with `stat virtualtexturing` and `stat virtualtexturememory`.
- Objects that render into the RVT should be static.
- RVT does not support ISM culling or LOD selection.

## 5. Nanite Landscape

Nanite landscape is supported in 5.8.
- **Enable:** select the landscape > Details > **Enable Nanite**. Build with Details > Nanite > **Build
  Data** / **Rebuild Data**, or **Build > Build Landscape**.
- **Stale data:** after sculpting, the editor falls back to non-Nanite rendering until you rebuild or save.
  Cooking rebuilds out-of-date data, which slows cooks, so save proxies regularly.
- **Memory:** both Nanite and non-Nanite data stream and stay resident, roughly twice the landscape memory.
  RVT and water still need the non-Nanite data.
- **Seams:** enable **Nanite Skirt** and set **Nanite Skirt Depth** to hide tiny holes between proxies at
  distance.
- **Displacement:** a displacement input in the landscape material drives Nanite tessellation. It shows in
  the editor only when the Nanite data is up to date.
- **Console variables:**
  - `Landscape.RenderNanite` (default 1).
  - `Landscape.Nanite.MultithreadedBuild` (default 1).
  - `Landscape.Nanite.LiveRebuildOnModification` (default 0; Experimental). Leave it off because it slows
    editing.
- **Why use it:** it mainly helps performance, especially with Virtual Shadow Maps. Final visuals match
  non-Nanite.

## 6. Landscape with World Partition

- **Streaming proxies:** a landscape in a World Partition level is edited as one object but stored as
  **Landscape Streaming Proxies**. They load and unload in the editor and at runtime, and several people can
  edit different regions without file conflicts.
- **New level:** the **Open World** map template (File > New Level) starts with a 2 km x 2 km landscape and
  outdoor lighting.
- **Import:** use the World Partition grid and region settings on import, and Import Type **Subregion** on
  existing landscapes (section 2).
- **Loaded vs. unloaded regions:** tools and Python only see loaded regions. Use **Mode: All** for import
  and export when you mean the whole landscape.
- **Saving:** Project Settings > Landscape > **Landscape Dirtying Mode** controls how landscape actors
  that need a resave appear. Use **Build > Save Modified Landscapes** when the viewport says actors aren't
  up to date.
- **Per-proxy settings:** HLOD settings are on the landscape (HLOD Layer, texture size policy, mesh source
  LOD). Project Settings > Landscape > **HLOD Max Texture Size** caps the texture size.

## 7. Foliage mode

Open with **Shift+3**.
- **Foliage types:** drag a Static Mesh into the Mesh List, or create a Static Mesh Foliage asset.
  - **Static Mesh Foliage** is instanced and batched into few draw calls. It is the default choice.
  - **Actor Foliage** costs as much as normal actors. Keep it sparse.
- **Tools:**
  - Paint (Shift erases), Erase, Single, Fill.
  - Select, Lasso, All, Deselect, Invalid.
  - **Reapply**: change settings on a foliage type, then paint over placed instances to apply them.
  - Remove, and Move (to the current level).
- **Brush:** Brush Size, **Point Density** (a multiplier on the type's Density), Erase Density, Single
  Instance Mode, Place in Current Level.
- **Filters:** Landscape, Static Mesh, BSP, Foliage, Translucent.
- **Key foliage type settings** (Python names in parentheses):
  - Density (`density`, instances per 1000x1000 units), and Radius (`radius`, minimum spacing).
  - Scaling (`scaling`) with `scale_x`/`scale_y`/`scale_z` ranges, `z_offset`, `random_yaw`,
    `align_to_normal`, and `align_max_angle`.
  - `ground_slope_angle` and `height` ranges, plus `landscape_layers` / `exclusion_landscape_layers`, which
    limit painting by landscape paint layers.
  - Cull Distance (`cull_distance`, a min/max interval).
  - `enable_density_scaling` and `enable_cull_distance_scaling`.
  - Shadow flags, and `world_position_offset_disable_distance`.
- **Culling:** **End Cull Distance** culls whole clusters, so they pop. For a smooth fade, also set
  **Start Cull Distance** and use `PerInstanceFadeAmount` in the material's opacity mask. **Nanite meshes
  ignore cull distance and instance fade.**
- **Scalability:** turn on **Enable Density Scaling** so `foliage.DensityScale` (0 to 1) thins the type at
  runtime.
- **Reattaching:** select the instances, move them above the new surface, and press **End** to snap and
  reparent them.
- **World Partition:**
  - Foliage instances use their own grid, 256 m by default. For new maps, set Project Settings >
    **Instanced Foliage Grid Size** (in cm).
  - For an existing map, run the commandlet
    `UnrealEditor <Project> <Map> -run=WorldPartitionBuilderCommandlet -Builder=WorldPartitionFoliageBuilder -NewGridSize=<cm>`.
- **Static lighting only:** meshes need a valid unique lightmap UV. Keep lightmap resolution small enough
  that a cluster's shadow maps tile into one texture.

**Procedural Foliage tool (legacy approach):**
- Enable it in Editor Preferences > Experimental > **Procedural Foliage**.
- Add Static Mesh Foliage types to a **Procedural Foliage Spawner** asset, then place it and simulate
  inside its volume.
- For rule-based scatter driven by graph logic, use PCG instead (see `ue-pcg-graphs`).

## 8. Landscape Grass

Grass spawns automatically from the landscape material and works **only on Landscape actors**.
1. Content Browser > Foliage > **Landscape Grass Type**. Add entries to **Grass Varieties**. Each entry
   has:
   - Grass Mesh and Grass Density (`grass_density`; the API describes it as instances per 10 square
     meters).
   - Use Grid / jitter, Random Rotation, Align to Surface, and scale ranges.
   - Start/End Cull Distance, and `instance_world_position_offset_disable_distance`.
   - Shadow flags, and Enable Density Scaling (driven by `grass.DensityScale`).
2. In the landscape material, add a **Landscape Grass Output** node, assign the grass type, and feed it
   from a `LandscapeLayerSample` of the layer that should grow grass.
3. Paint that layer. Grass regenerates after strokes, which can stall the editor at high density, so
   lower the density while you paint.
4. Per landscape, `grass_types_overrides` can swap grass types without editing the material.

Grass meshes can be Nanite ("Landscape grass" is a supported Nanite component type).

## 9. Nanite and foliage

Two different things:
- **Nanite on regular foliage meshes (Beta):**
  - Enable **Preserve Area** on foliage meshes so canopies don't thin out at distance.
  - Prefer real geometry over masked cards. Masked pixels cost almost as much as drawn ones, so
    card-based foliage may be slower with Nanite.
  - Clamp WPO with the material's **Max World Position Offset Displacement**.
- **Nanite Foliage (Experimental in 5.8):**
  - Enable it with Project Settings > Rendering > **Nanite Foliage**, then restart.
  - **Nanite Assemblies** instance parts, such as branches, inside one mesh.
  - **Nanite Voxels**: set Static Mesh > Nanite Settings > **Shape Preservation: Voxelize**.
  - **Nanite Skinning** replaces WPO wind with bones. The **Dynamic Wind** plugin is also Experimental.
  - Set **Animation Min Screen Size** so skinning stops on small, distant instances.
  - Treat it as not ready to ship without testing.

## 10. Water (Water plugin), basics only

- **Enable:** Edit > Plugins > **Water**, then restart. Example content is in the plugin's Water Content
  folder; turn on Show Engine/Plugin Content to see it.
- **Water Body actors:**
  - **Ocean**: a closed spline at one height.
  - **Lake**: a closed spline at one height.
  - **River**: an open spline. Each point can have a different height, depth, width, and velocity.
  - **Custom**: a Static Mesh, which doesn't carve terrain.
  - **Island**: raises the terrain.
  - **Exclusion Volume**.
- **Terrain carving:** needs the landscape to have **Edit Layers** enabled.
- **Distant ocean:** the **Water Zone** actor's **Far Distance Mesh** fills the gap to the horizon.
- Water rendering needs the non-Nanite landscape data, which stays resident even with Nanite landscape on.

## 11. Performance checklist

**Landscape:**
- Keep the component count down (1024 at most for the largest landscapes). Each section is a draw call.
- Don't shrink the section size and then scale the landscape up; that raises CPU cost.
- Material:
  - Use `LandscapeLayerSwitch` to skip unused layers.
  - Avoid a global masked material; use the Opaque plus Opacity Mask approach for holes.
  - Watch the layer count on mobile.
- Consider RVT for heavy materials and Nanite landscape when using Virtual Shadow Maps.
- Visualize paint coverage with View > Landscape Visualizers (Layer Debug).
- `per_lod_override_materials` can swap in a cheaper material at far LODs.

**Foliage and grass:**
- Set End Cull Distance on every non-Nanite type, and on grass varieties.
- Enable density scaling so scalability settings and `foliage.DensityScale` / `grass.DensityScale` work.

**WPO:**
- WPO costs more with more vertices.
- With Virtual Shadow Maps, WPO invalidates cached shadow pages every frame. Set **World Position Offset
  Disable Distance** (grass: `instance_world_position_offset_disable_distance`).
- Clamp **Max World Position Offset Displacement**.
- For static WPO, consider **Shadow Cache Invalidation Behavior: Rigid**.

**Shadows:**
- For grass and small foliage, Contact Shadows alone are sometimes enough.
- Distance Field Shadows can take over for non-Nanite foliage beyond the directional light's dynamic
  shadow distance.
- Hand deeper lighting and shadow tuning to `ue-lighting-lumen-nanite`.

## Editor Python

For bulk audits and edits (listing landscape proxies and their settings, batch-editing foliage type
culling and density scaling), use the snippets in `references/editor-python.md`. They use only API
confirmed in the UE 5.8 Python reference (`EditorAssetLibrary`, `EditorActorSubsystem`, `LandscapeProxy`,
`FoliageType_InstancedStaticMesh`).
