---
name: unity-current-api
description: Use whenever writing, reviewing, or upgrading Unity C# scripts, render passes, or input code, so the code targets current Unity 6 APIs instead of older ones. Also use when fixing obsolete-API warnings or errors (CS0618, CS0619, "is obsolete", "has been deprecated"), upgrading a project to Unity 6 or a newer 6.x release, or choosing between Input Manager and the Input System, coroutines and Awaitable, or URP Compatibility Mode and render graph. Triggers include "Unity", "Unity 6", "6000.", "upgrade to Unity 6", "MonoBehaviour", "FindObjectsOfType", "FindObjectOfType", "rigidbody.velocity", "drag", "angularDrag", "Input.GetAxis", "Input.GetKeyDown", "Execute render pass", "OnCameraSetup", "RecordRenderGraph", "Compatibility Mode", "WWW", "GetInstanceID", "TextMeshPro package", and "Built-in Render Pipeline".
---

# Current Unity API

Coding agents often write Unity C# from memory, and that memory is out of date. This skill covers
what Unity 6 expects and the old patterns you must not write. The current LTS release is
**Unity 6.3 LTS (`6000.3`)**. Unity 6.0 LTS (`6000.0`) is still supported, and there are newer
supported update releases (`6000.4` and later). Rules here apply to all Unity 6 releases unless a
version is given.

The detailed mapping from old patterns to current ones is in `references/removed-apis.md`. Each row
there gives the release where the change landed.

## Before writing any Unity code

1. **Read the editor version** in `ProjectSettings/ProjectVersion.txt` (`m_EditorVersion:
   6000.3.25f1` means Unity 6.3). Write code for that version, not the version you remember.
   `6000.N` is Unity 6.N.
2. **Read `Packages/manifest.json`** to learn the render pipeline and input setup:
   - `com.unity.render-pipelines.universal`: URP. `com.unity.render-pipelines.high-definition`:
     HDRP. Neither: probably the Built-In Render Pipeline (confirm in Project Settings > Graphics).
   - `com.unity.inputsystem`: the Input System package is installed. Which backend is active is the
     **Active Input Handling** Player setting (Project Settings > Player > Other Settings), stored in
     `ProjectSettings/ProjectSettings.asset` as `activeInputHandler`. In code, the Input System
     defines `ENABLE_INPUT_SYSTEM` and the old Input Manager defines `ENABLE_LEGACY_INPUT_MANAGER`.
     Both can be on.
3. **When unsure an API exists or is current, check the Scripting API page for the installed
   version**: `https://docs.unity3d.com/<6000.N>/Documentation/ScriptReference/<Class>.html`.
   Members use `Class.Method.html` or `Class-property.html` (for example
   `Rigidbody-linearVelocity.html`). An obsolete member shows an **Obsolete** banner with its
   replacement. A renamed member's old page usually no longer exists at all.
4. **When upgrading across releases**, read every upgrade guide between the two versions, in order:
   `https://docs.unity3d.com/<6000.N>/Documentation/Manual/UpgradeGuides.html`. URP has its own
   guides up to URP 17.1 (Unity 6.1). From Unity 6.2, URP changes are in the main guides.
5. **Never guess a method name, overload, or namespace.** If it is not in the Scripting API for the
   installed version, or in the package's documentation, it does not exist.
6. **When another skill's example disagrees with this one about whether an API is current**, follow
   this skill and the installed version. Other skills are often written against an older release.

Compiler warning CS0618 means you used an obsolete API that still compiles. CS0619 means it is
obsolete as an error. Fix both by switching to the replacement named in the message, not by
suppressing the warning. Unity's API Updater rewrites some obsolete calls when a project is
upgraded. Do not rely on it for code you write now.

## Finding objects

`Object.FindObjectsOfType` and `Object.FindObjectOfType` are obsolete in Unity 6.0.

```csharp
// Unity 6.0 – 6.3
var enemies = FindObjectsByType<Enemy>(FindObjectsSortMode.None);   // unsorted, faster
var any     = FindAnyObjectByType<GameManager>();                  // any match, fastest
var first   = FindFirstObjectByType<GameManager>();                // same result as the old call
```

- Pass `FindObjectsSortMode.None` unless you need a stable order. `FindObjectsSortMode.InstanceID`
  matches the old sorted behavior and is slower.
- Use `FindAnyObjectByType` when any instance will do. Use `FindFirstObjectByType` only when you
  need the old `FindObjectOfType` result.
- Pass `FindObjectsInactive.Include` to include objects on inactive GameObjects.
- **From Unity 6.4, `FindObjectsSortMode` itself is marked obsolete.** Unity 6.5 documents
  overloads without it: `FindObjectsByType<Enemy>()` and
  `FindObjectsByType<Enemy>(FindObjectsInactive.Include)`. On 6.4 and later, check the installed
  version's page and use the overload without a sort mode when it exists.

## Physics

