---
name: blender-animation-rigging
description: Use when animating or rigging in Blender 5.x with Python (bpy), directly or through the Blender MCP server - inserting keyframes, reading or editing F-Curves in slotted/layered Actions, assigning Actions and action slots, drivers, constraints, armatures and bones, IK/FK, bone collections, shape keys, the NLA, and baking. Also use when fixing `AttributeError: 'Action' object has no attribute 'fcurves'` or an Action that is assigned but does not animate. Triggers include "keyframe", "animate this object", "F-Curve", "fcurve", "action slot", "channelbag", "layered action", "driver", "constraint", "armature", "rig", "bone", "IK", "pole target", "FK/IK switch", "bone collection", "shape key", "NLA strip", "bake animation", "action.fcurves", and "copy animation to another object".
---

Adapted from ra100/blender-claude-plugin (MIT); see LICENSE.

# Blender Animation and Rigging

Keyframes, F-Curves, Actions, drivers, constraints, armatures, shape keys, and the NLA in
Blender 5.x, driven from Python. The full API patterns are in `references/python_api.md`, and every
constraint type with its properties is in `references/constraint_reference.md`.

For general bpy rules (check the Blender version, never guess an API name, prefer the data API to
operators, `temp_override`), follow `blender-current-api`. To prove a change worked, follow
`blender-verify`.

## Working through the Blender MCP server

When the official Blender MCP server (Blender Lab) is connected, work in the running session:

- `get_objects_summary` and `get_object_detail_summary` to read the scene and the object you will
  change before touching it.
- `search_api_docs` and `get_python_api_docs` to confirm a property, operator, or enum value before
  using it. The bundled docs match the running Blender.
- `execute_blender_code` to make the change. Keep each block small and safe to re-run. Assign a
  JSON-serialisable dict to `result` to return what you need to check.
- `get_screenshot_of_window_as_image`, `render_thumbnail_to_path`, or `render_viewport_to_path` to
  look at the result, for example at two frames of an animation.

Without the server, write a script and run it headless as `blender-verify` describes.

## Which section

- Animate an object or bone: Keyframes.
- Read, edit, or add F-Curves, interpolation, or F-Curve modifiers: Actions and F-Curves, then
  `references/python_api.md`.
- Copy or share animation between objects: Assigning Actions and slots.
- Build a rig: Armatures, then IK.
- Drive one property from another: Drivers.
- Pick a constraint: `references/constraint_reference.md`.
- Shape keys, NLA, baking: the sections below, then `references/python_api.md`.

## Keyframes

`keyframe_insert()` is the simplest way to animate and works in any mode. It creates the Action, the
slot, and the F-Curve when they are missing.

```python
import bpy

obj = bpy.data.objects["Cube"]

obj.location = (0, 0, 0)
obj.keyframe_insert(data_path="location", frame=1)
obj.location = (5, 0, 0)
obj.keyframe_insert(data_path="location", frame=60)

obj.keyframe_insert(data_path="location", index=0, frame=1)   # X only
obj.keyframe_insert(data_path="rotation_euler", frame=1)
obj.keyframe_insert(data_path="scale", frame=1)

obj["my_prop"] = 0.0                                          # custom property
obj.keyframe_insert(data_path='["my_prop"]', frame=1)
```

| Property | `data_path` | Indices |
| --- | --- | --- |
| Location | `"location"` | 0=X, 1=Y, 2=Z |
| Rotation (Euler) | `"rotation_euler"` | 0=X, 1=Y, 2=Z |
| Rotation (Quaternion) | `"rotation_quaternion"` | 0=W, 1=X, 2=Y, 3=Z |
| Scale | `"scale"` | 0=X, 1=Y, 2=Z |
| Custom property | `'["prop_name"]'` | none |
| Shape key value | `"value"` on the key block | none |
| Modifier property | `'modifiers["Name"].property'` | per property |
| Pose bone channel | `"location"` etc. on the pose bone | as above |

## Actions and F-Curves

Actions are slotted and layered. An F-Curve lives in a **channelbag**, which belongs to one **slot**
inside a keyframe strip on a layer:

```
action.layers[i].strips[j].channelbag(slot).fcurves
```

`action.fcurves`, `action.groups`, and `action.id_root` do not exist in 5.x. Use the helpers in
`bpy_extras.anim_utils`:

