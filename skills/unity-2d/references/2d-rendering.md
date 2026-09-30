# 2D Rendering, Lighting and Sorting

2D rendering in Unity 6 with URP: Light 2D, Shadow Caster 2D, sorting layers, Sprite Library swaps,
3D meshes in the 2D Renderer, and level rendering cost.

Covered by Unity's official skills instead:
- Sprite Atlases and sprite batching: `manage-sprite-atlas`
- Pixel art import settings and the Pixel Perfect Camera: `2d-pixel-perfect`
- Slicing sprite sheets and setting pivots: `sprite-editor`

---

## 1. Light 2D

URP 2D lighting uses the **Light 2D** component. The manual lists four types.

| Type | Use | Key properties |
|------|-----|----------------|
| **Global** | Ambient light for the whole scene, no attenuation | Intensity, Color |
| **Freeform** | Custom editable polygon of light | Falloff, Intensity, Color |
| **Sprite** | Light shaped like a sprite (cookie) | Sprite, Intensity |
| **Spot** | Light from a point, optionally limited to a cone | Inner/Outer Angle, Inner/Outer Radius, Falloff |

### Configuration

1. **2D Renderer Data:** configure **Light Blend Styles** here (for example multiply and additive).
2. **Target Sorting Layers:** each Light 2D can light only chosen sorting layers. Use this to light
   characters but not the background, or the reverse.

### Example lighting setup

```
Night scene:
- Global light: Intensity 0.15, dark blue
- Spot light on the player (full 360 degrees): Intensity 1.0, Outer Radius 5, warm yellow
- Freeform lights on windows: Intensity 0.8, orange
- Sprite lights on torches: flame texture, Intensity 1.2
```

### Performance

- Limit how many lights are active at once, especially on mobile.
- Disable lights that are off screen (`light2D.enabled = false`).
- Prefer Spot lights to Freeform lights where either works; they are cheaper.

---

## 2. Shadow Caster 2D

Objects that cast 2D shadows need a **Shadow Caster 2D** component.

### Setup

1. Add **Shadow Caster 2D** to the GameObject.
2. Choose its **Casting Source**: take the shape from the renderer, or draw it with the Shape Editor.
3. On each Light 2D that should cast shadows, turn shadows on and set their strength and softness
   (`Light2D.shadowsEnabled`, `shadowIntensity`, `shadowSoftness`). Softer shadows cost more.

### Composite Shadow Caster 2D

To merge shadows from a group of objects:
1. Create an empty parent GameObject and add **Composite Shadow Caster 2D**.
2. Make the objects its children. Children that have Shadow Caster 2D components cast one merged
   shadow instead of overlapping ones.

---

## 3. Sorting layers

Draw order in 2D comes from **Sorting Layers** and **Order in Layer**.

### Recommended order

```
Sorting layers (furthest to nearest):
  0. Background   -- skies, parallax backgrounds
  1. Level        -- ground, walls, scenery
  2. Props        -- interactive objects, decorations
  3. Characters   -- player, enemies, NPCs
  4. Foreground   -- things in front of characters (foliage, fog)
  5. VFX          -- particles, visual effects
  6. UI           -- in-world UI
```

### Order in Layer

Within one sorting layer, **Order in Layer** (an integer) decides the order. Lower is behind, higher
is in front.

### Sorting Group

For an object made of several SpriteRenderers (a character with a weapon and a hat):
1. Add a **Sorting Group** to the parent.
2. The children sort among themselves, and the whole group sorts as one unit in its sorting layer.
3. This stops parts of one character interleaving with other objects.

### Y-sorting

For top-down games where objects overlap based on their Y position:
- In the URP 2D Renderer Data, set **Transparency Sort Mode** = Custom Axis and **Transparency Sort
  Axis** = (0, 1, 0).
- Alternative: a script that sets `SpriteRenderer.sortingOrder` from `transform.position.y`.

---

## 4. Sprite Library and sprite swap

The **Sprite Library** (2D Animation package) swaps sprites at runtime without changing animations.

### Setup

1. Create a **Sprite Library Asset** (Create > 2D > Sprite Library Asset).
2. Define **Categories** (for example `Head`, `Body`, `Weapon`).
3. In each category, add **Labels** (for example Head > `default`, `angry`, `happy`).
4. Assign a sprite to each label.

### Use

1. Add **Sprite Library** to the character's root GameObject and assign the asset.
2. Add a **Sprite Resolver** to each body part. It picks which category and label to show.

### Runtime swap

```csharp
using UnityEngine;
using UnityEngine.U2D.Animation;

public class SkinSwapper : MonoBehaviour
{
    [SerializeField] private SpriteLibraryAsset skinA;
    [SerializeField] private SpriteLibraryAsset skinB;
    private SpriteLibrary library;

    private void Awake() => library = GetComponent<SpriteLibrary>();

    public void SwapSkin(bool useB)
    {
        library.spriteLibraryAsset = useB ? skinB : skinA;
    }
}
```

Uses: armor and equipment changes, facial expressions, color variants, unlockable skins.

---

## 5. 3D meshes in the 2D Renderer (Unity 6.3+)

From Unity 6.3, the 2D Renderer draws **Mesh Renderer** and **Skinned Mesh Renderer** objects in the
same scene as sprites. With compatible shaders, those meshes:
- receive light from 2D lights
- interact with Sprite Masks when their **2D > Mask Interaction** property is set
- sort with sprites when **Sort 3D As 2D** is enabled on a Sorting Group

Uses: 3D scenery in a 2D game (parallax with real depth), 3D characters in a 2D world, 3D props lit
by 2D lights.

---

## 6. Level rendering and collision cost

### Tilemap Renderer

Keep the **Tilemap Renderer** in **Chunk** mode (the default). It groups tiles into blocks for
rendering and culls chunks that are off screen.

### Merged collision

Always merge level collision:
1. Add a **Tilemap Collider 2D** (or other colliders) to the collision layer.
2. Set its **Composite Operation** to **Merge**.
3. Add a **Composite Collider 2D** and a **Rigidbody2D** with Body Type = Static.
4. Geometry Type = **Polygons**.

Without a composite, every tile has its own collider, which is very slow.

### Separate layers by purpose

- **Visual only** (decoration): no collider
- **Collision**: collider + composite
- **Triggers** (damage zones, checkpoints): colliders set as triggers

This avoids computing collisions for purely visual tiles.
