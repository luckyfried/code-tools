# Editor Python for landscape and foliage (UE 5.8)

These snippets use only classes, methods, and properties listed in the UE 5.8 Python API reference
(Experimental). Run them in the editor's Python console or with `py <file>` in the Output Log. The
**Python Editor Script Plugin** must be enabled.

Notes:
- In World Partition levels, actor queries return only **loaded** actors. Load the regions first.
- `set_editor_property` goes through the editor's property system. Changes to an asset still need a save.
- Test on a copy or under source control before bulk edits.

## 1. Audit landscapes and streaming proxies in the level

`unreal.Landscape` and `unreal.LandscapeStreamingProxy` both derive from `unreal.LandscapeProxy`.

```python
import unreal

actors = unreal.get_editor_subsystem(unreal.EditorActorSubsystem).get_all_level_actors()
for a in actors:
    if not isinstance(a, unreal.LandscapeProxy):
        continue
    kind = "Landscape" if isinstance(a, unreal.Landscape) else type(a).__name__
    mat = a.get_editor_property("landscape_material")
    rvts = a.get_editor_property("runtime_virtual_textures")
    unreal.log(
        f"{kind} {a.get_actor_label()}: "
        f"material={mat.get_name() if mat else None} "
        f"nanite={a.get_editor_property('enable_nanite')} "
        f"skirt={a.get_editor_property('nanite_skirt_enabled')} "
        f"rvt_count={len(rvts)} "
        f"vt_num_lods={a.get_editor_property('virtual_texture_num_lods')} "
        f"collision_mip={a.get_editor_property('collision_mip_level')}"
    )
```

## 2. Batch-set culling and scalability on foliage type assets

This walks a folder, and loads each asset it finds there.

```python
import unreal

FOLDER = "/Game/Environment/Foliage"   # change to your folder
START_CM, END_CM = 8000, 10000         # cull distance interval in cm; pick values for your project

for path in unreal.EditorAssetLibrary.list_assets(FOLDER, recursive=True):
    asset = unreal.EditorAssetLibrary.load_asset(path)
    if not isinstance(asset, unreal.FoliageType_InstancedStaticMesh):
        continue
    asset.set_editor_property("cull_distance", unreal.Int32Interval(min=START_CM, max=END_CM))
    asset.set_editor_property("enable_density_scaling", True)       # responds to foliage.DensityScale
    asset.set_editor_property("enable_cull_distance_scaling", True) # responds to foliage.CullDistanceScale
    unreal.EditorAssetLibrary.save_loaded_asset(asset)
    unreal.log(f"updated {path}")
```

Notes:
- Nanite meshes ignore cull distance and instance fade.
- A smooth fade also needs `PerInstanceFadeAmount` in the material.
- Placed instances pick up type changes through Foliage mode's Reapply tool when the matching Reapply
  checkboxes are set.

## 3. Report WPO and shadow settings on foliage types

```python
import unreal

for path in unreal.EditorAssetLibrary.list_assets("/Game/Environment/Foliage", recursive=True):
    ft = unreal.EditorAssetLibrary.load_asset(path)
    if isinstance(ft, unreal.FoliageType_InstancedStaticMesh):
        mesh = ft.get_editor_property("mesh")
        unreal.log(
            f"{path}: mesh={mesh.get_name() if mesh else None} "
            f"cast_shadow={ft.get_editor_property('cast_shadow')} "
            f"wpo_disable_dist={ft.get_editor_property('world_position_offset_disable_distance')} "
            f"shadow_invalidation={ft.get_editor_property('shadow_cache_invalidation_behavior')}"
        )
```

## Other confirmed LandscapeProxy methods

- `landscape_import_heightmap_from_render_target(render_target, import_height_from_rg_channel=False, edit_layer_index=0)`
- `landscape_import_weightmap_from_render_target(render_target, layer_name, edit_layer_index=0)`
- `landscape_export_heightmap_to_render_target(render_target, export_height_into_rg_channel=False, export_landscape_proxies=True)`
- `set_landscape_material_scalar_parameter_value(name, value)`, plus the matching `_vector_` and
  `_texture_` variants.
- `editor_apply_spline(spline_component, ..., paint_layer=None, edit_layer_name=...)`: deforms and paints
  along a Spline Component.
- `delete_unused_layers()`
- `get_landscape_actor()`

Useful editor properties on `LandscapeLayerInfoObject`: `phys_material`, `hardness`,
`minimum_collision_relevance_weight`, and `blend_method` (`unreal.LandscapeTargetLayerBlendMethod`).
`layer_name` is read-only.
