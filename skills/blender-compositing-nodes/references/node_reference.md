# Compositor node reference (Blender 5.x)

Every type string below can be added to a `CompositorNodeTree` with `tree.nodes.new(type)`.
Options are input sockets unless the node lists properties. Where an input's name and identifier
differ, the table gives `name (identifier)`. On these compositor nodes `node.inputs["<identifier>"]`
works, which is how to reach the second of two inputs that share a name.

## Types that no longer exist

| Old type | Use instead |
| --- | --- |
| `CompositorNodeComposite` | `NodeGroupOutput`, with a Color output socket on `tree.interface` |
| `CompositorNodeMixRGB` | `ShaderNodeMix` with `data_type = 'RGBA'` and `blend_type` |
| `CompositorNodeValue` | `ShaderNodeValue` |
| `CompositorNodeMath` | `ShaderNodeMath` |
| `CompositorNodeMapRange` | `ShaderNodeMapRange` |
| `CompositorNodeMapValue` | `ShaderNodeMapRange` or `ShaderNodeClamp` |
| `CompositorNodeValToRGB` | `ShaderNodeValToRGB` |
| `CompositorNodeGamma` | `ShaderNodeGamma` |
| `CompositorNodeCurveVec` | `ShaderNodeVectorCurve` |
| `CompositorNodeCombineXYZ`, `CompositorNodeSeparateXYZ` | `ShaderNodeCombineXYZ`, `ShaderNodeSeparateXYZ` |
| `CompositorNodeSplitViewer` | `CompositorNodeSplit` into a Viewer |
| `CompositorNodeSunBeams` | Glare with `Type` = `Sun Beams` |
| `CompositorNodeTexture` | The procedural `ShaderNodeTex*` nodes |

## Input

| Node | Type | Inputs and properties | Outputs |
| --- | --- | --- | --- |
| Render Layers | `CompositorNodeRLayers` | props `scene`, `layer` | `Image`, `Alpha`, plus one per enabled pass (below) |
| Image | `CompositorNodeImage` | props `image`, `frame_start`, `frame_duration`, `frame_offset`, `use_cyclic`, `layer`, `view` | `Image`, `Alpha` (multilayer images add their passes) |
| Movie Clip | `CompositorNodeMovieClip` | prop `clip` | `Image`, `Alpha`, `Offset X/Y`, `Scale`, `Angle` |
| Mask | `CompositorNodeMask` | prop `mask`; `Size Source`, `Size X/Y`, `Feather`, `Motion Blur` | `Mask` |
| Color | `CompositorNodeRGB` | set `outputs["Color"].default_value` | `Color` |
| Bokeh Image | `CompositorNodeBokehImage` | `Flaps`, `Angle`, `Roundness`, `Catadioptric Size`, `Color Shift` | `Image` |
| Blank Image | `CompositorNodeBlankImage` | `Color`, `Size` | `Image` |
| String To Image | `CompositorNodeStringToImage` | `String`, `Font`, `Size`, alignment, `Wrap` | `Image` |
| Scene Time | `CompositorNodeSceneTime` | | `Seconds`, `Frame` |
| Time Curve | `CompositorNodeTime` | prop `curve`; `Start Frame`, `End Frame` | `Factor` |
| Track Position | `CompositorNodeTrackPos` | props `clip`, `tracking_object`, `track_name`; `Mode`, `Frame` | `X`, `Y`, `Speed` |
| Image Info | `CompositorNodeImageInfo` | `Image` | `Dimensions`, `Resolution`, `Location`, `Rotation`, `Scale` |
| Image Coordinates | `CompositorNodeImageCoordinates` | `Image` | `Uniform`, `Normalized`, `Pixel` |
| Sequencer Strip Info | `CompositorNodeSequencerStripInfo` | | `Start Frame`, `End Frame`, `Location`, `Rotation`, `Scale` |
| Normal | `CompositorNodeNormal` | | `Normal` |

Shared input nodes also work: `ShaderNodeValue`, `FunctionNodeInputBool`, `FunctionNodeInputInt`,
`FunctionNodeInputVector`, `FunctionNodeInputString`, `NodeGroupInput`.

## Output

