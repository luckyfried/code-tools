# Constraints reference (Blender 5.x)

Every type string and enum value below is the identifier `constraints.new()` and the properties
accept. Confirm anything not listed with `get_python_api_docs` (for example
`bpy.types.CopyRotationConstraint`) or at <https://docs.blender.org/api/current/>.

## Adding constraints

```python
import bpy

obj = bpy.data.objects["Cube"]
con = obj.constraints.new(type='COPY_LOCATION')           # object constraint

arm_obj = bpy.data.objects["Rig"]
pb = arm_obj.pose.bones["Spine"]
con = pb.constraints.new(type='COPY_LOCATION')            # bone constraint, any mode

con.name = "My Constraint"
con.influence = 1.0          # 0.0 to 1.0
con.mute = False             # disable without removing
con.target = bpy.data.objects["Target"]
con.subtarget = ""           # a bone name when the target is an armature
```

Collections: `constraints.new(type)`, `remove(con)`, `move(from_index, to_index)`,
`copy(con)`.

## Motion tracking

| Constraint | Type | Key properties |
| --- | --- | --- |
| Camera Solver | `'CAMERA_SOLVER'` | `clip`, `use_active_clip` |
| Follow Track | `'FOLLOW_TRACK'` | `clip`, `track`, `camera`, `depth_object`, `use_3d_position` |
| Object Solver | `'OBJECT_SOLVER'` | `clip`, `camera`, `object` |

## Transform

| Constraint | Type | Key properties |
| --- | --- | --- |
| Copy Location | `'COPY_LOCATION'` | `target`, `subtarget`, `use_x/y/z`, `invert_x/y/z`, `use_offset`, `target_space`, `owner_space` |
| Copy Rotation | `'COPY_ROTATION'` | `target`, `subtarget`, `use_x/y/z`, `invert_x/y/z`, `mix_mode` (`REPLACE`, `ADD`, `BEFORE`, `AFTER`, `OFFSET`), `euler_order`, spaces |
| Copy Scale | `'COPY_SCALE'` | `target`, `subtarget`, `use_x/y/z`, `power`, `use_make_uniform`, `use_offset`, `use_add`, spaces |
| Copy Transforms | `'COPY_TRANSFORMS'` | `target`, `subtarget`, `mix_mode` (`REPLACE`, `BEFORE_FULL`, `BEFORE`, `BEFORE_SPLIT`, `AFTER_FULL`, `AFTER`, `AFTER_SPLIT`), spaces |
| Limit Distance | `'LIMIT_DISTANCE'` | `target`, `subtarget`, `distance`, `limit_mode` (`LIMITDIST_INSIDE`, `LIMITDIST_OUTSIDE`, `LIMITDIST_ONSURFACE`), `use_transform_limit` |
| Limit Location | `'LIMIT_LOCATION'` | `use_min_x/y/z`, `use_max_x/y/z`, `min_x/y/z`, `max_x/y/z`, `owner_space` |
| Limit Rotation | `'LIMIT_ROTATION'` | `use_limit_x/y/z`, `min_x/y/z`, `max_x/y/z`, `euler_order`, `owner_space` |
| Limit Scale | `'LIMIT_SCALE'` | `use_min_x/y/z`, `use_max_x/y/z`, `min_x/y/z`, `max_x/y/z`, `owner_space` |
| Maintain Volume | `'MAINTAIN_VOLUME'` | `mode` (`STRICT`, `UNIFORM`, `SINGLE_AXIS`), `free_axis` (`SAMEVOL_X`, `SAMEVOL_Y`, `SAMEVOL_Z`), `volume` |
| Transformation | `'TRANSFORM'` | `target`, `map_from` / `map_to` (`LOCATION`, `ROTATION`, `SCALE`), `from_min_x`... `to_max_z`, `mix_mode`, spaces |
| Transform Cache | `'TRANSFORM_CACHE'` | `cache_file`, `object_path` |
| Geometry Attribute | `'GEOMETRY_ATTRIBUTE'` | `target`, `attribute_name`, `domain`, `data_type`, `sample_index`, `apply_target_transform`, `mix_loc`, `mix_rot`, `mix_scl`, `mix_mode` |

Geometry Attribute (5.0 and later) samples a vector, quaternion, or 4x4 matrix attribute from the
target's geometry and applies it to the owner's transform.

## Tracking

| Constraint | Type | Key properties |
| --- | --- | --- |
| Clamp To | `'CLAMP_TO'` | `target` (curve), `main_axis` (`CLAMPTO_AUTO`, `CLAMPTO_X`, `CLAMPTO_Y`, `CLAMPTO_Z`), `use_cyclic` |
| Damped Track | `'DAMPED_TRACK'` | `target`, `subtarget`, `track_axis` (`TRACK_X`, `TRACK_Y`, `TRACK_Z`, `TRACK_NEGATIVE_X/Y/Z`) |
| Locked Track | `'LOCKED_TRACK'` | `target`, `subtarget`, `track_axis`, `lock_axis` (`LOCK_X`, `LOCK_Y`, `LOCK_Z`) |
| Stretch To | `'STRETCH_TO'` | `target`, `subtarget`, `rest_length`, `bulge`, `volume` (`VOLUME_XZX`, `VOLUME_X`, `VOLUME_Z`, `NO_VOLUME`), `keep_axis` (`PLANE_X`, `PLANE_Z`, `SWING_Y`) |
| Track To | `'TRACK_TO'` | `target`, `subtarget`, `track_axis`, `up_axis` (`UP_X`, `UP_Y`, `UP_Z`), `use_target_z` |

