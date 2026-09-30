# Compositor: Python API patterns (Blender 5.x)

Type strings and socket names for every node are in `node_reference.md`. Confirm anything not
listed with `search_api_docs` / `get_python_api_docs`, or at
<https://docs.blender.org/api/current/>.

## Creating or reusing the compositor tree

```python
import bpy

def compositor_tree(scene, name="Compositing"):
    """Return the scene's compositor tree, creating one with an Image output if needed."""
    tree = scene.compositing_node_group
    if tree is None:
        tree = bpy.data.node_groups.new(name, "CompositorNodeTree")
        scene.compositing_node_group = tree
    if not any(item.item_type == 'SOCKET' and item.in_out == 'OUTPUT'
               for item in tree.interface.items_tree):
        tree.interface.new_socket(name="Image", in_out='OUTPUT', socket_type='NodeSocketColor')
    return tree

scene = bpy.context.scene
tree = compositor_tree(scene)
nodes, links = tree.nodes, tree.links
nodes.clear()                        # start over; skip this to edit what is there

rl = nodes.new("CompositorNodeRLayers")
rl.location = (-300, 0)
out = nodes.new("NodeGroupOutput")
out.location = (300, 0)
links.new(rl.outputs["Image"], out.inputs["Image"])
```

`scene.render.use_compositing` must be `True` (the default) for the tree to run on renders. To use a
different view layer or scene in a Render Layers node, set `rl.scene` and `rl.layer`.

## Adding and configuring nodes

```python
blur = nodes.new("CompositorNodeBlur")
blur.inputs["Type"].default_value = "Fast Gaussian"   # menu inputs take the UI label
blur.inputs["Size"].default_value = (10, 10)          # pixels, X and Y

hsv = nodes.new("CompositorNodeHueSat")
hsv.inputs["Saturation"].default_value = 1.1

cb = nodes.new("CompositorNodeColorBalance")
cb.inputs["Type"].default_value = "Lift/Gamma/Gain"
cb.inputs["Color Lift"].default_value = (1.0, 1.0, 1.0, 1.0)   # identifier, name is "Lift"
cb.inputs["Color Gain"].default_value = (1.05, 1.0, 0.95, 1.0)

color = nodes.new("CompositorNodeRGB")
color.outputs["Color"].default_value = (1.0, 0.5, 0.0, 1.0)

value = nodes.new("ShaderNodeValue")
value.outputs["Value"].default_value = 0.5
```

To list what a node takes:

```python
print([(s.name, s.identifier, s.bl_idname) for s in blur.inputs])
```

A menu input rejects an unknown value with an error that lists the accepted ones.

### Mix, Math, Color Ramp, and other shared nodes

```python
mix = nodes.new("ShaderNodeMix")
mix.data_type = 'RGBA'
mix.blend_type = 'MULTIPLY'          # MIX, ADD, MULTIPLY, SCREEN, OVERLAY, ...
mix.inputs["Factor"].default_value = 1.0
# Mix has a Factor/A/B/Result socket per data type. Set data_type first; looking up
# "Factor", "A", "B", and "Result" by name then returns the sockets for that type.

math = nodes.new("ShaderNodeMath")
math.operation = 'GREATER_THAN'
math.inputs[1].default_value = 0.8

ramp = nodes.new("ShaderNodeValToRGB")
ramp.color_ramp.elements[0].color = (0, 0, 0, 1)
ramp.color_ramp.elements[1].color = (1, 1, 1, 1)

map_range = nodes.new("ShaderNodeMapRange")
map_range.inputs["From Max"].default_value = 10.0

gamma = nodes.new("ShaderNodeGamma")
gamma.inputs["Gamma"].default_value = 1.2
```

## Linking and layout

```python
links.new(rl.outputs["Image"], blur.inputs["Image"])
links.new(blur.outputs["Image"], mix.inputs["A"])
links.new(mix.outputs["Result"], out.inputs["Image"])

viewer = nodes.new("CompositorNodeViewer")
viewer.location = (300, -200)
links.new(blur.outputs["Image"], viewer.inputs["Image"])

frame = nodes.new("NodeFrame")
frame.label = "Blur stage"
frame.use_custom_color = True
frame.color = (0.2, 0.3, 0.4)
blur.parent = frame
```

Link by name or identifier, not by index; sockets move when a node's options change.

