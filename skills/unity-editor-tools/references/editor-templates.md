# Editor Tool Templates

UI Toolkit templates come first; use them for new tools on Unity 6. The IMGUI templates after them
are legacy, for extending existing IMGUI code. For UI Toolkit detail see `ui-uitk`; for IMGUI detail
see `ui-imgui`.

## Custom editor (UI Toolkit)

`PropertyField`s returned from `CreateInspectorGUI()` bind to the `serializedObject` automatically.
No `serializedObject.Update()` / `ApplyModifiedProperties()` calls are needed, and do not call
`Bind()` here.

```csharp
using UnityEditor;
using UnityEditor.UIElements;
using UnityEngine;
using UnityEngine.UIElements;

[CustomEditor(typeof(TargetComponent))]
public class TargetComponentEditor : Editor
{
    // Assign in the Inspector of this editor script (default references)
    [SerializeField] private VisualTreeAsset inspectorUXML;

    public override VisualElement CreateInspectorGUI()
    {
        var root = new VisualElement();

        // Option 1: external UXML (recommended for complex inspectors)
        if (inspectorUXML != null)
        {
            inspectorUXML.CloneTree(root);
            return root;
        }

        // Option 2: build in code (simple inspectors)
        root.Add(new Label("Main") { style = { unityFontStyleAndWeight = FontStyle.Bold } });
        root.Add(new PropertyField(serializedObject.FindProperty("_fieldName")));

        var foldout = new Foldout { text = "Advanced", value = false };
        foldout.Add(new PropertyField(serializedObject.FindProperty("_advancedField")));
        root.Add(foldout);

        root.Add(new Button(() =>
        {
            var component = (TargetComponent)target;
            Undo.RecordObject(component, "Action on TargetComponent");
            // Action logic
        }) { text = "Action" });

        return root;
    }
}
```

## Property drawer (UI Toolkit)

A drawer with only `CreatePropertyGUI` does not work inside an IMGUI inspector or an IMGUI parent
drawer. If the type can appear in IMGUI inspectors, also implement `OnGUI` (see the IMGUI drawer
below).

```csharp
using UnityEditor;
using UnityEditor.UIElements;
using UnityEngine.UIElements;

[CustomPropertyDrawer(typeof(TargetType))]
public class TargetTypeDrawer : PropertyDrawer
{
    public override VisualElement CreatePropertyGUI(SerializedProperty property)
    {
        var row = new VisualElement { style = { flexDirection = FlexDirection.Row } };
        row.Add(new Label(property.displayName) { style = { minWidth = 120 } });

        var fieldA = new PropertyField(property.FindPropertyRelative("fieldA"), string.Empty)
            { style = { flexGrow = 1 } };
        var fieldB = new PropertyField(property.FindPropertyRelative("fieldB"), string.Empty)
            { style = { flexGrow = 1 } };

        row.Add(fieldA);
        row.Add(fieldB);
        return row;
    }
}
```

## Editor window (UI Toolkit)

Build the UI in `CreateGUI()`, which runs when `rootVisualElement` is ready. An `EditorWindow` has no
`serializedObject` of its own; to bind fields to the window's own serialized fields, wrap it in a
`SerializedObject` and call `Bind()` on the root.

```csharp
using UnityEditor;
using UnityEditor.UIElements;
using UnityEngine;
using UnityEngine.UIElements;

public class MyToolWindow : EditorWindow
{
    [SerializeField] private VisualTreeAsset windowUXML;   // optional, assign as a default reference
    [SerializeField] private StyleSheet windowUSS;         // optional
    [SerializeField] private int _count = 10;

    [MenuItem("Tools/My Tool")]
    private static void Open() => GetWindow<MyToolWindow>("My Tool");

    public void CreateGUI()
    {
        var root = rootVisualElement;

        if (windowUXML != null) windowUXML.CloneTree(root);
        if (windowUSS != null) root.styleSheets.Add(windowUSS);

        // Toolbar
        var toolbar = new Toolbar();
        toolbar.Add(new ToolbarButton(Refresh) { text = "Refresh" });
        root.Add(toolbar);

        // Field bound to this window's serialized field
        root.Add(new PropertyField { bindingPath = nameof(_count) });

        root.Add(new HelpBox("General content.", HelpBoxMessageType.Info));

        root.Bind(new SerializedObject(this));
    }

    private void Refresh() { /* reload data, rebuild lists */ }
}
```

Load UXML and USS through serialized default references (as above) or by path with
`AssetDatabase.LoadAssetAtPath<VisualTreeAsset>(...)` / `LoadAssetAtPath<StyleSheet>(...)`.

## Menu item (with validation)

```csharp
using UnityEditor;
using UnityEngine;

public static class MyMenuItems
{
    [MenuItem("Tools/Do Thing %#d")] // Ctrl/Cmd+Shift+D
    private static void DoThing()
    {
        var go = Selection.activeGameObject;
        Undo.RecordObject(go, "Do Thing");
        // Action here
    }

    [MenuItem("Tools/Do Thing", true)]
    private static bool ValidateDoThing() => Selection.activeGameObject != null;
}
```

