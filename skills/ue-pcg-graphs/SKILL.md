---
name: ue-pcg-graphs
description: Use when building or editing PCG (Procedural Content Generation) graphs in the Unreal Engine 5.8 editor for environment art — scattering on landscapes, spline-driven placement, exclusions, reusable biome graphs, partitioned/hierarchical/runtime generation, and debugging or optimizing a graph. For C++ PCG elements or ProceduralMeshComponent code use ue-procedural-generation; for Python scripting of PCG use unreal-pcg-python.
---

# PCG graphs for environment art (UE 5.8)

This skill is for authoring PCG graphs in the editor: picking nodes, wiring recipes, setting
component and graph options, and debugging the result. It does not cover writing C++ PCG
elements (see `ue-procedural-generation`) or driving PCG from Python (see `unreal-pcg-python`).

Node names in this skill come from Epic's UE 5.8 PCG documentation. A full node list by category
is in `references/node-cheatsheet.md`. If a node or setting is not listed there, check the node
palette or the docs before using it; do not guess names.

## Working with the Unreal MCP (when connected)

UE 5.8 ships an experimental MCP server inside the editor (plugins: **Unreal MCP** plus
**All Toolsets**, which pulls in **Toolset Registry**). With tool search on (the default), the
server exposes only three meta-tools: `list_toolsets`, `describe_toolset`, `call_tool`.

1. Call `list_toolsets` first and look for PCG-related toolsets. Then `describe_toolset` on each
   candidate to get the exact tool names and argument schemas. Never guess a tool name or
   argument; use only what `describe_toolset` returned.
2. Invoke tools through `call_tool`. The editor handles MCP requests one after another, so wait
   for each result before sending the next.
3. After every edit (add node, connect pins, change a setting, assign a graph, generate), read the
   state back with the toolset's read/inspect tools and confirm the change landed before the next
   edit. Treat an unconfirmed edit as not done.
4. If no PCG toolset exists, say so and give the user the manual steps from this skill instead of
   improvising with unrelated tools. If toolsets were just added, `ModelContextProtocol.RefreshTools`
   in the editor console re-polls the registry.

## Setup and the three core objects

- Enable the **Procedural Content Generation Framework** plugin. Sampling points on static meshes
  (Mesh Sampler) also needs **Procedural Content Generation Framework Geometry Script Interop**
  (and Geometry Script).
- **PCG Graph** asset: Content Browser > right-click > Create Advanced Asset > PCG > PCG Graph.
  Node graph similar to the Material Editor. Graphs can be marked as templates (Graph Settings >
  Asset Info > Is Template).
- **PCG Component**: holds a graph and runs generation in the editor and at runtime. Add it to any
  actor or Blueprint. Key settings: Graph, Seed, Generation Trigger, Is Partitioned, and the
  Generate / Cleanup buttons.
- **PCG Volume**: a box volume with a PCG Component already on it. Fastest way to scatter over an
  area; its bounds limit the sampling.

## The data model

- A graph pulls spatial data (landscape, splines, volumes, primitives, textures) and turns it into
  **points**. Points carry a transform, bounds (BoundsMin/BoundsMax), color, **density**,
  steepness, and seed, plus any user attributes.
- **Density** (0–1) is the probability that the point exists. Debug view shows it as black (0) to
  white (1). Filters and set operations mostly work on density.
- **Steepness** is how hard the edge of a point's density falloff is. It is not terrain slope.
  For slope, use Normal To Density (see recipes).
- **Attributes**: names starting with `$` are built-in point properties (`$Position`, `$Rotation`,
  `$Scale`, `$Transform`, `$Density`, `$Seed`, ...). Names without `$` are dynamic attributes
  stored as metadata. `@Last` means the last attribute the previous node touched.
- Components can be picked out: `$Position.Z`, `$Position.ZYX`, `$Rotation.Yaw`, `.Length`, etc.
- **Metadata domains** use `@`: `@Data` (one value for the whole data; default for most spatial
  data), `@Points`, `@Elements` (attribute sets). Spline control-point metadata can be addressed
  with `@ControlPoints`; spline-level values include `@Data.$IsClosed`.
- **Attribute Sets** are tables of attributes with no spatial meaning (often from data tables or
  graph parameters).
- Node settings marked overridable get override pins (advanced pins). A pin fed an attribute whose
  name matches the setting name overrides that setting.

## Core recipe: landscape scatter

A forest/rock/grass scatter usually has this shape. Build it one node at a time and turn on debug
at each step.

