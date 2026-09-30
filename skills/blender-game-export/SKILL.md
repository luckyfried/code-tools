---
name: blender-game-export
description: Use when exporting models, rigs, or animation from Blender 5.x to a game engine or the web - FBX or glTF/GLB for Unity, Unreal Engine, Godot, or three.js - or when writing a bpy script that batch-exports them. Covers the pre-export checklist, exporter settings per target, rigs and actions, compression, and checking the result. Triggers include "export to Unity", "export to Unreal", "export to Godot", "export for three.js", "FBX", "glTF", "GLB", "Draco", "meshopt", "wrong scale", "tiny/huge after import", "rotated 90 degrees", "lying on its side", "animation missing after export", "only one animation exported", "leaf bones", "extra bones", "UCX collision", "LOD0", "blender -b export".
---

# Blender game export

Get a mesh, rig, or animation out of Blender and into an engine or a web page looking the same as it did in Blender. The exporter options below are the Blender 5.x Python names (`bpy.ops.export_scene.fbx` / `bpy.ops.export_scene.gltf`); the UI labels are in brackets. If an option name here fails, look it up in the API reference for the installed version (the blender-current-api skill covers how) rather than guessing.

## Pick the format

| Target | Format | Why |
|---|---|---|
| three.js / web | glTF Binary `.glb` | one file, compression extensions three.js decodes |
| Godot | glTF / `.glb` | Godot's recommended format; `.blend` import runs Blender's glTF exporter anyway |
| Unreal Engine 5 | FBX (rigs and animation); glTF/GLB also imports through Interchange | Epic documents the FBX pipeline in detail |
| Unity | FBX | Unity's own import chain is FBX; see below for `.blend` |

**Unity and `.blend`:** Unity can import a `.blend` in the Assets folder, but it does it by launching Blender in the background to convert it to FBX. Every machine that imports the project needs Blender installed, the first import is slow, and Unity's docs say textures and diffuse color are not assigned automatically from `.blend`. Unity's docs recommend exporting `.fbx` for production. Do that.

## Pre-export checklist

Run through this before every export. Most "wrong scale", "rotated 90 degrees", and "looks faceted" reports come from skipping one of these.

