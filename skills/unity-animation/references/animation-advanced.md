# Advanced animation reference

Technical reference for advanced Unity animation systems.

## 1. Root Motion

**Enable for:** realistic locomotion (mocap), combat with built-in movement (dash, lunge).
**Disable for:** arcade gameplay, precise controls, simple objects.

### Setup

1. Check the clip has root curves (model import settings)
2. Tick "Apply Root Motion" on the Animator component
3. The transform is driven by the animation's root curves

### NavMeshAgent integration

The agent plans the path; the animation moves the character. With `updatePosition` off, the
character follows the root motion and the agent is kept in sync with it.

```csharp
using UnityEngine;
using UnityEngine.AI;

[RequireComponent(typeof(Animator))]
[RequireComponent(typeof(NavMeshAgent))]
public class NavMeshRootMotion : MonoBehaviour
{
    private NavMeshAgent agent;
    private Animator animator;
    private static readonly int SpeedHash = Animator.StringToHash("Speed");

    private void Awake()
    {
        agent = GetComponent<NavMeshAgent>();
        animator = GetComponent<Animator>();
        agent.updatePosition = false;
        agent.updateRotation = false;
    }

    private void Update()
    {
        float speed = agent.desiredVelocity.magnitude;
        animator.SetFloat(SpeedHash, speed, 0.1f, Time.deltaTime);

        if (agent.desiredVelocity.sqrMagnitude > 0.01f)
        {
            var lookRotation = Quaternion.LookRotation(agent.desiredVelocity);
            transform.rotation = Quaternion.Slerp(
                transform.rotation, lookRotation, 5f * Time.deltaTime);
        }
    }

    private void OnAnimatorMove()
    {
        // Move with the animation, keep the agent's height, and tell the agent where we are
        Vector3 position = animator.rootPosition;
        position.y = agent.nextPosition.y;
        transform.position = position;
        agent.nextPosition = position;
    }
}
```

### Partial root motion (Y only)

```csharp
private void OnAnimatorMove()
{
    var pos = transform.position;
    pos.y += animator.deltaPosition.y;
    transform.position = pos;
    transform.rotation = animator.rootRotation;
}
```

## 2. IK: Animation Rigging package

Package: `com.unity.animation.rigging` (namespace `UnityEngine.Animations.Rigging`). Setup: Rig
Builder on the root, a child "Rig" with a Rig component, constraints as its children.

### Constraints

| Constraint | Use | Example |
|-----------|-------|---------|
| Two Bone IK | Arms / legs | Grab an object, feet on terrain |
| Multi-Aim | Head/torso follows a target | Look at an enemy |
| Multi-Position | Position follows a target | Hand on a handle |
| Multi-Parent | Dynamic re-parenting | Weapon switches hands |
| Damped Transform | Follow with inertia | Tail, hair |
| Chain IK | Bone chain | Tentacle |

### Look-at with falloff

```csharp
using UnityEngine;
using UnityEngine.Animations.Rigging;

public class LookAtTarget : MonoBehaviour
{
    [SerializeField] private Rig lookRig;
    [SerializeField] private Transform lookTarget;
    [SerializeField] private float maxAngle = 70f;
    [SerializeField] private float weightSpeed = 5f;

    private void Update()
    {
        var dir = (lookTarget.position - transform.position).normalized;
        var angle = Vector3.Angle(transform.forward, dir);
        float target = angle < maxAngle ? 1f : 0f;
        lookRig.weight = Mathf.MoveTowards(
            lookRig.weight, target, weightSpeed * Time.deltaTime);
    }
}
```

### Foot IK on terrain

```csharp
public class FootPlacement : MonoBehaviour
{
    [SerializeField] private Transform leftFootTarget, rightFootTarget;
    [SerializeField] private Transform leftFoot, rightFoot;
    [SerializeField] private float raycastDistance = 1.5f;
    [SerializeField] private LayerMask groundLayer;

    private void LateUpdate()
    {
        PlaceFoot(leftFoot, leftFootTarget);
        PlaceFoot(rightFoot, rightFootTarget);
    }

    private void PlaceFoot(Transform foot, Transform target)
    {
        var origin = foot.position + Vector3.up * 0.5f;
        if (Physics.Raycast(origin, Vector3.down, out var hit, raycastDistance, groundLayer))
        {
            target.position = hit.point;
            target.rotation = Quaternion.FromToRotation(Vector3.up, hit.normal)
                * transform.rotation;
        }
    }
}
```

## 3. Advanced blend trees

| Type | Parameters | Use case |
|------|-----------|-------------|
| 1D | 1 float | Speed: idle - walk - run |
| 2D Simple Directional | 2 floats | 4/8 discrete directions |
| 2D Freeform Directional | 2 floats | Free joystick movement |
| 2D Freeform Cartesian | 2 floats | Independent axes (lean X+Y) |
| Direct | N floats | Direct weight per clip (facial) |

### 2D Freeform Directional layout

```
        (0, 1) Forward
(-1, 0) Left    (1, 0) Right        In between: (+-0.7, +-0.7)
        (0, 0) Idle
        (0, -1) Backward
```

### Direct blend tree (facial)

```csharp
private static readonly int FaceHappyHash = Animator.StringToHash("FaceHappy");
private static readonly int FaceSadHash = Animator.StringToHash("FaceSad");

public void SetEmotion(float happy, float sad)
{
    animator.SetFloat(FaceHappyHash, happy);
    animator.SetFloat(FaceSadHash, sad);
}
```

## 4. Timeline

**PlayableDirector** plays the timeline. A **TimelineAsset** can be reused across scenes.

### Standard tracks

