# Animation and rigging: Python API patterns (Blender 5.x)

Every block assumes `import bpy` and an object named in the code. Look up anything not shown here
with `search_api_docs` / `get_python_api_docs`, or at <https://docs.blender.org/api/current/>.

## Keyframe insertion

### Objects

```python
import bpy

obj = bpy.data.objects["Cube"]

obj.location = (0, 0, 0)
obj.keyframe_insert(data_path="location", frame=1)
obj.rotation_euler = (0, 0, 1.5708)
obj.keyframe_insert(data_path="rotation_euler", frame=30)
obj.scale = (2, 2, 2)
obj.keyframe_insert(data_path="scale", frame=30)

obj.keyframe_insert(data_path="location", index=2, frame=1)   # Z only
obj.keyframe_delete(data_path="location", frame=1)

obj["my_prop"] = 0.0
obj.keyframe_insert(data_path='["my_prop"]', frame=1)
```

### Pose bones

```python
arm_obj = bpy.data.objects["Rig"]
pb = arm_obj.pose.bones["Spine"]

pb.location = (0, 0, 0)
pb.keyframe_insert(data_path="location", frame=1)
pb.rotation_mode = 'QUATERNION'              # the default for bones
pb.rotation_quaternion = (1, 0, 0, 0)
pb.keyframe_insert(data_path="rotation_quaternion", frame=1)
```

The F-Curves land in the armature object's Action with paths such as
`pose.bones["Spine"].location`.

### Material node inputs and constraints

```python
mat = bpy.data.materials["Material"]
bsdf = mat.node_tree.nodes["Principled BSDF"]
bsdf.inputs["Roughness"].default_value = 0.1
bsdf.inputs["Roughness"].keyframe_insert(data_path="default_value", frame=1)

con = obj.constraints["Copy Location"]
con.influence = 1.0
con.keyframe_insert(data_path="influence", frame=1)
```

Material keys go into the material's own Action (`mat.node_tree.animation_data`), not the object's.

## Actions, slots, layers, channelbags

The hierarchy is:

```
Action
├── slots[]              one per animated data-block identity (ID type + name)
└── layers[]
    └── strips[]         keyframe strips (strip.type == 'KEYFRAME')
        └── channelbags[]  one per slot: .slot, .fcurves, .groups
```

A data-block's `animation_data` holds both `action` and `action_slot`. The `bpy_extras.anim_utils`
helpers cover the common cases:

| Helper | Returns |
| --- | --- |
| `animdata_get_channelbag_for_assigned_slot(anim_data)` | The channelbag of the assigned Action and slot, or `None` |
| `action_get_channelbag_for_slot(action, slot)` | The channelbag for that slot, or `None` |
| `action_ensure_channelbag_for_slot(action, slot)` | The channelbag, creating the layer, strip, and channelbag if needed |
| `action_get_first_suitable_slot(action, id_type)` | The first slot for that ID type, or `None` |

### Reading F-Curves

```python
from bpy_extras import anim_utils

obj = bpy.data.objects["Cube"]
channelbag = anim_utils.animdata_get_channelbag_for_assigned_slot(obj.animation_data)
if channelbag:
    for fc in channelbag.fcurves:
        print(fc.data_path, fc.array_index, len(fc.keyframe_points))
    loc_x = channelbag.fcurves.find("location", index=0)
    for group in channelbag.groups:
        print(group.name)
```

To visit every F-Curve of every slot in an Action:

```python
def all_fcurves(action):
    for layer in action.layers:
        for strip in layer.strips:
            if strip.type != 'KEYFRAME':
                continue
            for channelbag in strip.channelbags:
                for fc in channelbag.fcurves:
                    yield channelbag.slot, fc

for slot, fc in all_fcurves(bpy.data.actions["CubeAction"]):
    print(slot.identifier, fc.data_path, fc.array_index)
```

### Creating F-Curves

