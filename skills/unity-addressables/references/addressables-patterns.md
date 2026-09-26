# Addressables patterns and reference

## Group layout in detail

### Default Local Group
Assets always shipped in the build: core UI, player prefabs, tutorial, critical ScriptableObjects.

### Per-scene group
One group per scene or zone (`Level1_Assets`, `BossArena_Assets`). Give it a label matching the
scene name to make preloading easy.

### Remote group
Assets downloaded after install (DLC, patches, seasonal content):
- Remote Build Path: `ServerData/[BuildTarget]`
- Remote Load Path: `https://cdn.example.com/[BuildTarget]`
- Enable **Build Remote Catalog** in the Addressables settings

### Group schema settings

```
Group Settings:
  Build Path:  LocalBuildPath  |  RemoteBuildPath
  Load Path:   LocalLoadPath   |  RemoteLoadPath
  Bundle Mode: Pack Together   |  Pack Separately  |  Pack Together By Label
```

- **Pack Together**: one bundle per group (fewer requests, bigger bundles).
- **Pack Separately**: one bundle per asset (granular, more requests).
- **Pack Together By Label**: one bundle per label in the group (a good middle ground).

### Labels
Cross-cutting tags (`enemies`, `props`, `level1`, `hd`/`sd`). An asset can have several labels.
Labels do not change group layout.

## Labels and filters

```csharp
// Load every asset with a label
var handle = Addressables.LoadAssetsAsync<GameObject>("enemies",
    obj => Debug.Log($"Loaded: {obj.name}"));
await handle.Task;
foreach (var enemy in handle.Result) Instantiate(enemy);
Addressables.Release(handle);

// Several labels, intersection (assets with ALL the labels)
var both = Addressables.LoadAssetsAsync<GameObject>(
    new List<string> { "enemies", "level1" },
    null, Addressables.MergeMode.Intersection);

// Several labels, union (assets with AT LEAST ONE label)
var either = Addressables.LoadAssetsAsync<GameObject>(
    new List<string> { "enemies", "level1" },
    null, Addressables.MergeMode.Union);

// Type-safe from the Inspector
[SerializeField] private AssetLabelReference enemyLabel;
var fromInspector = Addressables.LoadAssetsAsync<GameObject>(enemyLabel, null);
```

## Preloading with progress (loading screen)

`GetDownloadStatus().Percent` reports download progress in bytes; `PercentComplete` covers the whole
operation. Use the first for a download bar.

```csharp
using TMPro;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.UI;

public class LoadingScreen : MonoBehaviour
{
    [SerializeField] private Slider progressBar;
    [SerializeField] private TextMeshProUGUI statusText;
    [SerializeField] private AssetLabelReference sceneAssets;

    public async Awaitable PreloadAssetsAsync()
    {
        var sizeHandle = Addressables.GetDownloadSizeAsync(sceneAssets);
        await sizeHandle.Task;
        long downloadSize = sizeHandle.Result;
        Addressables.Release(sizeHandle);

        if (downloadSize > 0)
            statusText.text = $"Downloading {downloadSize / (1024 * 1024)} MB...";

        var handle = Addressables.DownloadDependenciesAsync(sceneAssets);
        while (!handle.IsDone)
        {
            float percent = handle.GetDownloadStatus().Percent;
            progressBar.value = percent;
            statusText.text = $"Loading... {percent * 100:F0}%";
            await Awaitable.NextFrameAsync();
        }
        Addressables.Release(handle);
    }
}
```

## Memory management

### Reference counting
Each `LoadAssetAsync` increments the count. Each `Release` decrements it. The asset unloads when the
count reaches 0.

```
LoadAssetAsync("sword")  -> refCount = 1 (loaded into memory)
LoadAssetAsync("sword")  -> refCount = 2 (same instance)
Release(handle1)         -> refCount = 1 (still in memory)
Release(handle2)         -> refCount = 0 (unloaded)
```

An asset released to 0 can stay in memory until every asset in its AssetBundle is released, and
until no other loaded bundle depends on it.

### Safe pattern with try/finally

```csharp
public async Awaitable UseTemporaryAssetAsync(AssetReference assetRef)
{
    var handle = Addressables.LoadAssetAsync<TextAsset>(assetRef);
    try
    {
        await handle.Task;
        if (handle.Status == AsyncOperationStatus.Succeeded)
            ProcessData(handle.Result.text);
    }
    finally
    {
        Addressables.Release(handle);
    }
}
```

### Asset manager with tracking

```csharp
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;

public class AddressableAssetManager : MonoBehaviour
{
    private readonly Dictionary<string, AsyncOperationHandle> loadedHandles = new();

    public async Awaitable<T> LoadAsync<T>(string address)
    {
        if (loadedHandles.TryGetValue(address, out var existing))
            return (T)existing.Result;

        var handle = Addressables.LoadAssetAsync<T>(address);
        await handle.Task;

        if (handle.Status == AsyncOperationStatus.Succeeded)
        {
            loadedHandles[address] = handle;
            return handle.Result;
        }
        Addressables.Release(handle);
        return default;
    }

    public void Unload(string address)
    {
        if (loadedHandles.TryGetValue(address, out var handle))
        {
            Addressables.Release(handle);
            loadedHandles.Remove(address);
        }
    }

    public void UnloadAll()
    {
        foreach (var handle in loadedHandles.Values)
            Addressables.Release(handle);
        loadedHandles.Clear();
    }

    private void OnDestroy() => UnloadAll();
}
```