| Track | Role |
|-------|------|
| Animation | Overrides the Animator |
| Activation | Enables/disables a GameObject |
| Audio | Plays AudioClips |
| Signal | Fires custom events |
| Cinemachine | Drives cameras (Cinemachine package) |
| Control | Sub-timeline or ParticleSystem |

### Control from code

```csharp
using UnityEngine;
using UnityEngine.Playables;

public class CutsceneController : MonoBehaviour
{
    [SerializeField] private PlayableDirector director;
    [SerializeField] private GameObject playerInput;

    public void PlayCutscene()
    {
        playerInput.SetActive(false);
        director.stopped += OnCutsceneEnd;
        director.Play();
    }

    private void OnCutsceneEnd(PlayableDirector d)
    {
        d.stopped -= OnCutsceneEnd;
        playerInput.SetActive(true);
    }

    public void SkipCutscene()
    {
        director.time = director.duration;
        director.Evaluate();
        director.Stop();
    }
}
```

### Custom PlayableBehaviour (dialogue track)

```csharp
public class DialoguePlayableBehaviour : PlayableBehaviour
{
    public string dialogueText;

    public override void OnBehaviourPlay(Playable playable, FrameData info)
        => DialogueUI.Instance?.ShowText(dialogueText);

    public override void OnBehaviourPause(Playable playable, FrameData info)
        => DialogueUI.Instance?.HideText();
}
```

## 5. Playables API

For mixing animations at runtime, dynamic layering, procedural animation.

```csharp
using UnityEngine;
using UnityEngine.Animations;
using UnityEngine.Playables;

public class PlayableMixer : MonoBehaviour
{
    [SerializeField] private AnimationClip clipA, clipB;
    [Range(0f, 1f)] [SerializeField] private float blendFactor;
    private PlayableGraph graph;
    private AnimationMixerPlayable mixer;

    private void OnEnable()
    {
        graph = PlayableGraph.Create("CustomMixer");
        graph.SetTimeUpdateMode(DirectorUpdateMode.GameTime);
        mixer = AnimationMixerPlayable.Create(graph, 2);

        var a = AnimationClipPlayable.Create(graph, clipA);
        var b = AnimationClipPlayable.Create(graph, clipB);
        graph.Connect(a, 0, mixer, 0);
        graph.Connect(b, 0, mixer, 1);

        var output = AnimationPlayableOutput.Create(graph, "out", GetComponent<Animator>());
        output.SetSourcePlayable(mixer);
        graph.Play();
    }

    private void Update()
    {
        mixer.SetInputWeight(0, 1f - blendFactor);
        mixer.SetInputWeight(1, blendFactor);
    }

    private void OnDisable()
    {
        if (graph.IsValid()) graph.Destroy();
    }
}
```

### Multiple layers with Playables

```csharp
var layerMixer = AnimationLayerMixerPlayable.Create(graph, 2);
layerMixer.SetLayerMaskFromAvatarMask(1, upperBodyMask);
layerMixer.SetInputWeight(0, 1f);          // base locomotion
layerMixer.SetInputWeight(1, attackWeight); // upper-body override
```

## 6. Advanced state machine patterns

### Sub-state machines

```
Root
+-- Locomotion: Idle, Walk, Run, Sprint
+-- Combat: Attack1, Attack2, Block, Dodge
+-- Interaction: Pickup, Talk, Use
```

### Any State transitions

- Hit reaction: Any State --> HitReaction (trigger "Hit")
- Death: Any State --> Death (trigger "Die")
- Always set "Can Transition To Self" to false

### Override controller

```csharp
using System.Collections.Generic;
using UnityEngine;

public class CharacterSkin : MonoBehaviour
{
    [SerializeField] private RuntimeAnimatorController baseController;
    [SerializeField] private AnimationClip[] overrideClips;
    [SerializeField] private string[] originalClipNames;

    private void Start()
    {
        var oc = new AnimatorOverrideController(baseController);
        var overrides = new List<KeyValuePair<AnimationClip, AnimationClip>>();
        var originals = oc.animationClips;

        for (int i = 0; i < originalClipNames.Length; i++)
        {
            var orig = System.Array.Find(originals, c => c.name == originalClipNames[i]);
            if (orig != null)
                overrides.Add(new(orig, overrideClips[i]));
        }
        oc.ApplyOverrides(overrides);
        GetComponent<Animator>().runtimeAnimatorController = oc;
    }
}
```

### Advanced StateMachineBehaviour

```csharp
public class RandomIdleState : StateMachineBehaviour
{
    [SerializeField] private float minIdleTime = 3f, maxIdleTime = 8f;
    private float idleTimer;
    private static readonly int RandomIdleHash = Animator.StringToHash("RandomIdle");

    public override void OnStateEnter(Animator animator, AnimatorStateInfo si, int layer)
        => idleTimer = Random.Range(minIdleTime, maxIdleTime);

    public override void OnStateUpdate(Animator animator, AnimatorStateInfo si, int layer)
    {
        idleTimer -= Time.deltaTime;
        if (idleTimer <= 0f) animator.SetTrigger(RandomIdleHash);
    }
}
```

## 7. Performance tips

| Tip | Why |
|---------|--------|
| `Animator.StringToHash` everywhere | Avoids string lookups by name |
| Fewer active layers | Each layer evaluates its whole state machine |
| Stop animating off-screen | Animator Culling Mode (Cull Update Transforms / Cull Completely) |
| Use StateMachineBehaviour callbacks instead of polling `GetCurrentAnimatorStateInfo` every frame | Event-driven logic, less per-frame work |
| Compress clips on import | Set "Anim. Compression" to "Optimal" |
| Limit Animation Events | Each event has overhead; group them where possible |
| Reuse override controllers | Create once, share across spawns |
