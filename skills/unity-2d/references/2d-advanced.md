# Advanced 2D: Procedural Levels and Camera

Procedural level generation from code and 2D camera setup with Cinemachine in Unity 6.

---

## 1. Procedural level generation

Simple Perlin-noise terrain (hills and caves) painted onto a Tilemap from code with
`Tilemap.SetTile`. Creating the tile assets themselves, including auto-connecting Rule Tiles, is
covered by the official `tilemap-ruletile-createempty` and `tilemap-ruletile-createfromsegment`
skills.

```csharp
using UnityEngine;
using UnityEngine.Tilemaps;

public class ProceduralTilemapGenerator : MonoBehaviour
{
    [Header("Tilemap")]
    [SerializeField] private Tilemap tilemap;
    [SerializeField] private TileBase groundTile;
    [SerializeField] private TileBase surfaceTile;

    [Header("Generation")]
    [SerializeField] private int width = 100;
    [SerializeField] private int height = 50;
    [SerializeField] private float noiseScale = 0.08f;
    [SerializeField] private float heightMultiplier = 15f;
    [SerializeField] private int baseHeight = 10;

    [Header("Caves")]
    [SerializeField] private bool generateCaves = true;
    [SerializeField] private float caveNoiseScale = 0.12f;
    [SerializeField] private float caveThreshold = 0.45f;

    [SerializeField] private int seed;

    public void Generate()
    {
        tilemap.ClearAllTiles();
        if (seed == 0) seed = Random.Range(0, 100000);

        for (int x = 0; x < width; x++)
        {
            // Terrain height from Perlin noise
            float noiseValue = Mathf.PerlinNoise((x + seed) * noiseScale, seed * noiseScale);
            int terrainHeight = baseHeight + Mathf.RoundToInt(noiseValue * heightMultiplier);

            for (int y = 0; y < Mathf.Min(terrainHeight, height); y++)
            {
                // Caves: a second noise layer
                if (generateCaves && y < terrainHeight - 1)
                {
                    float caveNoise = Mathf.PerlinNoise(
                        (x + seed) * caveNoiseScale, (y + seed) * caveNoiseScale);
                    if (caveNoise < caveThreshold) continue; // empty = cave
                }

                var tilePos = new Vector3Int(x - width / 2, y, 0);
                TileBase tile = (y == terrainHeight - 1) ? surfaceTile : groundTile;
                tilemap.SetTile(tilePos, tile);
            }
        }

        // Refresh so tiles that depend on neighbours update
        tilemap.RefreshAllTiles();
    }

#if UNITY_EDITOR
    [ContextMenu("Regenerate terrain")]
    private void RegenerateInEditor()
    {
        seed = 0;
        Generate();
    }
#endif
}
```

**Tips:**
- Add collision after generation: a Tilemap Collider 2D with Composite Operation = Merge, plus a
  Composite Collider 2D and a Static Rigidbody2D.
- For large maps, generate in chunks and use `Tilemap.SetTilesBlock`, which is faster than calling
  `SetTile` in a loop.
- For very large levels, load sections with Addressables (`unity-addressables`) and disable renderers
  of sections that are off screen.

---

## 2. 2D camera (Cinemachine)

A 2D camera that follows the player with a dead zone and stays inside the level bounds.

```csharp
using UnityEngine;

/// <summary>
/// Marks the level bounds. Attach to a GameObject with a PolygonCollider2D.
/// CinemachineConfiner2D references this collider.
/// </summary>
public class CameraBoundsSetup : MonoBehaviour
{
    [Tooltip("Draw the bounds in the Scene view")]
    [SerializeField] private bool showGizmos = true;

    private void Awake()
    {
        // The bounds must not collide with anything
        var col = GetComponent<Collider2D>();
        if (col != null) col.isTrigger = true;
    }

    private void OnDrawGizmos()
    {
        if (!showGizmos) return;
        var col = GetComponent<PolygonCollider2D>();
        if (col == null) return;

        Gizmos.color = new Color(0f, 1f, 0.5f, 0.3f);
        for (int i = 0; i < col.points.Length; i++)
        {
            Vector2 current = (Vector2)transform.position + col.points[i];
            Vector2 next = (Vector2)transform.position + col.points[(i + 1) % col.points.Length];
            Gizmos.DrawLine(current, next);
        }
    }
}
```

### Cinemachine setup in the Editor

1. **CinemachineCamera** on a GameObject:
   - Follow = the player's Transform
   - Position Control = **CinemachinePositionComposer**
     - Dead Zone width/height = 0.1 (a small area where the camera does not move)
     - Lookahead Time = 0.2 (anticipates movement)
     - Damping = 0.5 (smooths the follow)

2. **CinemachineConfiner2D** extension:
   - Bounding Shape 2D = the level-bounds PolygonCollider2D
   - Damping = 0.3

3. For a pixel-perfect camera with Cinemachine, see the official `2d-pixel-perfect` skill.

### Multiple camera zones

For a Metroidvania with different camera zones:
- Give each zone its own PolygonCollider2D bounds
- Use trigger zones to switch the confiner's bounding shape
- Smooth the transition with the confiner's Damping (0.3 to 0.5 s)

```csharp
using Unity.Cinemachine;
using UnityEngine;

public class CameraZoneTrigger : MonoBehaviour
{
    [SerializeField] private Collider2D zoneBounds;
    private CinemachineConfiner2D confiner;

    private void Awake()
    {
        confiner = FindAnyObjectByType<CinemachineConfiner2D>();
    }

    private void OnTriggerEnter2D(Collider2D other)
    {
        if (!other.CompareTag("Player")) return;
        confiner.BoundingShape2D = zoneBounds;
        confiner.InvalidateBoundingShapeCache();
    }
}
```