```python
from bpy_extras import anim_utils

obj = bpy.data.objects["Cube"]
anim = obj.animation_data_create()
if anim.action is None:
    anim.action = bpy.data.actions.new(obj.name + "Action")
if anim.action_slot is None:
    anim.action_slot = anim.action.slots.new(id_type='OBJECT', name=obj.name)

channelbag = anim_utils.action_ensure_channelbag_for_slot(anim.action, anim.action_slot)
fc = channelbag.fcurves.ensure("location", index=0, group_name="Object Transforms")
# .new() raises if the F-Curve exists; .ensure() returns the existing one.

# One-call form once the Action is assigned to obj:
fc_y = anim.action.fcurve_ensure_for_datablock(obj, "location", index=1, group_name="Object Transforms")
```

`channelbag.fcurves.remove(fc)` deletes one; `channelbag.fcurves.clear()` deletes all of them.
`strip.key_insert(slot, data_path, array_index, value, time)` on a keyframe strip inserts a key
directly.

### Assigning and copying Actions

```python
anim = target.animation_data_create()
anim.action = action
if anim.action_slot is None and anim.action_suitable_slots:
    anim.action_slot = anim.action_suitable_slots[0]

# Or choose the slot that will be picked before assigning:
anim.last_slot_identifier = "OBCube"          # ID-type prefix + name
anim.action = action
```

- `anim.action_slot` is the bound `ActionSlot`; `anim.action_slot_handle` is its integer `handle`.
  A slot's `handle`, `identifier`, and `target_id_type` are read-only.
- `action.slots.new(id_type='OBJECT', name="Cube")` creates a slot; `slot.users()` lists what it
  animates; `slot.duplicate()` copies a slot and its animation within the same Action.
- Two objects bound to the same slot play the same curves. To give a target its own editable copy,
  bind it to a copy of the Action (`action.copy()`) or to a duplicated slot.
- NLA strips (`strip.action_slot`) and the Action constraint (`con.action_slot`) bind slots the same
  way and pick the first compatible slot automatically.

### Action properties

```python
action = bpy.data.actions.new(name="WalkCycle")
action.use_fake_user = True          # keep it when nothing uses it
action.frame_range                   # (start, end): manual range if set, else the keys' range
action.curve_frame_range             # always the keys' range
action.use_frame_range = True        # use the manual range below
action.frame_start = 1
action.frame_end = 24
action.use_cyclic = True             # cyclic animation (needs the manual range)
action.is_empty, action.is_action_layered
bpy.data.actions.remove(action)
```

## Editing keyframes

```python
fc = channelbag.fcurves.find("location", index=0)

kp = fc.keyframe_points.insert(frame=15, value=3.0)
kp.interpolation = 'BEZIER'          # CONSTANT, LINEAR, BEZIER, SINE, QUAD, CUBIC, QUART, QUINT,
                                     # EXPO, CIRC, BACK, BOUNCE, ELASTIC
kp.easing = 'AUTO'                   # AUTO, EASE_IN, EASE_OUT, EASE_IN_OUT
kp.handle_left_type = 'AUTO_CLAMPED' # FREE, ALIGNED, VECTOR, AUTO, AUTO_CLAMPED
kp.handle_right_type = 'AUTO_CLAMPED'

for kp in fc.keyframe_points:
    frame, value = kp.co
    kp.interpolation = 'LINEAR'

for kp in list(fc.keyframe_points):
    if kp.co.x == 30:
        fc.keyframe_points.remove(kp)
        break

fc.update()                          # re-sort and recalculate handles after edits
```

Setting interpolation on every curve of an object:

```python
from bpy_extras import anim_utils

channelbag = anim_utils.animdata_get_channelbag_for_assigned_slot(obj.animation_data)
for fc in channelbag.fcurves:
    for kp in fc.keyframe_points:
        kp.interpolation = 'LINEAR'
    fc.update()
```

### Evaluating and sampling

