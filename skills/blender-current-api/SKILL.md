---
name: blender-current-api
description: Use whenever writing, reviewing, or upgrading Blender Python (bpy) scripts or add-ons, including headless or command-line Blender runs. Also use when fixing "AttributeError: ... has no attribute" or "... object has no attribute" errors from bpy, "poll() failed, context is incorrect" operator errors, TypeError from passing a dict to an operator, upgrading scripts to Blender 4.x or 5.x, scripting geometry nodes, shader nodes, or compositor nodes, creating materials, keyframes and Actions, or setting the render engine. Triggers include "bpy", "blender python", "blender script", "blender add-on", "blender addon", "bpy.ops", "context override", "temp_override", "bgl", "use_auto_smooth", "node_group.inputs.new", "action.fcurves", "BLENDER_EEVEE_NEXT", "Principled BSDF", "blender -b", and "upgrade to Blender 5".
---

# Current Blender Python API

Coding agents often write `bpy` from memory, and that memory is out of date. This skill covers what
current Blender (5.2 LTS) expects, and the old patterns you must not write.

The detailed mapping from old patterns to current ones is in `references/removed-apis.md`. Each row
there gives the Blender release where the change landed, taken from the official Python API release
notes.

## Before writing any bpy code

1. **Check the user's Blender version.** Ask, or read it from the environment: `bpy.app.version` is a
   tuple such as `(5, 2, 0)`, and `blender --version` prints it from the shell. Write code for that
   version, not the version you remember.
2. **When unsure an API exists, look it up** at `https://docs.blender.org/api/<major.minor>/` for
   that version (for example `https://docs.blender.org/api/4.5/`), or
   <https://docs.blender.org/api/current/> for the newest release. Per-release breaking changes are
   in the Python API section of <https://developer.blender.org/docs/release_notes/>.
3. **Never guess a property, operator, or socket name.** If it is not in the API docs, or you cannot
   see it with `dir()` or `bl_rna.properties.keys()` in the target Blender, it does not exist.
4. **Prefer the data API over operators.** Create and edit data through `bpy.data`, object and mesh
   properties, `mesh.attributes`, `node_tree.nodes` and `node_tree.links`. Data API calls work the
   same in the UI and in background mode. Operators (`bpy.ops.*`) act on the context: the active
   object, the selection, the mode, and the editor under the mouse. They fail with
   `RuntimeError: Operator bpy.ops.<name>.poll() failed, context is incorrect` when that context is
   missing, and they are slow in loops.
5. **When you must call an operator with a different context**, use `bpy.context.temp_override()`.
   Passing a context dict as the first argument to an operator was removed in 4.0.
6. **When another skill's example disagrees with this one about whether an API is current** (a
   property name, an operator argument, a socket name), follow this skill and the installed Blender
   version. Other skills are often written against an older release.

## Context overrides

```python
import bpy

objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
with bpy.context.temp_override(selected_objects=objs, active_object=objs[0]):
    bpy.ops.object.delete()
```

Keyword names match `bpy.context` members. `window`, `screen`, `area`, and `region` are also
accepted, and must be consistent (a region must belong to the area passed in). To find out which
context members an operator reads, call `override.logging_set(True)` inside the `with` block (5.0
and later).

Never write `bpy.ops.object.delete(override)` or `bpy.ops.x.y(context_dict, 'EXEC_DEFAULT')`.

## Running Blender headless

```sh
blender -b file.blend -P script.py                 # -b is --background, -P is --python
blender -b -P script.py -- --my-arg value          # args after -- are left in sys.argv
blender -b --python-expr "import bpy; print(bpy.app.version)"
blender -b file.blend --python-exit-code 1 -P script.py   # non-zero exit on a Python exception
blender -b --factory-startup -P script.py          # ignore the user's startup.blend
```

Arguments run in the order given, so put the `.blend` file before `-P` if the script needs that
file loaded. In background mode there is no window, area, or region, so operators that need a
viewport or editor fail; use the data API instead. From 5.2, a script that draws with the `gpu`
module in background mode calls `gpu.init()` first.

## Common current patterns

**Node group sockets** live on `tree.interface`, not `tree.inputs` / `tree.outputs` (4.0):

```python
tree = bpy.data.node_groups.new("MyGroup", "GeometryNodeTree")
tree.interface.new_socket(name="Geometry", in_out='INPUT', socket_type='NodeSocketGeometry')
tree.interface.new_socket(name="Geometry", in_out='OUTPUT', socket_type='NodeSocketGeometry')
for item in tree.interface.items_tree:
    if item.item_type == 'SOCKET' and item.in_out == 'INPUT':
        ...
```

