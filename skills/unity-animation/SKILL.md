---
name: unity-animation
description: Use when driving Unity character or object animation from code, or setting up advanced animation - Animator Controller integration (cached parameter hashes, layers, blend trees, sub-state machines, override controllers), Animation Events, StateMachineBehaviour, Root Motion (including with NavMeshAgent), IK with the Animation Rigging package, Timeline cutscenes, and the Playables API. Triggers include "Animator", "animation controller", "blend tree", "animation state machine", "animation events", "StateMachineBehaviour", "Root Motion", "IK", "foot IK", "look at IK", "Animation Rigging", "Timeline", "cutscene", "PlayableDirector", "Playables API", "AnimatorOverrideController", and "character is sliding/floating".
---

Adapted from JulianKerignard/Unity-Skills (MIT); see LICENSE.

# Unity Animation

## What this skill does

Guides advanced animation work in Unity: code-to-Animator integration, IK, Root Motion, Animation
Rigging, Timeline, the Playables API, and advanced blend trees.

It goes beyond basic Animator Controller setup: production-ready patterns for driving animation
from code, syncing gameplay logic with keyframes, and using the advanced systems (IK, Playables,
Timeline). Detailed reference: `references/animation-advanced.md`.

## Prerequisites

- An **Animator Controller** with basic states and transitions
- Imported **animation clips** (Humanoid or Generic rig as needed)
- **(Optional)** **Animation Rigging** package (`com.unity.animation.rigging`) for IK
- **(Optional)** **Timeline** package (`com.unity.timeline`) for cutscenes

## Quick start

1. Pick the animation system for the need (see the decision tree)
2. Set up the Animator Controller (states, transitions, parameters)
3. Integrate with code (cached hashes, parameters, events)
4. Refine with IK, advanced blending, layers

## Decision tree

```
Which animation system?
|
+-- Simple animation (door, platform, UI)?
|   --> Animator with 1-2 states (or the legacy Animation component for trivial cases)
|
+-- Player or enemy character with states (idle, run, attack)?
|   --> Animator Controller + state machine + code integration
|
+-- Cinematic / cutscene?
|   --> Timeline (PlayableDirector + tracks)
|
+-- Blending animations dynamically at runtime?
|   --> Playables API (custom mixer)
|
+-- IK (character looks at / grabs an object)?
|   --> Animation Rigging package (Rig Builder + constraints)
|
+-- Thousands of animated entities?
    --> Animator culling + LOD first. Entities (DOTS) has no official animation package;
        GPU-baked approaches (vertex animation textures) or third-party solutions are the options.
```

## Step by step

### Step 1: Animator setup and code integration

```csharp
using UnityEngine;

[RequireComponent(typeof(Animator))]
public class CharacterAnimator : MonoBehaviour
{
    private Animator animator;

    // ALWAYS cache hashes (avoids string lookups every frame)
    private static readonly int SpeedHash = Animator.StringToHash("Speed");
    private static readonly int IsGroundedHash = Animator.StringToHash("IsGrounded");
    private static readonly int JumpTrigger = Animator.StringToHash("Jump");
    private static readonly int AttackTrigger = Animator.StringToHash("Attack");

    private void Awake() => animator = GetComponent<Animator>();

    public void SetSpeed(float speed) => animator.SetFloat(SpeedHash, speed);
    public void SetGrounded(bool grounded) => animator.SetBool(IsGroundedHash, grounded);
    public void TriggerJump() => animator.SetTrigger(JumpTrigger);
    public void TriggerAttack() => animator.SetTrigger(AttackTrigger);
}
```

### Step 2: Animation Events

```csharp
// Called from an animation clip at a specific keyframe
public void OnFootstep()
{
    audioService.PlaySFX(footstepClip);
}

public void OnAttackHit()
{
    // Enable the hitbox at the right moment of the animation
    hitbox.SetActive(true);
}

public void OnAttackEnd()
{
    hitbox.SetActive(false);
}
```