```python
value = fc.evaluate(15.5)
start, end = fc.range()
fc.convert_to_samples(1, 100)        # bake to samples (keyframe_points become sampled_points)
fc.convert_to_keyframes(1, 100)      # back to editable keyframes
fc.bake(1, 100, step=1.0)            # replace keys with one per step
```

## F-Curve modifiers

`fc.modifiers.new(type)` with `type` one of `GENERATOR`, `FNGENERATOR`, `ENVELOPE`, `CYCLES`,
`NOISE`, `LIMITS`, `STEPPED`, `SMOOTH`.

```python
mod = fc.modifiers.new('NOISE')
mod.strength = 0.5
mod.scale = 2.0
mod.phase = 0.0
mod.depth = 0

mod = fc.modifiers.new('CYCLES')
mod.mode_before = 'REPEAT'           # NONE, REPEAT, REPEAT_OFFSET, MIRROR
mod.mode_after = 'REPEAT'
mod.cycles_before = 0                # 0 means infinite
mod.cycles_after = 0

mod = fc.modifiers.new('GENERATOR')
mod.mode = 'POLYNOMIAL'              # or POLYNOMIAL_FACTORISED
mod.poly_order = 1
mod.coefficients = (0.0, 1.0)        # y = 0 + 1*x

mod = fc.modifiers.new('STEPPED')
mod.frame_step = 2
mod.frame_offset = 0

mod = fc.modifiers.new('LIMITS')
mod.use_min_y = True
mod.min_y = 0.0
mod.use_max_y = True
mod.max_y = 10.0

mod = fc.modifiers.new('ENVELOPE')
```

**Gaussian Smooth** (5.1 and later) smooths a curve without changing its keys, for example jittery
motion capture. It only works as the first modifier in the stack.

```python
mod = fc.modifiers.new('SMOOTH')
mod.sigma = 1.0                      # width of the Gaussian, in frames; lower is sharper
mod.filter_width = 3                 # frames averaged around each key; higher smooths more
```

Every modifier also has `mute`, `influence` / `use_influence`, and a restricted frame range
(`use_restricted_range`, `frame_start`, `frame_end`, `blend_in`, `blend_out`).

## Drivers

```python
fc = obj.driver_add("location", 0)   # returns the driver F-Curve
drv = fc.driver
drv.type = 'SCRIPTED'                # AVERAGE, SUM, SCRIPTED, MIN, MAX
drv.expression = "var1 + var2 * 2"

var = drv.variables.new()
var.name = "var1"
var.type = 'SINGLE_PROP'
var.targets[0].id_type = 'OBJECT'
var.targets[0].id = bpy.data.objects["Target"]
var.targets[0].data_path = "location.x"

var = drv.variables.new()
var.name = "var2"
var.type = 'TRANSFORMS'
var.targets[0].id = bpy.data.objects["Rig"]
var.targets[0].bone_target = "Hand.L"          # optional, for armatures
var.targets[0].transform_type = 'LOC_X'
var.targets[0].transform_space = 'WORLD_SPACE' # WORLD_SPACE, TRANSFORM_SPACE, LOCAL_SPACE

var = drv.variables.new()
var.name = "angle"
var.type = 'ROTATION_DIFF'
var.targets[0].id = bpy.data.objects["Rig"]; var.targets[0].bone_target = "Bone1"
var.targets[1].id = bpy.data.objects["Rig"]; var.targets[1].bone_target = "Bone2"

var = drv.variables.new()
var.name = "dist"
var.type = 'LOC_DIFF'
var.targets[0].id = bpy.data.objects["Obj1"]
var.targets[1].id = bpy.data.objects["Obj2"]

obj.driver_remove("location", 0)
obj.driver_remove("location")        # all indices
```

Drivers are listed in `obj.animation_data.drivers` (F-Curves), not in the Action. A driver's
F-Curve starts with two keyframes that map its input to its output; add keys to reshape the mapping
or clear them for a straight pass-through. Driver targets can set `use_fallback_value` and
`fallback_value` to keep working when the target property is missing.

