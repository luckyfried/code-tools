---
name: ue-control-rig-ik
description: Use for rigging and IK in Unreal Engine 5.8 - building or fixing Control Rig and Modular Control Rig assets, animating or baking with Control Rig in Sequencer, procedural rig logic in Animation Blueprints (foot placement, look-at, Full Body IK), and IK Rig / IK Retargeter setup and batch retargeting. For general AnimInstance, montage, state machine, or blend space questions, use ue-animation-system instead.
---

# Control Rig, IK Rig, and Retargeting (UE 5.8)

This skill covers four connected tools:

| Tool | Asset | What it is for |
|---|---|---|
| Control Rig | Control Rig asset (default name `<Mesh>_CtrlRig`) | Animator controls and procedural rig logic, run in Sequencer or an Animation Blueprint |
| Modular Control Rig | Control Rig asset created as `ModularRig` | Build a rig by dropping prebuilt modules (Spine, Neck, Leg, Foot, Shoulder, Arm, Finger) onto sockets |
| IK Rig | IK Rig asset | IK goals + solver stack for one skeleton, and the retarget chains for that skeleton |
| IK Retargeter | IK Retargeter asset | Maps a source IK Rig's chains onto a target IK Rig's chains and transfers animation |

Node and setting names below are the exact names Epic uses. A per-node pin list is in
`references/rig-units.md`. If a name you need is not in this skill or that file, look it up in
the editor (right-click search in the Rig Graph) or Epic's node reference before using it.
Do not guess node names.

## If Epic's Unreal MCP is connected

The Unreal MCP plugin (experimental) exposes editor tools through three meta-tools:
`list_toolsets`, `describe_toolset`, `call_tool`.

1. Call `list_toolsets` and find the Control Rig toolset (and any animation or asset toolsets).
2. Call `describe_toolset` on it and use the tool names and argument schemas it returns. Do not
   guess tool names or argument shapes.
3. Call tools only through `call_tool`.
4. After every edit that changes a rig (add/rename/reparent an element, add a node, change a pin),
   read the rig hierarchy back and confirm the element names, parents, and types match what you
   intended before making the next edit. Recompile the rig when the toolset offers it and check
   for compile errors.
5. If a needed operation is not in any toolset, fall back to Editor Python (below) or give the
   user the manual editor steps.

The server is local-only with no authentication; do not suggest exposing it beyond the machine.

## 1. Control Rig basics

**Create:** right-click a Skeletal Mesh in the Content Browser > **Create > Control Rig**
(creates `<Mesh>_CtrlRig` next to it), or **Add (+) > Animation > Control Rig > Control Rig**.
Double-click to open the Control Rig Editor.

**Rig Hierarchy panel** holds the rig elements. Right-click > **New** to add a **Bone**,
**Control**, or **Null**. Bones come from the skeleton (Import Hierarchy); controls are what the
animator grabs; nulls are invisible transforms used as spaces, pivots, and offsets. Curves live in
the **Curve Container**.

**Events (solve directions)** in the Rig Graph:

- **Construction Event** - runs once before everything else. Use it to spawn or initialize
  elements (Spawn Bone, Spawn Null, Spawn Control, Spawn Animation Channel) and set initial
  control positions.
- **Forwards Solve** - controls drive bones. This is what runs in Sequencer and in Animation
  Blueprints. Most rig logic goes here.
- **Backwards Solve** - bones drive controls. Required for **Bake To Control Rig** in Sequencer
  and for layered Control Rig tracks.

The toolbar **Solve Direction** picks what the viewport previews: Forwards Solve, Backwards Solve
(yellow border), Construction Event (red border), or Backwards and Forwards (blue border, runs
backwards then forwards - use it to test that a bake round-trips cleanly).

Click **Compile** after hierarchy changes (or enable **Auto Compile**). The **Execution Stack**
panel shows node order for debugging.

### Adding a control for a bone

