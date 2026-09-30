---
name: ue-editor-python-pipeline
description: Use when automating Unreal Engine 5.8 content work with Editor Python - writing or running `unreal` module scripts, batch importing FBX/glTF/USD, bulk asset changes (renames, materials, Nanite, redirectors, validation), or headless content jobs through UnrealEditor-Cmd. Not for C++ editor modules or authoring skills for Epic's MCP.
---

# Unreal Editor Python content pipeline (UE 5.8)

Editor Python drives the Unreal Editor from scripts: import files, query and change assets, edit
levels, save and check out packages. It runs only in the Editor. It does not exist at runtime or in
packaged builds. UE 5.8 embeds Python 3.11.

Epic labels the Python API reference "Experimental". Before using a class or method that is not
in this skill, look it up in the 5.8 Python API reference
(`dev.epicgames.com/documentation/en-us/unreal-engine/python-api/`) or in the generated stub file
(see Setup). Do not guess method names.

## Route elsewhere

- Authoring skills or toolsets for Epic's MCP plugin: use Epic's plugin skills `create-toolset`
  and `unreal-skill`.
- C++ editor modules, custom asset editors, Slate UI, details customizations: use `ue-editor-tools`.

## Setup

1. Edit > Plugins, Scripting section: enable **Python Editor Script Plugin**. Restart the Editor.
   Epic also recommends **Editor Scripting Utilities**.
2. Autocomplete: Edit > Editor Preferences > Plugins > Python, turn on **Developer Mode**, restart.
   The stub `unreal.py` is written to `<Project>/Intermediate/PythonStub` and regenerated on each
   Editor start. Point your IDE at that folder. The stub is the fastest way to confirm what exists
   in your exact build, including plugin classes.
3. Script locations added to `sys.path` automatically: `<Project>/Content/Python`,
   `<Engine>/Content/Python`, `Content/Python` in each enabled plugin, and
   `Documents/UnrealEngine/Python` in the user folder. More via Project Settings > Plugins > Python
   > Additional Paths.

## Running scripts

| Where | How | Use for |
|---|---|---|
| Output Log | Switch the console dropdown from Cmd to Python; type lines | Quick experiments |
| Console (Cmd mode) | `py "C:/Pipeline/fix_names.py"` | Running a file in the open Editor |
| File menu | Execute Python Script / Recent Python Scripts | Same, from the menu |
| Startup | Project Settings > Plugins > Python > Startup Scripts, or an `init_unreal.py` on a Python path | Registering menus, tools, validators at Editor start |
| Blueprint (editor-only) | Execute Python Script, Execute Python Command, Execute Python Command (Advanced) nodes | Buttons in Editor Utility Widgets |
| Full Editor from the command line | `UnrealEditor-Cmd.exe "C:/Proj/Proj.uproject" -ExecutePythonScript="C:/Pipeline/job.py"` | Jobs that need the startup level and full Editor state |
| Commandlet (headless) | `UnrealEditor-Cmd.exe "C:/Proj/Proj.uproject" -run=pythonscript -script="C:/Pipeline/job.py"` | Fast batch jobs, CI, farm machines |

Command-line notes, from Epic's docs:

- `-ExecutePythonScript` starts the full Editor, loads the default startup level, then runs the
  script once everything is loaded. Arguments may follow the file name.
- `-run=pythonscript -script=` is fast, can run without the Editor UI, and shuts down when the
  script finishes. `-script` takes a file path or Python statements. It does **not** load a level;
  if the job touches actors, load one first:
  `unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).load_level("/Game/Maps/MyMap")`.
- In headless runs there is no one to answer a dialog. Set every import to automated and never
  call `*_with_dialog` functions.
- In a commandlet, call `unreal.AssetRegistryHelpers.get_asset_registry().wait_for_completion()`
  before querying the Asset Registry so results are not missing assets still being scanned.

Other commandlets that pipelines use (documented flags only):

- Fix redirectors: `UnrealEditor.exe <Project.uproject> -run=ResavePackages -fixupredirects -autocheckout -projectonly -unattended`
  (`-autocheckin` also checks the files back in).
- Data Validation over the project: `UnrealEditor-Cmd.exe <Project>.uproject -run=DataValidation`.

