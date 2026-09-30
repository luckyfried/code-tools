# Advanced save system: storage, migration, encryption

Advanced patterns for Unity 6 save systems: a local/cloud storage abstraction, versioned schema
migration, auto-save, AES encryption, and per-platform notes.

> Read `save-templates.md` first for ISaveable, SaveData, and SaveManager.

---

## 1. ISaveStorage abstraction

Lets local, cloud, and console storage be swapped behind one interface.

```csharp
using System.Threading;
using UnityEngine;

public interface ISaveStorage
{
    Awaitable SaveAsync(string key, byte[] data, CancellationToken ct = default);
    Awaitable<byte[]> LoadAsync(string key, CancellationToken ct = default);
    Awaitable<bool> ExistsAsync(string key, CancellationToken ct = default);
    Awaitable DeleteAsync(string key, CancellationToken ct = default);
}
```

Local implementation:

```csharp
using System.IO;
using System.Threading;
using UnityEngine;

public class LocalSaveStorage : ISaveStorage
{
    private readonly string basePath;

    public LocalSaveStorage(string subfolder = "saves")
    {
        basePath = Path.Combine(Application.persistentDataPath, subfolder);
        Directory.CreateDirectory(basePath);
    }

    private string GetPath(string key) => Path.Combine(basePath, key);

    public async Awaitable SaveAsync(string key, byte[] data, CancellationToken ct = default)
    {
        string path = GetPath(key);
        string tmpPath = path + ".tmp";

        await File.WriteAllBytesAsync(tmpPath, data, ct);
        if (File.Exists(path))
            File.Replace(tmpPath, path, path + ".bak");
        else
            File.Move(tmpPath, path);
    }

    public async Awaitable<byte[]> LoadAsync(string key, CancellationToken ct = default)
    {
        string path = GetPath(key);
        if (!File.Exists(path)) return null;
        return await File.ReadAllBytesAsync(path, ct);
    }

    public async Awaitable<bool> ExistsAsync(string key, CancellationToken ct = default)
    {
        await Awaitable.NextFrameAsync(ct);
        return File.Exists(GetPath(key));
    }

    public async Awaitable DeleteAsync(string key, CancellationToken ct = default)
    {
        string path = GetPath(key);
        if (File.Exists(path)) File.Delete(path);
        if (File.Exists(path + ".bak")) File.Delete(path + ".bak");
        await Awaitable.NextFrameAsync(ct);
    }
}
```

A cloud implementation of the same interface wraps Unity Gaming Services Cloud Save; see the
build-live-game skill for setting up the service and signing players in.

---

## 2. Save data versioning and migration

Chained v1 -> v2 -> v3 migration using `JObject` transforms (Newtonsoft). A migrated entry comes
back as a `JObject`, so `RestoreState` must accept one (see the `PlayerHealth` example in
`save-templates.md`).

```csharp
using Newtonsoft.Json.Linq;
using UnityEngine;

public static class SaveMigration
{
    public const int CurrentVersion = 3;

    // Applies every migration needed to bring saveData to the current version.
    public static SaveData Migrate(SaveData saveData)
    {
        if (saveData.version >= CurrentVersion)
            return saveData;

        Debug.Log($"[SaveMigration] Migrating v{saveData.version} -> v{CurrentVersion}");

        while (saveData.version < CurrentVersion)
        {
            switch (saveData.version)
            {
                case 1: MigrateV1ToV2(saveData); break;
                case 2: MigrateV2ToV3(saveData); break;
                default:
                    Debug.LogError($"[SaveMigration] Unknown version: {saveData.version}");
                    return saveData;
            }
            saveData.version++;
        }
        return saveData;
    }

    private static void MigrateV1ToV2(SaveData saveData)
    {
        // Example: v2 adds a "stamina" field that v1 did not have.
        if (saveData.data.TryGetValue("player", out object playerState))
        {
            var jObj = JObject.FromObject(playerState);
            if (!jObj.ContainsKey("stamina"))
                jObj["stamina"] = 100f;
            saveData.data["player"] = jObj;
        }
    }

    private static void MigrateV2ToV3(SaveData saveData)
    {
        // Example: v3 renames "items" (list) to "slots".
        if (saveData.data.TryGetValue("inventory", out object invState))
        {
            var jObj = JObject.FromObject(invState);
            if (jObj.ContainsKey("items") && !jObj.ContainsKey("slots"))
            {
                jObj["slots"] = jObj["items"];
                jObj.Remove("items");
            }
            saveData.data["inventory"] = jObj;
        }
    }
}
```

---

## 3. Auto-save manager

Saves automatically, driven by a dirty flag and a timer.