| Node | Type | Notes |
| --- | --- | --- |
| Group Output | `NodeGroupOutput` | The first input is the final image and must be Color |
| Viewer | `CompositorNodeViewer` | Input `Image`; shows it in the image editor or backdrop |
| File Output | `CompositorNodeOutputFile` | Props `directory`, `file_name`, `format`, `file_output_items`; see `python_api.md` |

## Color

| Node | Type | Inputs |
| --- | --- | --- |
| Alpha Over | `CompositorNodeAlphaOver` | `Background`, `Foreground`, `Factor (Fac)`, `Type` (`Over`, `Disjoint Over`, `Conjoint Over`), `Straight Alpha` |
| Brightness/Contrast | `CompositorNodeBrightContrast` | `Image`, `Brightness (Bright)`, `Contrast` |
| Color Balance | `CompositorNodeColorBalance` | `Image`, `Factor (Fac)`, `Type` (`Lift/Gamma/Gain`, `Offset/Power/Slope (ASC-CDL)`, `White Point`), `Base Lift`/`Color Lift`, `Base Gamma`/`Color Gamma`, `Base Gain`/`Color Gain`, `Base Offset`/`Color Offset`, `Base Power`/`Color Power`, `Base Slope`/`Color Slope`, `Input/Output Temperature`, `Input/Output Tint` |
| Color Correction | `CompositorNodeColorCorrection` | `Image`, `Mask`, `Master/Highlights/Midtones/Shadows Saturation`, `... Contrast`, `... Gamma`, `... Gain`, `... Offset` (identifiers) |
| Exposure | `CompositorNodeExposure` | `Image`, `Exposure` |
| Hue Correct | `CompositorNodeHueCorrect` | prop `mapping`; `Image`, `Factor (Fac)` |
| Hue/Saturation/Value | `CompositorNodeHueSat` | `Image`, `Hue`, `Saturation`, `Value`, `Factor (Fac)` |
| RGB Curves | `CompositorNodeCurveRGB` | prop `mapping`; `Image`, `Factor (Fac)`, `Black Level`, `White Level` |
| Invert Color | `CompositorNodeInvert` | `Color`, `Factor (Fac)`, `Invert Color`, `Invert Alpha` |
| Posterize | `CompositorNodePosterize` | `Image`, `Steps` |
| Tonemap | `CompositorNodeTonemap` | `Image`, `Type` (`R/D Photoreceptor`, `Rh Simple`), `Key`, `Balance`, `Gamma`, `Intensity`, `Contrast`, `Light Adaptation`, `Chromatic Adaptation` |
| Depth Combine | `CompositorNodeZcombine` | `A`, `Depth A`, `B`, `Depth B`, `Use Alpha`, `Anti-Alias`; outputs `Result`, `Depth` |
| Combine Color | `CompositorNodeCombineColor` | prop `mode` (`RGB`, `HSV`, `HSL`, `YCC`, `YUV`); `Red`, `Green`, `Blue`, `Alpha` |
| Separate Color | `CompositorNodeSeparateColor` | prop `mode`; `Image`; outputs `Red`, `Green`, `Blue`, `Alpha` |
| Set Alpha | `CompositorNodeSetAlpha` | `Image`, `Alpha`, `Type` (`Apply Mask`, `Replace Alpha`) |
| Alpha Convert | `CompositorNodePremulKey` | `Image`, `Type` (`To Premultiplied`, `To Straight`) |
| Convert Colorspace | `CompositorNodeConvertColorSpace` | props `from_color_space`, `to_color_space` |
| Convert to Display | `CompositorNodeConvertToDisplay` | props `view_settings`, `display_settings`; `Image`, `Invert` |
| RGB to BW | `CompositorNodeRGBToBW` | `Image`; output `Val` |
| Mix | `ShaderNodeMix` | props `data_type = 'RGBA'`, `blend_type` (`MIX`, `DARKEN`, `MULTIPLY`, `BURN`, `LIGHTEN`, `SCREEN`, `DODGE`, `ADD`, `OVERLAY`, `SOFT_LIGHT`, `LINEAR_LIGHT`, `DIFFERENCE`, `EXCLUSION`, `SUBTRACT`, `DIVIDE`, `HUE`, `SATURATION`, `COLOR`, `VALUE`), `clamp_result`; after setting `data_type`, `inputs["Factor"]`, `["A"]`, `["B"]` and `outputs["Result"]` return the sockets for that type |
| Gamma | `ShaderNodeGamma` | `Color`, `Gamma` |
| Color Ramp | `ShaderNodeValToRGB` | prop `color_ramp`; `Factor (Fac)`; outputs `Color`, `Alpha` |
| RGB Curves (shared) | `ShaderNodeRGBCurve` | prop `mapping`; `Factor (Fac)`, `Color` |
| Blackbody | `ShaderNodeBlackbody` | `Temperature` |

