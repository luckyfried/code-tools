---
name: unity-addressables
description: Use when loading, organizing, or releasing assets with the Unity Addressables package (com.unity.addressables) - async loading, group and label layout, memory and handle management, scene loading, remote content on a CDN, DLC and catalog updates, or migrating off Resources.Load. Triggers include "Addressables", "AssetReference", "LoadAssetAsync", "InstantiateAsync", "AsyncOperationHandle", "Addressables.Release", "asset bundles", "remote content", "content catalog", "DLC", "Resources.Load migration", "loading screen progress", "InvalidKeyException", and "Addressables memory leak".
---

Adapted from JulianKerignard/Unity-Skills (MIT); see LICENSE.

# Unity Addressables

## What this skill does

Guides the Addressables system for async asset loading, group layout, memory management, and remote
content (CDN/DLC). Covers migrating from `Resources.Load`, preloading with progress, reference
counting, and the release patterns that prevent memory leaks.

## Requirements

- The `com.unity.addressables` package, installed from the Package Manager.

## Quick start

1. Install the package: Window > Package Manager > Unity Registry > Addressables.
2. Open Window > Asset Management > Addressables > Groups.
3. Mark assets as Addressable (checkbox in the Inspector).
4. Organize them into logical groups (by feature, by scene, by download).
5. Load with `Addressables.LoadAssetAsync<T>`.

## Decision tree

```
How should this asset load?
|
+-- Always in memory, referenced directly in the Inspector?
|   --> Direct [SerializeField] reference (no Addressables needed)
|
+-- Loaded on demand, known at edit time?
|   --> AssetReference in the Inspector + LoadAssetAsync
|
+-- Loaded dynamically by label or name?
|   --> Addressables.LoadAssetsAsync with a label
|
+-- Downloadable content (DLC, patches)?
|   --> Remote group + catalog update
|
+-- Migrating from Resources.Load?
    --> Mark assets Addressable, replace Resources.Load with LoadAssetAsync
```

## Step by step

### Step 1: Group layout

- **By feature**: `Characters`, `Levels`, `UI`, `Audio`.
- **By download**: `Core` (shipped in the build), `Optional` (downloadable).
- **By scene**, if you load per scene.
- Avoid very large groups (>50 MB): split them by usage.
- Use labels for cross-cutting tags (`level1`, `boss`, `tutorial`).

### Step 2: Async load with a handle

```csharp
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;

public class AssetLoader : MonoBehaviour
{
    [SerializeField] private AssetReference prefabRef;
    private AsyncOperationHandle<GameObject> handle;

    public async Awaitable<GameObject> LoadAndInstantiateAsync()
    {
        handle = Addressables.LoadAssetAsync<GameObject>(prefabRef);
        await handle.Task;

        if (handle.Status == AsyncOperationStatus.Succeeded)
            return Instantiate(handle.Result);

        Debug.LogError($"Failed to load: {prefabRef}");
        return null;
    }

    private void OnDestroy()
    {
        // Always release the handle.
        if (handle.IsValid())
            Addressables.Release(handle);
    }
}
```

Key points:
- `AssetReference` in the Inspector avoids magic strings.
- `await handle.Task` waits for the load.
- Always check `handle.Status` before using `handle.Result`.
- `Release` in `OnDestroy` prevents leaks.

### Step 3: Load by label

```csharp
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;

public class LabelLoader : MonoBehaviour
{
    [SerializeField] private AssetLabelReference labelRef;
    private AsyncOperationHandle<IList<GameObject>> handle;

    public async Awaitable<IList<GameObject>> LoadAllAsync()
    {
        handle = Addressables.LoadAssetsAsync<GameObject>(labelRef, null);
        await handle.Task;

        if (handle.Status == AsyncOperationStatus.Succeeded)
            return handle.Result;

        Debug.LogError($"Failed to load label: {labelRef}");
        return null;
    }

    private void OnDestroy()
    {
        if (handle.IsValid())
            Addressables.Release(handle);
    }
}
```

### Step 4: Migrate Resources.Load to Addressables

```csharp
// Before (synchronous, everything under Resources/ ships in the build)
var prefab = Resources.Load<GameObject>("Enemies/Goblin");

// After (async, loaded on demand)
var handle = Addressables.LoadAssetAsync<GameObject>("Enemies/Goblin");
await handle.Task;
var prefab = handle.Result;
// ... use prefab ...
Addressables.Release(handle);
```

Migration steps:
1. Move the assets out of the `Resources/` folder.
2. Mark each asset Addressable (Inspector checkbox).
3. Make the address match the old `Resources/` path.
4. Replace `Resources.Load<T>(path)` with `Addressables.LoadAssetAsync<T>(address)`.
5. Add `Release()` where the asset is no longer needed.
6. Delete the `Resources/` folder once migration is done.

### Step 5: Addressable scenes

```csharp
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;
using UnityEngine.ResourceManagement.ResourceProviders;

public class SceneLoader : MonoBehaviour
{
    [SerializeField] private AssetReference sceneRef;
    private AsyncOperationHandle<SceneInstance> sceneHandle;

    public async Awaitable LoadSceneAsync()
    {
        sceneHandle = Addressables.LoadSceneAsync(sceneRef);
        await sceneHandle.Task;
    }

    public async Awaitable UnloadSceneAsync()
    {
        if (sceneHandle.IsValid())
        {
            await Addressables.UnloadSceneAsync(sceneHandle).Task;
        }
    }
}
```

## Rules

- **Always** call `Addressables.Release(handle)` when an asset is no longer needed.
- **Always** use `AssetReference` in the Inspector rather than hard-coded address strings.
- **Always** handle load failure (`handle.Status`).
- **Always** use `Addressables.ReleaseInstance()` instead of `Destroy()` for objects created with `InstantiateAsync`.
- **Never** use `Resources.Load` in a new project; use Addressables.
- **Never** keep a handle without releasing it (memory leak).
- **Never** load the same asset twice without tracking the reference count.
- **Prefer** typed references (`AssetReferenceT<T>`, `AssetReferenceGameObject`, `AssetReferenceSprite`, and so on).
- **Prefer** `AssetLabelReference` in the Inspector over label strings.

## Related skills

- unity-perf-audit: find memory leaks and unreleased assets.
- unity-profiling-workflow: capture and compare memory before and after loads.
- unity-save: store asset references in saves as address strings.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `InvalidKeyException` | The address or label does not exist. Check the Addressables Groups window |
| Memory leak | A missing `Release()`. Use the Addressables Profiler module (see references) |
| Asset missing from the build | The asset is in no group, or its group is not included in the build |
| Slow loading | Groups are too big. Split them by usage |
| "Cannot instantiate" | The asset is not a prefab, or the load failed (check `Status`) |
| Slow first load | Addressables initializes itself on the first API call. Call `Addressables.InitializeAsync()` earlier (for example during a splash screen) to move that cost |
| Duplicated assets | An asset is pulled into several groups. Check the Addressables Report's Potential Issues tab or the Analyze window |
| Remote catalog out of date | Call `CheckForCatalogUpdates` then `UpdateCatalogs` at startup |

Patterns, remote content, and profiling in detail: `references/addressables-patterns.md`.