1. In Rig Hierarchy, right-click the bone > **New Element > New Control**. It is named
   `<bone>_ctrl` and placed at the bone's position and orientation.
2. Press **Shift+P** to unparent it from the bone so controls form their own hierarchy.
3. In Details, set **Control Type**, **Animatable**, and the **Shape** (type, rotation, scale).
   Use the control's **Offset** transform to hold its rest placement so the animatable value
   starts at zero.
4. In the Rig Graph, drag the control in and pick **Get Control**, drag the bone in and pick
   **Set Bone**, connect Transform to Value, and wire the execution pin from Forwards Solve.

## 2. FK/IK limb rig

**FK:** one control per bone, parented control-to-control. In Forwards Solve, for each bone:
**Get Transform** (Item = the control, Space = GlobalSpace) into **Set Transform** (Item = the
bone). Set parents before children, or leave `bPropagateToChildren` on.

**IK (two-bone limb):** Control Rig's two-bone solver is **Basic IK** (category Hierarchy, works
in world space). Setup:

1. Controls: one IK end control (hand/foot) and one pole control (elbow/knee), both outside the
   bone hierarchy (parent them to a root or world-space null).
2. **Basic IK**: `ItemA` = upper bone (upperarm/thigh), `ItemB` = lower bone (lowerarm/calf),
   `EffectorItem` = end bone (hand/foot), `Effector` = the IK control's global transform
   (from **Get Transform**).
3. `PoleVector` = the pole control's global location with `PoleVectorKind` set to location (or a
   fixed direction with kind set to direction).
4. `PrimaryAxis` = the axis that points down the bone to its child; `SecondaryAxis` = the axis
   that points toward the pole. Read both off the joint axes in the viewport (Display Axes On
   Selection); they differ per skeleton.
5. Optional stretch: `bEnableStretch`, `StretchStartRatio`, `StretchMaximumRatio`.
6. After the solve, set the end bone's rotation from the IK control if the solver did not already.

"Two Bone IK" is the Animation Blueprint node, not a Control Rig unit. In Control Rig use Basic IK
(or **Basic IK Positions** / **Basic IK Transforms** / **Two Bone IK Off Plane** as listed in the
node reference). For chains longer than two bones use **Basic FABRIK**, **CCDIK**,
**Multi Effector FABRIK**, **Spring IK**, or **Full Body IK**.

**FK/IK blend:** compute the FK result and the IK result for the chain, then drive the bones with
a float control (0-1) used as the `Weight` on the IK node or to interpolate the two transforms.
Keep the switch value on an animation channel or control so it can be keyed in Sequencer.

## 3. Full Body IK (Control Rig node)

Right-click the Rig Graph > **Hierarchy > Full Body IK**, wire it into Forwards Solve.

- **Root**: usually pelvis/hips.
- **Effectors**: one entry per goal; set **Bone** and feed **Transform** from a control's
  **Get Transform**.
- **Bone Settings** (per bone): Rotation/Position **Stiffness** (0 free, 1 locked), **Limits**
  per axis (Free / Limited with min-max / Locked), **Preferred Angles** to bias which way a joint
  bends.
- **Excluded Bones**: removed from the solve entirely (they do not bend or constrain).
- **Settings**: **Iterations** (default 20; raise until effectors converge), **Mass Multiplier**
  (bone resistance), **Allow Stretch**, **Root Behavior** (Pre Pull / Pin to Input / Free),
  Global Pull Chain Alpha, Max Angle, Over Relaxation.

FBIK is best as a procedural adjustment on top of an input pose (ground alignment, reaching).
For animator-facing limbs, Basic IK with explicit pole controls is more predictable.

## 4. Modular Control Rig (experimental)

**Create:** Content Browser **Add (+) > Animation > Control Rig > Control Rig**, pick
**ModularRig**, then set **Preview Mesh** in Details.

