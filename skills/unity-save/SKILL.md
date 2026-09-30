---
name: unity-save
description: Use when building or fixing a save/load system in a Unity 6 project - serializing game state to disk, save slots, auto-save, save-file versioning and migration, corrupted or lost saves, or optional save encryption. Triggers include "save system", "save game", "load game", "save slots", "autosave", "persistence", "PlayerPrefs", "persistentDataPath", "JSON save", "JsonUtility", "Newtonsoft", "BinaryFormatter", "ISaveable", "save migration", "corrupted save", and "encrypt save file". For cloud saves with Unity Gaming Services, use build-live-game.
---

Adapted from JulianKerignard/Unity-Skills (MIT); see LICENSE.

# Unity save system

## What this skill does

Guides a complete save system for Unity 6: serializing game state, atomic file writes, versioned
save data, multiple slots, auto-save, and optional encryption. Scales from PlayerPrefs to a local
storage layer that a cloud backend can plug into. Cloud saves themselves (Unity Gaming Services
Cloud Save) belong to the build-live-game skill.

## Requirements

- Unity 6.0+ (`Awaitable`)
- **Recommended**: Newtonsoft.Json (`com.unity.nuget.newtonsoft-json`) for polymorphism and dictionaries
- No hard dependency for simple cases (`JsonUtility` is enough)

## Quick start

1. **Pick a format**: `JsonUtility` (simple) or Newtonsoft.Json (polymorphism, `Dictionary`).
2. **Implement `ISaveable`** on every component whose state is saved.
3. **Write a `SaveManager`** that writes atomically under `Application.persistentDataPath`.
4. **Wire auto-save** (dirty flag + timer + `OnApplicationPause`).
5. **Test** the save/load round trip with an Edit Mode test (see unity-test).

## Decision tree

```
What are you saving?
|
+-- User preferences (volume, language, bindings)?
|   +-- Very little data (<1 KB) --> PlayerPrefs
|   +-- More structured ----------> JSON in persistentDataPath
|
+-- Game state (progress, inventory, position)?
|   +-- One slot --------------> JSON + ISaveable pattern
|   +-- Several slots ---------> SaveManager with named slots
|   +-- Large data (>10 MB) ---> Binary format (MemoryPack/MessagePack)
|
+-- Cloud sync?
|   +-- Unity Gaming Services -----> Cloud Save (see build-live-game)
|   +-- Native per-platform saves --> Platform Toolkit package (Unity 6.3+)
|   +-- Hybrid (local + cloud) ----> ISaveStorage abstraction (references/save-advanced.md)
|
+-- Sensitive (anti-cheat)?
    +-- AES encryption + integrity hash (references/save-advanced.md)
```

## Step by step

### Step 1 - Pick the serialization format

| Criterion | JsonUtility | Newtonsoft.Json | MemoryPack | MessagePack |
|-----------|-------------|-----------------|------------|-------------|
| Setup | Built in | Unity package | NuGet | NuGet |
| Polymorphism | No | Yes (`TypeNameHandling`) | Yes | Yes |
| Dictionary | No | Yes | Yes | Yes |
| Readable | JSON | JSON | Binary | Binary |
| Speed | Fast | Medium | Very fast | Fast |
| Size | Medium | Medium | Small | Small |
| Use for | Prototypes | **Default choice** | >10 MB of data | Binary alternative |

### Step 2 - Create ISaveable and SaveData

- `ISaveable`: `SaveKey`, `CaptureState()`, `RestoreState(object)`.
- `SaveData`: a `version` field, a `Dictionary<string, object>`, and metadata.
- Full code in `references/save-templates.md` (ISaveable, SaveData, SaveManager).

### Step 3 - Implement SaveManager

- Singleton or service locator.
- Registry of `ISaveable` (Register/Unregister).
- `SaveAsync`: capture every state -> serialize -> atomic write (`.tmp` -> `.save`, keep `.bak`).
- `LoadAsync`: read file -> deserialize -> migrate -> restore every state.
- Path: `Path.Combine(Application.persistentDataPath, "saves", slotName + ".save")`.

### Step 4 - Auto-save

- Dirty flag: each `ISaveable` reports its changes.
- Configurable timer (60-120 s is typical).
- Save on `OnApplicationPause(true)` and on scene change.
- See the Auto-save section of `references/save-advanced.md`.

### Step 5 - Test the save/load cycle

- Edit Mode test: save -> clear state -> load -> assert state restored.
- Corruption test: load a truncated file -> check the `.bak` fallback.
- Migration test: load a v1 save with v2 code.

## Rules

### Always

- **Always** write atomically (write `.tmp`, replace, keep `.bak`).
- **Always** version `SaveData` (bump `version` on every schema change).
- **Always** use `Application.persistentDataPath`, never `dataPath` or `streamingAssetsPath`.
- **Always** save on `OnApplicationPause(true)` on mobile.
- **Always** serialize plain C# objects, not Unity types.
- **Always** handle "no save yet" (first launch).

### Never

- **Never** use `BinaryFormatter`: it is insecure and obsolete.
- **Never** store `MonoBehaviour`, `GameObject`, or `ScriptableObject` references in a save.
- **Never** write files over 100 KB synchronously on the main thread.
- **Never** delete the old file before the new one is fully written (a crash then loses the save).
- **Never** swallow I/O exceptions silently: try/catch and fall back.

## Related skills

- unity-test: Edit Mode tests for the save/load cycle.
- unity-addressables: save asset references as address strings.
- build-live-game: Unity Gaming Services Cloud Save and player accounts.

## Troubleshooting

| Problem | Likely cause | Fix |
|---------|--------------|-----|
| `FileNotFoundException` on load | First launch, no save | Check `File.Exists()` first and return default data |
| Data lost after an update | Schema changed with no migration | Add a `version` field and a v1->v2->vN migration chain |
| `JsonSerializationException` | Unrecognized polymorphic type | Newtonsoft: `TypeNameHandling.Auto` + a custom `SerializationBinder` |
| Corrupted save (truncated JSON) | Crash during write | Atomic write (`.tmp` -> replace) + `.bak` fallback |
| `UnauthorizedAccessException` | Disallowed path (Android scoped storage) | Use only `persistentDataPath` |
| PlayerPrefs gone (iOS) | System cleanup or reinstall | Move important data to a file |
| Save too large (>50 MB) | JSON on large volumes | Switch to MemoryPack/MessagePack, compress (GZip) |
| Cloud and local out of sync | Version conflict | Resolve conflicts by timestamp or version counter |
