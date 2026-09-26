# Rig unit and retarget op cheat-sheet (UE 5.8)

Names are exactly as Epic's node reference and docs list them. Pin names are the internal names
shown in the node reference; the graph may display them with spaces.

## Control Rig nodes

### Transforms
- **Get Transform** (`RigUnit_GetTransform`): `Item` (Rig Element Key), `Space` (GlobalSpace /
  LocalSpace, default GlobalSpace), `bInitial` (false = current, true = initial/reference) ->
  `Transform`.
- **Set Transform**: `Item`, `Space`, `bInitial`, `Value`, `Weight` (default 1.0),
  `bPropagateToChildren` (default true). Setting a control's initial transform writes its offset
  and zeroes its local value.
- Also: Copy Transform, Get Relative Transform, Set Relative Transform, Offset Transform,
  Modify Transforms, Set Scale, Get Transform Array, Set Transform Array.

### IK
- **Basic IK** (`RigUnit_TwoBoneIKSimplePerItem`, world space): `ItemA`, `ItemB`,
  `EffectorItem`, `Effector`, `PrimaryAxis`, `SecondaryAxis`, `SecondaryAxisWeight`,
  `PoleVector`, `PoleVectorKind` (direction or location), `PoleVectorSpace`, `bEnableStretch`,
  `StretchStartRatio`, `StretchMaximumRatio`, `Weight`, `ItemALength`, `ItemBLength`,
  `bPropagateToChildren`, `DebugSettings`.
- **Full Body IK** (`RigUnit_PBIK`): `Root`, `Effectors` (each with Bone + Transform),
  `BoneSettings` (stiffness, limits, preferred angles), `ExcludedBones`, `Settings`
  (Iterations 20, SubIterations 0, MassMultiplier 1.0, AllowStretch false, RootBehavior PrePull,
  GlobalPullChainAlpha 1.0, MaxAngle 30, OverRelaxation 1.3, PrePullRootSettings), `Debug`.
- Also: Basic IK Positions, Basic IK Transforms, Two Bone IK Off Plane, Basic FABRIK, CCDIK,
  Multi Effector FABRIK, Spring IK, IK Rig.

### Constraints and aim
- Aim, Aim Constraint, Aim Math, Parent Constraint, Parent Constraint Math, Position Constraint,
  Rotation Constraint, Scale Constraint.

### Collision
- **Sphere Trace By Trace Channel**: `Start`, `End` (rig/global space), `TraceChannel`, `Radius`
  -> `bHit`, `HitLocation`, `HitNormal`.
- **Sphere Trace By Object Types**: same idea, filtered by object types.

### Construction-time spawning
- Spawn Bone, Spawn Null, Spawn Control, Spawn Animation Channel.

### Simulation / smoothing
- Spring Interpolate, SpringInterp, AlphaInterp, Chain Harmonics, Harmonics, Verlet (Vector),
  AccumulateAdd / AccumulateLerp / AccumulateMul / AccumulateRange, DeltaFromPrevious,
  KalmanFilter, Time Loop, TimeOffset, Accumulated Time, Timer Value.

### Math
- Add, Subtract, Multiply, Divide, Clamp, Remap, Interpolate, Minimum, Maximum, Absolute, Sign,
  Round, Floor, Ceiling, Power, Sqrt, trig (Sin, Cos, Tan, Asin, Acos, Atan, Atan2), Degrees,
  Radians, comparisons (Greater, GreaterEqual, Less, LessEqual, IsNearlyEqual, IsNearlyZero),
  Magnitude, Negate, Inverse, ClampSpatially.

## Animation Blueprint nodes (not Control Rig)
- **Two Bone IK**: Effector Location + Joint Target Location for a two-bone chain.
- **Look At**: Bone to Modify, Look at Target / Look at Location, Look at Axis, Look at Clamp,
  Interpolation Type, Use Look Up Axis.
- **Control Rig** (Misc > Control Rig) and **IK Rig** nodes run those assets in the Anim Graph.

## IK Rig solvers
| Solver | Needs | Key settings |
|---|---|---|
| Full Body IK | Root bone, 1+ goals | Iterations, Mass Multiplier, Root Behavior (Pre Pull / Pin to Input / Free), per-bone Stiffness, Limits, Preferred Angles |
| Limb IK | Root bone, 1 goal, 3+ bones | Reach Precision, Max Iterations, Enable Limit, Enable Twist Correction |
| Body Mover | Root bone, 2+ goals | Rotation Alpha (0 for humanoids to avoid leaning), per-goal influence |
| Pole Solver | Root and end bone, goal used as pole | Orients middle joints toward the pole goal |
| Set Transform | 1 goal | Moves/rotates a bone to the goal, no IK |

## IK Retargeter op stack
Default:
- **Pelvis Motion**: Source/Target Pelvis Bone, Floor Constraint Weight, Crotch Offset,
  Rotation/Translation Alpha, Scale Horizontal/Vertical.
- **FK Chains**: Rotation Mode (Interpolated, One to One, One to One Reversed, None),
  Translation Mode, Rotation/Translation Alpha.
- **Root Motion**: Source Root, Target Root, Root Motion Source, Target Pelvis, Root Height
  Source, Global Offset.
- **Remap Curves**: Copy All Source Curves, Curves to Remap.
- **Run IK Rig**: sub-ops Blend to Source, Offset Goals, Scale Goals, Floor Constraint,
  Speed Plant IK Goals (Spring or Move Towards), Stride Warp IK Goals, Relative IK Retarget and
  Body Intersect Goals (these two need the Spatially Aware Retarget Ops plugin).

Optional:
- **Retarget Pose** (must be first op): override source/target retarget pose.
- **Additive Pose**: Pose to Apply, Alpha.
- **Pin Bones**: Bones to Pin, Skeleton to Copy From, Copy Translation/Rotation/Scale,
  Global/Local Offset.
- **Filter Bones**: One Euro Filter (Min Frequency, Responsiveness, Velocity Cutoff).
- **Scale Source**: Source Scale Factor, Scale Pivot, Scale Pivot Bone, Project Scale Pivot to
  Floor.
- **Stretch Chains**: Match Source Length, Scale Chain Length.
- **Pole Vector Alignment**: Align Alpha, Static Angular Offset, Maintain Offset.
- **Copy Base Pose**: Copy from Start bone, Bones to Exclude.
