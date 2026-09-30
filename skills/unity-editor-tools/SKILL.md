---
name: unity-editor-tools
description: Use when building custom Unity Editor tooling in C# - custom inspectors, property drawers, editor windows, menu items, wizards, and asset import processors - including setting up the Editor assembly definition. Targets Unity 6 with UI Toolkit (CreateInspectorGUI, CreatePropertyGUI, EditorWindow.CreateGUI) for new UI and IMGUI (OnInspectorGUI, OnGUI) as legacy. Triggers include "custom inspector", "custom editor", "editor window", "property drawer", "menu item", "editor tool", "editor script", "ScriptableWizard", "AssetPostprocessor", "CreateInspectorGUI", "OnInspectorGUI", "Editor folder", "Editor asmdef".
---

Adapted from JulianKerignard/Unity-Skills (MIT); see LICENSE.

# Unity Editor Tools

Builds custom Unity Editor tools that speed up development: custom inspectors, property drawers,
editor windows, menu items, wizards, and asset post-processors. Output is C# in an Editor folder
with a correct assembly definition.

**On Unity 6, build new editor UI with UI Toolkit:** `Editor.CreateInspectorGUI`,
`PropertyDrawer.CreatePropertyGUI`, and `EditorWindow.CreateGUI`. IMGUI (`OnInspectorGUI`, `OnGUI`)
is legacy; use it only when extending existing IMGUI code or where a UI Toolkit path does not exist.
For UI Toolkit detail (UXML, USS, binding, controls) use Unity's official `ui-uitk` skill; for IMGUI
detail use `ui-imgui`. For current Unity 6 APIs in general, see `unity-current-api`.

## Quick start

1. Identify the workflow to speed up.
2. Pick the tool type from the table below.
3. Check the Editor assembly structure.
4. Write the script from the matching template in `references/editor-templates.md`.
5. Compile and check it in Unity (`unity-compile-and-test`).

## Which tool type

| Need | Type | Base class | UI Toolkit entry point |
|------|------|------------|------------------------|
| Change how a component looks in the Inspector | Custom editor | `Editor` | `CreateInspectorGUI()` |
| Change how one field type is drawn | Property drawer | `PropertyDrawer` | `CreatePropertyGUI()` |
| A standalone tool window | Editor window | `EditorWindow` | `CreateGUI()` |
| A quick action in a menu | Menu item | static method + `[MenuItem]` | none |
| A step-by-step assistant | Wizard | `ScriptableWizard` | IMGUI only |
| Process assets on import | Asset post-processor | `AssetPostprocessor` | none |

## Step by step

### Step 1: Identify the workflow

Find the components involved: search `Assets/Scripts/**/*.cs` for `class .* : MonoBehaviour`. Ask:
which component should be easier to edit, which action should be automated, what visual feedback is
missing?

### Step 2: Check the Editor assembly

Before writing code, make sure the Editor infrastructure exists:

1. Look for `Assets/**/Editor/*.asmdef`.
2. If there is none, create `Assets/Scripts/Editor/`.
3. Create `Game.Editor.asmdef` that references the runtime assembly.
4. Make sure it targets only the Editor platform.

`Game.Editor.asmdef`:

```json
{
    "name": "Game.Editor",
    "rootNamespace": "",
    "references": ["Game.Runtime"],
    "includePlatforms": ["Editor"],
    "excludePlatforms": [],
    "allowUnsafeCode": false,
    "overrideReferences": false
}
```

If there is no `Game.Runtime.asmdef` (or equivalent runtime assembly) under `Assets/Scripts/`, create
one, or reference whatever runtime assembly the project already uses.

### Step 3: Write the editor script

Templates in `references/editor-templates.md`:

| Template | Base class | Use |
|----------|------------|-----|
| Custom editor (UI Toolkit) | `Editor` | Default for new inspectors; binds automatically |
| Property drawer (UI Toolkit) | `PropertyDrawer` | Default for new field drawers |
| Editor window (UI Toolkit) | `EditorWindow` | Default for new tool windows |
| Menu item | static attribute | Quick menu action |
| Custom editor (IMGUI, legacy) | `Editor` | Extending existing IMGUI inspectors |
| Property drawer (IMGUI, legacy) | `PropertyDrawer` | Drawers that must also work inside IMGUI inspectors |
| Editor window (IMGUI, legacy) | `EditorWindow` | Extending existing IMGUI windows |

### Step 4: Verify

1. The file is in an Editor folder (`Assets/Scripts/Editor/` or `Assets/Editor/`).
2. It compiles with a clean Console (`unity-compile-and-test`).
3. `using UnityEditor;` is present.
4. No runtime assembly references an Editor type.

## Rules

- **Always** put editor scripts under `Assets/Scripts/Editor/` or `Assets/Editor/`, never loose in
  `Assets/Scripts/`.
- **Always** use an Editor assembly definition with `includePlatforms: ["Editor"]`.
- **Always** call `Undo.RecordObject()` before changing an object from a button or menu action.
- **Never** reference Editor code from a runtime assembly.
- **Never** use `target` uncast in a custom editor; cast it (`(T)target`) or go through
  `serializedObject`.
- UI Toolkit: do not call `Bind()` inside `CreateInspectorGUI()` or `CreatePropertyGUI()`; the
  Inspector binds the returned element for you.
- IMGUI: wrap the body of `OnInspectorGUI` in `serializedObject.Update()` /
  `ApplyModifiedProperties()`, wrap drawers in `EditorGUI.BeginProperty` / `EndProperty`, and pass
  `GUIContent.none` when drawing sub-fields in a drawer.

## Related skills

- `ui-uitk`: UI Toolkit detail (UXML, USS, controls, binding), for editor and runtime UI
- `ui-imgui`: IMGUI detail
- `unity-test`: writing tests for editor tools
- `unity-compile-and-test`: compiling and running the tests
- `unity-current-api`: current Unity 6 APIs

## Troubleshooting

| Problem | Fix |
|---------|-----|
| `The type or namespace 'Editor' could not be found` | The script is not in an Editor folder, or its assembly definition lacks `includePlatforms: ["Editor"]` |
| Custom inspector does not show | `typeof(TargetComponent)` must match the target type exactly, and the script must compile |
| UI Toolkit inspector is blank | `CreateInspectorGUI()` returned `null` or an empty element, or an IMGUI `OnInspectorGUI` override is hiding it |
| `PropertyField` shows nothing | The property path passed to `FindProperty()` is wrong (it is case-sensitive and must match the serialized field name) |
| `NullReferenceException` in `OnEnable` | Same cause: `FindProperty()` name does not match the `[SerializeField]` field |
| Property drawer is not applied | `[CustomPropertyDrawer(typeof(T))]` must name the field's type (or attribute), not the field |
| Drawer works in one inspector, not another | Only `CreatePropertyGUI` is implemented and the host inspector is IMGUI; also implement `OnGUI` |
| `Multiple editors` warning | Two custom editors target the same type; search the project for `CustomEditor(typeof(X))` |
| Menu item is greyed out | Its validate method returned `false`; check the conditions |
| Changes cannot be undone | Call `Undo.RecordObject()` before each direct change |