## The `unreal` module essentials

Get editor subsystems with `unreal.get_editor_subsystem(Class)`; get tools via helpers.

| Object | How to get it | Main calls |
|---|---|---|
| `EditorAssetSubsystem` | `unreal.get_editor_subsystem(unreal.EditorAssetSubsystem)` | `list_assets`, `does_asset_exist`, `load_asset`, `find_asset_data`, `rename_asset`, `rename_loaded_asset`, `duplicate_asset`, `delete_asset`, `find_package_referencers_for_asset`, `checkout_asset`, `checkout_loaded_assets`, `save_asset`, `save_loaded_assets`, `save_directory` |
| `EditorAssetLibrary` | static class | Older function-library form of most of the same calls; still present in 5.8. Prefer the subsystem in new code |
| `AssetRegistry` | `unreal.AssetRegistryHelpers.get_asset_registry()` | `get_assets(ARFilter)`, `get_assets_by_path`, `get_assets_by_class`, `get_referencers`, `get_dependencies`, `wait_for_completion` |
| `AssetTools` | `unreal.AssetToolsHelpers.get_asset_tools()` | `import_asset_tasks`, `create_asset`, `duplicate_asset`, `rename_assets(AssetRenameData[])`, `export_assets`, `migrate_packages` |
| `EditorActorSubsystem` | `unreal.get_editor_subsystem(unreal.EditorActorSubsystem)` | `get_all_level_actors`, `get_selected_level_actors`, `set_selected_level_actors`, `spawn_actor_from_class`, `spawn_actor_from_object`, `destroy_actors` |
| `StaticMeshEditorSubsystem` | `unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)` | `get_nanite_settings`, `set_nanite_settings`, `get_number_materials`, LOD and collision helpers |
| `EditorUtilityLibrary` | static class | `get_selected_assets`, `get_selected_asset_data`, `get_current_content_browser_path` |
| `MaterialEditingLibrary` | static class | `set_material_instance_parent`, `set_material_instance_*_parameter_value`, `update_material_instance` |
| `EditorValidatorSubsystem` | `unreal.get_editor_subsystem(unreal.EditorValidatorSubsystem)` | `validate_assets_with_settings`, `is_asset_valid`, `add_validator` |
| `SourceControl` | static class | `is_enabled`, `check_out_or_add_files`, `mark_file_for_add`, `query_file_state`, `last_error_msg` |
| `EditorLoadingAndSavingUtils` | static class | `save_packages`, `save_dirty_packages`, `get_dirty_content_packages` |

Working rules:

- Asset paths look like `/Game/Props/SM_Crate` (package) or `/Game/Props/SM_Crate.SM_Crate`
  (object). Content paths start with `/Game` (or a plugin's mount point), never a disk path.
- Query with the Asset Registry (`AssetData`, no loading); load only the assets you will change.
  `AssetData` gives `package_name`, `package_path`, `asset_name`, `asset_class_path`,
  `get_asset()`, `is_redirector()`. `asset_class` and `ARFilter.class_names` are deprecated; use
  `asset_class_path` and `class_paths` with `unreal.TopLevelAssetPath("/Script/Engine", "StaticMesh")`.
- Change properties with `obj.set_editor_property("name", value)`, not plain attribute assignment,
  when the property is an editor property. It runs the pre/post edit code that keeps the Editor in
  sync.
- Log with `unreal.log`, `unreal.log_warning`, `unreal.log_error` so output lands in the Output Log
  and in commandlet logs.

Progress and undo:

```python
with unreal.ScopedSlowTask(len(items), "Fixing materials") as task:
    task.make_dialog(True)                      # True = show a Cancel button
    for item in items:
        if task.should_cancel():
            break
        task.enter_progress_frame(1, f"{item}")
        with unreal.ScopedEditorTransaction("Fix material"):
            ...                                  # set_editor_property edits here are one undo step
```

A transaction makes object property edits undoable. It does not undo files: imports, renames and
moves, deletes, saves, and source control actions are permanent. `delete_asset` may also clear
the whole undo history.

## Importing FBX, glTF and USD

All three import through `unreal.AssetImportTask` + `AssetTools.import_asset_tasks([...])`.
Always set `automated=True` (no dialogs), set `destination_path`, and decide `replace_existing`
on purpose. Read results from `task.get_objects()` or `imported_object_paths`. Keep `save=False`
during a dry run and save explicitly later. Full code: `references/snippets.md`.

Which importer runs in 5.8:

- The Interchange framework is the file-format-agnostic importer. It needs the **Interchange
  Editor** and **Interchange Framework** plugins, which are on by default. If Interchange does not
  support a format, the Editor falls back to the legacy importer for it.
- **glTF/GLB**: imported by Interchange. Import Into Level currently works with glTF and MaterialX.
- **FBX**: Epic's 5.8 Interchange page calls FBX through Interchange Experimental, controlled by
  the console variables `Interchange.FeatureFlags.Import.FBX` and
  `Interchange.FeatureFlags.Import.FBX.ToLevel`. Check the value in your project before you
  script FBX: when it is on, Interchange handles FBX and you configure the import with Interchange
  pipelines; when it is off, the legacy importer runs and `unreal.FbxImportUI` set on
  `task.options` controls it (`import_mesh`, `import_as_skeletal`, `mesh_type_to_import`,
  `import_materials`, `import_textures`, `import_animations`, `static_mesh_import_data`,
  `skeletal_mesh_import_data`).
- **Interchange directly**: `unreal.InterchangeManager.get_interchange_manager_scripted()`,
  `InterchangeManager.create_source_data(file)`, then `import_asset(content_path, source_data,
  params)` or `import_scene(...)`, with `unreal.ImportAssetParameters(is_automated=True, ...)`.
  `override_pipelines` takes pipeline asset paths to use instead of the project defaults
  (Project Settings > Engine > Interchange holds the default pipeline stack).
- **USD** (enable the **USD Importer** plugin). Two different things:
  - A **USD Stage actor** (`unreal.UsdStageActor`, `set_root_layer(path)`) opens the stage live.
    It creates transient assets, keeps the USD structure, and updates when the file changes on
    disk. Nothing is written to `/Game`. Use it for layout review and USD-native workflows.
  - **Importing** (File > Import Into Level, or an `AssetImportTask` with
    `options = unreal.UsdStageImportOptions()`) converts the stage into ordinary Unreal assets and
    actors. Use it when the content must become normal project assets. `import_actors`,
    `import_geometry`, `import_materials`, `prims_to_import`, `existing_asset_policy` control what
    comes in. `unreal.UsdStageEditorLibrary.actions_import(output_content_folder, options)` imports
    whatever stage is open in the USD Stage Editor.

## Bulk operations

Every bulk script has the same shape. Copy it from `references/snippets.md`.

1. **Collect** targets from the Asset Registry, scoped to a folder and a class.
2. **Plan**: compute the change for each asset as data (old name, new name; old material, new
   material). Skip assets already correct.
3. **Report** the plan: count and list. Stop here when `DRY_RUN = True`, which is the default.
4. **Apply** inside `ScopedSlowTask`, one `ScopedEditorTransaction` per property edit, checking
   `should_cancel()`.
5. **Check out and save** only what changed, then report failures.

Recipes (all in the snippet file):

- **Rename to naming conventions**: Epic's pattern is `Prefix_BaseName_Descriptor_Variant`
  (`SM_`, `SK_`, `M_`, `MI_`, `T_`, `BP_`, `AS_`, `PHYS_`, `SKEL_`, `FXS_`, `LS_`). Batch with
  `AssetTools.rename_assets([unreal.AssetRenameData(asset, new_package_path, new_name), ...])`.
  Renames and moves leave redirectors behind; fix them afterwards.
- **Material instances**: create with `AssetTools.create_asset(name, path,
  unreal.MaterialInstanceConstant, unreal.MaterialInstanceConstantFactoryNew())`, parent with
  `MaterialEditingLibrary.set_material_instance_parent`, set parameters, then
  `update_material_instance`. Assign to mesh slots with `StaticMesh.set_material(index, mi)`
  (`get_material_index(slot_name)` finds the index).
- **Nanite**: `settings = mesh_sub.get_nanite_settings(mesh)`, set `enabled`, then
  `mesh_sub.set_nanite_settings(mesh, settings, apply_changes=True)`. Applying the change
  rebuilds mesh data, so run large sets in batches.
- **Redirectors**: find them with `AssetData.is_redirector()`. Epic documents two ways to fix
  them: right-click > Fixup in the Content Browser, or the `ResavePackages -fixupredirects`
  commandlet above. There is no documented one-call Python fixup; do not invent one.
- **Validate**: `EditorValidatorSubsystem.validate_assets_with_settings(asset_data_list,
  settings)` with `unreal.ValidateAssetsSettings` (set `validation_usecase` to
  `unreal.DataValidationUsecase.SCRIPT`, `load_assets_for_validation=True`). Returns a count and a
  `ValidateAssetsResults` (`num_checked`, `num_valid`, `num_invalid`, `num_warnings`,
  `num_skipped`). The Data Validation plugin is on by default. Validate before saving a bulk change
  and again before submit.

## Saving and source control

- Nothing a script changes is on disk until it is saved. Save explicitly, and only what the job
  changed: `asset_sub.save_loaded_assets(changed, only_if_is_dirty=True)` or
  `unreal.EditorLoadingAndSavingUtils.save_packages(packages, True)`. Avoid
  `save_dirty_packages` in shared sessions; it saves everything the user has dirty too.
- The subsystem's `save_asset` and `rename_asset` try to check files out themselves. For a clear
  report, check out first yourself: if `unreal.SourceControl.is_enabled()`, call
  `unreal.SourceControl.check_out_or_add_files(paths)` and log `last_error_msg()` on failure.
  Check-in (`check_in_files`) belongs to the user or the build system, not a content script.
- For level edits, `LevelEditorSubsystem.save_current_level()` or `save_all_dirty_levels()`.

## UI for scripts: Editor Utility Widgets and Blueprints

- Create: Content Browser right-click > Editor Utilities > Editor Utility Widget. Design it like
  any UMG widget. Run: right-click the asset > Run Editor Utility Widget; it docks as a tab and is
  listed under the Level Editor's Tools menu.
- Wire buttons to the **Execute Python Command** node (file or code) or **Execute Python Script**
  (inline code with typed input/output pins). Keep the logic in `.py` modules on the Python path
  and make the widget a thin front end: a folder picker, a Dry Run checkbox that defaults on, and
  an Apply button.
- Open a widget from Python with
  `unreal.get_editor_subsystem(unreal.EditorUtilitySubsystem).spawn_and_register_tab(widget_bp)`.
- Selection-driven tools read `unreal.EditorUtilityLibrary.get_selected_assets()` or
  `EditorActorSubsystem.get_selected_level_actors()`.

## Safety rules

1. **Dry run first.** Every script takes `DRY_RUN = True` by default and prints what it would do.
   Apply only after a person has read the list.
2. **Scope narrowly.** Target one folder and one class. Never run a bulk change over `/Game` on
   the first pass.
3. **Wrap edits in `ScopedEditorTransaction`** so property changes can be undone, and remember
   file operations cannot be undone that way.
4. **Save explicitly**, and only the packages you changed. Never set `task.save=True` or save all
   dirty packages as a shortcut.
5. **Never delete without listing.** Print each asset and its referencers
   (`find_package_referencers_for_asset`) first. `delete_asset` and `delete_directory` are force
   deletes: they do not check references and may clear undo history. Require a separate explicit
   confirmation flag to delete.
6. **Work under source control** and on a clean changelist, so a bad run can be reverted there.
7. **Automate imports** (`automated=True` / `is_automated=True`); a dialog blocks a headless run.
8. **Fail loudly**: count successes and failures, log each failure with its asset path, and raise
   at the end of an unattended job when anything failed so the log shows it. Check how your
   build system reads the commandlet's result before relying on its exit code.

## References

- `references/snippets.md`: complete, copyable scripts for every recipe above.
- Epic docs (UE 5.8): Scripting the Unreal Editor Using Python; Setting up Autocomplete for Unreal
  Editor Python Scripting; Unreal Python API reference; Importing Assets Using Interchange;
  Universal Scene Description in Unreal Engine; Asset Redirectors; Data Validation; Editor Utility
  Widgets; Recommended Asset Naming Conventions.