1. **Get Landscape Data** → **Surface Sampler**.
   - Surface Sampler: `Points Per Square Meter` (how many cells are kept), `Point Extents` (base
     cell/point size), `Looseness` (cell size = extents × (1 + Looseness); higher = less grid-like).
2. **Slope filter**: **Normal To Density** (Normal = up axis; also Offset, Strength, Density Mode)
   → **Density Filter** with the range you want kept. Steep areas get low density and drop out.
3. **Height filter**: **Attribute Filter Range** on `$Position.Z`, or **Attribute Filter** against a
   constant.
4. **Noise breakup**:
   - **Density Noise** (alias of Attribute Noise: Mode, Noise Min, Noise Max) then **Density
     Filter** for random thinning.
   - **Spatial Noise** writes spatially coherent noise (Perlin-like) to an attribute. Use it for
     natural clumps and patches, then filter on that attribute.
   - **Select Points** keeps a random ratio of points (approximate, not exact).
5. **Variation**: **Transform Points** — random offset, rotation (e.g. Rotation Max Z = 360),
   scale min/max, `Uniform Scale`. Tick `Absolute Rotation` to keep points upright instead of
   aligned to the landscape normal.
6. **Spacing**: set point bounds to the real mesh size, then **Self Pruning**.
   - Easiest: put mesh selection upstream, or use **Bounds Modifier** / **Extents Modifier** to
     size the bounds before pruning.
   - Self Pruning types: Large To Small, Small To Large, All Equal, None, Remove Duplicates.
     Randomized pruning avoids visible patterns when radii are similar.
7. **Layering against other content**: **Difference** of these points against already-placed
   points (e.g. trees minus rocks). Density Function `Binary` plus Mode `Discrete` gives a hard
   cut on concrete points.
8. **Static Mesh Spawner**:
   - `Mesh Entries` array; each entry has a Descriptor (Static Mesh and component options) and a
     `Weight`. Chance = weight / sum of weights.
   - Mesh Selector Type: **PCG Mesh Selector Weighted** (by weight), **PCG Mesh Selector By
     Attribute** (mesh path stored on each point), **PCG Mesh Selector Weighted By Category**
     (category attribute on the point, then weighted pick inside the category).
   - `Apply Mesh Bounds To Points` writes the chosen mesh's bounds onto the points; the selected
     mesh is also written to `Out Attribute Name` when the output pin is used.
   - Mesh property overrides map a point attribute onto an instance-component descriptor property.

Data-driven mesh choice: load a table with **Load Data Table** (or graph parameters), assign per
point with **Match And Set Attributes** (supports weights and nearest-value matching; it
supersedes Point Match and Set), then use the By Attribute selector.

## Spline-driven scatter (roads, rivers, fences)

- Get the spline: **Get Spline Data** (Actor Filter `Self` when the spline is on the same
  Blueprint as the PCG Component; `All World Actors` + select by tag or class for splines in the
  level).