## Filter

| Node | Type | Inputs |
| --- | --- | --- |
| Blur | `CompositorNodeBlur` | `Image`, `Size` (2D, pixels), `Type` (`Flat`, `Tent`, `Quadratic`, `Cubic`, `Gaussian`, `Fast Gaussian`, `Catrom`, `Mitch`), `Extend Bounds`, `Separable` |
| Bilateral Blur | `CompositorNodeBilateralblur` | `Image`, `Determinator`, `Size`, `Threshold` |
| Bokeh Blur | `CompositorNodeBokehBlur` | `Image`, `Bokeh`, `Size` (pixels), `Mask`, `Extend Bounds` |
| Defocus | `CompositorNodeDefocus` | props `bokeh`, `angle`, `f_stop`, `blur_max`, `use_zbuffer`, `z_scale`, `scene`; inputs `Image`, `Z` |
| Denoise | `CompositorNodeDenoise` | `Image`, `Albedo`, `Normal`, `HDR`, `Prefilter` (`None`, `Fast`, `Accurate`), `Quality` (`Follow Scene`, `High`, `Balanced`, `Fast`) |
| Despeckle | `CompositorNodeDespeckle` | `Image`, `Factor (Fac)`, `Color Threshold`, `Neighbor Threshold` |
| Dilate/Erode | `CompositorNodeDilateErode` | `Mask`, `Size` (negative erodes), `Type` (`Steps`, `Threshold`, `Distance`, `Feather`), `Falloff Size`, `Falloff` |
| Directional Blur | `CompositorNodeDBlur` | `Image`, `Samples`, `Center`, `Rotation`, `Scale`, `Amount (Translation Amount)`, `Direction (Translation Direction)` |
| Filter | `CompositorNodeFilter` | `Image`, `Factor (Fac)`, `Type` (`Soften`, `Box Sharpen`, `Diamond Sharpen`, `Laplace`, `Sobel`, `Prewitt`, `Kirsch`, `Shadow`) |
| Glare | `CompositorNodeGlare` | `Image`, `Type` (`Bloom`, `Ghosts`, `Streaks`, `Fog Glow`, `Simple Star`, `Sun Beams`, `Kernel`), `Quality` (`High`, `Medium`, `Low`), `Threshold (Highlights Threshold)`, `Smoothness (Highlights Smoothness)`, `Strength`, `Saturation`, `Tint`, `Size`, `Streaks`, `Streaks Angle`, `Iterations`, `Fade`, `Color Modulation`, `Diagonal (Diagonal Star)`, `Sun Position`, `Jitter`, `Kernel`; outputs `Image`, `Glare`, `Highlights` |
| Inpaint | `CompositorNodeInpaint` | `Image`, `Size` |
| Kuwahara | `CompositorNodeKuwahara` | `Image`, `Size`, `Type` (`Classic`, `Anisotropic`), `Uniformity`, `Sharpness`, `Eccentricity`, `High Precision` |
| Pixelate | `CompositorNodePixelate` | `Color`, `Size` |
| Anti-Aliasing | `CompositorNodeAntiAliasing` | `Image`, `Threshold`, `Contrast Limit`, `Corner Rounding` |
| Vector Blur | `CompositorNodeVecBlur` | `Image`, `Speed`, `Depth (Z)`, `Samples`, `Shutter` |
| Convolve | `CompositorNodeConvolve` | `Image`, `Kernel Data Type`, `Kernel (Float Kernel / Color Kernel)`, `Normalize Kernel` |

## Matte and keying

