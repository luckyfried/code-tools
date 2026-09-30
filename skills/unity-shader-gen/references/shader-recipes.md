# Shader recipes

Effect recipes for `unity-shader-gen`. Each gives the principle, the required Properties, and the
HLSL for the fragment and/or vertex shader.

These snippets target URP (HLSL). For the Built-In pipeline, adapt the includes and macros (see the
Built-In template in `shader-templates.md`). Every property listed goes in the
`UnityPerMaterial` CBUFFER (textures excepted: declare them with `TEXTURE2D`/`SAMPLER`).

---

## 1. Dissolve

Principle: sample a noise texture, `clip()` against a threshold, emit on the edge.

Required Properties:
- `_NoiseTex ("Noise", 2D)`: noise texture
- `_DissolveAmount ("Amount", Range(0,1))`: dissolve progress
- `_EdgeWidth ("Edge Width", Range(0,0.1))`: glowing edge width
- `_EdgeColor ("Edge Color", Color)`: edge color

```hlsl
half4 frag (Varyings IN) : SV_Target
{
    half4 col = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, IN.uv) * _Color;
    half noise = SAMPLE_TEXTURE2D(_NoiseTex, sampler_NoiseTex, IN.uv).r;
    clip(noise - _DissolveAmount);
    half edge = smoothstep(_DissolveAmount, _DissolveAmount + _EdgeWidth, noise);
    col.rgb = lerp(_EdgeColor.rgb, col.rgb, edge);
    return col;
}
```

Apply the same `clip()` in the ShadowCaster pass, or the dissolved parts still cast shadows.

---

## 2. Outline (two passes)

Pass 1: extrude vertices along normals and draw back faces. Pass 2: normal rendering.

Required Properties:
- `_OutlineWidth ("Outline Width", Range(0, 0.1))`: outline thickness
- `_OutlineColor ("Outline Color", Color)`: outline color

```hlsl
// Pass "Outline" (Cull Front)
Varyings vertOutline (Attributes IN)
{
    Varyings OUT;
    float3 posOS = IN.positionOS.xyz + IN.normalOS * _OutlineWidth;
    OUT.positionHCS = TransformObjectToHClip(posOS);
    return OUT;
}
half4 fragOutline (Varyings IN) : SV_Target { return _OutlineColor; }
```

URP draws the `UniversalForward` pass plus one pass with no `LightMode` tag (treated as
`SRPDefaultUnlit`). Leave the outline pass untagged so both render. For more control over draw
order, give it a custom `LightMode` and draw it with a Render Objects renderer feature.

---

## 3. Toon / cel shading

Light steps with `step()` or `smoothstep()`, rim lighting from fresnel.

Required Properties:
- `_ShadowThreshold ("Shadow Threshold", Range(0,1))`: shadow/light threshold
- `_ShadowColor ("Shadow Color", Color)`: shadow color
- `_RimThreshold ("Rim Threshold", Range(0,1))`: rim threshold
- `_RimColor ("Rim Color", Color)`: rim color

```hlsl
// Needs #include ".../ShaderLibrary/Lighting.hlsl"
Light mainLight = GetMainLight();
half NdotL = saturate(dot(normalize(IN.normalWS), mainLight.direction));
half toon = smoothstep(_ShadowThreshold - 0.01, _ShadowThreshold + 0.01, NdotL);
half3 diffuse = lerp(_ShadowColor.rgb, col.rgb, toon);
half rim = 1.0 - saturate(dot(IN.normalWS, normalize(IN.viewDirWS)));
rim = smoothstep(_RimThreshold - 0.1, _RimThreshold + 0.1, rim);
diffuse += _RimColor.rgb * rim;
```

---

## 4. Hologram

Scanlines + fresnel + transparency + vertex jitter.

Required Properties:
- `_HoloColor ("Holo Color", Color)`: hologram color
- `_HoloAlpha ("Holo Alpha", Range(0,1))`: base transparency
- `_ScanlineCount ("Scanline Count", Float)`: number of scanlines
- `_ScanlineSpeed ("Scanline Speed", Float)`: scroll speed
- `_ScanlineDensity ("Scanline Density", Range(0,1))`: line density
- `_FresnelPower ("Fresnel Power", Range(0.1, 10))`: fresnel power
- `_JitterAmount ("Jitter Amount", Float)`: jitter amplitude
- `_JitterSpeed ("Jitter Speed", Float)`: jitter frequency

```hlsl
// Vertex: random jitter
float jitter = frac(sin(dot(IN.positionOS.xy, float2(12.9898, 78.233))) * 43758.5453);
IN.positionOS.x += jitter * _JitterAmount * step(0.99, frac(_Time.y * _JitterSpeed));

// Fragment
half scanline = frac(IN.positionWS.y * _ScanlineCount + _Time.y * _ScanlineSpeed);
scanline = step(_ScanlineDensity, scanline);
half rim = pow(1.0 - saturate(dot(IN.normalWS, IN.viewDirWS)), _FresnelPower);
half4 col = _HoloColor * (scanline * 0.5 + 0.5) * (rim + 0.3);
col.a = (_HoloAlpha + rim * 0.5) * scanline;
```

