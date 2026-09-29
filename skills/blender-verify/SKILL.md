---
name: blender-verify
description: Use after changing a Blender scene or running a bpy script, to prove the result is right before reporting done - reads the scene back, checks for missing files, and renders or screenshots an image you actually look at. Works through the official Blender MCP server (Blender Lab) when it is connected, or headless with `blender -b` when it is not. Also covers connecting Blender to an agent. Use when the user says "check the render", "did it work", "screenshot the viewport", "connect Blender", "blender mcp", or after any edit to a .blend file or Blender Python script.
---

# Blender verify

The loop is: protect the user's file, make the change, read the scene back, look at a picture of it, report. A script that ran without a traceback says nothing about what is in the scene or what it looks like.

## The rule

After changing a Blender scene or running a bpy script, you are not done until:

1. The user's original `.blend` is untouched, or you saved a copy first and said where it is.
2. Every Python traceback the change produced is fixed. A silent exception counts (see "Exit codes" below).
3. You have read the scene back and the numbers match what the change was meant to do: object counts, names, modifiers, materials, and no new missing files.
4. You have taken a viewport screenshot or rendered a check image and actually looked at it, and it shows what the change was meant to show.

Then report exactly what you checked and what each check showed. If you could not check something (no MCP server, no Blender binary, render failed), say so plainly. Never report "done" or "should work" on a scene you have not read back and seen.

## 0. Protect the file and check your tools

**Never overwrite the user's `.blend`.** Before any change:

- With the MCP server, save a copy of the open file without switching to it:
  ```python
  bpy.ops.wm.save_as_mainfile(filepath="/path/to/scene_before_edit.blend", copy=True)
  ```
- Headless, work on a copy: `cp scene.blend scene_work.blend` and open that. In a background script, save to a new path, never back to the file you opened.

Then look at your tool list. MCP tools usually show the server name in front (in Claude Code, `mcp__<server>__get_objects_summary`). If the Blender tools below are listed, use path A. If not, use path B. Do not call a tool you cannot see.

## Path A: Blender open with the official Blender MCP server

The official server is Blender Lab's `blender_mcp` (projects.blender.org/lab/blender_mcp, docs at blender.org/lab/mcp-server). In Claude's connector directory it is the "Blender" connector made by Blender Lab.

**Safety:** the server runs model-generated Python in Blender with no guards; code can delete data or send it elsewhere. Blender Lab recommends a virtual machine or a system without sensitive data. Save before every change and keep changes small enough to undo.

### Setup

Three pieces: Blender with the add-on, the MCP server, and a client.

1. **Blender 5.1 or newer.**
2. **The add-on.** In Blender, add the Blender Lab extensions repository `https://lab.blender.org/` (Preferences > Get Extensions > Repositories), then find the MCP add-on, install and enable it. Dragging the install link from blender.org/lab/mcp-server into Blender also works; drop it twice (the first adds the repository, the second installs the add-on).
3. **Start the bridge.** In the add-on's preferences press "Start MCP Bridge Server"; it shows "Server is running". Turn on "Auto Start" to start it with Blender. Startup errors are shown in the same panel. It listens on `localhost:9876` by default (Host and Port are in the same panel).
4. **The client.**
   - Claude Desktop: add the Blender connector from the connector directory (Settings > Connectors). The add-on is still required.
   - Claude Code and other MCP clients: install the server package and register it as a stdio server:
     ```
     pip install git+https://projects.blender.org/lab/blender_mcp.git#subdirectory=mcp
     claude mcp add blender -- blender-mcp
     ```
     The entry point is `blender-mcp`; stdio is its default transport. Install it from the git URL
     above, not by package name: `blender-mcp` on PyPI (and so `uvx blender-mcp`) is a different,
     community server that does not talk to this add-on. If you changed the add-on's host or port, set `BLENDER_MCP_HOST` / `BLENDER_MCP_PORT` in the server's environment to match.
   - Clients that take `.mcpb` bundles can install the bundle from the project's releases page instead.

### The loop

1. **Know the file.** `get_blendfile_summary_path_info` (path, save status, backups) and `get_blendfile_summary_datablocks` (data-block counts, render engine). Record the counts before the change.
2. **Look up the API before guessing.** `search_api_docs` (full-text search of the bundled Python API reference) and `get_python_api_docs` (docs for one identifier, such as `bpy.types.Object`). `search_manual_docs` searches the user manual. Use these before writing bpy calls you are not sure of; the bundled docs match current Blender, older examples online often do not.
3. **Make the change** with `execute_blender_code`. To return data, assign a JSON-serialisable dict to a variable named `result`. Prefer direct data access (`bpy.data...`) over `bpy.ops` operators, which depend on context.
4. **Read the scene back.**
   - `get_objects_summary`: collection hierarchy and objects (name, type, parent, data, selection, visibility). The objects you added exist, sit in the right collection, and are visible.
   - `get_object_detail_summary` with the object's `name`: check the specific thing you changed (transform, modifiers, materials).
   - `get_blendfile_summary_datablocks` again: counts moved the way they should (one new mesh means one more mesh, not three; no orphaned leftovers).
   - `get_blendfile_summary_missing_files`: no missing images, libraries, fonts, sounds, caches. Anything new here is a failure.
   - For something the summaries do not cover, read it with `execute_blender_code` and `result`, for example modifier stacks or evaluated polygon counts after modifiers.