| Node | Type | Inputs |
| --- | --- | --- |
| Keying | `CompositorNodeKeying` | `Image`, `Key Color`, `Preprocess Blur Size`, `Key Balance`, `Black Level`, `White Level`, `Edge Search Size`, `Edge Tolerance`, `Garbage Matte`, `Core Matte`, `Postprocess Blur Size`, `Postprocess Dilate Size`, `Postprocess Feather Size`, `Feather Falloff`, `Despill Strength`, `Despill Balance` (identifiers); outputs `Image`, `Matte`, `Edges` |
| Keying Screen | `CompositorNodeKeyingScreen` | props `clip`, `tracking_object`; `Smoothness`; output `Screen` |
| Channel Key | `CompositorNodeChannelMatte` | `Image`, `Minimum`, `Maximum`, `Color Space` (`RGB`, `HSV`, `YUV`, `YCbCr`), `RGB Key Channel` etc., `Limit Method` |
| Chroma Key | `CompositorNodeChromaMatte` | `Image`, `Key Color`, `Minimum`, `Maximum` (angles), `Falloff` |
| Color Key | `CompositorNodeColorMatte` | `Image`, `Key Color`, `Hue`, `Saturation`, `Value` |
| Color Spill | `CompositorNodeColorSpill` | `Image`, `Factor (Fac)`, `Spill Channel`, `Limit Method`, `Limit Channel`, `Limit Strength`, `Use Spill Strength`, `Spill Strength` |
| Difference Key | `CompositorNodeDiffMatte` | `Image 1`, `Image 2`, `Tolerance`, `Falloff` |
| Distance Key | `CompositorNodeDistanceMatte` | `Image`, `Key Color`, `Color Space`, `Tolerance`, `Falloff` |
| Luminance Key | `CompositorNodeLumaMatte` | `Image`, `Minimum`, `Maximum` |
| Box Mask | `CompositorNodeBoxMask` | `Operation` (`Add`, `Subtract`, `Multiply`, `Not`), `Mask`, `Value`, `Position`, `Size`, `Rotation` |
| Ellipse Mask | `CompositorNodeEllipseMask` | Same as Box Mask |
| Double Edge Mask | `CompositorNodeDoubleEdgeMask` | `Outer Mask`, `Inner Mask`, `Image Edges`, `Only Inside Outer` |
| ID Mask | `CompositorNodeIDMask` | `ID value`, `Index`, `Anti-Alias`; output `Alpha` |
| Cryptomatte | `CompositorNodeCryptomatteV2` | props `source` (`RENDER`, `IMAGE`), `scene`, `image`, `matte_id`, `layer_name`; outputs `Image`, `Matte`, `Pick` |
| Cryptomatte (Legacy) | `CompositorNodeCryptomatte` | Deprecated; use the one above |
| Mask To SDF | `CompositorNodeMaskToSDF` | `Mask`; outputs `SDF`, `Nearest Pixel` |

## Transform and distort

| Node | Type | Inputs |
| --- | --- | --- |
| Translate | `CompositorNodeTranslate` | `Image`, `X`, `Y`, `Interpolation`, `Extension X`, `Extension Y` (`Clip`, `Extend`, `Repeat`) |
| Rotate | `CompositorNodeRotate` | `Image`, `Angle`, `Interpolation`, `Extension X/Y` |
| Scale | `CompositorNodeScale` | `Image`, `Type` (`Relative`, `Absolute`, `Scene Size`, `Render Size`), `X`, `Y`, `Frame Type` (`Stretch`, `Fit`, `Crop`), `Interpolation`, `Extension X/Y` |
| Transform | `CompositorNodeTransform` | `Image`, `X`, `Y`, `Angle`, `Scale`, `Interpolation`, `Extension X/Y` |
| Flip | `CompositorNodeFlip` | `Image`, `Flip X`, `Flip Y` |
| Crop | `CompositorNodeCrop` | `Image`, `X`, `Y`, `Width`, `Height`, `Alpha Crop` |
| Lens Distortion | `CompositorNodeLensdist` | `Image`, `Type` (`Radial`, `Horizontal`), `Distortion`, `Dispersion`, `Jitter`, `Fit` |
| Displace | `CompositorNodeDisplace` | `Image`, `Displacement`, `Interpolation`, `Extension X/Y` |
| Map UV | `CompositorNodeMapUV` | `Image`, `UV`, `Interpolation`, `Extension X/Y` |
| Corner Pin | `CompositorNodeCornerPin` | `Image`, `Upper Left`, `Upper Right`, `Lower Left`, `Lower Right`, `Interpolation`, `Extension X/Y`; outputs `Image`, `Plane` |
| Movie Distortion | `CompositorNodeMovieDistortion` | prop `clip`; `Image`, `Type` |
| Stabilize 2D | `CompositorNodeStabilize` | prop `clip`; `Image`, `Frame`, `Invert`, `Interpolation`, `Extension X/Y` |
| Plane Track Deform | `CompositorNodePlaneTrackDeform` | props `clip`, `tracking_object`, `plane_track_name`; `Image`, `Motion Blur` |

