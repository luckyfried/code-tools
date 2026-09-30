---
name: unity-shader-gen
description: Use when the user wants a hand-written Unity shader (.shader file, ShaderLab + HLSL) for a visual effect, in URP, HDRP, or the Built-In Render Pipeline. It detects the render pipeline, writes a ready-to-use .shader file with SRP Batcher and shadow support, and gives the Material setup steps. Triggers include "write a shader", "create a shader", "shader effect", "dissolve shader", "outline shader", "toon shader", "cel shading", "hologram shader", "force field shader", "water shader", "triplanar", "vertex displacement", "HLSL", "ShaderLab", "shader is pink/magenta", "SRP Batcher not compatible", and "fullscreen effect".
---

Adapted from JulianKerignard/Unity-Skills (MIT); see LICENSE.

# Unity Shader Generator

## What this skill does

Writes complete Unity shaders (`.shader` files) for the project's render pipeline. Covers common
effects: dissolve, outline, toon, hologram, force field, water, triplanar, vertex displacement.
Produces clean ShaderLab/HLSL tuned for mobile, followed by Material setup steps.

Other work belongs elsewhere:

- Reviewing or writing a URP renderer feature / render pass (Render Graph): Unity's official
  `validate-urp-render-graph-renderer-feature` skill. The fullscreen pattern below is a starting
  point; run that review on it.
- Wrapping HLSL as a Shader Graph node: Unity's official `shader-graph-create-custom-node` skill.
- C# API currency for render passes (Render Graph only, no Compatibility Mode): `unity-current-api`.

## Prerequisites

- A Unity project with `Packages/manifest.json`
- A description of the effect (text or visual reference)
- Write access to `Assets/`

## Decision tree

```
What kind of shader?
|
+-- Material effect (dissolve, outline, toon, hologram)?
|   +-- Recipes in references/shader-recipes.md
|
+-- Post-processing / fullscreen effect?
|   +-- URP, simple effect --> Fullscreen Shader Graph + Full Screen Pass Renderer Feature (no C#)
|   +-- URP, custom logic --> ScriptableRenderPass with RecordRenderGraph (Render Graph API)
|   +-- HDRP --> Custom Pass Volume
|
+-- Custom render pass (injected into the pipeline)?
|   +-- Render Graph API (RecordRenderGraph). Never Execute/OnCameraSetup.
|
+-- Vertex deformation (displacement, wind, snow)?
    +-- Vertex shader with noise (see references/hlsl-utils.md)
```

## Quick start

1. The user describes the effect ("a dissolve shader with a glowing edge").
2. Detect the project's render pipeline.
3. Write the `.shader` file and the Material instructions.

## Step by step

### Step 1: Identify the effect

Classify the request against the known recipes:

- **Dissolve**: progressive destruction against a threshold
- **Outline**: colored contour around an object
- **Toon / cel shading**: cartoon lighting with hard steps
- **Hologram**: scanlines and transparency
- **Force field**: energy shield with fresnel and scene intersection
- **Water surface**: waves and transparency
- **Triplanar mapping**: world-space UV projection
- **Vertex displacement**: noise-driven vertex deformation
- **Custom**: combine the techniques above

Detailed recipes: `references/shader-recipes.md`.

### Step 2: Detect the render pipeline

Search `Packages/manifest.json`:

```
"com.unity.render-pipelines.universal"      --> URP
"com.unity.render-pipelines.high-definition" --> HDRP
neither                                      --> Built-In Render Pipeline (confirm in Project Settings > Graphics)
```

This detection is **mandatory** before writing any code. The Built-In Render Pipeline is deprecated
from Unity 6.5; for new rendering work target URP unless the project is Built-In.

### Step 3: Pick the shader format

Use the matching template in `references/shader-templates.md`:

| Pipeline | Format | Key tags |
|----------|--------|----------|
| Built-In | ShaderLab + CG/HLSL | `CGPROGRAM/ENDCG`, surface shader |
| URP | ShaderLab + HLSL | `"RenderPipeline"="UniversalPipeline"`, `CBUFFER_START(UnityPerMaterial)` |
| HDRP | ShaderLab + HLSL (HDRP includes) | Prefer Shader Graph |

