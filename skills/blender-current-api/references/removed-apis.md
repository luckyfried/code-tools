# Old pattern to current pattern

"Changed in" is the Blender release whose Python API release notes
(<https://developer.blender.org/docs/release_notes/>, section Python API) list the change. Where a
release deprecated something and a later one removed it, both are given. Nothing marked removed
exists in Blender 5.2.

## Context, operators, and modules

| Old pattern | Current pattern | Changed in |
| --- | --- | --- |
| `bpy.ops.x.y(override_dict, ...)` | `with bpy.context.temp_override(**members): bpy.ops.x.y(...)` | 4.0 (removed) |
| `import bgl` | The `gpu` module (`gpu.shader`, `gpu.types`, `gpu.state`, `gpu_extras.batch`) | 5.0 (removed) |
| `image.bindcode` | `gpu.texture.from_image(image)` | 5.0 (removed) |
| `gpu.types.GPUShader(vertexcode, fragcode)` | `gpu.shader.create_from_info(info)` | 4.5 (deprecated), 5.0 (removed) |
| Built-in shader names with `2D_` / `3D_` prefix, such as `'3D_UNIFORM_COLOR'` | `'UNIFORM_COLOR'` and the other unprefixed names | 4.0 |
| Wide or smooth lines with `UNIFORM_COLOR` / `FLAT_COLOR` / `SMOOTH_COLOR` | `POLYLINE_UNIFORM_COLOR`, `POLYLINE_FLAT_COLOR`, `POLYLINE_SMOOTH_COLOR`; points use the `POINT_` variants | 4.5 |
| `bpy.app.version_char` | `bpy.app.version`, `bpy.app.version_string` | 4.0 |
| `blf.size(font_id, size, dpi)` | `blf.size(font_id, size)` | 4.0 |
| `scene["cycles"]`, `obj["my_addon"]` to reach `bpy.props` data | Attribute access (`scene.cycles`); `property_unset()` to reset; `bl_system_properties_get()` only for versioning old data | 5.0 |
| `get` / `set` callbacks that only transform a stored value | `get_transform` / `set_transform`; read-only via `options={'READ_ONLY'}` | 5.0 |
| Importing `rna_info`, `bl_ui_utils`, `keyingsets_utils`, `bpy_restrict_state`, and other bundled internals | Not public; do not import them | 5.0 |
| `Operator` subclass `__init__` that does not call `super().__init__(*args, **kwargs)` | Call the parent constructor with all arguments | 4.4 |

## Meshes

| Old pattern | Current pattern | Changed in |
| --- | --- | --- |
| `mesh.use_auto_smooth = True`, `mesh.auto_smooth_angle = a` | `mesh.shade_smooth()` plus `mesh.set_sharp_from_angle(angle=a)`, or `bpy.ops.object.shade_auto_smooth(angle=a)` (adds the Smooth by Angle modifier) | 4.1 (removed) |
| `mesh.calc_normals_split()`, `create_normals_split()`, `free_normals_split()`, then `loop.normal` | `mesh.corner_normals` (read-only cache); set custom normals with `normals_split_custom_set()` | 4.1 |
| `mesh.calc_normals()` | Nothing; normals are computed on demand | 4.0 |
| `edge.crease`, `vertex` crease | Attributes `crease_edge` / `crease_vert`; `mesh.edge_creases_ensure()` / `vertex_creases_ensure()` | 4.0 |
| `edge.bevel_weight` | Attributes `bevel_weight_edge` / `bevel_weight_vert` | 4.0 |
| Face maps | An integer attribute | 4.0 |
| `mesh.sculpt_vertex_colors` | `mesh.color_attributes` | 4.0 |
| `vertex_layers_float` / `_int` / `_string`, `polygon_layers_*` | `mesh.attributes.new(name, type, domain)` | 4.0 |
| Sculpt mask as a layer collection | `mesh.vertex_paint_mask` returns the `.sculpt_mask` attribute; `vertex_paint_mask_ensure()` / `_remove()` | 4.1 |
| `bmesh_from_object` / `BVHTree.FromObject` with an unevaluated depsgraph | Pass an evaluated depsgraph | 4.0 |
| `uv_layer.vertex_selection`, `uv_layer.edge_selection`, `BMLoopUV.select`, `BMLoopUV.select_edge` | UV selection shared by all UV maps: `.uv_select_vert` / `.uv_select_edge` / `.uv_select_face` attributes, `BMLoop.uv_select_vert`, `BMFace.uv_select` | 5.0 (removed) |
| Accessing `uv_layer.pin` to create the attribute | The matching `_ensure()` function | 5.0 |
| Boolean solver `'FAST'` | `'FLOAT'` | 5.0 |
| `bpy.types.AttributeGroup` | `AttributeGroupMesh`, `AttributeGroupPointCloud`, `AttributeGroupCurves`, `AttributeGroupGreasePencil` | 4.3 |

## Nodes and materials

| Old pattern | Current pattern | Changed in |
| --- | --- | --- |
| `tree.inputs.new(type, name)`, `tree.outputs.new(...)`, `tree.inputs.remove(s)`, iterating `tree.inputs` | `tree.interface.new_socket(name, in_out='INPUT', socket_type=...)`, `tree.interface.remove(item)`, iterate `tree.interface.items_tree` | 4.0 |
| `tree.interface.new_panel(name, parent=...)` | `new_panel(name)` (no `parent` argument) | 4.2 |
| `node.outputs[index]` on nodes with switchable data types | `node.outputs["identifier"]` | 4.1 |
| `modifier["Socket_2"] = value` on a Geometry Nodes modifier | `modifier.properties.inputs.<identifier>.value = value`; attribute inputs via `.type = "ATTRIBUTE"` and `.attribute_name` | 5.2 |
| Principled BSDF `"Subsurface"` | `"Subsurface Weight"` | 4.0 |
| Principled BSDF `"Subsurface Color"` | `"Base Color"` | 4.0 (removed) |
| Principled BSDF `"Specular"` | `"Specular IOR Level"` | 4.0 |
| Principled BSDF `"Specular Tint"` as a float | `"Specular Tint"` as a color | 4.0 |
| Principled BSDF `"Transmission"` | `"Transmission Weight"` | 4.0 |
| Principled BSDF `"Coat"` | `"Coat Weight"` | 4.0 |
| Principled BSDF `"Sheen"` | `"Sheen Weight"` | 4.0 |
| Principled BSDF `"Emission"` | `"Emission Color"` (`"Emission Strength"` is unchanged) | 4.0 |
| `ShaderNodeBsdfGlossy` | `ShaderNodeBsdfAnisotropic` (the old id still creates it) | 4.0 |
| `mat.use_nodes = True` to get a default node tree | `bpy.data.materials.new()` already has one; `use_nodes` does nothing | 5.0 (deprecated) |
| `world.use_nodes = True` | `bpy.data.worlds.new()` already has a node tree | 5.0 (deprecated) |
| `scene.use_nodes = True` then `scene.node_tree` | `tree = bpy.data.node_groups.new(name, "CompositorNodeTree")`; `scene.compositing_node_group = tree` | 5.0 (`node_tree` removed) |
| Compositor nodes such as `CompositorNodeGamma` | The shader node equivalent, such as `ShaderNodeGamma` | 5.0 |
| `CompositorNodeOutputFile.base_path`, `file_slots`, `layer_slots` | `directory`, `file_name`, `file_output_items` | 5.0 (removed) |
| Compositor Box/Ellipse Mask `width` / `height`; AOV Output `name`; Geometry Color `color` | `mask_width` / `mask_height`; `aov_name`; `value` | 4.2 |
| Changing a reroute's socket type directly | `reroute_node.socket_idname` | 4.3 |
| Sky Texture inputs `sun_direction`, `turbidity`, `ground_albedo` | Removed | 5.0 |

## Rendering and EEVEE

| Old pattern | Current pattern | Changed in |
| --- | --- | --- |
| `scene.render.engine = 'BLENDER_EEVEE'` (legacy EEVEE) | `'BLENDER_EEVEE_NEXT'` | 4.2 |
| `scene.render.engine = 'BLENDER_EEVEE_NEXT'` | `'BLENDER_EEVEE'` | 5.0 |
| `scene.eevee.use_motion_blur`, `scene.eevee.motion_blur_shutter`, `scene.eevee.motion_blur_position`, `scene.cycles.motion_blur_position` | `scene.render.use_motion_blur`, `scene.render.motion_blur_shutter`, `scene.render.motion_blur_position` | 4.2 |
| `light.cycles.cast_shadow` | `light.use_shadow` | 4.2 |
| `material.blend_method` | `material.surface_render_method` (`blend_method` remains, deprecated) | 4.2 |
| `material.show_transparent_back` | `material.use_transparency_overlap` | 4.2 |
| `material.use_screen_refraction` | `material.use_raytrace_refraction` | 4.2 |
| `material.shadow_method`, `light.use_contact_shadow`, `scene.eevee.use_bloom` and other bloom, SSR, GTAO, and soft shadow settings | Removed; the new EEVEE has no equivalent property | 4.2 (deprecated), 4.3 (removed) |
| `scene.eevee.gtao_distance` | `view_layer.eevee.ambient_occlusion_distance` | 5.0 |
| `scene.eevee.use_gtao`, `gtao_quality` | Removed | 5.0 |
| Light probe types `CUBEMAP`, `PLANAR`, `GRID` | `SPHERE`, `PLANE`, `VOLUME` | 4.1 |
| Render pass names such as `'DiffCol'`, `'IndexMA'`, `'Z'` | `'Diffuse Color'`, `'Material Index'`, `'Depth'` | 5.0 |
| Setting `image_settings.file_format` alone | Set `image_settings.media_type` first, then `file_format` | 5.0 |
| Material `displacement_method` on `mat.cycles` | `mat.displacement_method` | 4.1 |

## Animation and rigging

| Old pattern | Current pattern | Changed in |
| --- | --- | --- |
| `action.fcurves.new(path, index=i, action_group="G")` | `anim_utils.action_ensure_channelbag_for_slot(action, slot).fcurves.new(path, index=i, group_name="G")` | 4.4 (deprecated), 5.0 (removed) |
| `action.fcurves.find(...)` then `new(...)` if missing | `channelbag.fcurves.ensure(path, index=i, group_name="G")` | 5.0 |
| `action.groups` | `channelbag.groups` | 4.4 (deprecated), 5.0 (removed) |
| `action.id_root` | `action_slot.target_id_type` | 4.4 (deprecated), 5.0 (removed) |
| Assigning `anim_data.action` and assuming it animates | Also check or set `anim_data.action_slot` (for example `anim_data.action_suitable_slots[0]`) | 4.4 |
| Armature layers and bone groups | Bone collections (`armature.collections`) and bone colors | 4.0 |
| `edit_bones.new()` adding the bone to a collection | It adds to none; assign to `arm.collections.active` yourself | 4.0 |
| `bone.use_inherit_scale` | `bone.inherit_scale` | 4.0 |
| `armature.bones[i].select` / `select_head` / `select_tail` | `pose.bones[i].select` in pose mode, `edit_bones[i].select` in edit mode | 5.0 (removed) |
| `armature.bones[i].hide` to hide in pose or object mode | `pose.bones[i].hide` (`bone.hide` now affects edit mode) | 5.0 |
| `context.space_data.action` in the Dope Sheet | `context.active_action` | 5.0 |
| `anim_utils.bake_action(obj, ..., keyword flags)` | `bake_action(...)` with an `anim_utils.BakeOptions` dataclass, every field set | 4.0 |

## Sequencer, assets, grease pencil, and I/O

| Old pattern | Current pattern | Changed in |
| --- | --- | --- |
| `bpy.types.Sequence` and every `*Sequence` type | `bpy.types.Strip` and `*Strip` types | 4.4 |
| `context.sequences`, `context.selected_sequences`, `context.active_sequence_strip`, `SequenceEditor.sequences`, `sequences_all` | `context.strips`, `context.selected_strips`, `context.active_strip`, `SequenceEditor.strips`, `strips_all` | 4.4 (deprecated); the old names are not in the 5.2 API |
| Strip `frame_final_start`, `frame_final_end`, `frame_final_duration`, `frame_start`, `frame_duration` | `left_handle`, `right_handle`, `duration`, `content_start`, `content_duration` | 5.1 (old names deprecated) |
| `strips.new_effect(..., seq1=, seq2=)` | `input1=`, `input2=` | 4.5 |
| `context.scene` as the sequencer's scene | `context.sequencer_scene` | 5.0 |
| `bpy.data.grease_pencils` for annotations; `bpy.types.GPencilStroke` etc. | `bpy.data.annotations`; `AnnotationStroke` etc. | 5.0 |
| `bpy.data.grease_pencils_v3`, `bpy.types.GreasePencilv3` | `bpy.data.grease_pencils`, `bpy.types.GreasePencil` | 5.0 |
| `context.asset_file_handle`, `context.selected_asset_files` | `context.asset`, `context.selected_assets` | 4.0 |
| `bpy.types.AssetHandle`, `UILayout.template_asset_view()` | `AssetRepresentation`; the asset shelf | 5.0 (removed) |
| `bpy.ops.import_scene.obj` / `export_scene.obj` | `bpy.ops.wm.obj_import` / `wm.obj_export` | 4.0 |
| `bpy.ops.import_mesh.ply` / `export_mesh.ply` | `bpy.ops.wm.ply_import` / `wm.ply_export` | 4.0 |
| `wm.usd_import(import_subdiv=, attr_import_mode=)` | `import_subdivision=`, `property_import_mode=` | 5.0 |
| `wm.usd_export(export_textures=)` | `export_textures_mode=` | 5.0 |
| `scene.alembic_export` | `bpy.ops.wm.alembic_export` | 5.0 (removed) |
| `bl_info` in the add-on script | `blender_manifest.toml` (extensions); `bl_info` still works but is legacy | 4.2 |
| `import pyopenvdb` | `import openvdb` | 4.4 |