5. **Look at it.**
   - `jump_to_view3d_object_by_name` to frame the object you changed, then `get_screenshot_of_window_as_image` (or `get_screenshot_of_area_as_image` for one area). Look at the image.
   - For how it renders: `render_thumbnail_to_path` (small, low quality, temporarily overrides render settings) or `render_viewport_to_path` (full render with the current settings, which can be slow). Then open the written file with your image-reading tool and look at it.
   - Not done if the object is missing, off-screen, black, untextured (pink means a missing texture), or something that used to be there has gone.
6. **Save** only when the user wants the change kept, and to the path they agreed to.

### Checking a file without the GUI

The server also has `_for_cli` variants that open a `.blend` in a background Blender process: `execute_blender_code_for_cli`, `get_blendfile_summary_datablocks_for_cli`, `get_blendfile_summary_missing_files_for_cli`, `get_blendfile_summary_of_linked_libraries_for_cli`, `get_blendfile_summary_path_info_for_cli`, `get_blendfile_summary_usage_guess_for_cli`. They run `blender` from `PATH`, or the binary in `BLENDER_PATH`. If the running Blender has the same file open with unsaved changes, they check a temporary numbered copy that includes those changes.

## Path B: no MCP server, headless Blender

Say so first: "The Blender MCP server is not connected; checking headless." Find the binary (`blender` on `PATH`; on macOS usually `/Applications/Blender.app/Contents/MacOS/Blender`).

### Run the change

```
blender -b scene_work.blend --python-exit-code 1 -P change.py > run.log 2>&1; echo $?
```

- `-b` / `--background` runs without the UI.
- `-P <file>` runs a script; `--python-expr "<code>"` runs code given inline.
- `--factory-startup` skips the user's startup file and preferences, for a clean run. Add it when their setup might interfere; leave it off when the script needs their add-ons.
- Arguments run in the order given. Put the `.blend` first, then settings, then the actions that use them.
- Redirect output to a file and read it. Do not pipe into `tail` or `head`; the pipe hides Blender's exit code.

### Exit codes

Without `--python-exit-code`, a Python exception in a command-line script still leaves Blender exiting 0. Always pass `--python-exit-code 1` (any value 1 to 255), check the exit code, and search `run.log` for `Traceback` and `Error`. Fix the first traceback, rerun, repeat.

### Read the scene back

Have the check script print one JSON line you can find in the log:

```python
import bpy, json, os
scene = bpy.context.scene
missing = [i.name for i in bpy.data.images
           if i.source == 'FILE' and i.filepath and not i.packed_file
           and not os.path.exists(bpy.path.abspath(i.filepath))]
print("CHECK " + json.dumps({
    "objects": {o.name: {"type": o.type,
                         "modifiers": [m.type for m in o.modifiers],
                         "materials": [s.material.name if s.material else None for s in o.material_slots],
                         "hide_render": o.hide_render}
                for o in scene.objects},
    "camera": scene.camera.name if scene.camera else None,
    "engine": scene.render.engine,
    "missing_images": missing,
}))
```

```
blender -b scene_work.blend --python-exit-code 1 -P check.py > check.log 2>&1; echo $?
grep '^CHECK ' check.log
```

Compare with what the change was meant to produce.

### Render a check image and look at it

```
blender -b scene_work.blend -o /abs/path/check_#### -F PNG -f 1 > render.log 2>&1; echo $?
```

- `-o` sets the output path (`#` becomes the zero-padded frame number, `//` means relative to the .blend); `-F PNG` sets the format; `-f 1` renders frame 1 and saves it, giving `check_0001.png`. `-o` and `-F` must come before `-f`.
- `-E <engine>` overrides the render engine (`-E help` lists them). Cycles device options go after a double dash: `-E CYCLES -f 1 -- --cycles-device CPU`.
- Open the PNG with your image-reading tool and look at it. A render that exits 0 can still be black.

## Report

List each check and its result:

- The copy you saved, and whether the original was left untouched.
- The commands or tools you ran and their exit codes or errors.
- Scene read-back: object counts before and after, the objects, modifiers and materials you checked, missing files.
- The screenshot or render: its path, what it shows, and whether that matches the change.
- Anything you could not check, and why.

## Troubleshooting

| Symptom | Likely cause and what to do |
|---|---|
| `RuntimeError: Operator bpy.ops.... poll() failed, context is incorrect` | The operator needs an area, a mode, or an active or selected object that is not there, which is common in background mode. Do the same thing through `bpy.data` and object properties, or run the operator inside `with bpy.context.temp_override(...)` with the context it needs. Look it up with `search_api_docs` first. |
| MCP tools fail to connect, or the Blender tools are not listed | Blender is not open, the add-on is not enabled, or the bridge is not started (preferences say "Server is running" when it is). Check the port in the add-on preferences matches `BLENDER_MCP_PORT` (default 9876) and nothing else is using it. Restart the client after adding the server. |
| Pink textures, or missing files after moving the .blend | Absolute or relative paths no longer resolve. Run `get_blendfile_summary_missing_files` (or the check script). Relink with File > External Data > Find Missing Files, then Make Paths Relative before moving files again. |
| Render is black | No camera (`scene.camera` is `None`), no lights and a black or zero-strength World, objects hidden for render (`hide_render`) or in a collection excluded from the view layer, or the camera is inside or pointing away from the scene. Check each in the read-back. |
| Headless render fails or needs a GPU | EEVEE and Workbench need a working GPU context, which a headless server may not have. Use `-E CYCLES -- --cycles-device CPU` for the check image and say so in the report. |
| Script "succeeded" but nothing changed | The script ran against a different file, the change was not saved to the file you then checked, or an exception was swallowed. Pass `--python-exit-code 1` and check the log for tracebacks. |
