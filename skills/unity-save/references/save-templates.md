# Save system templates

Complete C# for a Unity 6 save system. The templates use Newtonsoft.Json (recommended); swap in
`JsonUtility` if you need to.

The file APIs here are limited to what Unity's .NET Standard 2.1 and .NET Framework API
compatibility levels provide. `File.Move(source, dest, overwrite)` is not in either, so the atomic
write uses `File.Replace`.

---

## 1. ISaveable interface

```csharp
// Implemented by every component whose state is saved.
public interface ISaveable
{
    // Unique key for this saveable (for example "player", "inventory_chest_03").
    string SaveKey { get; }

    // Captures the current state as a serializable plain C# object.
    object CaptureState();

    // Restores state from deserialized data.
    void RestoreState(object state);
}
```

Example implementation:

```csharp
using Newtonsoft.Json.Linq;
using UnityEngine;

public class PlayerHealth : MonoBehaviour, ISaveable
{
    [SerializeField] private float maxHealth = 100f;
    private float currentHealth;

    public string SaveKey => "player_health";

    public object CaptureState() => new PlayerHealthData
    {
        currentHealth = this.currentHealth,
        maxHealth = this.maxHealth
    };

    public void RestoreState(object state)
    {
        // A migrated save hands back a JObject instead of the typed object.
        PlayerHealthData data = state switch
        {
            PlayerHealthData d => d,
            JObject j => j.ToObject<PlayerHealthData>(),
            _ => null
        };
        if (data == null) return;
        currentHealth = data.currentHealth;
        maxHealth = data.maxHealth;
    }

    [System.Serializable]
    private class PlayerHealthData
    {
        public float currentHealth;
        public float maxHealth;
    }
}
```

---

## 2. SaveData container

```csharp
using System;
using System.Collections.Generic;

[Serializable]
public class SaveData
{
    // Schema version: bump on every structural change.
    public int version = 1;

    // State captured by each ISaveable, keyed by SaveKey.
    public Dictionary<string, object> data = new();

    public SaveMetadata metadata = new();
}

[Serializable]
public class SaveMetadata
{
    public string timestamp;
    public float playTimeSeconds;
    public string sceneName;
    public string displayName;

    public static SaveMetadata CreateNow(float playTime, string scene) => new()
    {
        timestamp = DateTime.UtcNow.ToString("o"),
        playTimeSeconds = playTime,
        sceneName = scene,
        displayName = $"Save - {DateTime.Now:g}"
    };
}
```

---

## 3. SaveManager

Atomic writes, multiple slots, and `Awaitable`.

