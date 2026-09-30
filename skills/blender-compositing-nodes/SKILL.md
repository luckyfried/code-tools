---
name: blender-compositing-nodes
description: Use when building or editing a Blender 5.x compositor node tree with Python (bpy), directly or through the Blender MCP server - post-processing a render, color grading, denoising, glare and bloom, depth of field, lens distortion, vignettes, keying green or blue screen, Cryptomatte and ID masks, splitting render passes, and writing multilayer EXR or per-pass files. Also use when fixing `AttributeError: 'Scene' object has no attribute 'node_tree'`, a missing Composite node, or "node type CompositorNode... undefined" after upgrading to Blender 5. Triggers include "compositor", "compositing", "compositing nodes", "post-process the render", "color grade", "denoise node", "glare", "bloom", "defocus", "green screen", "keying", "cryptomatte", "render passes", "render layers node", "file output node", "multilayer EXR", "scene.node_tree", "CompositorNodeComposite", and "compositing_node_group".
---

Adapted from ra100/blender-claude-plugin (MIT); see LICENSE.

# Blender Compositing Nodes

Build compositor node trees in Blender 5.x from Python. The API patterns and a full pipeline are in
`references/python_api.md`. Every node that can be added to a compositor tree, with its type
string, is listed in `references/node_reference.md`.

For general bpy rules (check the Blender version, never guess an API name, prefer the data API),
follow `blender-current-api`. To prove the result looks right, follow `blender-verify`.

## Working through the Blender MCP server

When the official Blender MCP server (Blender Lab) is connected, work in the running session:

- `get_objects_summary` to see the scene, camera, and lights the render comes from.
- `search_api_docs` and `get_python_api_docs` to confirm a node type, socket, or property before
  using it. The bundled docs match the running Blender.
- `execute_blender_code` to build or edit the tree. Keep each block small and safe to re-run, and
  return what you need to check (node names, links, the tree assigned to the scene) in `result`.
- `render_thumbnail_to_path` or `render_viewport_to_path` to render through the compositor, then
  open the image and look at it. `get_screenshot_of_window_as_image` shows the node editor.

Without the server, write a script and run it headless as `blender-verify` describes.

## How the 5.x compositor is wired

The compositor tree is a node group data-block assigned to the scene. There is no
`scene.use_nodes` to switch on, no `scene.node_tree`, and no Composite node.

```python
import bpy

scene = bpy.context.scene
tree = bpy.data.node_groups.new("Compositing", "CompositorNodeTree")
scene.compositing_node_group = tree
tree.interface.new_socket(name="Image", in_out='OUTPUT', socket_type='NodeSocketColor')

rl = tree.nodes.new("CompositorNodeRLayers")
out = tree.nodes.new("NodeGroupOutput")
rl.location = (-300, 0)
tree.links.new(rl.outputs["Image"], out.inputs["Image"])
```

- The **Group Output** node's first input is the final image, and it must be a Color socket. Other
  inputs are ignored.
- To edit an existing setup, start from `scene.compositing_node_group`; it is `None` when the scene
  has no compositor tree. Because the tree is its own data-block, one tree can serve several scenes
  or files.
- `scene.render.use_compositing` must stay on for the tree to run on renders.
- A **Viewer** node (`CompositorNodeViewer`) shows any intermediate result in the image editor or
  backdrop without changing the final image.

## Writing node trees

1. Create or fetch the tree as above.
2. Add nodes with `tree.nodes.new(type)`. Type strings are in `references/node_reference.md`.
   Several operations use shared nodes, not compositor-only ones: Mix is `ShaderNodeMix` with
   `data_type = 'RGBA'`, and Math, Map Range, Color Ramp, RGB Curves, Gamma, Clamp, and Value are the
   `ShaderNode*` types.
3. Set options through **input sockets**. Most former node properties are now inputs, including
   the menus, which take the label shown in the UI:
   ```python
   glare = tree.nodes.new("CompositorNodeGlare")
   glare.inputs["Type"].default_value = "Bloom"
   glare.inputs["Quality"].default_value = "High"
   glare.inputs["Strength"].default_value = 0.8
   ```
   Look sockets up by name. When two inputs share a name (Color Balance has a `Lift` factor and a
   `Lift` color), use the identifier, for example `inputs["Color Lift"]`. Print
   `[(s.name, s.identifier) for s in node.inputs]` when unsure. On `ShaderNodeMix`, set
   `data_type` first; `inputs["A"]`, `["B"]`, and `outputs["Result"]` then return that type's
   sockets.
4. Enable every render pass you link on the view layer (`view_layer.use_pass_*`), then re-render.
   The Render Layers node only has outputs for enabled passes.
5. Lay nodes out left to right (about 300 apart in x) and group stages in `NodeFrame` nodes.

## Recipes

