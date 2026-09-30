# Landscape sizing reference (UE 5.8)

Source: Epic's Landscape Technical Guide.

## How the numbers relate

- A **component** is the unit of rendering, visibility, and collision. All components are square and the
  same size. Each one's height data is one texture.
- A component has 1 or 4 (2x2) **sections**. A section is the unit of LOD, and each section is a draw call.
- A section's vertex count per side is a power of two, 256 at most. So quads per section is 2^n - 1
  (7, 15, 31, 63, 127, 255).
- Quads per component = quads per section (1 section) or 2 x quads per section (2x2 sections).
- Overall size in vertices = (components_X * quads_per_component + 1) x (components_Y * quads_per_component + 1).
  Landscapes do not have to be square.
- Neighboring components duplicate their shared edge row of vertices.
- Epic recommends at most 1024 components (32x32) even for the largest landscapes.

Examples:
- 1 section of 64x64 vertices = 63x63 quads per component. With 10x10 components that is 630 quads, so
  631x631 vertices.
- 2x2 sections of 64x64 vertices = 126x126 quads per component. With 32x32 components that is 4032 quads,
  so 4033x4033 vertices.

## Recommended sizes

These maximize area while minimizing component count.

| Overall size (vertices) | Quads / section | Sections / component | Component size (quads) | Total components |
|---|---|---|---|---|
| 8129 x 8129 | 127 | 4 (2x2) | 254x254 | 1024 (32x32) |
| 4033 x 4033 | 63 | 4 (2x2) | 126x126 | 1024 (32x32) |
| 2017 x 2017 | 63 | 4 (2x2) | 126x126 | 256 (16x16) |
| 1009 x 1009 | 63 | 4 (2x2) | 126x126 | 64 (8x8) |
| 1009 x 1009 | 63 | 1 | 63x63 | 256 (16x16) |
| 505 x 505 | 63 | 4 (2x2) | 126x126 | 16 (4x4) |
| 505 x 505 | 63 | 1 | 63x63 | 64 (8x8) |
| 253 x 253 | 63 | 4 (2x2) | 126x126 | 4 (2x2) |
| 253 x 253 | 63 | 1 | 63x63 | 16 (4x4) |
| 127 x 127 | 63 | 4 (2x2) | 126x126 | 1 |
| 127 x 127 | 63 | 1 | 63x63 | 4 (2x2) |

When two rows give the same size, the 2x2-section row uses fewer components, which costs less CPU.

## World size

The X/Y scale is the spacing between vertices in cm. At the default scale of 100 (1 m per quad), a
4033x4033 landscape covers 4032 m x 4032 m, about 4 km on a side. World size = quads per axis * X/Y scale.

## Z scale

- Stored heights run from -256 to 255.992 units at 16-bit precision, multiplied by Z scale (in cm).
- Z scale 1 covers about +/-256 cm. Z scale 100 covers +/-256 m.
- `Z scale = total height range (m) * 100 * 0.001953125`
- The range is centered on the landscape actor's Z. Move the actor to put sea level where you want it.

## Memory note

- Landscape vertex data is 4 bytes per vertex, compared with 24 to 28 bytes for a Static Mesh. That is
  6 to 7 times less memory at the same density.
- Height and weight data are textures that stream by mip.