---

## Legacy IMGUI templates

### Custom editor (IMGUI)

```csharp
using UnityEditor;
using UnityEngine;

[CustomEditor(typeof(TargetComponent))]
public class TargetComponentEditor : Editor
{
    SerializedProperty _propName;
    bool _foldoutAdvanced;

    void OnEnable()
    {
        _propName = serializedObject.FindProperty("_fieldName");
    }

    public override void OnInspectorGUI()
    {
        serializedObject.Update();

        EditorGUILayout.LabelField("Main", EditorStyles.boldLabel);
        EditorGUILayout.PropertyField(_propName);

        EditorGUILayout.Space(8);
        _foldoutAdvanced = EditorGUILayout.Foldout(_foldoutAdvanced, "Advanced", true);
        if (_foldoutAdvanced)
        {
            EditorGUI.indentLevel++;
            // Advanced fields here
            EditorGUI.indentLevel--;
        }

        if (GUILayout.Button("Action"))
        {
            var component = (TargetComponent)target;
            Undo.RecordObject(component, "Action on TargetComponent");
            // Action logic
        }

        serializedObject.ApplyModifiedProperties();
    }
}
```

### Property drawer (IMGUI)

```csharp
using UnityEditor;
using UnityEngine;

[CustomPropertyDrawer(typeof(TargetType))]
public class TargetTypeDrawer : PropertyDrawer
{
    public override void OnGUI(Rect position, SerializedProperty property, GUIContent label)
    {
        EditorGUI.BeginProperty(position, label, property);

        position = EditorGUI.PrefixLabel(position, label);
        var indent = EditorGUI.indentLevel;
        EditorGUI.indentLevel = 0;

        // Lay out sub-fields side by side
        var halfWidth = position.width * 0.5f;
        var rectA = new Rect(position.x, position.y, halfWidth - 2, position.height);
        var rectB = new Rect(position.x + halfWidth, position.y, halfWidth, position.height);

        EditorGUI.PropertyField(rectA, property.FindPropertyRelative("fieldA"), GUIContent.none);
        EditorGUI.PropertyField(rectB, property.FindPropertyRelative("fieldB"), GUIContent.none);

        EditorGUI.indentLevel = indent;
        EditorGUI.EndProperty();
    }

    public override float GetPropertyHeight(SerializedProperty property, GUIContent label)
    {
        return EditorGUIUtility.singleLineHeight;
    }
}
```

### Editor window (IMGUI, tabs and toolbar)

```csharp
using UnityEditor;
using UnityEngine;

public class MyToolWindow : EditorWindow
{
    [MenuItem("Tools/My Tool")]
    static void Open() => GetWindow<MyToolWindow>("My Tool");

    int _selectedTab;
    readonly string[] _tabs = { "General", "Config", "Debug" };
    Vector2 _scrollPos;

    void OnGUI()
    {
        // Toolbar
        EditorGUILayout.BeginHorizontal(EditorStyles.toolbar);
        if (GUILayout.Button("Refresh", EditorStyles.toolbarButton, GUILayout.Width(60)))
            Refresh();
        GUILayout.FlexibleSpace();
        EditorGUILayout.EndHorizontal();

        // Tabs
        _selectedTab = GUILayout.Toolbar(_selectedTab, _tabs);
        EditorGUILayout.Space(4);

        _scrollPos = EditorGUILayout.BeginScrollView(_scrollPos);
        switch (_selectedTab)
        {
            case 0: DrawGeneralTab(); break;
            case 1: DrawConfigTab(); break;
            case 2: DrawDebugTab(); break;
        }
        EditorGUILayout.EndScrollView();
    }

    void DrawGeneralTab() { EditorGUILayout.HelpBox("General content.", MessageType.Info); }
    void DrawConfigTab() { /* Configuration */ }
    void DrawDebugTab() { /* Debug info */ }
    void Refresh() { Repaint(); }
}
```

### Common IMGUI calls

```csharp
// Horizontal / vertical layout
EditorGUILayout.BeginHorizontal();
EditorGUILayout.EndHorizontal();

// PropertyField with a custom label and tooltip
EditorGUILayout.PropertyField(prop, new GUIContent("Label", "Tooltip"));

// Foldout
foldout = EditorGUILayout.Foldout(foldout, "Section", true);

// Progress bar
EditorGUI.ProgressBar(rect, value, "Loading...");

// ReorderableList (namespace UnityEditorInternal)
var list = new ReorderableList(serializedObject, prop, true, true, true, true);
list.drawElementCallback = (rect, index, active, focused) => { };
list.DoLayoutList();
```

In UI Toolkit, a `PropertyField` for an array or list draws a list view itself; use `ListView` when
you need more control. `ReorderableList` belongs to IMGUI code.
