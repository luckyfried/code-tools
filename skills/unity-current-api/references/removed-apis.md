# Old pattern to current pattern

"Changed in" is the release where Unity's upgrade guides, URP upgrade guides, or Scripting API mark
the change. Unity 6.N is editor version `6000.N`. Unity 6.0 continues the 2023.x line, so a change
listed for 2023.1 or 2023.2 is already in every Unity 6 release. "Status" says whether the old form
still compiles.

Before relying on a row, open the Scripting API page for the installed version:
`https://docs.unity3d.com/<6000.N>/Documentation/ScriptReference/<Class>.html`.

## Core scripting

| Old pattern | Current pattern | Changed in | Status |
| --- | --- | --- | --- |
| `Object.FindObjectsOfType<T>()` | `Object.FindObjectsByType<T>(FindObjectsSortMode.None)`. Use `FindObjectsSortMode.InstanceID` only if you need the old sorted order. | 6.0 | Obsolete |
| `Object.FindObjectOfType<T>()` | `Object.FindAnyObjectByType<T>()` (any match, faster) or `Object.FindFirstObjectByType<T>()` (the old behavior) | 6.0 | Obsolete |
| `FindObjectsByType<T>(FindObjectsSortMode.None)` | `FindObjectsByType<T>()` or `FindObjectsByType<T>(FindObjectsInactive.Include)`: the overloads without a sort mode | 6.4 (enum marked obsolete); 6.5 (overloads without it documented) | Obsolete from 6.4. On 6.0–6.3, keep passing `FindObjectsSortMode.None`. |
| `obj.GetInstanceID()` returning `int` | `obj.GetEntityId()` returning `EntityId`. It is 8 bytes from 6.5, so do not store it in an `int` or use `EntityId.GetHashCode()` as a key. | 6.4 (obsolete); 6.5 (error) | Error from 6.5 |
| `gameObject.rigidbody`, `.rigidbody2D`, `.camera`, `.light`, `.animation`, `.constantForce`, `.renderer`, `.audio`, `.collider`, `.collider2d`, `.hingeJoint`, `.particleSystem`, `.networkView` (on `GameObject` or `Component`) | `GetComponent<Rigidbody>()`, `GetComponent<Renderer>()`, `GetComponent<AudioSource>()`, and so on | 6.5 (removed; obsolete as errors long before) | Removed |
| `gameObject.AddComponent("Name")` | `gameObject.AddComponent<T>()` | 6.5 (removed) | Removed |
| `GameObject.SampleAnimation(clip, t)` | `clip.SampleAnimation(gameObject, t)` | 6.5 (removed) | Removed |
| `[SerializeField]` on a property, method, or type | `[SerializeField]` on a field, or `[field: SerializeField]` for an auto-property's backing field | 6.3 | Compile error |
| `#if DEVELOPMENT_BUILD` | `#if UNITY_ENABLE_CHECKS` for safety checks and assertions; `#if UNITY_INCLUDE_INSTRUMENTATION` or `[Conditional("UNITY_INCLUDE_INSTRUMENTATION")]` for profiling and diagnostic logging; `Debug.isDebugBuild` for a runtime check that the Player is a development build | 6.6 | Deprecated (analyzer warning UAC0009). The 6.6 guide says it is removed in 6.8. |
| `#if UNITY_64` | A runtime check on `IntPtr.Size` (8 = 64-bit), or code that does not depend on bitness | 6.6 | Deprecated (analyzer warning UAC0008) |
| `BuildOptions.ForceEnableAssertions` | `PlayerSettings.SetManagedCodeVariant(namedBuildTarget, ManagedCodeVariant.Checked)` | 6.6 | Obsolete |
| Wrapper classes or parallel key/value lists to serialize a dictionary | A `[SerializeField] Dictionary<TKey, TValue>` field. Existing wrapper solutions keep working. | 6.6 | Unity 6.5 and earlier cannot serialize `Dictionary` fields |

## Physics