## Armatures and bones

```python
import bpy

arm_data = bpy.data.armatures.new("Skeleton")
arm_data.display_type = 'OCTAHEDRAL'  # OCTAHEDRAL, STICK, BBONE, ENVELOPE, WIRE
arm_obj = bpy.data.objects.new("Skeleton", arm_data)
bpy.context.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj

bpy.ops.object.mode_set(mode='EDIT')
hip = arm_data.edit_bones.new("Hip")
hip.head = (0, 0, 1.0)
hip.tail = (0, 0, 1.3)
spine = arm_data.edit_bones.new("Spine")
spine.head = hip.tail
spine.tail = (0, 0, 1.6)
spine.parent = hip
spine.use_connect = True
bpy.ops.object.mode_set(mode='OBJECT')
```

### Edit bone properties (Edit Mode)

```python
bone = arm_data.edit_bones["Spine"]
bone.head, bone.tail = (0, 0, 0), (0, 0, 1)
bone.roll = 0.0
bone.parent = arm_data.edit_bones["Hip"]
bone.use_connect = True
bone.use_deform = True
bone.use_inherit_rotation = True
bone.use_local_location = True
bone.inherit_scale = 'FULL'           # FULL, FIX_SHEAR, ALIGNED, AVERAGE, NONE, NONE_LEGACY
bone.envelope_distance = 0.25
bone.envelope_weight = 1.0

bone.bbone_segments = 4               # 1 means a straight bone
bone.bbone_curveinx = 0.0             # B-Bone curve in/out, X and Z
bone.bbone_curveinz = 0.0
bone.bbone_curveoutx = 0.0
bone.bbone_curveoutz = 0.0
bone.bbone_scalein = (1, 1, 1)
bone.bbone_scaleout = (1, 1, 1)
```

### Pose bone properties

```python
pb = arm_obj.pose.bones["Spine"]
pb.location, pb.rotation_mode, pb.rotation_quaternion, pb.rotation_euler, pb.scale
pb.matrix          # pose-space matrix
pb.matrix_basis    # local transform only
pb.head, pb.tail   # posed positions, read-only

pb.color.palette = 'THEME01'          # DEFAULT, THEME01..THEME20, CUSTOM
pb.custom_shape = bpy.data.objects["WGT_Circle"]
pb.custom_shape_scale_xyz = (1, 1, 1)
pb.use_custom_shape_bone_size = True
pb.select = True                      # selection in Object/Pose Mode
pb.hide = False                       # visibility in Object/Pose Mode
```

### Bone constraints

```python
pb = arm_obj.pose.bones["Spine"]
con = pb.constraints.new('COPY_ROTATION')
con.target = arm_obj
con.subtarget = "Hip"
con.influence = 1.0

limit = pb.constraints.new('LIMIT_ROTATION')
for c in pb.constraints:
    print(c.name, c.type, c.influence)
pb.constraints.move(1, 0)            # from_index, to_index: evaluate the limit first
pb.constraints.remove(con)
```

No mode switch is needed to add or edit constraints. See `constraint_reference.md` for every type.

### Bone collections

```python
arm_data = arm_obj.data
ctrl = arm_data.collections.new("Controls")
deform = arm_data.collections.new("Deform")
mech = arm_data.collections.new("Mechanism", parent=deform)   # nested

ctrl.assign(arm_data.bones["Spine"])  # accepts a Bone, EditBone, or PoseBone
mech.is_visible = False
ctrl.is_solo = False
print([b.name for b in ctrl.bones])
```

`edit_bone.collections` / `bone.collections` list a bone's collections.

## NLA

