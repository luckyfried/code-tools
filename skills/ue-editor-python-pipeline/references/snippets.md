# Editor Python snippets (UE 5.8)

Every snippet uses only calls listed in Epic's 5.8 Python API reference. Each bulk script defaults
to `DRY_RUN = True`. Replace the `/Game/...` folders and disk paths with your own.

## Common header

```python
import unreal

asset_sub = unreal.get_editor_subsystem(unreal.EditorAssetSubsystem)
actor_sub = unreal.get_editor_subsystem(unreal.EditorActorSubsystem)
mesh_sub = unreal.get_editor_subsystem(unreal.StaticMeshEditorSubsystem)
asset_tools = unreal.AssetToolsHelpers.get_asset_tools()
registry = unreal.AssetRegistryHelpers.get_asset_registry()

STATIC_MESH = unreal.TopLevelAssetPath("/Script/Engine", "StaticMesh")


def find_assets(folder, class_path, recursive=True):
    """Asset Registry query: returns AssetData without loading anything."""
    flt = unreal.ARFilter(
        package_paths=[folder],
        class_paths=[class_path],
        recursive_paths=recursive,
    )
    return registry.get_assets(flt) or []
```

In a commandlet (`-run=pythonscript`), call `registry.wait_for_completion()` before the first
query.

## Import: AssetImportTask (FBX, glTF, USD)

```python
def make_task(filename, dest, options=None, replace=False):
    task = unreal.AssetImportTask()
    task.set_editor_property("filename", filename)
    task.set_editor_property("destination_path", dest)
    task.set_editor_property("automated", True)        # never show a dialog
    task.set_editor_property("replace_existing", replace)
    task.set_editor_property("save", False)            # save explicitly afterwards
    if options is not None:
        task.set_editor_property("options", options)
    return task


files = ["D:/Incoming/crate.fbx", "D:/Incoming/lamp.glb"]
tasks = [make_task(f, "/Game/Incoming") for f in files]
asset_tools.import_asset_tasks(tasks)

imported = []
for t in tasks:
    paths = list(t.get_editor_property("imported_object_paths"))
    if not paths:
        unreal.log_error(f"Import produced nothing: {t.get_editor_property('filename')}")
    imported.extend(paths)
unreal.log(f"Imported {len(imported)} objects")
```

Skip files whose destination already exists instead of overwriting by accident:

```python
dest_asset = "/Game/Incoming/crate"
if asset_sub.does_asset_exist(dest_asset):
    unreal.log_warning(f"Exists, skipping: {dest_asset}")
```

### Legacy FBX options (when Interchange FBX import is off)

`Interchange.FeatureFlags.Import.FBX` decides which importer handles FBX. These options apply to
the legacy importer.

```python
ui = unreal.FbxImportUI()
ui.set_editor_property("import_mesh", True)
ui.set_editor_property("import_as_skeletal", False)
ui.set_editor_property("mesh_type_to_import", unreal.FBXImportType.FBXIT_STATIC_MESH)
ui.set_editor_property("import_materials", False)
ui.set_editor_property("import_textures", False)
ui.set_editor_property("import_animations", False)
ui.set_editor_property("automated_import_should_detect_type", False)

task = make_task("D:/Incoming/crate.fbx", "/Game/Incoming", options=ui)
asset_tools.import_asset_tasks([task])
```

### Interchange directly

```python
manager = unreal.InterchangeManager.get_interchange_manager_scripted()
source = unreal.InterchangeManager.create_source_data("D:/Incoming/lamp.glb")

params = unreal.ImportAssetParameters()
params.set_editor_property("is_automated", True)
params.set_editor_property("replace_existing", False)
# Optional: use your own pipeline assets instead of the project's default stack.
# params.set_editor_property("override_pipelines", [unreal.SoftObjectPath("/Game/Pipelines/MyPipeline.MyPipeline")])

if manager.can_translate_source_data(source):
    objects = manager.import_asset("/Game/Incoming", source, params) or []
    unreal.log(f"Interchange imported {len(objects)} objects")
else:
    unreal.log_error("No Interchange translator for this file")
```

`import_scene(content_path, source, params)` imports into the level; set `import_level` on the
parameters to choose the level.