## Relationship

| Constraint | Type | Key properties |
| --- | --- | --- |
| Action | `'ACTION'` | `target`, `action`, `action_slot`, `transform_channel` (`LOCATION_X`... `SCALE_Z`), `min`, `max`, `frame_start`, `frame_end`, `mix_mode` |
| Armature | `'ARMATURE'` | `targets` (each with `target`, `subtarget`, `weight`) |
| Child Of | `'CHILD_OF'` | `target`, `subtarget`, `use_location_x/y/z`, `use_rotation_x/y/z`, `use_scale_x/y/z`, `inverse_matrix`, `set_inverse_pending` |
| Floor | `'FLOOR'` | `target`, `subtarget`, `use_rotation`, `offset`, `floor_location` (`FLOOR_X/Y/Z`, `FLOOR_NEGATIVE_X/Y/Z`) |
| Follow Path | `'FOLLOW_PATH'` | `target` (curve), `use_fixed_location`, `offset`, `offset_factor`, `forward_axis` (`FORWARD_X/Y/Z`, `TRACK_NEGATIVE_X/Y/Z`), `up_axis`, `use_curve_follow`, `use_curve_radius` |
| Pivot | `'PIVOT'` | `target`, `subtarget`, `rotation_range` (`ALWAYS_ACTIVE`, `NX`, `NY`, `NZ`, `X`, `Y`, `Z`), `offset` |
| Shrinkwrap | `'SHRINKWRAP'` | `target`, `shrinkwrap_type` (`NEAREST_SURFACE`, `PROJECT`, `NEAREST_VERTEX`, `TARGET_PROJECT`), `distance`, `project_axis`, `use_track_normal`, `track_axis` |

Child Of has no set-inverse method on the constraint. Either set `con.set_inverse_pending = True`
(the inverse is computed on the next evaluation) or call
`bpy.ops.constraint.childof_set_inverse(constraint=con.name, owner='OBJECT')` (`owner='BONE'` for a
bone constraint) with the owner active.

## Inverse kinematics

| Constraint | Type | Key properties |
| --- | --- | --- |
| Inverse Kinematics | `'IK'` | `target`, `subtarget`, `pole_target`, `pole_subtarget`, `pole_angle`, `chain_count`, `use_rotation`, `use_location`, `use_stretch`, `iterations`, `weight`, `orient_weight`, `ik_type` (`COPY_POSE`, `DISTANCE`) |
| Spline IK | `'SPLINE_IK'` | `target` (curve), `chain_count`, `use_chain_offset`, `use_curve_radius`, `use_even_divisions`, `y_scale_mode` (`NONE`, `FIT_CURVE`, `BONE_ORIGINAL`), `xz_scale_mode` (`NONE`, `BONE_ORIGINAL`, `INVERSE_PRESERVE`, `VOLUME_PRESERVE`) |

## Spaces

`target_space` and `owner_space` accept `'WORLD'`, `'CUSTOM'` (with `space_object` /
`space_subtarget`), `'POSE'`, `'LOCAL_WITH_PARENT'`, and `'LOCAL'`. `POSE` and `LOCAL_WITH_PARENT`
only mean something for bones.

## Patterns

### FK/IK switch

Drive the IK constraint's influence from a custom property, and the FK constraint's from its
inverse.

```python
import bpy

arm_obj = bpy.data.objects["Rig"]
pb = arm_obj.pose.bones["LowerArm.L"]
arm_obj["ik_fk_switch"] = 0.0          # 0 = FK, 1 = IK

def drive_influence(con, expression):
    drv = con.driver_add("influence").driver
    drv.type = 'SCRIPTED'
    var = drv.variables.new()
    var.name = "switch"
    var.type = 'SINGLE_PROP'
    var.targets[0].id = arm_obj
    var.targets[0].data_path = '["ik_fk_switch"]'
    drv.expression = expression

drive_influence(pb.constraints["IK"], "switch")
drive_influence(pb.constraints["FK"], "1 - switch")
```

### Follow Path animation

```python
import bpy

curve_data = bpy.data.curves.new("Path", type='CURVE')
curve_data.dimensions = '3D'
spline = curve_data.splines.new('POLY')
spline.points.add(3)
for p, co in zip(spline.points, [(0, 0, 0), (2, 0, 0), (4, 2, 0), (6, 2, 1)]):
    p.co = (*co, 1.0)
path = bpy.data.objects.new("Path", curve_data)
bpy.context.collection.objects.link(path)

obj = bpy.data.objects["Cube"]
con = obj.constraints.new('FOLLOW_PATH')
con.target = path
con.use_fixed_location = True          # animate offset_factor (0..1) instead of the curve's time
con.use_curve_follow = True
con.forward_axis = 'FORWARD_Y'
con.up_axis = 'UP_Z'

con.offset_factor = 0.0
con.keyframe_insert(data_path="offset_factor", frame=1)
con.offset_factor = 1.0
con.keyframe_insert(data_path="offset_factor", frame=120)
```

### Stretch To chain

```python
chain = ["Tail.001", "Tail.002", "Tail.003", "Tail.004"]
for i, name in enumerate(chain[:-1]):
    con = arm_obj.pose.bones[name].constraints.new('STRETCH_TO')
    con.target = arm_obj
    con.subtarget = chain[i + 1]
    con.rest_length = 0.0                 # 0 recomputes it from the current length
    con.volume = 'VOLUME_XZX'
    con.keep_axis = 'SWING_Y'
```