```csharp
using System;
using System.Collections.Generic;
using System.IO;
using System.Threading;
using Newtonsoft.Json;
using UnityEngine;
using UnityEngine.SceneManagement;

public class SaveManager : MonoBehaviour
{
    public static SaveManager Instance { get; private set; }

    [SerializeField] private string saveFolder = "saves";
    [SerializeField] private string fileExtension = ".save";

    private readonly Dictionary<string, ISaveable> saveables = new();
    private readonly JsonSerializerSettings jsonSettings = new()
    {
        TypeNameHandling = TypeNameHandling.Auto,
        Formatting = Formatting.Indented,
        ReferenceLoopHandling = ReferenceLoopHandling.Ignore
    };

    private string SaveDirectory =>
        Path.Combine(Application.persistentDataPath, saveFolder);

    private void Awake()
    {
        if (Instance != null && Instance != this)
        {
            Destroy(gameObject);
            return;
        }
        Instance = this;
        DontDestroyOnLoad(gameObject);
        Directory.CreateDirectory(SaveDirectory);
    }

    // --- Registry ---

    public void RegisterSaveable(ISaveable saveable)
    {
        if (!saveables.TryAdd(saveable.SaveKey, saveable))
            Debug.LogWarning($"[SaveManager] Duplicate SaveKey: {saveable.SaveKey}");
    }

    public void UnregisterSaveable(ISaveable saveable) =>
        saveables.Remove(saveable.SaveKey);

    // --- Save ---

    public async Awaitable SaveAsync(string slotName, float playTime = 0f,
        CancellationToken ct = default)
    {
        var saveData = new SaveData
        {
            version = SaveMigration.CurrentVersion,
            metadata = SaveMetadata.CreateNow(playTime,
                SceneManager.GetActiveScene().name)
        };

        foreach (var (key, saveable) in saveables)
        {
            try { saveData.data[key] = saveable.CaptureState(); }
            catch (Exception e)
            { Debug.LogError($"[SaveManager] Capture failed for '{key}': {e.Message}"); }
        }

        string json = JsonConvert.SerializeObject(saveData, jsonSettings);
        await WriteAtomicAsync(slotName, json, ct);
        Debug.Log($"[SaveManager] Saved '{slotName}'.");
    }

    // --- Load ---

    public async Awaitable<bool> LoadAsync(string slotName,
        CancellationToken ct = default)
    {
        string filePath = GetSavePath(slotName);
        if (!File.Exists(filePath))
        {
            Debug.LogWarning($"[SaveManager] No save found: {slotName}");
            return false;
        }

        try
        {
            string json = await File.ReadAllTextAsync(filePath, ct);
            var saveData = JsonConvert.DeserializeObject<SaveData>(json, jsonSettings);

            if (saveData == null)
            {
                Debug.LogError("[SaveManager] Save file is corrupted.");
                return await TryLoadBackupAsync(slotName, ct);
            }

            saveData = SaveMigration.Migrate(saveData);
            RestoreAll(saveData);
            Debug.Log($"[SaveManager] Loaded '{slotName}' (v{saveData.version}).");
            return true;
        }
        catch (Exception e)
        {
            Debug.LogError($"[SaveManager] Load failed: {e.Message}");
            return await TryLoadBackupAsync(slotName, ct);
        }
    }

    private void RestoreAll(SaveData saveData)
    {
        foreach (var (key, saveable) in saveables)
        {
            if (saveData.data.TryGetValue(key, out object state))
            {
                try { saveable.RestoreState(state); }
                catch (Exception e)
                { Debug.LogError($"[SaveManager] Restore failed for '{key}': {e.Message}"); }
            }
        }
    }

    // --- Atomic write ---

    private async Awaitable WriteAtomicAsync(string slotName, string content,
        CancellationToken ct)
    {
        string filePath = GetSavePath(slotName);
        string tmpPath = filePath + ".tmp";
        string bakPath = filePath + ".bak";

        await File.WriteAllTextAsync(tmpPath, content, ct);
        if (File.Exists(filePath))
            File.Replace(tmpPath, filePath, bakPath);   // swaps in the new file, keeps the old one as .bak
        else
            File.Move(tmpPath, filePath);
    }

    private async Awaitable<bool> TryLoadBackupAsync(string slotName,
        CancellationToken ct)
    {
        string bakPath = GetSavePath(slotName) + ".bak";
        if (!File.Exists(bakPath)) return false;

        Debug.LogWarning("[SaveManager] Trying to restore from .bak");
        try
        {
            string json = await File.ReadAllTextAsync(bakPath, ct);
            var saveData = JsonConvert.DeserializeObject<SaveData>(json, jsonSettings);
            if (saveData == null) return false;
            saveData = SaveMigration.Migrate(saveData);
            RestoreAll(saveData);
            return true;
        }
        catch { return false; }
    }

    // --- Utilities ---

    public bool SaveExists(string slotName) =>
        File.Exists(GetSavePath(slotName));

    public void DeleteSave(string slotName)
    {
        string path = GetSavePath(slotName);
        if (File.Exists(path)) File.Delete(path);
        if (File.Exists(path + ".bak")) File.Delete(path + ".bak");
    }

    public string[] GetAllSlots()
    {
        if (!Directory.Exists(SaveDirectory))
            return Array.Empty<string>();

        var files = Directory.GetFiles(SaveDirectory, $"*{fileExtension}");
        var slots = new string[files.Length];
        for (int i = 0; i < files.Length; i++)
            slots[i] = Path.GetFileNameWithoutExtension(files[i]);
        return slots;
    }

    private string GetSavePath(string slotName) =>
        Path.Combine(SaveDirectory, slotName + fileExtension);
}
```