## Enabling render passes

```python
vl = bpy.context.view_layer            # or scene.view_layers["ViewLayer"]

vl.use_pass_z = True                   # Depth
vl.use_pass_mist = True
vl.use_pass_normal = True
vl.use_pass_position = True
vl.use_pass_vector = True              # motion vectors for Vector Blur
vl.use_pass_uv = True
vl.use_pass_object_index = True
vl.use_pass_material_index = True

vl.use_pass_diffuse_direct = True
vl.use_pass_diffuse_indirect = True
vl.use_pass_diffuse_color = True
vl.use_pass_glossy_direct = True
vl.use_pass_glossy_indirect = True
vl.use_pass_glossy_color = True
vl.use_pass_transmission_direct = True
vl.use_pass_transmission_indirect = True
vl.use_pass_transmission_color = True
vl.use_pass_emit = True
vl.use_pass_environment = True
vl.use_pass_ambient_occlusion = True

vl.use_pass_cryptomatte_object = True
vl.use_pass_cryptomatte_material = True
vl.use_pass_cryptomatte_asset = True

# Cycles-only passes live on view_layer.cycles:
vl.cycles.denoising_store_passes = True   # Denoising Albedo / Normal for the Denoise node
vl.cycles.use_pass_volume_direct = True
vl.cycles.use_pass_shadow_catcher = True

print([s.name for s in rl.outputs if s.enabled])
```

Object and material indices come from `obj.pass_index` and `material.pass_index`.

## File Output

The node writes to `directory` + `file_name`, with one input per `file_output_items` entry. With
`file_format` set to a single-layer format, each item becomes its own file; with multilayer EXR,
each item becomes a layer in one file.

### Multilayer EXR

```python
fo = nodes.new("CompositorNodeOutputFile")
fo.location = (300, -400)
fo.directory = "//render/passes/"      # // means relative to the .blend file
fo.file_name = "shot_"
fo.format.media_type = 'MULTI_LAYER_IMAGE'
fo.format.file_format = 'OPEN_EXR_MULTILAYER'
fo.format.color_depth = '32'           # or '16'
fo.format.exr_codec = 'ZIP'            # NONE, ZIP, PIZ, DWAA, DWAB, HTJ2K, ZIPS, RLE, PXR24, B44, B44A

fo.file_output_items.clear()
fo.file_output_items.new('RGBA', "beauty")
fo.file_output_items.new('RGBA', "diffuse_color")
fo.file_output_items.new('VECTOR', "normal")
fo.file_output_items.new('FLOAT', "depth")

links.new(rl.outputs["Image"], fo.inputs["beauty"])
links.new(rl.outputs["Diffuse Color"], fo.inputs["diffuse_color"])
links.new(rl.outputs["Normal"], fo.inputs["normal"])
links.new(rl.outputs["Depth"], fo.inputs["depth"])
```

### One file per pass

```python
fo = nodes.new("CompositorNodeOutputFile")
fo.directory = "//render/"
fo.format.media_type = 'IMAGE'
fo.format.file_format = 'PNG'
fo.file_output_items.clear()
for name in ("beauty", "mist"):
    fo.file_output_items.new('RGBA', name)
links.new(rl.outputs["Image"], fo.inputs["beauty"])
links.new(rl.outputs["Mist"], fo.inputs["mist"])
```

- Always set `format.media_type` before `format.file_format`.
- Rename an item with `fo.file_output_items[0].name = "..."`. An item name may contain a
  subdirectory (5.1 and later).
- An item can use its own format: `item.override_node_format = True`, then set `item.format`.
- The frame number is appended only on animation renders; put `####` in `file_name` to get it on a
  single-frame render too.

## Full pipeline: denoise, grade, bloom

