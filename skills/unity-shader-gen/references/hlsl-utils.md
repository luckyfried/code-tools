# HLSL utilities

Helper functions and optimization advice for `unity-shader-gen`.

## HLSL helpers

Include in the shader as needed:

```hlsl
float2 rotateUV(float2 uv, float angle)
{
    float s = sin(angle);
    float c = cos(angle);
    uv -= 0.5;
    uv = float2(uv.x * c - uv.y * s, uv.x * s + uv.y * c);
    uv += 0.5;
    return uv;
}

float noise(float2 p)
{
    return frac(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
}

half fresnel(float3 normal, float3 viewDir, half power)
{
    return pow(1.0 - saturate(dot(normal, viewDir)), power);
}

float remap(float value, float from1, float to1, float from2, float to2)
{
    return from2 + (value - from1) * (to2 - from2) / (to1 - from1);
}
```

## Debugging helpers

Visualize intermediate data:

```hlsl
// Visualize normals
half4 debugNormals(float3 normalWS)
{
    return half4(normalWS * 0.5 + 0.5, 1.0);
}

// Visualize UVs
half4 debugUVs(float2 uv)
{
    return half4(uv.x, uv.y, 0, 1);
}
```

Temporarily replace the fragment shader's `return` with `return debugNormals(IN.normalWS);` to
diagnose normal or UV problems.

## Mobile optimization

- Use `half` instead of `float` for colors, UVs, normals
- At most 4 texture samples per pass
- Avoid dependent texture reads (compute UVs in the vertex shader)
- Use `#pragma shader_feature` for material toggles instead of `#pragma multi_compile` (fewer
  variants are built); keep `multi_compile` for keywords set at runtime
- Avoid dynamic branching (`if`): use `step()`, `lerp()`, `saturate()` instead
- Test with at least `#pragma target 3.0`
- Use `Tags { "Queue"="Geometry" }` unless transparency is required
