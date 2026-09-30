---
name: unity-2d
description: Use when building 2D gameplay in a Unity 6 project - platformer or top-down character controllers on Rigidbody2D, 2D physics and colliders, coyote time and jump buffering, parallax backgrounds, Cinemachine 2D camera follow and level bounds, URP 2D lighting (Light 2D, Shadow Caster 2D), sorting layers and Y-sorting, Sprite Library skin swaps, and mixing 3D meshes into the 2D Renderer. Triggers include "2D game", "2D platformer", "top-down 2D", "Rigidbody2D", "2D physics", "2D controller", "coyote time", "jump buffer", "parallax", "Light2D", "2D lights", "shadow caster 2D", "sorting layer", "Y-sort", "Cinemachine 2D", "Confiner2D", "sprite swap". For Tilemap palettes and Rule Tiles, Sprite Atlases, pixel-perfect cameras, and sprite slicing, use Unity's official skills instead.
---

Adapted from JulianKerignard/Unity-Skills (MIT); see LICENSE.

# Unity 2D

Guides 2D game development in Unity 6: 2D physics (Rigidbody2D, Collider2D), character controllers
driven by the Input System, 2D lighting in URP (Light 2D, Shadow Caster 2D), Cinemachine camera
setup, sorting, and gameplay patterns (platformer, top-down, puzzle). Also covers parallax scrolling.

These topics belong to Unity's official skills. Use them rather than this one:

| Topic | Skill |
|-------|-------|
| Tile palettes | `tilemap-palette-create` |
| Rule Tiles | `tilemap-ruletile-createempty`, `tilemap-ruletile-createfromsegment` |
| Sprite Atlases, draw-call batching of sprites | `manage-sprite-atlas` |
| Pixel-perfect camera and pixel art setup | `2d-pixel-perfect` |
| Slicing sprite sheets, pivots | `sprite-editor` |

Write every API against Unity 6; see `unity-current-api` for the rules and old-to-new mappings.

## Prerequisites

- Unity 6.0+ with **URP** using the **2D Renderer**
- **Input System** package (`com.unity.inputsystem`), with Active Input Handling set to Input System
  or Both. The controllers in `references/` read the project-wide actions (Project Settings > Input
  System Package), which include `Move` and `Jump` by default.
- **Cinemachine** package for the 2D camera
- **2D Animation** package if you need Sprite Library swaps

## Quick start

1. **Set up URP 2D:** create a **2D Renderer Data** asset, assign it as the default renderer on the
   URP Asset, and assign that URP Asset in the project's Graphics settings.
2. **Add physics:** player gets a Dynamic Rigidbody2D and a capsule or box collider. Level geometry
   gets static colliders (see Step 2).
3. **Wire input:** confirm the project-wide actions have `Move` (Vector2) and `Jump` (Button), or
   point the controller at your own actions.
4. **Set up the camera:** add a CinemachineCamera with CinemachinePositionComposer, Follow = player.
   Add CinemachineConfiner2D with a PolygonCollider2D or CompositeCollider2D for the level bounds.

## Decision tree

```
What kind of 2D game?
|
+-- Platformer?
|   +-- Classic ------------> Rigidbody2D + coyote time + jump buffer
|   |                         (references/2d-patterns.md)
|   +-- Metroidvania -------> same + ability unlocks
|                             + one Cinemachine confiner per zone (references/2d-advanced.md)
|
+-- Top-down?
|   +-- Action -------------> Rigidbody2D, 8 directions, Gravity Scale = 0
|   +-- RPG / exploration --> same + layered level art + dialogue system
|
+-- Puzzle / match?
|   +-- Grid-based ---------> Grid or custom grid, no physics
|
+-- Visual novel / UI-heavy?
|   +-- --------------------> UI Toolkit (ui-uitk), no 2D physics
|
+-- Need lights / shadows?
    +-- --------------------> URP 2D Renderer + Light 2D
                              (references/2d-rendering.md)
```

## Step by step

### Step 1: URP 2D Renderer

Create a **2D Renderer Data** asset (Create > Rendering > URP 2D Renderer). Assign it as the default
renderer in the URP Asset. Check that the camera uses that renderer in its Inspector.

### Step 2: Level collision

Keep collision geometry separate from decoration. On the collision layer, set each collider's
**Composite Operation** to **Merge** and add a **Composite Collider 2D** (Geometry Type = Polygons)
with a **Static** Rigidbody2D, so the level is one merged shape instead of one collider per piece.
Organise art on sorting layers (Background < Level < Characters < Foreground). For tile-based levels,
building the tiles and palettes is covered by the official tilemap skills.

### Step 3: 2D physics

On the player: Rigidbody2D (Dynamic, Freeze Rotation Z, Interpolate), plus a CapsuleCollider2D or
BoxCollider2D. Use Physics Material 2D for friction and bounce.

### Step 4: Cinemachine camera

CinemachineCamera with **CinemachinePositionComposer** (dead zone, lookahead). Add
**CinemachineConfiner2D** bound to a PolygonCollider2D or CompositeCollider2D that marks the level
bounds. Details and a zone-switching script are in `references/2d-advanced.md`.

### Step 5: Controller code

Copy the platformer or top-down controller from `references/2d-patterns.md`. They read input in
`Update` and move the body in `FixedUpdate`.

## Rules

- **Always** use `Rigidbody2D.linearVelocity` (also `linearVelocityX` / `linearVelocityY`),
  `linearDamping`, and `angularDamping`. The old `velocity`, `drag`, and `angularDrag` are gone in
  Unity 6.
- **Always** read input with the Input System (`InputAction`, `PlayerInput`, or a generated input
  class). Do not write `Input.GetAxis`, `Input.GetButton`, or `Input.GetKey*`.
- **Always** read input in `Update` and apply physics in `FixedUpdate`.
- **Always** merge level collision with a Composite Collider 2D.
- **Always** organise sorting layers (Background < Level < Characters < Foreground < UI).
- **Never** put a Dynamic Rigidbody2D on level geometry; use Static or Kinematic.
- **Never** mix 3D Rigidbody and Rigidbody2D on one GameObject.
- **Never** flip a sprite with negative scale; use `SpriteRenderer.flipX`.
- For shipped sprites, pack them into atlases; see `manage-sprite-atlas`.

## Related skills

- `unity-current-api`: current Unity 6 APIs and what replaced the old ones
- `unity-animation`: Animator, sprite animation, Timeline
- `unity-shader-gen`: custom 2D shaders (outline, dissolve, water)
- `unity-perf-audit`: draw calls, batching, 2D performance
- `unity-profiling-workflow`: measuring frame time before optimising
- `unity-addressables`: streaming large levels in sections

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Sprite invisible | Wrong sorting layer or order | Check Sorting Layer and Order in Layer on the SpriteRenderer |
| Player falls through level collision | No composite, or pieces not merged | Set Composite Operation = Merge on the colliders, add Composite Collider 2D + Static Rigidbody2D |
| Player sticks to walls | Friction against side tiles | Physics Material 2D with Friction = 0 on the player |
| 2D light has no effect | Not using the 2D Renderer | Check the URP Asset uses a 2D Renderer Data |
| Camera stutters | Rigidbody moved outside `FixedUpdate`, no interpolation | Interpolation = Interpolate on the Rigidbody2D |
| Controller never moves | Actions not found or not enabled | Check the action names exist in the project-wide actions and Active Input Handling includes the Input System |
| High draw calls | Sprites not batched | Pack into atlases (`manage-sprite-atlas`), check the Frame Debugger |