## Utility and conversion

| Node | Type | Notes |
| --- | --- | --- |
| Split | `CompositorNodeSplit` | Two `Image` inputs (identifiers `Image`, `Image_001`), `Position`, `Rotation` |
| Switch | `CompositorNodeSwitch` | `Switch`, `Off`, `On` |
| Switch View | `CompositorNodeSwitchView` | `left`, `right` stereo views |
| Levels | `CompositorNodeLevels` | `Image`, `Channel`; outputs `Mean`, `Standard Deviation`, `Minimum`, `Maximum` |
| Normalize | `CompositorNodeNormalize` | `Value` to the 0..1 range of the image |
| Relative To Pixel | `CompositorNodeRelativeToPixel` | props `data_type`, `reference_dimension`; converts image-relative values to pixels |
| Math | `ShaderNodeMath` | prop `operation` |
| Map Range | `ShaderNodeMapRange` | `Value`, `From Min`, `From Max`, `To Min`, `To Max` |
| Clamp | `ShaderNodeClamp` | |
| Vector Math | `ShaderNodeVectorMath` | prop `operation` |
| Combine / Separate XYZ | `ShaderNodeCombineXYZ`, `ShaderNodeSeparateXYZ` | |
| Float Curve, Vector Curves | `ShaderNodeFloatCurve`, `ShaderNodeVectorCurve` | |
| Menu Switch, Index Switch | `GeometryNodeMenuSwitch`, `GeometryNodeIndexSwitch` | |
| Group | `CompositorNodeGroup` | prop `node_tree` (another `CompositorNodeTree`) |
| Frame, Reroute | `NodeFrame`, `NodeReroute` | |

Procedural textures (`ShaderNodeTexNoise`, `ShaderNodeTexWhiteNoise`, `ShaderNodeTexVoronoi`,
`ShaderNodeTexGradient`, `ShaderNodeTexChecker`, `ShaderNodeTexBrick`, `ShaderNodeTexMagic`,
`ShaderNodeTexWave`, `ShaderNodeTexGabor`) and many `FunctionNode*` string, rotation, and matrix
nodes also work in the compositor.

## Render Layers outputs

The Render Layers node has an output for each pass enabled on its view layer.

| View layer property | Output name |
| --- | --- |
| (always) | `Image`, `Alpha` |
| `use_pass_z` | `Depth` |
| `use_pass_mist` | `Mist` |
| `use_pass_normal` | `Normal` |
| `use_pass_position` | `Position` |
| `use_pass_vector` | `Vector` |
| `use_pass_uv` | `UV` |
| `use_pass_object_index` | `Object Index` |
| `use_pass_material_index` | `Material Index` |
| `use_pass_diffuse_direct` / `_indirect` / `_color` | `Diffuse Direct`, `Diffuse Indirect`, `Diffuse Color` |
| `use_pass_glossy_direct` / `_indirect` / `_color` | `Glossy Direct`, `Glossy Indirect`, `Glossy Color` |
| `use_pass_transmission_direct` / `_indirect` / `_color` | `Transmission Direct`, `Transmission Indirect`, `Transmission Color` |
| `use_pass_emit` | `Emission` |
| `use_pass_environment` | `Environment` |
| `use_pass_ambient_occlusion` | `Ambient Occlusion` |
| `use_pass_cryptomatte_object` / `_material` / `_asset` | `CryptoObject00`..., `CryptoMaterial00`..., `CryptoAsset00`... |
| `view_layer.cycles.use_pass_volume_direct` / `_indirect` | `Volume Direct`, `Volume Indirect` (Cycles) |
| `view_layer.cycles.use_pass_shadow_catcher` | `Shadow Catcher` (Cycles) |
| `view_layer.cycles.denoising_store_passes` | `Noisy Image`, `Denoising Albedo`, `Denoising Normal`, and more (Cycles) |

Which passes exist depends on the render engine; EEVEE and Cycles differ. Check
`[s.name for s in rl.outputs if s.enabled]` after enabling passes.