**URP:** always declare material properties inside `CBUFFER_START(UnityPerMaterial)` for SRP
Batcher compatibility, and every pass must see the same CBUFFER (put it in a SubShader-level
`HLSLINCLUDE` block).

### Step 4: Write the shader

Write the full `.shader` file into the project:

- **Location:** `Assets/Shaders/` or `Assets/Art/Shaders/`
- **File name:** `Game_Category_EffectName.shader` (for example `Game_FX_Dissolve.shader`)
- **Shader path:** `Game/Category/EffectName`
- Include: Properties, SubShader, Pass(es), vertex/fragment, Fallback

### Step 5: Material instructions

Always give the Material setup:

1. In Unity: `Assets > Create > Material`
2. Pick the shader in the Material's shader dropdown (search `Game/Category/EffectName`)
3. Set the exposed properties (textures, colors, thresholds)
4. Assign the Material to the target GameObject

## Render Graph (Unity 6)

URP in Unity 6 records custom passes with the Render Graph API: override `RecordRenderGraph`.
`Execute` and `OnCameraSetup` belong to Compatibility Mode, which is removed in Unity 6.3.
Pattern and migration table: `references/shader-templates.md#render-graph-api`.

## URP ShadowCaster pass

**Required** for the object to cast shadows in URP. Template:
`references/shader-templates.md#shadowcaster-pass`.

## Hard rules

- **ALWAYS** detect the render pipeline before writing code
- **ALWAYS** include a `Fallback`
- **ALWAYS** expose key values as Properties (never hardcoded)
- **ALWAYS** give the Material instructions after the shader
- **ALWAYS** put the file in `Assets/Shaders/` or a subfolder
- **ALWAYS** name the shader `Game/Category/EffectName`
- **ALWAYS** include a `ShadowCaster` pass in URP opaque shaders
- **NEVER** mix `CGPROGRAM/ENDCG` and `HLSLPROGRAM/ENDHLSL` in one shader
- **NEVER** use surface shaders in URP/HDRP (vertex/fragment only)
- **NEVER** leave out `CBUFFER_START(UnityPerMaterial)` in URP (needed for the SRP Batcher)
- **NEVER** write a URP render pass with `Execute`/`OnCameraSetup`; use `RecordRenderGraph`
- **PREFER** `half` precision on mobile targets
- **PREFER** Shader Graph for non-technical artists (describe the node graph)

## Related skills

- Rendering performance: `unity-perf-audit` for a code scan, `unity-profiling-workflow` to measure.
- Renderer feature review: Unity's official `validate-urp-render-graph-renderer-feature`.
- Shader Graph custom nodes: Unity's official `shader-graph-create-custom-node`.

## Troubleshooting

| Problem | Fix |
|---------|-----|
| Pink/magenta shader | Compile error: check pipeline includes, function names, semantics |
| Not SRP Batcher compatible | Put all Properties in one `CBUFFER_START(UnityPerMaterial)` / `CBUFFER_END`, identical in every pass |
| Shader does nothing in URP | Check the `"RenderPipeline"="UniversalPipeline"` and `"LightMode"="UniversalForward"` tags |
| Transparency not showing | Add `Tags { "Queue"="Transparent" "RenderType"="Transparent" }`, `Blend SrcAlpha OneMinusSrcAlpha`, `ZWrite Off` |
| No shadow | Add a `ShadowCaster` pass (see template) |
| Slow on mobile | Fewer texture samples, use `half`, drop dynamic branches |
| Blurry texture / wrong tiling | Check `TRANSFORM_TEX(IN.uv, _MainTex)` and that `_MainTex_ST` is in the CBUFFER |
| Depth intersection does not work | Enable Depth Texture on the URP asset (or the camera) |
| Object missing from depth-based effects (SSAO, soft particles) | Add a `DepthOnly` pass (and `DepthNormals` for SSAO) |

## References

- Effect recipes: `references/shader-recipes.md`
- Pipeline templates, Render Graph, ShadowCaster: `references/shader-templates.md`
- HLSL helpers and mobile optimization: `references/hlsl-utils.md`
