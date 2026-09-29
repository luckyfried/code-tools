# PCG node cheat-sheet (UE 5.8)

Node names as listed in Epic's PCG Framework Node Reference, grouped by palette category, with a
one-line note on the ones environment graphs use most. If a node you need is not here, search the
node palette; UE 5.8 also adds nodes such as Align Points, Apply Spline to Component, Get Editor
Cameras, and complex-attribute (array/struct/set/map) constants.

## Getting data in (Spatial)

| Node | Use |
|---|---|
| Get Landscape Data | Landscape as surface data; usual input to Surface Sampler. |
| Get Spline Data | Spline components (self, or world actors by tag/class). |
| Get Volume Data / Get Primitive Data | Volumes or primitive components, e.g. for exclusions. |
| Get Actor Data | General version. Actor Filter: Self, Parent, Root, All World Actors, Original, From Input. Modes include parsing components, one point per actor, or reading another PCG component's output. |
| Get PCG Component Data | Output of other PCG components (graph-to-graph). |
| Get Texture Data | Texture as surface data. |
| Get Bounds / Get Points Count | Bounds or count as an attribute set. |
| World Ray Hit Query / World Volumetric Query | Sample the physics world (option Ignore PCG Hits). |

Other Spatial nodes: Attribute Set To Point, Clip Paths, Create Points, Create Points Grid,
Create Polygon 2D, Create Spline, Create Surface From Polygon 2D, Create Surface From Spline,
Cull Points Outside Actor Bounds, Difference, Distance, Find Convex Hull 2D, Get Segment,
Inner Intersection, Intersection, Make Concrete, Merge Points, Mutate Seed, Normal To Density,
Offset Polygon, Point Neighborhood, Point From Mesh, Polygon Operation, Projection,
Spatial Noise, Spline Intersection, Split Splines, To Point, Union.

## Samplers

| Node | Use |
|---|---|
| Surface Sampler | Grid of points on a surface. Points Per Square Meter, Point Extents, Looseness. |
| Spline Sampler | On Spline / On Horizontal / On Vertical / On Volume / On Interior; Subdivision, Distance, or Number Of Samples. Interior needs a closed spline. |
| Volume Sampler | Regular 3D grid inside a volume (can be costly). |
| Mesh Sampler | Points on a static mesh. Costly. Needs PCG Geometry Script Interop + Geometry Script. |
| Texture Sampler | Samples a texture's value at each point. |
| Copy Points | Copies source points onto each target point (assemblies, local-space patterns). |
| Select Points | Keeps an approximate random ratio of points. |

## Filters and density

| Node | Use |
|---|---|
| Density Filter | Keep points inside a density range. Fast. |
| Attribute Filter / Attribute Filter Range | Filter on any attribute or property (e.g. `$Position.Z`), against a constant, spatial data, or attribute set. |
| Point Filter / Point Filter Range | Per-point filters. |
| Self Pruning | Remove overlaps within one point set: Large To Small, Small To Large, All Equal, None, Remove Duplicates. |
| Normal To Density | Density from alignment with an axis; slope masks. |
| Density Remap / Curve Remap Density | Remap density linearly or by curve. |
| Density Noise (alias Attribute Noise) | Random noise on an attribute (Mode, Noise Min, Noise Max). |
| Filter Data By Tag / By Attribute / By Index / By Type | Split whole data objects, not points. |
| Discard Points on Irregular Surface | Drops points that are not on a flat patch. |

Distance to Density exists but the Distance node supersedes it for most uses.

## Point Ops

Apply Scale to Bounds, Bounds Modifier (size bounds before pruning or differences),
Build Rotation From Up Vector, Combine Points, Duplicate Point, Extents Modifier, Split Points,
Transform Points (random offset/rotation/scale, Absolute options, Uniform Scale, Recompute Seed).

## Spawners

| Node | Use |
|---|---|
| Static Mesh Spawner | Instanced meshes. Mesh Entries + Weight; selectors: Weighted, By Attribute, Weighted By Category. Execute on GPU available. |
| Spawn Actor | Actors per point or collapsed into a target actor. Options: Collapse Actors, Merge PCG only, No Merging. Attach: Not attached, Attached, In Folder. |
| Create Target Actor | Empty actor to receive spawner output. |
| Point from Player Pawn | Point at the player pawn (runtime generation). |

## Metadata

Add Attribute, Attribute Noise, Attribute Partition, Attribute Rename, Attribute Select,
Attribute String Op, Break Transform Attribute, Break Vector Attribute, Copy Attribute,
Create Attribute, Delete Attributes, Density Noise, Filter Attributes by Name,
Get Attribute from Point Index, Make Transform Attribute, Make Vector Attribute,
Match And Set Attributes (table lookup with weights; supersedes Point Match and Set),
Merge Attributes, Point Match and Set, Transfer Attribute.

Operator families: Attribute Maths Op (Add, Subtract, Multiply, Divide, Clamp, Lerp, Min, Max,
Pow, Round, One Minus, ...), Attribute Compare Op, Attribute Boolean Op, Attribute Bitwise Op,
Attribute Reduce Op (Average, Min, Max), Attribute Rotator Op (Combine, Invert, Lerp,
Make Rot from ...), Attribute Transform Op, Attribute Trig Op, Attribute Vector Op
(Cross, Dot, Distance, Length, Normalize, Rotate Around Axis, ...).

## Flow, reuse, and structure

- Control Flow: Branch, Select, Select (Multi), Switch.
- Subgraph: Subgraph, Loop.
- Generic: Add Tags, Delete Tags, Replace Tags, Apply On Actor, Gather (has a Dependency Only pin
  for ordering), Get Data Count, Get Entries Count, Get Loop Index, Proxy, Sort Attributes,
  Sort Points.
- Param: Get Actor Property, Get Property From Object Path, Point To Attribute Set.
- Input Output: Load Data Table, Data Table Row to Attribute Set, Load PCG Data Asset,
  Load Alembic File (needs PCG External Data Interop).
- Hierarchical Generation: Grid Size.
- Helpers: Spatial Data Bounds To Point.
- Blueprint: Execute Blueprint.
- Debug: Debug, Print String, Sanity Check Point Data.
- Organization: Add Comment, Add Reroute Node, Add Named Reroute Declaration Node.
- GPU: Custom HLSL (kernel types Point Processor, Point Generator, Attribute Processor, Custom).

## Set operations: density functions

- Difference — Density Function: Minimum, Clamped Subtraction, Binary. Mode: Inferred,
  Continuous, Discrete (Discrete collapses to points; use it for clean cuts).
- Union — Density Function: Maximum, Clamped Addition, Binary.
- Intersection — each Primary Source data ∩ (union of each Source pin).
- Inner Intersection — intersection of all inputs.