- **Spline Sampler** settings:
  - Dimension: `On Spline` (along the curve — fences, posts, road-edge props), `On Horizontal`,
    `On Vertical`, `On Volume` (in the spline's volume, sized by control-point scale), `On
    Interior` (fill a closed spline — fields, ponds, clearings).
  - Mode: `Subdivision`, `Distance` (use Distance Increment — even spacing for fence posts),
    `Number Of Samples`.
  - Also: Start Offset / End Offset, Fit To Curve, Interior Sample Spacing, Interior Density
    Falloff Curve, and optional outputs such as alpha, distance, tangents, curvature.
  - Sampling inside a spline requires a closed spline.
- **Create Surface From Spline** makes a closed spline usable as a surface for Surface Sampler,
  Difference, or Intersection. It discretizes the spline, so very large splines can fail; sample
  and rebuild with **Create Spline** first if needed.
- Riverbank or roadside bands: sample the spline to points, then **Distance** from scatter points
  to those points (writes distance to an attribute), then **Attribute Filter Range** on that
  attribute to keep a band or clear a corridor.
- Points on a spline are not on the landscape. Use **Projection** (target = landscape data) to put
  them back on the ground, or sample the landscape inside the spline area instead.
- Splines drawn in **PCG Editor Mode** (Modes dropdown > PCG): Draw Spline, Draw Spline Surface,
  Paint, and Volume tools. A graph appears in a tool when its Tool Data > Compatible Tool Tags
  include `SplineTool`, `SplineSurfaceTool`, `PaintTool`, or `VolumeTool`.

## Exclusion

- Pull the exclusion shapes: **Get Actor Data**, **Get Volume Data**, **Get Primitive Data**, or
  **Get Spline Data** with Actor Filter `All World Actors` and actor selection **By Tag**
  (e.g. a `PCG_Exclude` tag you choose) or **By Class**.
- **Filter Data By Tag** splits data by tags when one query returns both inclusions and exclusions.
- Subtract with **Difference** (Binary, Discrete for a clean cut). Use **Bounds Modifier** on the
  exclusion data or points to add a margin.
- Open splines (roads, paths) have no area. Sample them to points, grow the bounds with Bounds
  Modifier to the road half-width, then Difference; or use the Distance approach above.
- **World Ray Hit Query** / **World Volumetric Query** sample the physics world directly (option
  `Ignore PCG Hits` avoids hitting other PCG output).
- Manual fixes: UE 5.8 adds non-destructive manual editing of PCG output (select, exclude, modify,
  restore) so one-off cleanups do not require graph changes.

## Reuse: subgraphs, parameters, instances

- **Subgraph** node runs another graph. Graphs can call themselves recursively (stop the recursion
  with control flow or empty input). **Loop** runs a subgraph once per data on its loop pins;
  feedback pins carry results between iterations. Pair with **Attribute Partition** to loop per
  group.
- UE 5.8 adds embedded subgraphs stored inside the parent graph, like Blueprint functions.
- **Graph Parameters** (Graph Settings > Parameters > +): typed, overridable values. The UE 5.8
  parameters hierarchy editor organizes them into categories.
- **Graph Instances** work like Material Instances: select the PCG Component and click Save
  Instance, then change parameters on the instance. When an instance is used as a subgraph,
  override its parameters through the subgraph node's pins.
- A reusable biome graph: one master graph with parameters for density, slope and height ranges,
  mesh table, and seed; one instance per biome; exclusions and per-level data come in through
  Get … Data nodes filtered by tag.
- Control flow: **Branch**, **Select**, **Select (Multi)**, **Switch**. **Proxy** lets a
  parameter choose which node runs.
- Graph Settings can also restrict the node palette by category and restrict which subgraphs are
  offered.

## PCG Biome Core

**PCG Biome Core** and **PCG Biome Sample** are experimental plugins built only from native PCG
nodes and data assets. Biome Core gives a fixed pipeline: biome actors (volume, spline, texture)
compute a local biome cache, generator graphs produce root points, assets are assigned from an
attribute-set table, filter graphs run (Height and Density by default), recursive child-asset
transforms run, and a global Biome Core graph applies a priority-based difference between biomes
and generators before spawning. It supports exclusion volumes and splines, landscape layer
weights, assemblies, and optional runtime generation of close-up detail.

Use it as a starting point or as a reference. Epic recommends copying the plugin into the project
if used in production, so engine updates do not break content. The Biome Setup actor class is
deprecated; use Biome Texture volumes as in the sample level.

## Generation modes and World Partition

- **Non-partitioned** (default): all output lives with the one component. Fine for small areas.
- **Partitioned**: tick `Is Partitioned` on the component. The grid comes from `Partition Grid
  Size` on the **PCGWorldActor**. After changing it, Cleanup then Generate each PCG actor. Output
  is split per cell, which streams well with World Partition.
- **Hierarchical Generation** (requires partitioned components): Graph Settings > `Use
  Hierarchical Generation` and `HiGen Default Grid Size`. Put a **Grid Size** node before the
  sampler in each branch to pick that branch's grid. Big, sparse assets (trees, boulders) on large
  grids; small, dense ones (grass, pebbles) on small grids. Data flows from larger grids to
  smaller, never back. Mixed inputs run at the smallest grid.
  - `Unbounded` runs a branch once for the whole component. Use it for expensive shared work
    (such as a Mesh Sampler) and apply Grid Size downstream.
  - Passing large-grid data into a small grid duplicates it into every cell; remove copies with
    **Cull Points Outside Actor Bounds**.
  - Subgraphs use the grid size of their input or parent graph.
- **World Partition**: generated content takes its Data Layer and HLOD Layer from the PCG actor. Spawn Actor and
  Create Target Actor have Data Layer and HLOD source settings (Self, references, template).
- **Get Actor Data** reading another PCG component's output can target specific grids (`Get Data
  On All Grids`, `Allowed Grids`) and `Expected Pins`.

## Editor vs runtime generation

Generation Trigger on the PCG Component:

- **Generate On Load** — generates when the component loads.
- **Generate On Demand** — generates only when asked (Generate button, Blueprint, etc.).
- **Generate At Runtime** — generated and cleaned up by the Runtime Generation Scheduler around
  generation sources.

Choose:

- Editor-generated (On Load / On Demand, results baked into the level): hero areas, anything that
  needs baked lighting, HLOD, collision, navigation, or hand cleanup; content that must look the
  same every time.
- Runtime: dense, low-importance detail over huge areas (grass, pebbles, ground clutter) that would
  bloat the saved level. Works best with hierarchical generation, generating fine grids only near
  the player.

Runtime settings: Graph Settings > Runtime Generation > `Generation Radii` per grid size (radii
should grow with grid size) and `Cleanup Radius Multiplier`. The component can `Override
Generation Radii`, choose a scheduling policy, and `Use Frustum Culling` (with generate and
cleanup bounds modifiers). Generation sources: players, World Partition streaming sources, **PCG
Generation Source Components**, and the editor viewport when `Treat Editor Viewport as Generation
Source` is on in the PCGWorldActor (use this to preview in the editor).

## Debugging

- In the graph editor, select a node and press **D** (or tick Debug) to draw its points in the
  level viewport. **E** toggles the node's Enabled state. **A** (or right-click > Inspect) lists
  every point and attribute of that node in the Attributes list. Pick the component (or partition
  cell) to inspect in the **Debug Tree**.
- A permanent **Debug** node shows its input without a checkbox. **Print String** and **Sanity
  Check Point Data** validate assumptions (Sanity Check cancels generation when values are out of
  range).
- Each node shows its grid size in the top-right corner under hierarchical generation. Partition
  component names include the grid size (e.g. `PCGPartitionActor_12800_...` is the 12800 cm grid).
- Empty output checklist: the component has a Graph; it was generated (or regenerated after a
  change); the sampler's source overlaps the volume; density was not filtered to zero; Static Mesh
  Spawner has at least one mesh entry; inspect each node in order to find where points vanish.
- **Determinism**: output depends on the component Seed, each node's Seed, and each point's
  `$Seed`. Same inputs and seeds give the same result. Change the component Seed for a new
  variation. After duplicating points, use **Mutate Seed** or Transform Points `Recompute Seed` so
  copies do not share random choices.
- Runtime console commands: `pcg.RuntimeGeneration.EnableDebugOverlay 1`,
  `pcg.GraphExecution.DebugDrawGeneratedCells 1`, `pcg.RuntimeGeneration.Refresh`,
  `pcg.RuntimeGeneration.Enable`, `pcg.RuntimeGeneration.NumGeneratingComponents`,
  `pcg.FrameTime`, `pcg.EditorFrameTime`.
- The graph editor's profiling pane shows per-node CPU time.

## Performance

- Keep instance counts per component manageable by partitioning; one huge unpartitioned component
  produces huge instance components that stream and cull as one unit.
- Filter early and cheaply: put Density Filter or Attribute Filter right after the sampler.
  Density Filter is faster than a general Attribute Filter for density.
- Delete temporary attributes (**Delete Attributes**) before costly nodes like Copy Points.
- Keep Points Per Square Meter as low as the look allows, especially on small grids.
- The Static Mesh Spawner outputs instanced static mesh components. `Allow Descriptor Changes`
  lets PCG adjust the descriptor as needed (for example ISM rather than HISM for Nanite meshes).
  `Setup Culling Cells` divides instances into cells so the renderer can cull subranges.
- Use Nanite meshes for dense foliage and rocks where the project allows. Nanite Foliage (Nanite
  Assemblies, Voxels, Skinning) is experimental and enabled in Project Settings > Rendering.
- GPU execution (beta): nodes such as Static Mesh Spawner, Copy Points, Transform Points, Normal
  To Density, Cull Points Outside Actor Bounds, and **Custom HLSL** can run on the GPU (`Execute
  on GPU`). Group GPU nodes together; yellow up/down arrow badges mark costly CPU↔GPU transfers.
  A GPU Static Mesh Spawner uses a procedurally instanced component: instances are not saved and
  have no baked lighting, HLOD, collision, physics, navigation, ray tracing, or distance field
  lighting. Use it for runtime detail only.
- Put expensive shared work on the `Unbounded` or a large grid, not on every small cell.