### USD: import as assets

```python
opts = unreal.UsdStageImportOptions()
opts.set_editor_property("import_actors", False)       # assets only, no level actors
opts.set_editor_property("import_geometry", True)
opts.set_editor_property("import_materials", True)

task = make_task("D:/Incoming/set.usd", "/Game/USD/Set", options=opts)
asset_tools.import_asset_tasks([task])
```

### USD: open live in a Stage actor (no assets written)

```python
stage_actor = actor_sub.spawn_actor_from_class(unreal.UsdStageActor, unreal.Vector(0, 0, 0))
stage_actor.set_root_layer("D:/Incoming/set.usd")
```

## Rename to naming conventions (dry run first)

```python
DRY_RUN = True
FOLDER = "/Game/Incoming"

PREFIX = {
    "StaticMesh": "SM_",
    "SkeletalMesh": "SK_",
    "Material": "M_",
    "MaterialInstanceConstant": "MI_",
    "Texture2D": "T_",
    "Blueprint": "BP_",
    "AnimSequence": "AS_",
    "PhysicsAsset": "PHYS_",
    "Skeleton": "SKEL_",
    "NiagaraSystem": "FXS_",
    "LevelSequence": "LS_",
}

plan = []
for data in registry.get_assets_by_path(FOLDER, recursive=True) or []:
    if data.is_redirector():
        continue
    cls = str(data.asset_class_path.asset_name)
    prefix = PREFIX.get(cls)
    name = str(data.asset_name)
    if not prefix or name.startswith(prefix):
        continue
    new_name = prefix + name
    new_path = f"{data.package_path}/{new_name}"
    if asset_sub.does_asset_exist(new_path):
        unreal.log_warning(f"Target exists, skipping: {new_path}")
        continue
    plan.append((data, str(data.package_path), new_name))

for data, path, new_name in plan:
    unreal.log(f"RENAME {data.package_name} -> {path}/{new_name}")
unreal.log(f"{len(plan)} renames planned")

if not DRY_RUN and plan:
    rename_data = [
        unreal.AssetRenameData(data.get_asset(), path, new_name)
        for data, path, new_name in plan
    ]
    ok = asset_tools.rename_assets(rename_data)
    unreal.log(f"rename_assets returned {ok}. Fix up redirectors next.")
```

## Material instances: create and assign

```python
DRY_RUN = True
PARENT = "/Game/Materials/M_Master"
MESH_FOLDER = "/Game/Props"
MI_FOLDER = "/Game/Materials/Instances"

parent = asset_sub.load_asset(PARENT)
changed = []

meshes = find_assets(MESH_FOLDER, STATIC_MESH)
with unreal.ScopedSlowTask(len(meshes), "Assigning material instances") as task:
    task.make_dialog(True)
    for data in meshes:
        if task.should_cancel():
            break
        task.enter_progress_frame(1, str(data.asset_name))

        mi_name = "MI_" + str(data.asset_name).removeprefix("SM_")
        mi_path = f"{MI_FOLDER}/{mi_name}"
        unreal.log(f"{data.package_name}: slot 0 -> {mi_path}")
        if DRY_RUN:
            continue

        if asset_sub.does_asset_exist(mi_path):
            mi = asset_sub.load_asset(mi_path)
        else:
            mi = asset_tools.create_asset(
                mi_name, MI_FOLDER,
                unreal.MaterialInstanceConstant,
                unreal.MaterialInstanceConstantFactoryNew(),
            )
            unreal.MaterialEditingLibrary.set_material_instance_parent(mi, parent)
            # Parameter names must exist on the parent material.
            unreal.MaterialEditingLibrary.set_material_instance_scalar_parameter_value(
                mi, "Roughness", 0.6)
            unreal.MaterialEditingLibrary.update_material_instance(mi)
            changed.append(mi)

        mesh = data.get_asset()
        with unreal.ScopedEditorTransaction("Assign material instance"):
            mesh.set_material(0, mi)
        changed.append(mesh)
```

Find a slot by name instead of index with `mesh.get_material_index("Body")`.

## Enable Nanite on static meshes