Each recipe ends at the Group Output node. Code for the first two is in
`references/python_api.md`.

- **Denoise.** For Cycles, set `view_layer.cycles.denoising_store_passes = True`. Link Render
  Layers `Image`, `Denoising Albedo`, and `Denoising Normal` into Denoise `Image`, `Albedo`, and
  `Normal`. For a plain final render, Cycles' own denoiser (`scene.cycles.use_denoising`) is simpler.
- **Color grade.** Render Layers, then Color Balance (`Type`: `Lift/Gamma/Gain`,
  `Offset/Power/Slope (ASC-CDL)`, or `White Point`), then Hue/Saturation/Value, then RGB Curves
  (`ShaderNodeRGBCurve`). Brightness/Contrast and Exposure are separate nodes.
- **Glare and bloom.** Glare `Type`: `Bloom`, `Ghosts`, `Streaks`, `Fog Glow`, `Simple Star`,
  `Sun Beams`, `Kernel`. Lower `Threshold` catches more highlights. Glare outputs `Image`, and also
  `Glare` and `Highlights` on their own. Sun Beams is a Glare type, with a `Sun Position` input.
- **Depth of field.** Enable `view_layer.use_pass_z`. Link Render Layers `Depth` into Defocus `Z`,
  and set `defocus.use_zbuffer = True`, `f_stop`, and `blur_max`. Camera depth of field at render
  time is usually better.
- **Lens distortion.** Lens Distortion inputs `Distortion` (negative barrel, positive pincushion),
  `Dispersion` (chromatic aberration; keep it small), and `Fit` to avoid black edges.
- **Vignette.** Ellipse Mask (its `Size` input), then Blur, then a `ShaderNodeMix` in `MULTIPLY`
  mode with the image.
- **Film grain.** Mix a `ShaderNodeTexNoise` or `ShaderNodeTexWhiteNoise` over the image with
  `ShaderNodeMix` in `OVERLAY` or `ADD` at a low factor.
- **Keying.** Image or Movie Clip into Keying, with `Key Color` set to the screen color. Tune
  `Key Balance`, `Black Level`, `White Level`, `Despill Strength`, and `Despill Balance` (these are
  socket identifiers; see `references/node_reference.md`). Clean the matte with Dilate/Erode and put
  the result over the plate with Alpha Over (`Background`, `Foreground`).
- **Render pass work.** Enable passes such as `use_pass_diffuse_direct`, `use_pass_diffuse_color`,
  and `use_pass_glossy_direct`. The Render Layers outputs are then named `Diffuse Direct`,
  `Diffuse Color`, `Glossy Direct`, and so on. Rebuild lighting as `(Direct + Indirect) x Color` per
  component with Mix nodes, then add the components.
- **Mist and fog.** Enable `view_layer.use_pass_mist` and set `world.mist_settings.start`,
  `.depth`, and `.falloff`. Put Render Layers `Mist` through a Color Ramp into the Factor of a Mix
  with a fog color.
- **Cryptomatte.** Enable `view_layer.use_pass_cryptomatte_object` (or `_material`, `_asset`),
  add `CompositorNodeCryptomatteV2` with `source = 'RENDER'`, and put the object or material
  names to include in `matte_id` (or pick them in the Viewer). It outputs `Image`, `Matte`, and `Pick`. For
  index passes, use ID Mask with the `Object Index` or `Material Index` output.
- **Signed distance fields (5.1 and later).** Mask To SDF turns a mask into a distance field
  (`SDF` output) for outlines and soft edges.
- **Sequencer strips.** Sequencer Strip Info gives the active strip's `Start Frame`, `End Frame`,
  `Location`, `Rotation`, and `Scale`, inside a tree used by a Compositor strip modifier.
- **Save passes to disk.** Use File Output with `directory`, `file_name`, and one
  `file_output_items` entry per input. For multilayer EXR, set `format.media_type =
  'MULTI_LAYER_IMAGE'` before `format.file_format = 'OPEN_EXR_MULTILAYER'`. See
  `references/python_api.md`.

## When the result looks wrong

- **The compositor does nothing:** `scene.compositing_node_group` is `None` or a different tree,
  `scene.render.use_compositing` is off, or nothing is linked into the Group Output's first input.
- **Black or missing pass:** the pass is not enabled on the view layer, or the scene was not
  re-rendered after enabling it. The compositor works on the render result.
- **Socket lookup `KeyError`:** the socket was renamed or became an input in 5.0. Print the node's
  `inputs` and `outputs` (name and identifier) and use what is there.
- **Menu value rejected:** menu inputs take the UI label (`"Fast Gaussian"`, not `'FAST_GAUSS'`).
  The error message lists the accepted values.
- **Slow:** lower the Glare and Denoise quality while iterating, and use Fast Gaussian blur.

Then render through the compositor and look at the image, as `blender-verify` describes.