```python
import bpy

scene = bpy.context.scene
scene.render.engine = 'CYCLES'
vl = scene.view_layers[0]
vl.cycles.denoising_store_passes = True

tree = bpy.data.node_groups.new("Grade", "CompositorNodeTree")
scene.compositing_node_group = tree
tree.interface.new_socket(name="Image", in_out='OUTPUT', socket_type='NodeSocketColor')
nodes, links = tree.nodes, tree.links

rl = nodes.new("CompositorNodeRLayers");        rl.location = (-900, 0)
denoise = nodes.new("CompositorNodeDenoise");   denoise.location = (-600, 0)
cb = nodes.new("CompositorNodeColorBalance");   cb.location = (-300, 0)
hsv = nodes.new("CompositorNodeHueSat");        hsv.location = (0, 0)
glare = nodes.new("CompositorNodeGlare");       glare.location = (300, 0)
out = nodes.new("NodeGroupOutput");             out.location = (600, 0)
viewer = nodes.new("CompositorNodeViewer");     viewer.location = (600, -200)

cb.inputs["Type"].default_value = "Lift/Gamma/Gain"
cb.inputs["Color Gain"].default_value = (1.05, 1.0, 0.95, 1.0)
hsv.inputs["Saturation"].default_value = 1.1
glare.inputs["Type"].default_value = "Bloom"
glare.inputs["Quality"].default_value = "Medium"
glare.inputs["Highlights Threshold"].default_value = 1.0
glare.inputs["Strength"].default_value = 0.6

links.new(rl.outputs["Image"], denoise.inputs["Image"])
links.new(rl.outputs["Denoising Albedo"], denoise.inputs["Albedo"])
links.new(rl.outputs["Denoising Normal"], denoise.inputs["Normal"])
links.new(denoise.outputs["Image"], cb.inputs["Image"])
links.new(cb.outputs["Image"], hsv.inputs["Image"])
links.new(hsv.outputs["Image"], glare.inputs["Image"])
links.new(glare.outputs["Image"], out.inputs["Image"])
links.new(glare.outputs["Image"], viewer.inputs["Image"])
```

## Vignette

```python
ellipse = nodes.new("CompositorNodeEllipseMask")
ellipse.inputs["Size"].default_value = (0.9, 0.7)
soften = nodes.new("CompositorNodeBlur")
soften.inputs["Size"].default_value = (200, 200)
vignette = nodes.new("ShaderNodeMix")
vignette.data_type = 'RGBA'
vignette.blend_type = 'MULTIPLY'
vignette.inputs["Factor"].default_value = 1.0

links.new(ellipse.outputs["Mask"], soften.inputs["Image"])
links.new(rl.outputs["Image"], vignette.inputs["A"])
links.new(soften.outputs["Image"], vignette.inputs["B"])
links.new(vignette.outputs["Result"], out.inputs["Image"])
```

## Depth of field

```python
scene.view_layers[0].use_pass_z = True
defocus = nodes.new("CompositorNodeDefocus")
defocus.use_zbuffer = True           # the Z input is real depth, not a 0..1 mask
defocus.f_stop = 2.8                 # 128 is perfect focus; halving it doubles the blur
defocus.blur_max = 16.0              # maximum blur radius in pixels
defocus.bokeh = 'CIRCLE'             # OCTAGON, HEPTAGON, HEXAGON, PENTAGON, SQUARE, TRIANGLE, CIRCLE
links.new(rl.outputs["Image"], defocus.inputs["Image"])
links.new(rl.outputs["Depth"], defocus.inputs["Z"])
```

Focus distance comes from the scene camera (`camera.data.dof.focus_distance` or focus object).

## Keying over a background plate

```python
fg = nodes.new("CompositorNodeImage")
fg.image = bpy.data.images.load("//footage/greenscreen.png")
bg = nodes.new("CompositorNodeImage")
bg.image = bpy.data.images.load("//footage/plate.png")

key = nodes.new("CompositorNodeKeying")
key.inputs["Key Color"].default_value = (0.0, 1.0, 0.0, 1.0)
key.inputs["Despill Strength"].default_value = 1.0
key.inputs["Postprocess Dilate Size"].default_value = -1   # shrink the matte by a pixel

over = nodes.new("CompositorNodeAlphaOver")
links.new(fg.outputs["Image"], key.inputs["Image"])
links.new(bg.outputs["Image"], over.inputs["Background"])
links.new(key.outputs["Image"], over.inputs["Foreground"])
links.new(over.outputs["Image"], out.inputs["Image"])
```

## Rendering through the compositor

```python
scene.render.filepath = "//render/frame_"
bpy.ops.render.render(write_still=True)
```

Headless, `blender -b file.blend -o //render/frame_#### -F PNG -f 1` renders frame 1 through the
compositor and writes it. With the MCP server, render with `render_viewport_to_path` and look at
the written image.