---

## 5. Force field

Fresnel + intersection with the scene (depth buffer) + animated distortion.

Required Properties:
- `_FieldColor ("Field Color", Color)`: field color
- `_FieldAlpha ("Field Alpha", Range(0,1))`: transparency
- `_FresnelPower ("Fresnel Power", Range(0.1, 10))`: fresnel power
- `_IntersectionWidth ("Intersection Width", Float)`: intersection band width
- `_PatternTex ("Pattern", 2D)`: pattern texture
- `_ScrollSpeed ("Scroll Speed", Float)`: animation speed

Prerequisite: Depth Texture enabled on the URP asset (or the camera). Transparent queue.

```hlsl
// Needs #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/DeclareDepthTexture.hlsl"
float2 screenUV = GetNormalizedScreenSpaceUV(IN.positionHCS);
float sceneDepth = LinearEyeDepth(SampleSceneDepth(screenUV), _ZBufferParams);
half intersection = 1.0 - saturate((sceneDepth - IN.positionHCS.w) / _IntersectionWidth);
half rim = pow(1.0 - saturate(dot(IN.normalWS, IN.viewDirWS)), _FresnelPower);
half pattern = SAMPLE_TEXTURE2D(_PatternTex, sampler_PatternTex, IN.uv + _Time.y * _ScrollSpeed).r;
half4 col = _FieldColor * (rim + intersection) * pattern;
col.a = saturate(rim + intersection) * _FieldAlpha;
```

---

## 6. Water surface

Vertex displacement (sum of sines) + scrolling normal maps + depth-based transparency.

Required Properties:
- `_WaveFreq ("Wave Frequency", Float)`: wave frequency
- `_WaveSpeed ("Wave Speed", Float)`: wave speed
- `_WaveAmp ("Wave Amplitude", Float)`: wave amplitude
- `_NormalMap ("Normal Map", 2D)`: surface normal map
- `_ScrollDir1 ("Scroll Dir 1", Vector)`: scroll direction 1
- `_ScrollDir2 ("Scroll Dir 2", Vector)`: scroll direction 2
- `_ScrollSpeed ("Scroll Speed", Float)`: scroll speed

```hlsl
// Vertex displacement
float wave = sin(IN.positionOS.x * _WaveFreq + _Time.y * _WaveSpeed) * _WaveAmp;
wave += sin(IN.positionOS.z * _WaveFreq * 0.7 + _Time.y * _WaveSpeed * 1.3) * _WaveAmp * 0.5;
IN.positionOS.y += wave;

// Fragment: two scrolling normal maps
float2 uv1 = IN.uv + _Time.y * _ScrollDir1.xy * _ScrollSpeed;
float2 uv2 = IN.uv + _Time.y * _ScrollDir2.xy * _ScrollSpeed * 0.8;
half3 n1 = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv1));
half3 n2 = UnpackNormal(SAMPLE_TEXTURE2D(_NormalMap, sampler_NormalMap, uv2));
half3 normal = normalize(n1 + n2);
```

---

## 7. Triplanar mapping

Project UVs on 3 world-space axes, blended by the normal.

Required Properties:
- `_TriplanarTex ("Triplanar Texture", 2D)`: texture to project
- `_TriplanarSharpness ("Sharpness", Range(1, 20))`: blend sharpness

```hlsl
half4 triplanar(TEXTURE2D_PARAM(tex, samp), float3 posWS, float3 normalWS, float sharpness)
{
    half3 blend = pow(abs(normalWS), sharpness);
    blend /= (blend.x + blend.y + blend.z);
    half4 cx = SAMPLE_TEXTURE2D(tex, samp, posWS.yz);
    half4 cy = SAMPLE_TEXTURE2D(tex, samp, posWS.xz);
    half4 cz = SAMPLE_TEXTURE2D(tex, samp, posWS.xy);
    return cx * blend.x + cy * blend.y + cz * blend.z;
}
```

---

## 8. Vertex displacement

Noise-driven deformation for terrain, cloth, explosions.

Required Properties:
- `_NoiseScale ("Noise Scale", Float)`: noise scale
- `_AnimSpeed ("Anim Speed", Float)`: animation speed
- `_DisplaceAmount ("Displace Amount", Float)`: displacement amplitude

```hlsl
float3 displaced = IN.positionOS.xyz;
float n = noise(displaced.xz * _NoiseScale + _Time.y * _AnimSpeed);
displaced += IN.normalOS * n * _DisplaceAmount;
OUT.positionHCS = TransformObjectToHClip(displaced);
```

Apply the same displacement in the ShadowCaster pass so shadows match the deformed mesh.