```python
import bpy
from bpy_extras import anim_utils

obj = bpy.data.objects["Cube"]
anim = obj.animation_data                       # None until something is animated

# Read: the channelbag for the slot the object uses (None if it has no keys yet)
channelbag = anim_utils.animdata_get_channelbag_for_assigned_slot(anim)
if channelbag:
    for fc in channelbag.fcurves:
        print(fc.data_path, fc.array_index, len(fc.keyframe_points))
    fc = channelbag.fcurves.find("location", index=0)

# Write: create the Action, slot, layer, strip, and channelbag as needed
anim = obj.animation_data_create()
if anim.action is None:
    anim.action = bpy.data.actions.new(obj.name + "Action")
if anim.action_slot is None:
    anim.action_slot = anim.action.slots.new(id_type='OBJECT', name=obj.name)
channelbag = anim_utils.action_ensure_channelbag_for_slot(anim.action, anim.action_slot)
fc = channelbag.fcurves.ensure("location", index=2, group_name="Object Transforms")
fc.keyframe_points.insert(frame=1, value=0.0)
fc.keyframe_points.insert(frame=30, value=2.0)
```

`action.fcurve_ensure_for_datablock(obj, "location", index=0, group_name="...")` does the same in
one call once the Action is assigned to `obj`. Keyframe editing, interpolation, and F-Curve modifiers
are in `references/python_api.md`.

### Assigning Actions and slots

An Action animates nothing until the data-block is also bound to one of its slots. Assigning
`anim.action` picks a slot automatically only when one matches (same ID type and name, or the
`last_slot_identifier`). Always check:

```python
anim = target.animation_data_create()
anim.action = action
if anim.action_slot is None and anim.action_suitable_slots:
    anim.action_slot = anim.action_suitable_slots[0]
```

`anim.action_slot` takes an `ActionSlot`; `anim.action_slot_handle` is the same binding as the
slot's integer `handle`. A slot's `handle` is read-only; you never assign an object to it. Several
data-blocks may share one slot, and then they play the same animation. To copy animation so the
target can be edited on its own, copy the Action and bind the target to the copy's slot:

```python
src_action = src.animation_data.action
new_action = src_action.copy()
anim = dst.animation_data_create()
anim.action = new_action
anim.action_slot = anim.action_suitable_slots[0]
```

`slot.users()` lists the data-blocks a slot animates. NLA strips and the Action constraint have the
same `action_slot` / `action_suitable_slots` properties.

## Armatures

Bones are created as edit bones, which exist only in Edit Mode, so this is one of the few places an
operator (`mode_set`) is needed. In background mode it works when the armature is the active object.

```python
import bpy

arm_data = bpy.data.armatures.new("Rig")
arm_obj = bpy.data.objects.new("Rig", arm_data)
bpy.context.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj

bpy.ops.object.mode_set(mode='EDIT')
eb = arm_data.edit_bones
root = eb.new("Root");   root.head = (0, 0, 0);     root.tail = (0, 0, 0.5)
spine = eb.new("Spine"); spine.head = root.tail;     spine.tail = (0, 0, 1.0)
spine.parent = root;     spine.use_connect = True
upper = eb.new("UpperArm.L"); upper.head = (0.2, 0, 1.0); upper.tail = (0.7, 0, 1.0)
upper.parent = spine
lower = eb.new("LowerArm.L"); lower.head = upper.tail;    lower.tail = (1.2, 0, 1.0)
lower.parent = upper;    lower.use_connect = True
bpy.ops.object.mode_set(mode='OBJECT')
```

A new edit bone belongs to no bone collection. Bone layers and bone groups do not exist; use bone
collections (`arm_data.collections.new("Deform")`, then `coll.assign(bone)`) and bone colors
(`pose_bone.color.palette = 'THEME01'`). See `references/python_api.md`.

## IK

The IK constraint type string is `'IK'`. Constraints can be added in Object Mode; no mode switch is
needed.

```python
import bpy

arm_obj = bpy.data.objects["Rig"]
ik = arm_obj.pose.bones["LowerArm.L"].constraints.new('IK')
ik.target = bpy.data.objects["IK_Target"]    # an Empty, or the armature plus ik.subtarget = "Bone"
ik.chain_count = 2                           # bones in the chain; 0 means up to the root
ik.pole_target = bpy.data.objects["Pole_Target"]
ik.pole_angle = 0.0                          # adjust if the elbow or knee points the wrong way
ik.use_rotation = False                      # True also matches the target's rotation
```

An FK/IK switch drives the constraint `influence` from a custom property; the full pattern is in
`references/constraint_reference.md`.

## Drivers

`driver_add()` returns the driver's F-Curve. That F-Curve starts with two keyframes, not a
Generator modifier.

