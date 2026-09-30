# Shader templates and Render Graph patterns

## Templates per pipeline

### Built-In Render Pipeline: ShaderLab + CG/HLSL

```hlsl
Shader "Game/Category/EffectName"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        CGPROGRAM
        #pragma surface surf Standard fullforwardshadows
        struct Input { float2 uv_MainTex; };
        sampler2D _MainTex;
        fixed4 _Color;
        void surf (Input IN, inout SurfaceOutputStandard o)
        {
            fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
            o.Albedo = c.rgb;
            o.Alpha = c.a;
        }
        ENDCG
    }
    Fallback "Diffuse"
}
```

### URP: ShaderLab + HLSL with URP includes

The CBUFFER lives in a SubShader-level `HLSLINCLUDE` so every pass (ForwardLit, ShadowCaster)
shares the same layout, which the SRP Batcher requires.

```hlsl
Shader "Game/Category/EffectName"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color ("Color", Color) = (1,1,1,1)
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" "RenderPipeline"="UniversalPipeline" "Queue"="Geometry" }

        HLSLINCLUDE
        #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

        TEXTURE2D(_MainTex); SAMPLER(sampler_MainTex);
        CBUFFER_START(UnityPerMaterial)
            float4 _MainTex_ST;
            half4 _Color;
        CBUFFER_END
        ENDHLSL

        Pass
        {
            Name "ForwardLit"
            Tags { "LightMode"="UniversalForward" }
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv : TEXCOORD0;
                float3 normalOS : NORMAL;
            };
            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv : TEXCOORD0;
                float3 normalWS : TEXCOORD1;
            };

            Varyings vert (Attributes IN)
            {
                Varyings OUT;
                OUT.positionHCS = TransformObjectToHClip(IN.positionOS.xyz);
                OUT.uv = TRANSFORM_TEX(IN.uv, _MainTex);
                OUT.normalWS = TransformObjectToWorldNormal(IN.normalOS);
                return OUT;
            }
            half4 frag (Varyings IN) : SV_Target
            {
                half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv) * _Color;
                return col;
            }
            ENDHLSL
        }

        // ShadowCaster pass goes here (see below)
    }
    Fallback "Universal Render Pipeline/Lit"
}
```

### HDRP

Same structure as URP but with HDRP includes
(`Packages/com.unity.render-pipelines.high-definition/Runtime/ShaderLibrary/`). Prefer Shader
Graph for HDRP whenever possible.

## Render Graph API

URP in Unity 6 records custom passes with the Render Graph API. Compatibility Mode (the old
`Execute` path) is deprecated in 6.0 and removed in 6.3. Run the finished renderer feature through
Unity's official `validate-urp-render-graph-renderer-feature` skill.

### Required migration

| Old (do not write) | Render Graph |
|---|---|
| `ScriptableRenderPass.Execute(ScriptableRenderContext, ref RenderingData)` | `ScriptableRenderPass.RecordRenderGraph(RenderGraph, ContextContainer)` |
| `OnCameraSetup` / `Configure` | Declare inputs/outputs on the builder inside `RecordRenderGraph` |
| `ScriptableRendererFeature.SetupRenderPasses` (deprecated in 6.2) | Enqueue in `AddRenderPasses(ScriptableRenderer, ref RenderingData)` |
| Manually allocated `RTHandle`s, `cmd.GetTemporaryRT` | `renderGraph.CreateTexture(desc)`: the graph owns the resource |
| `cmd.Blit(...)` | `renderGraph.AddBlitPass(new RenderGraphUtils.BlitMaterialParameters(...), name)` |

### Pattern: fullscreen material pass (URP)

For a simple effect, prefer a Fullscreen Shader Graph on the built-in **Full Screen Pass Renderer
Feature**: no C#. Write code only when you need custom logic.