| Old pattern | Current pattern | Changed in | Status |
| --- | --- | --- | --- |
| `Rigidbody.velocity` | `Rigidbody.linearVelocity` | 6.0 | Old name not in the 6.x Scripting API |
| `Rigidbody.drag` | `Rigidbody.linearDamping` | 6.0 | Old name not in the 6.x Scripting API |
| `Rigidbody.angularDrag` | `Rigidbody.angularDamping` | 6.0 | Old name not in the 6.x Scripting API |
| `Rigidbody2D.velocity` | `Rigidbody2D.linearVelocity`, plus `linearVelocityX` and `linearVelocityY` | 6.0 | Old name not in the 6.x Scripting API |
| `Rigidbody2D.drag` | `Rigidbody2D.linearDamping` | 6.0 | Old name not in the 6.x Scripting API |
| `Rigidbody2D.angularDrag` | `Rigidbody2D.angularDamping` | 6.0 | Old name not in the 6.x Scripting API |
| `Rigidbody.SetDensity(d)` | Set `Rigidbody.mass` | 6.1 | Deprecated |
| `rb.AddForceAtPosition(f, p, ForceMode.Acceleration)` expecting the old torque | Same call now scales torque by the inertia tensor. For the old result: `rb.AddForceAtPosition(f * rb.mass, p, ForceMode.Force)`. Likewise `VelocityChange` becomes `Impulse` with `f * rb.mass`. The same applies to `AddExplosionForce`. | 6.0 | Behavior change, not a rename |
| `using UnityEngine.LowLevelPhysics2D;` | `using Unity.U2D.Physics;` (renamed PhysicsCore2D API). Gate with `#if UNITY_6000_5_OR_NEWER` if you support both. | 6.5 | Unity migrates projects automatically |

## Input

| Old pattern | Current pattern | Changed in | Status |
| --- | --- | --- | --- |
| `Input.GetAxis("Horizontal")` / `("Vertical")` | `moveAction.ReadValue<Vector2>()` on an `InputAction` found once with `InputSystem.actions.FindAction("Move")` | Unity 6 manual calls the Input Manager legacy | Works only when Active Input Handling includes the Input Manager |
| `Input.GetButtonDown("Jump")` | `jumpAction.WasPressedThisFrame()` | as above | as above |
| `Input.GetButton("Jump")` | `jumpAction.IsPressed()` | as above | as above |
| `Input.GetKeyDown(KeyCode.Space)` | `Keyboard.current.spaceKey.wasPressedThisFrame` | as above | as above |
| `Input.GetMouseButtonDown(0)` | `Mouse.current.leftButton.wasPressedThisFrame` | as above | as above |
| `Input.mousePosition` | `Mouse.current.position.ReadValue()` | as above | as above |
| `Input.GetTouch(i)` | `UnityEngine.InputSystem.EnhancedTouch.Touch.activeTouches[i]` (enable `EnhancedTouchSupport` first) | as above | as above |

The full mapping is in the Input System package manual, page "Migrating from the old Input
Manager".

## URP and rendering

| Old pattern | Current pattern | Changed in | Status |
| --- | --- | --- | --- |
| `ScriptableRenderPass.Execute(ScriptableRenderContext, ref RenderingData)` and `OnCameraSetup(CommandBuffer, ref RenderingData)` | `RecordRenderGraph(RenderGraph, ContextContainer)`, with the rendering commands in a static render function set by `builder.SetRenderFunc` | URP 17 / 6.0 (render graph on by default in new projects; Compatibility Mode deprecated) | Compatibility Mode removed in 6.3 (the `URP_COMPATIBILITY_MODE` define exists only to convert a project) and fully removed in 6.4 |
| Project Settings > Graphics > Render Graph > Compatibility Mode (Render Graph Disabled) | Render graph (the only path from 6.4) | 6.0 (deprecated); 6.3 (removed) | `RenderGraphSettings.enableRenderCompatibilityMode` is read-only and returns `false` from 6.3 |
| `ScriptableRendererFeature.SetupRenderPasses` | Enqueue passes in `AddRenderPasses`, and write the passes with the render graph API | 6.2 | Deprecated |
| `RenderTargetHandle`, `ScriptableRenderer.cameraColorTarget`, `cameraDepthTarget` | `RTHandle` and `cameraColorTargetHandle` / `cameraDepthTargetHandle`. In a render graph pass, use `TextureHandle`s from `UniversalResourceData` (for example `activeColorTexture`). | URP 13 / 2022.1 | Obsolete |
| `_FORWARD_PLUS` shader keyword | `_CLUSTER_LIGHT_LOOP` | 6.1 | Replaced |
| URP `AfterRendering` injection point expecting to run before the final blit | `AfterRenderingPostProcessing` to keep rendering into an intermediate texture | 6.2 | Behavior change |
| `CustomEditorForRenderPipelineAttribute` | `CustomEditor` combined with `SupportedOnRenderPipelineAttribute` | 6.0 | Deprecated |
| `VolumeComponentMenuForRenderPipelineAttribute` | `VolumeComponentMenu` combined with `SupportedOnRenderPipelineAttribute` | 6.0 | Deprecated |
| `GraphicsFormat.DepthAuto`, `ShadowAuto`, `VideoAuto` | `GraphicsFormat.None` for depth-only targets (set `shadowSamplingMode` to `ShadowSamplingMode.CompareDepths` for shadow maps) | 2023.2 | Compile error |
| Built-In Render Pipeline for new work | URP. Built-In stays supported through the Unity 6.7 LTS lifecycle. | 6.5 | Deprecated |
| Dynamic batching | Another draw call optimization method (see the manual page "Choose a method for optimizing draw calls") | 6.6 | Obsolete |
| Lighting window **Auto Generate** and its APIs | `Lightmapping.Bake()` or `Lightmapping.BakeAsync()` | 2023.2 | Obsolete |

