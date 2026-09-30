# Unity performance anti-patterns

Full list of anti-patterns to look for in a static audit. Used by `unity-perf-audit` (see
`../SKILL.md` for the workflow).

## CPU anti-patterns

| # | Pattern | Search | Severity |
|---|---------|---------------|----------|
| C1 | GetComponent in Update/FixedUpdate | `GetComponent`, then check whether it is inside Update/FixedUpdate/LateUpdate | Critical |
| C2 | Find at runtime | `Find\("\|FindWithTag\|FindGameObjectsWithTag\|FindObjects?OfType\|FindObjectsByType\|FindFirstObjectByType\|FindAnyObjectByType` | Critical |
| C3 | String concatenation in a hot path | `\+ "` and `\.ToString()` inside Update/FixedUpdate | High |
| C4 | Instantiate in Update | `Instantiate\(` inside Update/FixedUpdate | High |
| C5 | LINQ in Update | `\.Where(\|\.Select(\|\.Any(\|\.First(\|\.OrderBy(` in or called from Update | High |
| C6 | foreach over an interface in a hot path | `foreach` inside Update/FixedUpdate/LateUpdate | Low |
| C7 | `new` allocation in Update | `new List\|new Dictionary\|new \w+\[\]` inside Update | Medium |
| C8 | SendMessage / BroadcastMessage | `SendMessage\(\|BroadcastMessage\(` | Medium |
| C9 | Missing CompareTag | `\.tag\s*==\|\.tag\s*!=` | Low |
| C10 | Repeated Camera.main | `Camera\.main` inside Update | Medium |
| C11 | Obsolete Rigidbody members | `\.velocity\b\|\.drag\b\|\.angularDrag\b` in files that use `Rigidbody` or `Rigidbody2D` | Low |
| C12 | Synchronous Instantiate of large prefabs in bulk | `Instantiate\(` spawning many complex prefabs at once (suggest `Object.InstantiateAsync`) | Medium |

### Notes

**C2 - Find:** the old `FindObjectOfType`/`FindObjectsOfType` are obsolete in Unity 6; the current
`FindObjectsByType`/`FindFirstObjectByType`/`FindAnyObjectByType` still walk the scene and are
just as expensive per frame. Cache the result or inject the reference. When a fix must find
objects, write `FindObjectsByType<T>(FindObjectsSortMode.None)` or `FindAnyObjectByType<T>()`
(on Unity 6.4 and later, check the installed version for the overload without a sort mode).

**C6 - foreach:** `foreach` over a `List<T>` or array does not allocate. It allocates when the
collection is typed as an interface (`IEnumerable<T>`, `IList<T>`), which boxes the enumerator.
Report only that case.

**C11 - Rigidbody members:** Unity 6 renamed `velocity` to `linearVelocity`, `drag` to
`linearDamping`, and `angularDrag` to `angularDamping` (on both `Rigidbody` and `Rigidbody2D`).
Performance is the same; the old names are obsolete. Flag them for update, and see
`unity-current-api` for other obsolete APIs.

**C12 - Instantiate:** `Object.InstantiateAsync` clones objects asynchronously and returns an
`AsyncInstantiateOperation<T>`. It helps only when spawning many objects, or complex prefabs, in
one frame causes a hitch. Report as a suggestion, not an error.

### Detecting hot paths

Hot paths: `Update()`, `FixedUpdate()`, `LateUpdate()`, `OnGUI()`, `OnTriggerStay`,
`OnCollisionStay`.

To check whether a match is in a hot path:

1. Search the pattern across the project
2. For each match, read the file and check whether the line is inside a hot-path method body
3. If it is in a method called from a hot path (call chain), report it at reduced severity

Search with context (`-B`, `-A`) to see the enclosing method:

```
Search the pattern with -B 20 to find the preceding method signature
Look for "void Update" or "void FixedUpdate" in the lines above
```

## GPU anti-patterns

| # | Pattern | Detection |
|---|---------|---------------------|
| G1 | Too many transparent materials | Search `transparent\|fade\|Transparent` in `.shader` and `.mat` files (glob `**/*.shader`, `**/*.mat`) |
| G2 | No LOD on meshes | Search `MeshRenderer\|MeshFilter` and check for a missing `LODGroup` on the same GameObject or a parent |
| G3 | Realtime lights | Search `LightType\|new Light\|GetComponent<Light>`; check the scenes if possible |
| G4 | Many SetPass calls | Search `\.material\b\|new Material` (accessing `renderer.material` or creating materials at runtime makes per-object material copies and breaks batching) |

### Note: GPU Resident Drawer (Unity 6, URP)

The GPU Resident Drawer draws GameObjects with a Mesh Renderer through the BatchRendererGroup API
with GPU instancing, which cuts draw calls and CPU time. It needs: Project Settings > Graphics >
BatchRendererGroup Variants set to Keep All; on the URP Asset, SRP Batcher on and GPU Resident
Drawer set to Instanced Drawing; the Universal Renderer's Rendering Path set to Forward+; and a
platform with compute shaders (not OpenGL ES). If the project uses it, manual draw-call work
(static batching, manual mesh combining) matters less. Check before recommending batching work.

## Memory anti-patterns

| # | Pattern | Search | Severity |
|---|---------|---------------|----------|
| M1 | Resources.Load without unload | `Resources\.Load` with no `Resources\.UnloadUnusedAssets` in the same file | High |
| M2 | Runtime texture creation | `new Texture2D\|new RenderTexture` without a matching `Destroy`/`Release` | High |
| M3 | Event leak (subscribe without unsubscribe) | `\+=` on an event/Action/delegate; check for a matching `-=` in OnDisable/OnDestroy | High |
| M4 | Array allocation in Update | `new\s+\w+\[` inside Update | Medium |
| M5 | Allocating coroutine | `new WaitForSeconds\|new WaitForEndOfFrame` in a frequently started coroutine | Medium |
| M6 | IDisposable not disposed | `new\s+(StreamReader\|StreamWriter\|FileStream\|HttpClient)` or `UnityWebRequest\.` without `using` or `.Dispose()` | Medium |
| M7 | Repeated `new WaitForSeconds` in a loop | `new WaitForSeconds\(` inside a looping coroutine | Low |

### M7 detail: caching WaitForSeconds

`new WaitForSeconds` creates an instance on every call. For coroutines that run often (loops,
spawns), a `static readonly` cache removes the allocation.

```csharp
// BEFORE
IEnumerator Spawn()
{
    while (true)
    {
        SpawnEnemy();
        yield return new WaitForSeconds(2f); // allocates every iteration
    }
}

// AFTER
private static readonly WaitForSeconds SpawnDelay = new(2f);
IEnumerator Spawn()
{
    while (true)
    {
        SpawnEnemy();
        yield return SpawnDelay; // no allocation
    }
}
```

**Detection:** search `new WaitForSeconds\(` and check whether the coroutine has a `while` loop or
is started via `InvokeRepeating` / from `Update`. If it runs once (for example a tutorial
sequence), the allocation is negligible; do not report it.

## Performance budgets per platform

Rough reference to put findings in context. Do not cite if no GPU/rendering problem was found.
Real budgets come from measuring on the target device (`unity-profiling-workflow`).

| Platform | Target FPS | Draw calls | Triangles | Memory |
|------------|----------|------------|-----------|---------|
| Mobile | 30-60 | < 200 | < 100K | < 1 GB |
| Console | 30-60 | < 2000 | < 2M | < 4 GB |
| PC | 60-144 | < 5000 | < 10M | < 8 GB |