```csharp
using UnityEngine;
using UnityEngine.Rendering;
using UnityEngine.Rendering.Universal;
using UnityEngine.Rendering.RenderGraphModule;
using UnityEngine.Rendering.RenderGraphModule.Util;

public class CustomFullscreenFeature : ScriptableRendererFeature
{
    [SerializeField] private Material material;
    private CustomFullscreenPass _pass;

    public override void Create()
    {
        _pass = new CustomFullscreenPass(material);
    }

    public override void AddRenderPasses(ScriptableRenderer renderer, ref RenderingData renderingData)
    {
        if (material != null)
            renderer.EnqueuePass(_pass);
    }
}

public class CustomFullscreenPass : ScriptableRenderPass
{
    private readonly Material _material;

    public CustomFullscreenPass(Material material)
    {
        _material = material;
        renderPassEvent = RenderPassEvent.AfterRenderingPostProcessing;
        requiresIntermediateTexture = true; // the pass samples the camera color
    }

    public override void RecordRenderGraph(RenderGraph renderGraph, ContextContainer frameData)
    {
        var resourceData = frameData.Get<UniversalResourceData>();
        if (resourceData.isActiveTargetBackBuffer)
            return; // cannot sample the back buffer

        TextureHandle source = resourceData.activeColorTexture;
        TextureDesc desc = renderGraph.GetTextureDesc(source);
        desc.name = "CustomFullscreenColor";
        desc.clearBuffer = false;
        desc.depthBufferBits = 0;
        TextureHandle destination = renderGraph.CreateTexture(desc);

        var blitParams = new RenderGraphUtils.BlitMaterialParameters(source, destination, _material, 0);
        renderGraph.AddBlitPass(blitParams, "Custom Fullscreen");

        resourceData.cameraColor = destination; // later passes read the result
    }
}
```

The blit material's shader reads the source as `_BlitTexture`: include
`Packages/com.unity.render-pipelines.core/Runtime/Utilities/Blit.hlsl` and use its `Vert` vertex
function. Verify method names against the URP package docs for the installed version, and confirm
the pass in the Render Graph Viewer.

### Why Render Graph

- **Automatic resource management**: no manual allocation/release of render textures
- **Pass culling**: passes whose output nobody reads are removed
- **Clearer profiling**: each pass shows up in the Frame Debugger and Render Graph Viewer

## ShadowCaster pass

**Required** for the object to cast shadows in URP. Add it after the ForwardLit pass. It uses the
CBUFFER from the SubShader `HLSLINCLUDE`, so the shader stays SRP Batcher compatible.

```hlsl
Pass
{
    Name "ShadowCaster"
    Tags { "LightMode"="ShadowCaster" }
    ZWrite On
    ZTest LEqual
    ColorMask 0

    HLSLPROGRAM
    #pragma vertex ShadowVert
    #pragma fragment ShadowFrag
    #pragma multi_compile_vertex _ _CASTING_PUNCTUAL_LIGHT_SHADOW
    #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Shadows.hlsl"

    float3 _LightDirection;
    float3 _LightPosition;

    struct ShadowAttributes { float4 positionOS : POSITION; float3 normalOS : NORMAL; };
    struct ShadowVaryings   { float4 positionCS : SV_POSITION; };

    ShadowVaryings ShadowVert (ShadowAttributes IN)
    {
        ShadowVaryings OUT;
        float3 positionWS = TransformObjectToWorld(IN.positionOS.xyz);
        float3 normalWS = TransformObjectToWorldNormal(IN.normalOS);
    #if _CASTING_PUNCTUAL_LIGHT_SHADOW
        float3 lightDirectionWS = normalize(_LightPosition - positionWS);
    #else
        float3 lightDirectionWS = _LightDirection;
    #endif
        float4 positionCS = TransformWorldToHClip(ApplyShadowBias(positionWS, normalWS, lightDirectionWS));
    #if UNITY_REVERSED_Z
        positionCS.z = min(positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #else
        positionCS.z = max(positionCS.z, UNITY_NEAR_CLIP_VALUE);
    #endif
        OUT.positionCS = positionCS;
        return OUT;
    }

    half4 ShadowFrag (ShadowVaryings IN) : SV_Target { return 0; }
    ENDHLSL
}
```

If the main pass clips (dissolve, alpha test) or moves vertices (waves, displacement), repeat that
in `ShadowVert`/`ShadowFrag` so the shadow matches.