- Modules come from the **Module Assets** panel (Control Rig Modules plugin): Spine, Neck, Leg,
  Foot, Shoulder, Arm, Finger. Drag a module onto an unresolved socket in the viewport.
- **Sockets** are attach points on the mesh. **Connectors** link modules: each module has one
  **Primary** connector (resolves to a socket) and may have **Secondary** connectors (resolve to
  bones, nulls, or controls). **Connector Rules** (Type Rule, Tag Rule, Child of Primary, And/Or)
  decide what can resolve.
- When a module is added, its **Connector Event** runs and tries to resolve connectors. Fix
  leftovers in the **Module Hierarchy** panel dropdown, with the **Use Selected** arrow button, or
  right-click the connector > **Auto Resolve**.
- The **Show Empty Sockets Only** viewport option helps when placing modules.
- **Mirror**: select modules in Module Hierarchy > right-click > **Mirror**, set **Mirror Axis**,
  **Axis to Flip**, and the name search/replace (for example `_l` to `_r`).
- Turn your own Control Rig into a module with **Switch to Rig Module**.

A biped workflow: Spine on the root socket, then Neck, Shoulders, Arms, Legs, Feet, Fingers,
resolving connectors as you go, then mirror one side. Tell the user it is experimental.

## 5. Control Rig in Sequencer

- Drag the Control Rig asset from the Content Browser into the level (opens Sequencer with the
  mesh and rig tracks), or on an existing Skeletal Mesh track click **Add (+) Track > Control Rig
  > Control Rig Classes** and pick the rig.
- Select a control and press **S** to key its transform. Reset selected controls with
  **Ctrl+G** (all: **Ctrl+Shift+G**).
- **FK Control Rig**: **Add (+) Track > Control Rig > FK Control Rig** on any skeletal mesh, no
  rig asset needed. Right-click the track > **Additive** to layer on existing animation instead of
  replacing it.
- **Bake To Control Rig**: right-click the character track > **Bake To Control Rig** > choose the
  rig. A rig only appears in this list if it has a Backwards Solve.
- **Layered Control Rig**: **Control Rig > Layered**, or right-click a track > **Convert To
  Layered**. Tracks evaluate by **Order** (default 100); key **Weight** to blend.
- Bake the result back: right-click the Skeletal Mesh track > **Bake Animation Sequence** (a
  one-off asset) or **Create Linked Animation Sequence** (stays linked to the sequence).

## 6. Control Rig in Animation Blueprints (runtime)

In the Anim Graph, right-click > **Misc > Control Rig**, set **Control Rig Class**, connect the
incoming pose to Source and the output toward Output Pose.

- **Transfer Input Pose** / **Transfer Input Curves**: feed the incoming pose and curves into the
  rig (needed for adjustments on top of animation).
- **Set Initial Transform From Mesh**: use the mesh's reference pose instead of the rig's.
- Mark a rig variable instance-editable in the Control Rig, then enable **Use Pin** on the node to
  drive it from the AnimBP; float variables can instead read an Animation Curve (**Use Curve**).
  Controls appear under the node's **Input** property and can also be pinned.

**Foot placement pattern:** in Forwards Solve, for each foot, run **Sphere Trace By Trace
Channel** (or **Sphere Trace By Object Types**) downward from above the foot; if `bHit`, offset
the foot IK target to `HitLocation` and align to `HitNormal`; lower the pelvis by the largest
foot drop; solve legs with Basic IK or Full Body IK. Smooth offsets frame to frame with the
Simulation nodes (for example **Spring Interpolate**) to avoid popping.