```python
DRY_RUN = True
todo = []
for data in find_assets("/Game/Environment", STATIC_MESH):
    mesh = data.get_asset()
    if not mesh_sub.get_nanite_settings(mesh).enabled:
        todo.append(mesh)
unreal.log(f"{len(todo)} meshes will get Nanite enabled")

changed = []
if not DRY_RUN:
    with unreal.ScopedSlowTask(len(todo), "Enabling Nanite") as task:
        task.make_dialog(True)
        for mesh in todo:
            if task.should_cancel():
                break
            task.enter_progress_frame(1, mesh.get_name())
            settings = mesh_sub.get_nanite_settings(mesh)
            settings.set_editor_property("enabled", True)
            mesh_sub.set_nanite_settings(mesh, settings, apply_changes=True)
            changed.append(mesh)
```

Loading every mesh to read its settings is slow on big folders; scope the folder tightly.

## Find redirectors

```python
redirectors = [
    d for d in (registry.get_assets_by_path("/Game", recursive=True) or [])
    if d.is_redirector()
]
for d in redirectors:
    unreal.log(f"REDIRECTOR {d.package_name}")
unreal.log(f"{len(redirectors)} redirectors")
```

Fix them in the Content Browser (right-click > Fixup) or with the documented commandlet:

```
UnrealEditor.exe <Project.uproject> -run=ResavePackages -fixupredirects -autocheckout -projectonly -unattended
```

## Validate assets

```python
validator = unreal.get_editor_subsystem(unreal.EditorValidatorSubsystem)

settings = unreal.ValidateAssetsSettings()
settings.set_editor_property("validation_usecase", unreal.DataValidationUsecase.SCRIPT)
settings.set_editor_property("load_assets_for_validation", True)
settings.set_editor_property("show_if_no_failures", False)

targets = find_assets("/Game/Incoming", STATIC_MESH)
count, results = validator.validate_assets_with_settings(targets, settings)
unreal.log(
    f"checked={results.num_checked} valid={results.num_valid} "
    f"invalid={results.num_invalid} warnings={results.num_warnings} skipped={results.num_skipped}"
)
if results.num_invalid:
    raise RuntimeError("Validation failed; see the Message Log")
```

## Check out and save only what changed

```python
def checkout_and_save(objects):
    paths = [asset_sub.get_path_name_for_loaded_asset(o) for o in objects]
    if unreal.SourceControl.is_enabled():
        if not unreal.SourceControl.check_out_or_add_files(paths):
            unreal.log_error(f"Checkout failed: {unreal.SourceControl.last_error_msg()}")
            return False
    ok = asset_sub.save_loaded_assets(objects, only_if_is_dirty=True)
    unreal.log(f"Saved {len(objects)} assets: {ok}")
    return ok
```

## List before delete

```python
DRY_RUN = True
CONFIRM_DELETE = False          # a second, separate switch
targets = ["/Game/Old/SM_Unused_A", "/Game/Old/SM_Unused_B"]

blocked = []
for path in targets:
    refs = asset_sub.find_package_referencers_for_asset(path, load_assets_to_confirm=True)
    unreal.log(f"DELETE {path}  referencers={list(refs)}")
    if refs:
        blocked.append(path)

if blocked:
    unreal.log_warning(f"{len(blocked)} assets are still referenced; not deleting them")

if not DRY_RUN and CONFIRM_DELETE:
    for path in targets:
        if path in blocked:
            continue
        # Force delete: does not check references and may clear undo history.
        if not asset_sub.delete_asset(path):
            unreal.log_error(f"Delete failed: {path}")
```

## Headless job skeleton

```python
# Run with:
# UnrealEditor-Cmd.exe "C:/Proj/Proj.uproject" -run=pythonscript -script="C:/Pipeline/job.py"
import unreal

registry = unreal.AssetRegistryHelpers.get_asset_registry()
registry.wait_for_completion()

# Load a level only if the job touches actors:
# unreal.get_editor_subsystem(unreal.LevelEditorSubsystem).load_level("/Game/Maps/Main")

failures = 0
# ... collect, plan, apply, save ...
if failures:
    raise RuntimeError(f"{failures} failures")
```