```csharp
using UnityEngine;
using UnityEngine.SceneManagement;

public class AutoSaveManager : MonoBehaviour
{
    [SerializeField] private float autoSaveIntervalSeconds = 90f;
    [SerializeField] private string autoSaveSlot = "autosave";

    private float timeSinceLastSave;
    private float totalPlayTime;
    private bool isDirty;
    private bool isSaving;

    // Call from any system when state changes.
    public void MarkDirty() => isDirty = true;

    private void OnEnable() =>
        SceneManager.activeSceneChanged += OnSceneChanged;

    private void OnDisable() =>
        SceneManager.activeSceneChanged -= OnSceneChanged;

    private void Update()
    {
        totalPlayTime += Time.unscaledDeltaTime;
        timeSinceLastSave += Time.unscaledDeltaTime;

        if (isDirty && !isSaving
            && timeSinceLastSave >= autoSaveIntervalSeconds)
        {
            _ = PerformAutoSave();
        }
    }

    private void OnApplicationPause(bool pauseStatus)
    {
        if (pauseStatus && isDirty && !isSaving)
            _ = PerformAutoSave();
    }

    private void OnSceneChanged(Scene from, Scene to)
    {
        if (isDirty && !isSaving)
            _ = PerformAutoSave();
    }

    private async Awaitable PerformAutoSave()
    {
        isSaving = true;
        try
        {
            await SaveManager.Instance.SaveAsync(autoSaveSlot, totalPlayTime);
            isDirty = false;
            timeSinceLastSave = 0f;
        }
        catch (System.Exception e)
        {
            Debug.LogError($"[AutoSave] Failed: {e.Message}");
        }
        finally
        {
            isSaving = false;
        }
    }
}
```

---

## 4. Encryption (optional)

AES encryption plus a SHA-256 integrity hash for sensitive data. A fresh random IV is generated for
every save and stored in front of the ciphertext; never reuse a fixed IV. The key must be 16, 24,
or 32 bytes. A key shipped inside the game only deters casual editing; it does not stop a
determined player.

```csharp
using System;
using System.IO;
using System.Security.Cryptography;
using System.Text;

public static class SaveEncryption
{
    // Returns IV (16 bytes) followed by the ciphertext.
    public static byte[] Encrypt(string plainText, byte[] key)
    {
        using var aes = Aes.Create();
        aes.Key = key;
        aes.GenerateIV();

        using var ms = new MemoryStream();
        ms.Write(aes.IV, 0, aes.IV.Length);
        using (var cs = new CryptoStream(ms, aes.CreateEncryptor(), CryptoStreamMode.Write))
        using (var writer = new StreamWriter(cs))
            writer.Write(plainText);
        return ms.ToArray();
    }

    public static string Decrypt(byte[] data, byte[] key)
    {
        using var aes = Aes.Create();
        aes.Key = key;
        var iv = new byte[aes.BlockSize / 8];
        Array.Copy(data, iv, iv.Length);
        aes.IV = iv;

        using var ms = new MemoryStream(data, iv.Length, data.Length - iv.Length);
        using var cs = new CryptoStream(ms, aes.CreateDecryptor(), CryptoStreamMode.Read);
        using var reader = new StreamReader(cs);
        return reader.ReadToEnd();
    }

    // SHA-256 hash to check the save file has not been altered.
    public static string ComputeHash(string content)
    {
        using var sha = SHA256.Create();
        byte[] bytes = sha.ComputeHash(Encoding.UTF8.GetBytes(content));
        return Convert.ToBase64String(bytes);
    }

    public static bool VerifyHash(string content, string expectedHash) =>
        ComputeHash(content) == expectedHash;
}
```

---

## 5. Per-platform notes

| Platform | `persistentDataPath` | Notes |
|----------|----------------------|-------|
| Windows | `%userprofile%\AppData\LocalLow\<company>\<product>` | Reliable, no restrictions |
| macOS | `~/Library/Application Support/<company>/<product>` | Reliable, backed up by Time Machine |
| Linux | `~/.config/unity3d/<company>/<product>` | Reliable |
| Android | `/storage/emulated/0/Android/data/<package>/files` | Wiped by "Clear data" |
| iOS | the app's `Documents` folder | Backed up by iCloud automatically |
| Web | IndexedDB (via Emscripten) | No real file system; size limited by the browser's storage quota |

### Platform tips

- **Mobile**: always save in `OnApplicationPause(true)`. The OS can kill the app without calling
  `OnApplicationQuit`.
- **Web**: file operations are synchronous and blocking. Keep saves small (<1 MB).
- **Consoles**: each platform has its own save system. Hide it behind `ISaveStorage`, or use the
  Platform Toolkit package (Unity 6.3+), which gives one save-data API across platforms.
- **Cloud**: Cloud Save handles sync, but keep a local fallback for when the network drops. Setup is
  in build-live-game.