## Async, networking, instantiation

| Old pattern | Current pattern | Changed in | Status |
| --- | --- | --- | --- |
| `new WWW(url)` | `UnityWebRequest.Get(url)` (and `UnityWebRequestTexture`, `UnityWebRequestAssetBundle`), disposed with `using` | 2018.3 | Obsolete |
| Coroutine-only async (`IEnumerator` + `yield return`) | `async Awaitable` methods with `Awaitable.NextFrameAsync`, `WaitForSecondsAsync`, `FixedUpdateAsync`, `MainThreadAsync`, `BackgroundThreadAsync`. Coroutines still work. | `Awaitable` added in 2023.1 | Both current |
| `.NET Task` in game code | `Awaitable` / `Awaitable<T>` (pooled, resumes in the same frame). Use `Task` only when you must await more than once. | 2023.1 | Both current |
| Spawning many objects with `Instantiate` in one frame | `Object.InstantiateAsync(prefab, count, ...)`, which returns `AsyncInstantiateOperation<T>`; read `op.Result` after it completes | Available in 2022.3 and Unity 6 | Addition, not a replacement |

## UI

| Old pattern | Current pattern | Changed in | Status |
| --- | --- | --- | --- |
| `com.unity.textmeshpro` in `Packages/manifest.json` | Nothing to add. TextMesh Pro ships in `com.unity.ugui` 2.0. The namespace is still `TMPro`. | Unity 6 (uGUI 2.0) | Do not add the separate package |
| UI Toolkit `UxmlFactory` / `UxmlTraits` | `[UxmlElement]` on the class, `[UxmlAttribute]` on properties | 2023.2 | Replaced |
| UI Toolkit `ExecuteDefaultAction`, `ExecuteDefaultActionAtTarget` | `HandleEventBubbleUp` (and `HandleEventTrickleDown`) | 2023.2 | Deprecated |
| UI Toolkit `evt.PreventDefault()` | `evt.StopPropagation()` | 2023.2 | Deprecated |
| UI Toolkit `VisualElement.transform` | Set `style.translate`, `style.rotate`, `style.scale`; read `resolvedStyle.translate`, `.rotate`, `.scale` | 6.2 | Deprecated |
| `AccessibilityNode.selected` | `AccessibilityNode.invoked` | 6.3 | Deprecated |
| Cinemachine 2 APIs | Cinemachine 3, a core package in 6.6 (Unity upgrades Cinemachine 2 projects automatically; the API is different) | 6.6 | Cinemachine 2 needs a local package copy |

## Editor and lighting

| Old pattern | Current pattern | Changed in | Status |
| --- | --- | --- | --- |
| `LightingSettings.filteringGaussRadiusAO` / `Direct` / `Indirect` (`int`) | `filteringGaussianRadiusAO` / `Direct` / `Indirect` (`float`) | 2023.1 | Deprecated |
| `RenderPipelineEditorUtility.FetchFirstCompatibleTypeUsingScriptableRenderPipelineExtension` | `GetDerivedTypesSupportedOnCurrentPipeline` (returns all derived types) | 2023.1 | Deprecated |
| Progressive CPU Lightmapper | Progressive GPU Lightmapper or Unity Compute Light Baker | 6.6 | Deprecated |