### Step 3: StateMachineBehaviour (logic attached to states)

```csharp
public class AttackState : StateMachineBehaviour
{
    public override void OnStateEnter(
        Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        animator.GetComponent<CombatSystem>().OnAttackStart();
    }

    public override void OnStateExit(
        Animator animator, AnimatorStateInfo stateInfo, int layerIndex)
    {
        animator.GetComponent<CombatSystem>().OnAttackEnd();
    }
}
```

### Step 4: Animator layers (partial animations)

```csharp
// Drive a layer's weight at runtime (for example an upper-body attack)
private const int UpperBodyLayer = 1;

public void EnableUpperBodyOverride(float weight)
{
    animator.SetLayerWeight(UpperBodyLayer, weight);
}
```

- **Layer 0**: Base (full locomotion)
- **Layer 1**: Upper Body Override (attack, interaction) with an Avatar Mask
- **Layer 2**: Additive (breathing, hit reactions)

### Step 5: Blend trees for locomotion

In the Animator Controller:

- Create a 2D Freeform Directional blend tree
- Parameters: `MoveX` (float), `MoveY` (float)
- Motions: idle (0,0), walk forward (0,0.5), run forward (0,1), strafe left (-1,0), strafe
  right (1,0)

```csharp
private static readonly int MoveXHash = Animator.StringToHash("MoveX");
private static readonly int MoveYHash = Animator.StringToHash("MoveY");

public void SetMovement(Vector2 input)
{
    // Damped to avoid abrupt changes
    animator.SetFloat(MoveXHash, input.x, 0.1f, Time.deltaTime);
    animator.SetFloat(MoveYHash, input.y, 0.1f, Time.deltaTime);
}
```

Feed `input` from an Input System action (`move.ReadValue<Vector2>()`), not the legacy
`Input` class; see `unity-current-api`.

## Hard rules

**ALWAYS:**

- Cache hashes with `Animator.StringToHash` (no strings in Update)
- Use Animation Events to sync logic with animation (no hand-tuned timers)
- Use Animator layers for partial animations (upper-body attack + lower-body run)
- Use `SetFloat` with damping for smooth blend tree transitions
- Destroy `PlayableGraph`s you create (in `OnDisable`/`OnDestroy`) to avoid leaks

**NEVER:**

- `GetComponent<Animator>()` in Update; cache it in Awake
- `transition duration = 0` except for purely logical state machines (causes visual snapping)
- Move `transform.position` by hand while Root Motion is active
- Use `Play()` or `CrossFade()` without a reason; prefer Animator Controller transitions

**PREFER:**

- 2D Freeform blend trees for directional movement
- Sub-state machines to organize complex Animator Controllers
- Override controllers to reuse a state machine with different clips
- Animation Rigging over `OnAnimatorIK()` for new projects

## Related skills

- `unity-2d`: 2D animation with Sprite Library and Sprite Swap
- `unity-perf-audit`: static scan for animation anti-patterns in code
- `unity-profiling-workflow`: measure Animator cost on device

## Troubleshooting

| Problem | Fix |
|----------|----------|
| Animation does not play | Check the state is reachable (transitions connected) and the parameter is set correctly |
| Character slides/floats | Root Motion misconfigured: check "Apply Root Motion" on the Animator and the clip's root curves |
| Blend tree jitters | Check the clips have matching foot cycles; adjust thresholds |
| IK does nothing | Check "IK Pass" is enabled on the layer in the Animator Controller |
| Animation Event not called | The method name must match exactly, be on a script on the same GameObject as the Animator, and take no parameter or one `float`, `int`, `string`, object reference, or `AnimationEvent` |
| Transition stuck | Check the transition conditions; disable "Has Exit Time" for an immediate transition |
| Layer override does nothing | Check the layer's Avatar Mask and that its weight > 0 |
| PlayableGraph leak | Always call `graph.Destroy()` when done |