1. **Transforms applied.** Object scale should read 1,1,1 and rotation 0,0,0 on meshes (Object > Apply > All Transforms, or `bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)`). Unapplied scale is the usual cause of wrong-size or wrongly-scaled physics in the engine. On a rig, apply on the armature and its meshes together before animating, not after.
2. **Origin placed deliberately.** The origin becomes the pivot in the engine. For props, put it where the object should rest or rotate; for characters, at the feet on the floor (Unity's animation docs ask for the feet on the local origin). `bpy.ops.object.origin_set(type='ORIGIN_CURSOR')` with the 3D cursor where you want it.
3. **Units.** Scene Properties > Units: Metric, Unit Scale 1.0 (`scene.unit_settings.system = 'METRIC'`, `scale_length = 1.0`), modelled so 1 Blender unit = 1 m. Unity expects 1 m = 1 unit; Unreal works in centimeters and converts on import with **Convert Scene Unit**. Do a test export of a 1 m cube next to the engine's own cube before trusting a whole batch.
4. **Axes.** Blender is Z up, Y forward. glTF is Y up and the glTF exporter converts for you (`export_yup=True` [+Y Up], on by default). FBX writes the axis you choose (`axis_forward`, `axis_up`; defaults `-Z` and `Y`, the common Y-up convention). Leave the defaults and let the engine convert: Unity has **Bake Axis Conversion** on the Model tab, Unreal has **Convert Scene** and **Force Front XAxis**. `bake_space_transform` [Apply Transform] exists but the API marks it experimental and known broken with armatures and animation; do not use it on rigs.
5. **Modifiers.** Decide whether they export. FBX `use_mesh_modifiers` [Apply Modifiers] defaults on; glTF `export_apply` [Apply Modifiers] defaults off. Both warn that applying modifiers prevents exporting shape keys. Armature modifiers are never applied.
6. **Triangles and n-gons.** glTF always converts quads and n-gons to triangles. FBX keeps them unless `use_triangles=True` [Triangulate Faces]. Unreal's docs recommend triangulating yourself so you control the split; a Triangulate modifier as the last modifier (with Apply Modifiers on) does that non-destructively.
7. **Normals and smoothing.** Shade Auto Smooth adds a **Smooth by Angle** modifier (`bpy.ops.object.shade_auto_smooth(angle=...)`), pinned last. Because it is a modifier, its sharp edges only reach the file when the exporter applies modifiers - turn on `export_apply` for glTF, or bake it with `shade_smooth_by_angle` (which sets sharp edges on the mesh itself). For FBX, `mesh_smooth_type='OFF'` [Normals Only] is the exporter's recommended default when the importer reads custom normals; use `'FACE'` if the target needs smoothing groups (Unity notes blend shape normals need smoothing groups). In the engine, import normals rather than recalculating (Unity **Normals: Import**, Unreal **Normal Import Method: Import Normals**).
8. **UVs.** Every textured or normal-mapped mesh needs a UV map. glTF: `export_texcoords=True` [UVs] (default). For normal maps also export tangents (`export_tangents` / FBX `use_tspace`), or let the engine compute MikkTSpace.
9. **Materials** - see the glTF material subset below. FBX carries only a simple material description; expect to rebuild materials in Unity/Unreal and plan for it.
10. **Textures.** glTF requires PNG or JPEG in the file (WebP via extension); other formats are converted during export. `.glb` embeds images; `GLTF_SEPARATE` writes them next to the `.gltf` (`export_texture_dir` for a subfolder). For FBX use `path_mode='COPY'` and `embed_textures=True` to put images inside the file, or `COPY` alone to write them beside it. Unity looks for a `Textures` folder next to (or above) the model. Pack or fix missing files first (File > External Data > Report Missing Files).
11. **Names.** Name objects, meshes, materials, bones, and actions as they should appear in the engine; the exporters keep them.
   - Unreal collision: a separate mesh named `UCX_<RenderMeshName>_##` (convex hull, must be a closed convex shape), or `UBX_` box, `USP_` sphere, `UCP_` capsule, with `<RenderMeshName>` exactly matching the render mesh. Export them in the same FBX.
   - Unity LODs: suffix meshes `_LOD0`, `_LOD1`, ... (`_LOD0` most detailed, max eight levels) and export one FBX; Unity builds the LOD Group automatically.

### What a glTF material keeps

The exporter reads a Principled BSDF (or an unlit setup) and writes only what glTF can express:

- Core: **Base Color** (value or Image Texture), **Metallic** and **Roughness** (one image: roughness in G, metallic in B, Non-Color; a Separate Color node wired that way is copied verbatim), **Normal** (Image Texture -> Normal Map node in Tangent Space -> Normal input; strength is kept), **Emission** (strength above 1 uses `KHR_materials_emissive_strength`), **Alpha** (opaque, mask when alpha is rounded to 0/1, otherwise blend).
- Occlusion: only through a node group named `glTF Material Output` with an `Occlusion` input (occlusion in R).
- Extensions, written when the input is non-default or textured: Clearcoat (+ roughness, normal), Transmission, Volume (Volume Absorption node, needs transmission), IOR, Specular (Specular IOR Level / Tint), Sheen, Anisotropy, Iridescence, Dispersion, unlit (`KHR_materials_unlit`).
- UV Map + Mapping nodes -> `KHR_texture_transform`. Image textures in any color other than these arrangements, procedural textures, and arbitrary node math are not exported; bake them to images first (Cycles Bake panel).
- Backface Culling off in Blender exports as a double-sided material. Turn it on for closed meshes (Godot notes double-sided costs performance).
- Area lights and World lighting are not exported.

## Rigs and animation

### FBX (Unity, Unreal)

```python
bpy.ops.export_scene.fbx(
    filepath=path, use_selection=True,
    object_types={'ARMATURE', 'MESH'},
    add_leaf_bones=False,          # [Add Leaf Bones] default True: appends an extra end bone to every chain
    use_armature_deform_only=True, # [Only Deform Bones] drops control/IK bones (keeps non-deform parents of deform bones)
    bake_anim=True,                # [Baked Animation] constraints/IK become keys
    bake_anim_use_all_actions=False,
    bake_anim_use_nla_strips=True, # one AnimStack per non-muted NLA strip
)
```

- **Leaf bones:** "extra `_end` bones" in the engine come from `add_leaf_bones=True` (the default). It only exists to round-trip bone length back into Blender; turn it off for engines. When importing FBX back into Blender, `ignore_leaf_bones=True` drops them.
- **Which animations are written:** `bake_anim_use_nla_strips` writes each non-muted NLA strip as its own take; `bake_anim_use_all_actions` writes every action compatible with the armature as its own take (animated objects get every compatible action, others get none). With both off only the current scene animation is written. "Animation missing" usually means the action was neither active nor on an NLA strip, or had no fake user and was never assigned. Push each clip down to its own NLA track.
- **Unreal:** Epic's animation pipeline takes one animation per skeletal mesh per FBX file, so export each clip to its own file (mesh file first, then animation-only files targeting that Skeleton). The skeletal mesh's pivot is its root bone, so keep a single root bone at the origin. After import, open the Skeleton and check the hierarchy: if an unwanted extra root appears above your root bone, that is the armature object; adjust and re-export rather than working around it. `bake_anim_use_all_bones` [Key All Bones] (default on) keys every bone, which the exporter notes some engines need.
- **Unity Humanoid:** at least 15 bones in a human-like hierarchy (hips -> spine -> chest -> neck -> head, limbs in pairs with consistent L/R naming), modelled in a T-pose, feet on the origin, max four influences per vertex by default (Skin Weights setting raises it). Set Rig > Animation Type: Humanoid and check the Avatar mapping. Generic rigs only need a bone you can pick as the root node.
- Bone axes: FBX bones are -X aligned and Blender's are Y aligned; the exporter notes this does not affect skinning or animation, only how bones look in other apps. `primary_bone_axis` / `secondary_bone_axis` change it; leave the defaults unless an engine-side tool needs otherwise.

### glTF (three.js, Godot)

Blender 5.x actions are slotted (one action can animate several objects through slots). The glTF exporter's `export_animation_mode` [Animation Mode] decides how actions become glTF animations:

| Mode | Result |
|---|---|
| `'ACTIONS'` (default) | each action that is active or on an NLA track becomes an animation; tracks are merged by the action they use. Best for a character with an animation library. Each action on its own NLA track. |
| `'ACTIVE_ACTIONS'` | the currently assigned actions on all objects become one animation |
| `'NLA_TRACKS'` | each NLA track becomes an animation; same-named tracks on different objects play together |
| `'SCENE'` | the scene as the viewport plays it, baked |
| `'BROADCAST'` | every compatible action applied to every object |

- An action that is neither active nor stashed/pushed to an NLA track is not exported. Stash every clip you want.
- `export_merge_animation` [Merge Animation]: `'ACTION'` (default, by action/slot), `'NLA_TRACK'` (by track name), `'NONE'`.
- `export_anim_single_armature` (default on) exports all actions bound to one armature; it does not support multiple armatures in one export.
- `export_reset_pose_bones` / `export_morph_reset_sk_data` (default on) reset between actions so an unkeyed bone does not inherit the previous clip's pose.
- `export_def_bones=True` [Export Deformation Bones Only]: Godot requires it on when the model has shape keys (non-deforming bones cause incorrect shading).
- `export_bake_animation=True` [Bake All Objects Animations] when constraints drive objects that have no keys of their own.
- `export_leaf_bone` defaults off already; leave it off.
- Only object transforms, pose bones, and shape key values export as animation; material, light, and physics properties are ignored (except experimental `export_pointer_animation` in `NLA_TRACKS`/`SCENE` modes).
- `export_influence_nb` defaults to 4; viewers may render wrong with values other than 4 or 8.

## Per-target recipes

### three.js / web: GLB

```python
bpy.ops.export_scene.gltf(
    filepath="out/model.glb", export_format='GLB',
    use_selection=True, export_apply=True, export_yup=True,
    export_image_format='AUTO',          # or 'WEBP' / 'JPEG' for smaller files
    export_draco_mesh_compression_enable=True,   # or meshopt below, not both
    # export_meshopt_compression_enable=True,
    # export_meshopt_extension='EXT_meshopt_compression',
    export_animation_mode='ACTIONS',
)
```

- Draco (`KHR_draco_mesh_compression`): level 0-6 via `export_draco_mesh_compression_level`, plus per-attribute quantization bits. In three.js give the loader a decoder: `loader.setDRACOLoader(new DRACOLoader().setDecoderPath(...))`, or the file fails to load.
- Meshopt: `export_meshopt_compression_enable` with `EXT_meshopt_compression` or `KHR_meshopt_compression`. three.js needs `loader.setMeshoptDecoder(MeshoptDecoder)`.
- The exporter can also run the external `gltfpack` tool (`export_use_gltfpack`, with KTX2 texture compression and simplification options); gltfpack must be installed. KTX2 textures need `loader.setKTX2Loader(...)`.
- For further optimization (texture resize/KTX2, dedupe, prune, simplify, instancing) use the gltf-transform skill, if installed; otherwise run the exported file through the `gltf-transform` CLI (npm `@gltf-transform/cli`). Keep the Blender export uncompressed if you plan to post-process, and compress once at the end.
- Then load it in the app and look at it: the threejs-visual-check skill covers the browser check.

### Unreal Engine 5: FBX

- Static mesh: transforms applied, origin set, `UCX_` collision meshes alongside, triangulated, `mesh_smooth_type='FACE'` or `'OFF'` with Normal Import Method: Import Normals.
- Skeletal: settings above, one animation per file.
- Import dialog: Convert Scene on, Convert Scene Unit on (centimeters), Import Mesh LODs if the file carries LODs, Use T0 As Ref Pose only if frame 0 is the bind pose you want.
- Unreal also imports glTF/GLB through Interchange (including Import Into Level); prefer FBX for rigged, animated characters.

### Unity: FBX

- Units metric 1.0, transforms applied, default FBX axes; in Unity's Model tab leave Convert Units on and use Bake Axis Conversion if the root arrives rotated.
- `_LOD0.._LODn` naming for automatic LOD Groups; Humanoid rules above for characters.
- Normals: Import; Tangents: Import (with `use_tspace=True`) or Calculate Mikktspace.

### Godot: glTF/GLB

- Export `.glb` (or `GLTF_SEPARATE` if you want reviewable text and loose textures). Godot can import `.blend` directly if Blender is installed and its path is set in Editor Settings (Filesystem > Import > Blender); it runs the same glTF exporter.
- `export_def_bones=True` when shape keys are present; Backface Culling on in materials.

## Scripting it

Batch-export from a script, headless. Save the settings you use in the script, not in the UI, so every run is the same.

```python
# export.py - run: blender -b scene.blend --python-exit-code 1 -P export.py -- out_dir
import bpy, sys, os

out_dir = sys.argv[sys.argv.index("--") + 1]
os.makedirs(out_dir, exist_ok=True)

for coll in bpy.data.collections:
    if coll.name.startswith("_"):          # skip helper collections by convention
        continue
    bpy.ops.export_scene.gltf(
        filepath=os.path.join(out_dir, f"{coll.name}.glb"),
        export_format='GLB', collection=coll.name,
        export_apply=True, export_yup=True,
    )
    bpy.ops.export_scene.fbx(
        filepath=os.path.join(out_dir, f"{coll.name}.fbx"),
        collection=coll.name, add_leaf_bones=False,
        use_armature_deform_only=True, bake_anim=True,
    )
```

- `collection="<name>"` exports that collection and its children (both exporters). `use_selection=True` exports the selection. `use_visible`, `use_active_collection` also exist on both.
- FBX `batch_mode` ('COLLECTION', 'SCENE', 'SCENE_COLLECTION', 'ACTIVE_SCENE_COLLECTION') writes one file per collection/scene in a single call, with `use_batch_own_dir` for a folder each.
- Collection Exporters (Collection Properties > Exporters) store per-collection export settings in the `.blend`; `bpy.ops.collection.export_all()` runs every exporter configured on the active collection. Useful when artists own the settings.
- `--python-exit-code 1` makes a Python error fail the run; without it Blender exits 0. Write output to a log and check the exit code separately (a pipe to `tail` hides it).
- `export_scene.*` are operators; in background mode they run without a UI but still act on the current scene, view layer, and selection. Set selection explicitly in the script when using `use_selection`.

## Check the result

A file that exported without errors is not proof it is right. Before reporting done:

1. **Re-import into a clean Blender** and compare: `bpy.ops.wm.read_factory_settings(use_empty=True)` then `bpy.ops.import_scene.gltf(filepath=...)` or `bpy.ops.wm.fbx_import(filepath=..., ignore_leaf_bones=False)`. Check object and bone counts, dimensions (`obj.dimensions`), rotation (should be 0 on meshes you applied), material count, and that each expected action/animation exists and has the right frame range.
2. **Look at it** in the target: the three.js page (threejs-visual-check skill), the engine's import preview, or a Blender render of the re-import. The blender-verify skill covers reading the scene back and rendering a check image, with or without the Blender MCP server.
3. **Test cube once per pipeline:** a 1 m cube with applied transforms, exported with the same settings, should be the same size as the engine's default cube and unrotated.

## Symptoms

| Symptom | Likely cause | Fix |
|---|---|---|
| Wrong scale (100x / 0.01x) | Unit Scale not 1.0, unapplied object scale, or engine unit conversion off | Apply scale; units metric 1.0; engine Convert Units / Convert Scene Unit on; FBX `apply_scale_options` if needed; test cube |
| Rotated 90 degrees / lying on its side | Unapplied rotation, or engine axis conversion off | Apply rotation; keep exporter default axes; Unity Bake Axis Conversion, Unreal Convert Scene |
| Extra `_end` bones | `add_leaf_bones=True` (FBX default) | `add_leaf_bones=False` |
| Control/IK bones in engine | deform-only off | `use_armature_deform_only=True` / `export_def_bones=True` |
| Animation missing / only one clip | Action not active and not on an NLA track | Push each action to its own NLA track; check animation mode / NLA-strip options |
| Shape keys missing | Apply Modifiers on | Turn modifier applying off, or apply modifiers in Blender first and keep shape keys |
| Faceted or all-smooth shading | Smooth by Angle modifier not applied at export, or engine recalculating normals | `export_apply=True` or `shade_smooth_by_angle`; engine Normals: Import |
| three.js model fails to load | Draco/meshopt/KTX2 decoder not set on GLTFLoader | `setDRACOLoader` / `setMeshoptDecoder` / `setKTX2Loader` |
| Textures missing | Absolute/missing paths | `.glb`, or FBX `path_mode='COPY'` + `embed_textures=True`; fix missing files first |
| Material looks different | Node setup outside the glTF subset | Rebuild with Principled BSDF inputs listed above, or bake to images |