Unity 6.0 renamed the Rigidbody velocity and drag members. The old names are not in the Unity 6
Scripting API.

| Do not write | Write |
| --- | --- |
| `rb.velocity` | `rb.linearVelocity` |
| `rb.drag` | `rb.linearDamping` |
| `rb.angularDrag` | `rb.angularDamping` |
| `rb2d.velocity` | `rb2d.linearVelocity` (also `linearVelocityX`, `linearVelocityY`) |
| `rb2d.drag` | `rb2d.linearDamping` |
| `rb2d.angularDrag` | `rb2d.angularDamping` |

`angularVelocity` keeps its name. `Rigidbody.SetDensity` is deprecated in Unity 6.1: set
`Rigidbody.mass` instead. In Unity 6.0, `AddForceAtPosition` and `AddExplosionForce` with
`ForceMode.VelocityChange` or `ForceMode.Acceleration` apply a different torque than before, so
tuning copied from older projects may need changing.

## Input

Unity 6 has two input systems. The manual calls the Input System package the default and
recommended one. It calls the Input Manager (the `UnityEngine.Input` class) legacy and not
recommended for new projects.

- For new code, use the Input System (`using UnityEngine.InputSystem;`), unless the project's
  Active Input Handling is set to the old Input Manager only. Then either keep to `Input`, or ask
  before changing the setting, because changing it needs an Editor restart and affects all code.
- Do not mix both in one project without checking that Active Input Handling is set to **Both**.

```csharp
using UnityEngine.InputSystem;

InputAction move, jump;
void Start()
{
    move = InputSystem.actions.FindAction("Move");   // project-wide actions (Project Settings > Input System Package)
    jump = InputSystem.actions.FindAction("Jump");
}
void Update()
{
    Vector2 m = move.ReadValue<Vector2>();            // was Input.GetAxis("Horizontal"/"Vertical")
    if (jump.WasPressedThisFrame()) { /* ... */ }     // was Input.GetButtonDown("Jump")
    if (Keyboard.current.spaceKey.wasPressedThisFrame) { /* ... */ }  // was Input.GetKeyDown(KeyCode.Space)
    Vector2 p = Mouse.current.position.ReadValue();   // was Input.mousePosition
}
```

Find actions once (in `Start` or `Awake`) and read them each frame. Do not look them up every frame.
`Keyboard.current` and `Mouse.current` are null when no such device is connected. The full mapping
is on the Input System package's "Migrating from the old Input Manager" page.

## URP custom render passes: render graph only

URP 17 (Unity 6.0) introduced the render graph system. New URP projects use it by default.

- **Write `RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)`.** Do not write
  `Execute(ScriptableRenderContext, ref RenderingData)` or `OnCameraSetup` for new passes. Those
  belong to **Compatibility Mode (Render Graph Disabled)**, which Unity no longer develops.
- Compatibility Mode is deprecated in Unity 6.0 and **removed in Unity 6.3**. In 6.3,
  `RenderGraphSettings.enableRenderCompatibilityMode` is read-only and returns `false`, and the
  `URP_COMPATIBILITY_MODE` scripting define exists only to help convert a project. In **Unity 6.4
  it is fully removed**, the define included.
- `ScriptableRendererFeature.SetupRenderPasses` is deprecated in Unity 6.2. Enqueue passes in
  `AddRenderPasses`.

```csharp
class CopyPass : ScriptableRenderPass
{
    class PassData { public TextureHandle source; }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        var resources = frameData.Get<UniversalResourceData>();
        using (var builder = renderGraph.AddRasterRenderPass<PassData>("Copy", out var passData))
        {
            passData.source = resources.activeColorTexture;
            TextureDesc desc = renderGraph.GetTextureDesc(resources.activeColorTexture);
            desc.depthBufferBits = 0;
            TextureHandle dest = renderGraph.CreateTexture(desc);

            builder.UseTexture(passData.source);
            builder.SetRenderAttachment(dest, 0);
            builder.SetRenderFunc(static (PassData data, RasterGraphContext ctx) =>
                Blitter.BlitTexture(ctx.cmd, data.source, new Vector4(1, 1, 0, 0), 0, false));
        }
    }
}
```

In `RecordRenderGraph` you declare inputs and outputs. Rendering commands go only in the render
function. Get camera textures from `UniversalResourceData` and camera state from
`UniversalCameraData`. The render graph owns resources, so you cannot allocate or dispose them
yourself: create textures with `renderGraph.CreateTexture`, not `RTHandle`s or
`cmd.GetTemporaryRT`. Verify method names against the URP
package documentation for the installed version, and see the "URP RenderGraph Samples" package
sample. Check the Render Graph Viewer window to confirm the pass runs.

## Render pipeline choice

The **Built-In Render Pipeline is deprecated in Unity 6.5** and will be made obsolete in a future
release. It stays supported through the Unity 6.7 LTS lifecycle. For new projects and new rendering
code, target URP. In an existing Built-In project, keep to Built-In APIs unless the task is the
migration.