**Look-at pattern:** pass the target location in as a pinned variable and use **Aim** on the
head/neck bone (or the AnimBP's own **Look At** node when no rig is needed). Clamp or weight it so
the head does not flip past the shoulders.

IK Rig assets also run at runtime through the **IK Rig** Anim Graph node.

## 7. IK Rig

**Create:** **Add (+) > Animation > IK Rig** and pick the Skeletal Mesh.

- **Hierarchy** panel: bones and goals. Select an end bone > **Add (+) > New IK Goal**. The first
  goal prompts for a solver.
- **Solver Stack** panel (order matters; drag to reorder). Solvers: **Full Body IK**, **Limb IK**,
  **Body Mover**, **Pole Solver**, **Set Transform**. Right-click a bone > **Set Root Bone on
  Selected Solver**; right-click a goal > **Connect Goal to Selected Solver**.
- **IK Retargeting** panel: **Add New Chain (+)** or right-click bones > **New Retarget
  Chain...** (Chain Name, Start Bone, End Bone, optional Goal). Right-click the hip bone > **Set
  Pelvis**.

Make chains for spine, neck, head, each arm, each leg, and optionally fingers. Chains need an IK
goal only if you want IK retarget ops (speed planting, stride warping, blend to source) on them.

## 8. IK Retargeter

**Create:** **Add (+) > Animation > IK Rig > IK Retargeter**, choose the source IK Rig, then set
the target IK Rig.

1. **Chain mapping**: map each target chain to a source chain (auto-map by name first, then fix).
2. **Retarget pose**: both skeletons must be in a matching pose (usually both T-pose or both
   A-pose). Enter edit mode and use **Auto Align** (Direction, Local Rotation Axes, Global Rotation
   Axes, Mesh) and **Snap Character to Ground**, then hand-adjust. Poses can be imported from an
   Animation Sequence or Pose Asset and exported as a Pose Asset.
3. **Op stack**: default ops are **Pelvis Motion**, **FK Chains**, **Root Motion**,
   **Remap Curves**, **Run IK Rig**. Optional ops include **Retarget Pose** (must be first),
   **Additive Pose**, **Pin Bones**, **Filter Bones**, **Scale Source**, **Stretch Chains**,
   **Pole Vector Alignment**, **Copy Base Pose**. Details in `references/rig-units.md`.
4. **Retarget Override Sets** let one retargeter hold several configurations.
5. **Export**: select animations in the Asset Browser > **Export Selected Animations**, with
   prefix, suffix, and search/replace naming. Write to a separate folder so the originals stay
   untouched.

**Quick path:** right-click animation assets > **Retarget Animation Assets** opens the Retarget
Animations window. With **Auto Generate Retargeter** it builds IK Rigs and a retargeter from
templates for common bipeds (UE4/UE5 Mannequin, MetaHuman, Stack O Bot). Inspect the generated
assets before trusting a large batch.

## 9. Editor Python (confirmed APIs)

Requires the Python Editor Script Plugin (and the Control Rig / IK Rig plugins).

```python
import unreal

# Batch retarget with an existing IK Retargeter
subsys = unreal.get_editor_subsystem(unreal.EditorAssetSubsystem)
anims = [subsys.find_asset_data("/Game/Anims/MM_Idle")]
rtg = unreal.load_asset("/Game/Rigs/RTG_Source_To_Target")
new_assets = unreal.IKRetargetBatchOperation.duplicate_and_retarget(
    anims, None, None, rtg,            # None meshes = use each IK Rig's preview mesh
    search="", replace="", prefix="RTG_", suffix="",
    remap_referenced_assets=True)

# IK Rig
ikr = unreal.load_asset("/Game/Rigs/IK_Target")
ikc = unreal.IKRigController.get_controller(ikr)
ikc.apply_auto_generated_retarget_definition()   # chains + retarget root from a template
ikc.set_retarget_root("pelvis")
ikc.add_retarget_chain("LeftArm", "upperarm_l", "hand_l", "hand_l_goal")

# IK Retargeter
rc = unreal.IKRetargeterController.get_controller(rtg)
rc.set_ik_rig(unreal.RetargetSourceOrTarget.TARGET, ikr)
rc.auto_map_chains(unreal.AutoMapChainType.FUZZY, True)
rc.auto_align_all_bones(unreal.RetargetSourceOrTarget.TARGET)

# Control Rig hierarchy
unreal.load_module("ControlRigDeveloper")
rig = unreal.load_object(name="/Game/Rigs/CR_Hero", outer=None)  # ControlRigBlueprint
hc = rig.get_hierarchy_controller()
hc.add_null(name="ik_root", parent=unreal.RigElementKey(), transform=unreal.Transform())
print([str(k) for k in rig.hierarchy.get_all_keys()])        # read back after each change
rig.recompile_vm()
```

Other confirmed calls: `unreal.ControlRigBlueprint.get_currently_open_rig_blueprints()`,
`hc.add_bone(...)` / `hc.add_control(...)`, `rig.get_controller()` for the graph with
`add_unit_node(script_struct=..., method_name="Execute", position=unreal.Vector2D(0, 0))`,
`ikc.set_skeletal_mesh`, `ikc.add_solver(unreal.IKRigFBIKSolver)` (also `IKRig_LimbSolver`,
`IKRig_BodyMover`, `IKRig_PoleSolver`, `IKRig_SetTransform`), `ikc.set_root_bone`,
`ikc.add_new_goal`, `ikc.connect_goal_to_solver`, `ikc.apply_auto_fbik()`,
`rc.set_source_chain`, `rc.create_retarget_pose`, `rc.set_current_retarget_pose`,
`rc.add_retarget_op` / `remove_retarget_op`. Check any other signature with `help()` in the
editor's Python console before using it.

## 10. Common problems and fixes

| Symptom | Likely cause | Fix |
|---|---|---|
| Knee/elbow flips or snaps past straight | Pole on the wrong side or nearly in line with the limb; wrong `SecondaryAxis` | Place the pole control well in front of the knee / behind the elbow; set `SecondaryAxis` to the axis that points at the pole; in FBIK add **Preferred Angles** or **Limits** |
| Forearm/shin twists (roll) after IK | `PrimaryAxis`/`SecondaryAxis` do not match the skeleton's joint axes | Read the axes in the viewport and set them per bone; set the end bone rotation from the IK control after the solve; in IK Rig Limb IK try **Enable Twist Correction** |
| Controls jump when the rig is first applied | Control rest placement stored in its value, not its **Offset** | Move rest placement into the Offset transform; initialize in Construction Event |
| Rig does not appear in Bake To Control Rig | No Backwards Solve | Add a Backwards Solve that sets each control from its bone; test with Backwards and Forwards preview |
| Limb stretches or never reaches | Stretch enabled / scale mismatch | Toggle `bEnableStretch` or **Allow Stretch**; check bone lengths and mesh import scale |
| FBIK does not reach effectors | Too few iterations or stiff bones | Raise **Iterations**, lower **Stiffness** / **Mass Multiplier**, check **Root Behavior** |
| Retargeted arms point wrong / hands cross body | Retarget pose mismatch (T-pose vs A-pose) | Edit the target retarget pose with **Auto Align**, match the source pose, verify with the source at frame 0 |
| Character floats or sinks, feet slide | Pelvis / scale differences | Tune **Pelvis Motion** (Scale Horizontal/Vertical, Floor Constraint Weight), add **Scale Source**, use Run IK Rig ops (Floor Constraint, Speed Plant, Stride Warp) with foot goals |
| Wrong limb driven or limb frozen | Chain mapping wrong or unmapped | Re-check each target chain's source chain; make chain start/end bones cover the same anatomy on both skeletons |
| Knees/elbows point differently than source | Different proportions | Add **Pole Vector Alignment** op |
| Weapon or prop bone drifts | Prop bone not following the hand | Add **Pin Bones** op |
| Jitter on large creatures | Noisy source | Add **Filter Bones** op |

When fixing a rig, change one thing, recompile, and re-test in the viewport (or re-read the
hierarchy via MCP) before the next change.