## InstantiateAsync pattern

```csharp
// InstantiateAsync loads and instantiates in one call
var handle = Addressables.InstantiateAsync(prefabRef, position, rotation);
await handle.Task;
var instance = handle.Result;

// To destroy: ReleaseInstance, NOT Destroy
Addressables.ReleaseInstance(instance);
```

### Pool with Addressables

```csharp
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.AddressableAssets;

public class AddressablePool : MonoBehaviour
{
    [SerializeField] private AssetReferenceGameObject prefabRef;
    [SerializeField] private int initialSize = 10;
    private readonly Queue<GameObject> pool = new();
    private readonly List<GameObject> active = new();

    public async Awaitable InitializeAsync()
    {
        for (int i = 0; i < initialSize; i++)
        {
            var handle = Addressables.InstantiateAsync(prefabRef);
            await handle.Task;
            handle.Result.SetActive(false);
            pool.Enqueue(handle.Result);
        }
    }

    public GameObject Get(Vector3 pos, Quaternion rot)
    {
        if (pool.Count == 0) return null;
        var inst = pool.Dequeue();
        inst.transform.SetPositionAndRotation(pos, rot);
        inst.SetActive(true);
        active.Add(inst);
        return inst;
    }

    public void Return(GameObject inst)
    {
        inst.SetActive(false);
        active.Remove(inst);
        pool.Enqueue(inst);
    }

    private void OnDestroy()
    {
        foreach (var inst in pool) Addressables.ReleaseInstance(inst);
        foreach (var inst in active) Addressables.ReleaseInstance(inst);
    }
}
```

## Remote content (CDN)

### Setup
1. Addressables settings: enable **Build Remote Catalog**.
2. Remote Load Path: `https://cdn.example.com/[BuildTarget]`.
3. Remote groups: `RemoteBuildPath` / `RemoteLoadPath`.
4. Build: in the Groups window, Build > New Build > Default Build Script.
5. Upload `ServerData/` to the CDN.

### Runtime catalog update

```csharp
using UnityEngine;
using UnityEngine.AddressableAssets;
using UnityEngine.ResourceManagement.AsyncOperations;

public class ContentUpdater : MonoBehaviour
{
    public async Awaitable<bool> CheckAndUpdateAsync()
    {
        var checkHandle = Addressables.CheckForCatalogUpdates(false);
        await checkHandle.Task;
        if (checkHandle.Status != AsyncOperationStatus.Succeeded)
        {
            Addressables.Release(checkHandle);
            return false;
        }

        var catalogs = checkHandle.Result;
        Addressables.Release(checkHandle);
        if (catalogs == null || catalogs.Count == 0) return false;

        var updateHandle = Addressables.UpdateCatalogs(catalogs, false);
        await updateHandle.Task;
        bool success = updateHandle.Status == AsyncOperationStatus.Succeeded;
        Addressables.Release(updateHandle);
        return success;
    }
}
```

### Check the download size

```csharp
public async Awaitable<long> GetDownloadSizeAsync(string label)
{
    var handle = Addressables.GetDownloadSizeAsync(label);
    await handle.Task;
    long size = handle.Result;
    Addressables.Release(handle);
    return size; // bytes; 0 if already cached
}
```

## Profiling Addressables

Both tools below need build reports: Edit > Preferences > Addressables > enable **Debug Build
Layout**.

- **Addressables Profiler module** (Window > Analysis > Profiler, then enable the Addressable Assets
  module from the Profiler Modules dropdown): per-frame view of loaded catalogs, bundles, assets,
  and their handle counts. Leaks show as handle counts above 0 at the end of a scene. It does not
  work with the "Use Asset Database" Play Mode script; build the content and use an existing build.
- **Addressables Report** (Window > Asset Management > Addressables > Addressables Report): bundle
  sizes and a Potential Issues tab that flags assets duplicated across groups. If a material sits in
  two groups it ships twice; move shared dependencies into a `Shared_Dependencies` group.
- **Analyze window** (Window > Asset Management > Addressables > Analyze): the Check Duplicate
  Bundle Dependencies rule finds duplicates and can fix them by moving them into a new group.
- **Memory Profiler**: compare snapshots before and after a load to confirm `Release` really unloads.

### Profiling checklist
1. Enable Debug Build Layout and build Addressables content.
2. Open the Profiler with the Addressable Assets module before entering Play Mode.
3. Play a full cycle (load scene, play, leave scene).
4. Check that every handle count returns to 0.
5. If a count stays above 0, find the missing `Release`.
6. Check the Addressables Report for duplication and move duplicated assets into a shared group.