## Async code

- **`Awaitable`** (`UnityEngine.Awaitable`) is the Unity type for `async` methods. Prefer it over
  `Task` in game code. Coroutines are not deprecated. Use `Awaitable` when async/await reads better
  or you need a result.
  - Awaitables are pooled. **Never await the same `Awaitable` instance twice.** If you need that,
    wrap it in a `Task`.
  - Static helpers: `Awaitable.NextFrameAsync()`, `WaitForSecondsAsync(s)`, `FixedUpdateAsync()`,
    `EndOfFrameAsync()`, `MainThreadAsync()`, `BackgroundThreadAsync()`,
    `FromAsyncOperation(op)`. Any `AsyncOperation`, such as `SceneManager.LoadSceneAsync`, can be
    awaited directly.
  - Pass `destroyCancellationToken` (on `MonoBehaviour`) so work stops when the object is
    destroyed. Unity does not stop background work when Play mode exits: use
    `Application.exitCancellationToken` for that.
  - Call Unity APIs only on the main thread. After `BackgroundThreadAsync()`, go back with
    `await Awaitable.MainThreadAsync()` before touching GameObjects.
- **`Object.InstantiateAsync`** clones objects asynchronously and returns an
  `AsyncInstantiateOperation<T>`. You can `await` it or yield on it, and read `op.Result`. Use it
  when spawning many objects at once would cause a frame hitch.
- **`WWW` is obsolete.** Use `UnityEngine.Networking.UnityWebRequest` (`UnityWebRequest.Get`,
  `UnityWebRequestTexture.GetTexture`, and so on), wrapped in `using` so it is disposed.

```csharp
async Awaitable SpawnWave(GameObject prefab, int count)
{
    var op = InstantiateAsync(prefab, count);
    await op;
    foreach (var go in op.Result) { /* ... */ }
    await Awaitable.WaitForSecondsAsync(2f, destroyCancellationToken);
}
```

## Static state and Enter Play Mode settings

Projects can turn off domain reload in Project Settings > Editor > Enter Play Mode Settings, to make
entering Play mode faster. With domain reload off:

- **Static fields keep their values between Play mode sessions, and static events keep their
  subscribers.** Non-serialized fields on MonoBehaviours and ScriptableObjects also keep their
  values.
- Reset static state yourself. Use a
  `[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]` static
  method that clears it, and unsubscribe static event handlers when Play mode exits.

```csharp
static int s_Score;
static event System.Action OnReset;

[RuntimeInitializeOnLoadMethod(RuntimeInitializeLoadType.SubsystemRegistration)]
static void ResetStatics() { s_Score = 0; OnReset = null; }
```

Write singletons and static caches this way even when the project reloads the domain today, so they
keep working if the setting changes.

## UI and text

- **TextMesh Pro is part of the Unity UI package (`com.unity.ugui` 2.0) in Unity 6.** Do not add
  `com.unity.textmeshpro` to the manifest. The namespace is still `TMPro`
  (`TextMeshProUGUI`, `TMP_Text`). Import TMP Essential Resources from Window > TextMeshPro when a
  project has none.
- UI Toolkit custom controls: use `[UxmlElement]` on the class and `[UxmlAttribute]` on
  properties, not `UxmlFactory` and `UxmlTraits`. Handle events with `HandleEventBubbleUp` and
  `HandleEventTrickleDown`, not `ExecuteDefaultAction`. Use `StopPropagation`, not
  `PreventDefault`.
- UI Toolkit: `VisualElement.transform` is deprecated in Unity 6.2. Set
  `style.translate`, `style.rotate`, and `style.scale`, and read `resolvedStyle.*`.

## Serialization and object identity

- `[SerializeField]` is valid only on fields. Since Unity 6.3, putting it on a property is a
  compile error. For an auto-property's backing field, write `[field: SerializeField]`.
- `Object.GetInstanceID()` is obsolete in Unity 6.4 and an error in 6.5. Use
  `GetEntityId()`, which returns an `EntityId`. In 6.5, `EntityId` is 8 bytes, so do not store it in
  an `int`.

## Quick "never write" list

On Unity 6: `FindObjectsOfType`, `FindObjectOfType`, `rb.velocity`, `rb.drag`, `rb.angularDrag`
(3D and 2D), `new WWW(...)`, a URP pass that overrides only `Execute` or `OnCameraSetup`,
`com.unity.textmeshpro` in the manifest, `[SerializeField]` on a property, and the
`gameObject.rigidbody` / `.renderer` / `.collider` / `.audio` shortcut properties (removed in Unity
6.5; use `GetComponent<T>()`). Avoid the legacy `UnityEngine.Input` class in projects using the
Input System, and version-gated items in `references/removed-apis.md`: `GetInstanceID` (6.4+),
`FindObjectsSortMode` (6.4+), and `DEVELOPMENT_BUILD` / `UNITY_64` (6.6+).