```python
import bpy

obj = bpy.data.objects["Cube"]
fc = obj.driver_add("scale", 1)              # Y scale
drv = fc.driver
drv.type = 'SCRIPTED'                        # or 'AVERAGE', 'SUM', 'MIN', 'MAX'

var = drv.variables.new()
var.name = "ctrl_x"
var.type = 'TRANSFORMS'
var.targets[0].id = bpy.data.objects["Controller"]
var.targets[0].transform_type = 'LOC_X'
var.targets[0].transform_space = 'WORLD_SPACE'
drv.expression = "ctrl_x * 2"
```

| Variable type | Reads |
| --- | --- |
| `'SINGLE_PROP'` | Any RNA property: `targets[0].id` plus `targets[0].data_path` (e.g. `'["my_prop"]'`) |
| `'TRANSFORMS'` | A transform channel of an object or bone (`bone_target`) |
| `'ROTATION_DIFF'` | The rotation difference between two objects or bones |
| `'LOC_DIFF'` | The distance between two objects or bones |
| `'CONTEXT_PROP'` | `'ACTIVE_SCENE'` or `'ACTIVE_VIEW_LAYER'` properties |

`transform_type`: `LOC_X/Y/Z`, `ROT_X/Y/Z/W`, `SCALE_X/Y/Z`, `SCALE_AVG`. `transform_space`:
`WORLD_SPACE`, `TRANSFORM_SPACE`, `LOCAL_SPACE`. Remove with `obj.driver_remove("scale", 1)`.

## Shape keys

```python
import bpy

obj = bpy.data.objects["Face"]
if obj.data.shape_keys is None:
    obj.shape_key_add(name="Basis", from_mix=False)
smile = obj.shape_key_add(name="Smile", from_mix=False)
for i, v in enumerate(smile.data):
    if obj.data.vertices[i].co.z > 0.5:
        v.co.y += 0.1

smile.value = 0.0
smile.keyframe_insert(data_path="value", frame=1)
smile.value = 1.0
smile.keyframe_insert(data_path="value", frame=30)
```

Key block properties: `value`, `slider_min`, `slider_max`, `mute`, `relative_key`, `vertex_group`,
`interpolation`. Shape key keyframes live on the `Key` data-block (`obj.data.shape_keys`), not on
the object. `bpy.ops.object.shape_key_apply_to_basis()` (5.1 and later) applies the selected shape
keys to the basis and removes them; `bpy.ops.object.shape_key_make_basis()` makes the active key the
basis. Both act on the active object.

## NLA

```python
anim = obj.animation_data
action = anim.action
track = anim.nla_tracks.new()
track.name = "Walk Cycle"
strip = track.strips.new(name="Walk", start=1, action=action)
anim.action = None                           # the strip now plays the Action
```

The strip binds its own slot on assignment; check `strip.action_slot` when the Action has several.
Strip properties are in `references/python_api.md`.

## Mode and data gotchas

1. `armature.edit_bones` is only filled in Edit Mode. Do not keep edit bone references across a mode
   switch; look them up again by name.
2. `obj.pose.bones` works in Object and Pose Mode. Keyframes, constraints, and drivers on pose bones
   can all be set from Object Mode.
3. Selection and visibility of bones in Object and Pose Mode are `pose_bone.select` and
   `pose_bone.hide`. `bone.select`, `select_head`, and `select_tail` do not exist; `bone.hide`
   affects Edit Mode only.
4. Editing a mesh in Edit Mode edits the active shape key, not the basis, unless the basis is active.
5. `obj.keyframe_insert()` works in any mode; `bpy.ops.anim.keyframe_insert()` needs the right
   context. Prefer the data API.
6. Set `edit_bone.roll` in Edit Mode. A wrong roll makes IK chains flip.
7. `armature.bones[...].head_local` is the rest position. `pose.bones[...].head` is the posed
   position and read-only.

## When the animation looks wrong

- **Nothing plays:** the Action is assigned but `anim.action_slot` is `None`, or the frame range
  (`scene.frame_start` / `frame_end`) does not cover the keys, or an NLA track is muted or soloed.
- **Keys on the wrong channel:** check `fc.data_path` and `fc.array_index` in the channelbag.
- **IK flips:** move the pole target or fix the bone roll.
- **Driver does nothing:** check the expression, variable names, target ids, and dependency
  cycles. A driver whose expression calls a Python function needs auto-run scripts enabled.
- **Shape key does not blend:** the Basis must exist and `relative_key` must point at it.
- **Constraint has no effect:** `influence` is 0, `mute` is on, the target is missing, or the bone
  name in `subtarget` is misspelled.

Then read the result back and look at it at two or more frames, as `blender-verify` describes.