`socket_type` takes base socket type names such as `NodeSocketFloat`, not subtypes such as
`NodeSocketFloatFactor`. Look sockets up on nodes by identifier or name
(`node.inputs["Geometry"]`), not by index; several nodes change their sockets with their data type.

**Geometry Nodes modifier inputs** (5.2) are RNA properties, not custom properties:
`mod.properties.inputs.<identifier>.value = 5.0`, not `mod["Socket_2"] = 5.0`.

**Principled BSDF sockets** (renamed in 4.0): `Subsurface Weight`, `Specular IOR Level`,
`Transmission Weight`, `Coat Weight`, `Sheen Weight`, `Emission Color`. `Emission Strength` is
unchanged. `Subsurface Color` is gone (subsurface uses `Base Color`), and `Specular Tint` is a
color, not a float.

**Materials and worlds** (5.0): `bpy.data.materials.new()` and `bpy.data.worlds.new()` already
create a default node tree. `use_nodes` is deprecated and does nothing; do not rely on it.

**Compositor** (5.0): `scene.node_tree` is gone. Create a `CompositorNodeTree` with
`bpy.data.node_groups.new(...)` and assign it to `scene.compositing_node_group`.

**Smooth shading** (4.1): meshes have no `use_auto_smooth` or `auto_smooth_angle`. Use
`mesh.shade_smooth()` / `mesh.shade_flat()` and `mesh.set_sharp_from_angle(angle=...)` on the data,
or the `bpy.ops.object.shade_auto_smooth()` operator, which adds the Smooth by Angle modifier. Read
normals from `mesh.corner_normals`; `calc_normals_split()` is gone.

**Mesh data** goes through the attribute API: `mesh.attributes.new(name, type, domain)`,
`mesh.attributes["name"].data.foreach_get(...)`, and `mesh.color_attributes`. Creases, bevel
weights, and the sculpt mask are named attributes (`crease_vert`, `crease_edge`,
`bevel_weight_vert`, `bevel_weight_edge`, `.sculpt_mask`), not per-element properties.

**Actions** are slotted (4.4), and `action.fcurves`, `action.groups`, and `action.id_root` were
removed in 5.0. Keep using `obj.keyframe_insert("location", index=0)` when it is enough. To work
with F-Curves directly, go through the channelbag for the slot:

```python
from bpy_extras import anim_utils

anim = obj.animation_data_create()
action = bpy.data.actions.new("ObjAction")
anim.action = action
if anim.action_slot is None:
    anim.action_slot = action.slots.new(id_type='OBJECT', name=obj.name)
channelbag = anim_utils.action_ensure_channelbag_for_slot(action, anim.action_slot)
fc = channelbag.fcurves.ensure("location", index=2, group_name="Object Transforms")
```

**Render engine id**: EEVEE is `'BLENDER_EEVEE'` in 5.0 and later. In 4.2 through 4.5 it was
`'BLENDER_EEVEE_NEXT'`. Cycles is `'CYCLES'`. For a script that must run on both:

```python
scene.render.engine = 'BLENDER_EEVEE' if bpy.app.version >= (5, 0, 0) else 'BLENDER_EEVEE_NEXT'
```

**Drawing**: the `bgl` module was removed in 5.0. Use the `gpu` module (`gpu.shader`, `gpu.types`,
`gpu.state`, `gpu_extras.batch`) and create shaders with `gpu.shader.create_from_info()`.
`Image.bindcode` is gone; use `gpu.texture.from_image(image)`.

**Add-on properties** (5.0): properties defined with `bpy.props` are no longer reachable as custom
properties. `scene["cycles"]` or `obj["my_addon"]` do not return them; use attribute access
(`scene.cycles`, `obj.my_addon`), and `property_unset()` to reset.

## Quick "never write" list

`bpy.ops.x.y(override_dict)`, `import bgl`, `tree.inputs.new(...)` / `tree.outputs.new(...)` on a
node group, `mesh.use_auto_smooth`, `mesh.auto_smooth_angle`, `mesh.calc_normals()`,
`mesh.calc_normals_split()`, `edge.crease`, `edge.bevel_weight`, `action.fcurves`, `action.groups`,
`action.id_root`, `'BLENDER_EEVEE_NEXT'` on 5.x, `scene.node_tree` for compositing,
Principled sockets `"Specular"`, `"Subsurface"`, `"Emission"`, `"Transmission"`,
`bpy.types.Sequence`, `SequenceEditor.sequences`, `bpy.ops.import_scene.obj`, and
`bpy.app.version_char`. See `references/removed-apis.md` for what to write instead.