```python
anim = obj.animation_data_create()

track = anim.nla_tracks.new()
track.name = "Base Animation"
track.mute = False
track.is_solo = False
track.lock = False

action = bpy.data.actions["WalkCycle"]
strip = track.strips.new(name="Walk", start=1, action=action)
strip.frame_start = 1
strip.action_frame_start, strip.action_frame_end = action.frame_range
strip.repeat = 1.0
strip.scale = 1.0
strip.blend_type = 'REPLACE'         # REPLACE, COMBINE, ADD, SUBTRACT, MULTIPLY
strip.influence = 1.0
strip.blend_in = 0.0
strip.blend_out = 0.0
strip.use_auto_blend = False
strip.use_reverse = False
strip.extrapolation = 'HOLD'         # NOTHING, HOLD, HOLD_FORWARD
strip.mute = False

track.strips.remove(strip)
anim.nla_tracks.remove(track)
```

Stash an Action so it is kept but does not play:

```python
track = anim.nla_tracks.new()
track.name = "[Action Stash]"
track.strips.new(name=action.name, start=1, action=action)
track.mute = True
anim.action = None
```

## Shape keys

```python
obj = bpy.data.objects["Face"]
basis = obj.shape_key_add(name="Basis", from_mix=False)   # the first key is the basis
wide = obj.shape_key_add(name="Wide", from_mix=False)
for v in wide.data:
    v.co.x *= 1.5
mixed = obj.shape_key_add(name="Mixed", from_mix=True)     # from the current mix

key_blocks = obj.data.shape_keys.key_blocks
key = key_blocks["Wide"]
key.value = 0.5
key.slider_min, key.slider_max = 0.0, 1.0
key.mute = False
key.relative_key = key_blocks["Basis"]
key.vertex_group = ""
key.interpolation = 'KEY_LINEAR'     # KEY_LINEAR, KEY_CARDINAL, KEY_CATMULL_ROM, KEY_BSPLINE

key.value = 0.0
key.keyframe_insert("value", frame=1)
key.value = 1.0
key.keyframe_insert("value", frame=30)
```

Driving a shape key from a bone:

```python
fc = key_blocks["Wide"].driver_add("value")
drv = fc.driver
drv.type = 'SCRIPTED'
var = drv.variables.new()
var.name = "jaw_rot"
var.type = 'TRANSFORMS'
var.targets[0].id = bpy.data.objects["Rig"]
var.targets[0].bone_target = "Jaw"
var.targets[0].transform_type = 'ROT_X'
var.targets[0].transform_space = 'LOCAL_SPACE'
drv.expression = "jaw_rot * -5.0"
```

Operators on the active object: `bpy.ops.object.shape_key_make_basis()` makes the active key the
basis; `bpy.ops.object.shape_key_apply_to_basis()` (5.1 and later) applies the selected keys to the
basis and removes them.

## Baking

Data API, no selection or context needed:

```python
from bpy_extras import anim_utils

scene = bpy.context.scene
opts = anim_utils.BakeOptions(
    only_selected=False, do_pose=False, do_object=True, do_visual_keying=True,
    do_constraint_clear=False, do_parents_clear=False, do_clean=False,
    do_location=True, do_rotation=True, do_scale=True, do_bbone=False,
    do_custom_props=False,
)
baked = anim_utils.bake_action_objects(
    [(obj, None)], frames=range(scene.frame_start, scene.frame_end + 1), bake_options=opts)
```

`BakeOptions` has no defaults; set every field. For armatures set `do_pose=True` (with
`only_selected` limiting it to selected bones).

Operator form, which needs the objects selected and one active:

```python
with bpy.context.temp_override(active_object=obj, selected_objects=[obj], object=obj):
    bpy.ops.nla.bake(frame_start=1, frame_end=100, only_selected=True, visual_keying=True,
                     clear_constraints=False, clear_parents=False, use_current_action=True,
                     bake_types={'OBJECT'})        # {'POSE'} for armature bones
```

## Clearing animation

```python
if obj.animation_data:
    obj.animation_data.action = None   # unassign, keep the Action data-block
    obj.animation_data_clear()         # or remove animation data, drivers, and NLA
```
