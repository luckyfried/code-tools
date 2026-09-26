# Netcode for GameObjects: advanced patterns

Pooling, basic client prediction, interpolation, bandwidth, and local testing. Input uses the
Input System package's project-wide actions.

## 1. Network object pooling

Server side: take an instance from the pool, spawn it, and despawn it with `Despawn(false)` so the
GameObject is kept.

```csharp
using System.Collections.Generic;
using Unity.Netcode;
using UnityEngine;

public class NetworkObjectPool : MonoBehaviour
{
    public static NetworkObjectPool Instance { get; private set; }

    [SerializeField] private NetworkObject prefab;
    [SerializeField] private int initialSize = 10;

    private readonly Queue<NetworkObject> pool = new();

    private void Awake() => Instance = this;

    public void InitializePool()
    {
        for (int i = 0; i < initialSize; i++)
        {
            var netObj = Instantiate(prefab);
            netObj.gameObject.SetActive(false);
            pool.Enqueue(netObj);
        }
    }

    // Server: get an instance, then call Spawn() on it.
    public NetworkObject Get(Vector3 position, Quaternion rotation)
    {
        if (pool.Count > 0)
        {
            var netObj = pool.Dequeue();
            netObj.transform.SetPositionAndRotation(position, rotation);
            netObj.gameObject.SetActive(true);
            return netObj;
        }
        return Instantiate(prefab, position, rotation);
    }

    // Server: despawn without destroying, and keep it for reuse.
    public void Return(NetworkObject netObj)
    {
        netObj.Despawn(false);
        netObj.gameObject.SetActive(false);
        pool.Enqueue(netObj);
    }
}
```

This pools on the server only; clients still instantiate and destroy their copies. To pool on
clients too, implement `INetworkPrefabInstanceHandler` (`Instantiate(ulong ownerClientId, Vector3
position, Quaternion rotation)` and `Destroy(NetworkObject networkObject)`) and register it with
`NetworkManager.PrefabHandler.AddHandler(prefab, handler)`.

## 2. Basic client prediction

### Move locally, reconcile with the server

```csharp
using Unity.Netcode;
using UnityEngine;
using UnityEngine.InputSystem;

public class PredictedMovement : NetworkBehaviour
{
    [SerializeField] private float moveSpeed = 7f;

    // The server's authoritative position
    private NetworkVariable<Vector3> serverPosition = new(
        default, NetworkVariableReadPermission.Everyone,
        NetworkVariableWritePermission.Server);

    private InputAction move;

    public override void OnNetworkSpawn()
    {
        if (IsOwner) move = InputSystem.actions.FindAction("Move");
        serverPosition.OnValueChanged += OnServerPositionChanged;
    }

    public override void OnNetworkDespawn()
    {
        serverPosition.OnValueChanged -= OnServerPositionChanged;
    }

    private void Update()
    {
        if (!IsOwner) return;

        Vector2 m = move.ReadValue<Vector2>();
        var input = new Vector3(m.x, 0, m.y);
        if (input.sqrMagnitude < 0.01f) return;
        input = input.normalized;

        // Predict locally so the player sees the move at once
        transform.position += input * (moveSpeed * Time.deltaTime);

        // Send the input to the server for the authoritative move
        MoveRpc(input, Time.deltaTime);
    }

    [Rpc(SendTo.Server, InvokePermission = RpcInvokePermission.Owner)]
    private void MoveRpc(Vector3 input, float deltaTime)
    {
        // Clamp deltaTime and input magnitude here in real code: never trust the client
        var newPos = transform.position + input * (moveSpeed * deltaTime);
        transform.position = newPos;
        serverPosition.Value = newPos;
    }

    private void OnServerPositionChanged(Vector3 oldPos, Vector3 newPos)
    {
        if (IsOwner)
        {
            // Reconcile: correct only when the drift is large
            if (Vector3.Distance(transform.position, newPos) > 0.5f)
                transform.position = Vector3.Lerp(transform.position, newPos, 0.5f);
        }
        else
        {
            transform.position = newPos;
        }
    }
}
```

On NGO earlier than 2.7, write `RequireOwnership = true` instead of `InvokePermission`.

### Interpolation for non-owners

```csharp
public class NetworkTransformInterpolation : NetworkBehaviour
{
    private NetworkVariable<Vector3> netPosition = new(
        default, NetworkVariableReadPermission.Everyone,
        NetworkVariableWritePermission.Server);

    private NetworkVariable<Quaternion> netRotation = new(
        default, NetworkVariableReadPermission.Everyone,
        NetworkVariableWritePermission.Server);

    [SerializeField] private float interpolationSpeed = 12f;

    private void Update()
    {
        if (IsOwner) return;

        transform.position = Vector3.Lerp(
            transform.position, netPosition.Value,
            interpolationSpeed * Time.deltaTime);
        transform.rotation = Quaternion.Slerp(
            transform.rotation, netRotation.Value,
            interpolationSpeed * Time.deltaTime);
    }
}
```

The built-in `NetworkTransform` already interpolates. Write your own only when you need more
control.

## 3. Bandwidth

### Tick rate

```csharp
NetworkManager.Singleton.NetworkConfig.TickRate = 30; // updates per second
// Lower for slow-paced games, higher for competitive shooters
```

### Send input at a fixed interval, not every frame

```csharp
private InputAction move;         // found once in OnNetworkSpawn
private float sendInterval = 0.05f; // 20 times per second
private float sendTimer;
private Vector3 accumulatedInput;

private void Update()
{
    if (!IsOwner) return;

    Vector2 m = move.ReadValue<Vector2>();
    accumulatedInput += new Vector3(m.x, 0, m.y);
    sendTimer += Time.deltaTime;

    if (sendTimer >= sendInterval)
    {
        SendInputRpc(accumulatedInput.normalized);
        accumulatedInput = Vector3.zero;
        sendTimer = 0f;
    }
}

[Rpc(SendTo.Server, InvokePermission = RpcInvokePermission.Owner)]
private void SendInputRpc(Vector3 input)
{
    ApplyMovement(input);
}
```

### Smaller types

```csharp
private NetworkVariable<byte> healthByte = new(); // 0-255 instead of int
private NetworkVariable<short> posX = new();      // position in centimetres

// Yaw and pitch as shorts instead of a full quaternion
public struct CompressedRotation : INetworkSerializable
{
    public short Yaw;   // -180..180
    public short Pitch;

    public void NetworkSerialize<T>(BufferSerializer<T> serializer) where T : IReaderWriter
    {
        serializer.SerializeValue(ref Yaw);
        serializer.SerializeValue(ref Pitch);
    }

    public static CompressedRotation FromQuaternion(Quaternion q)
    {
        var euler = q.eulerAngles;
        return new CompressedRotation
        {
            Yaw = (short)(euler.y > 180 ? euler.y - 360 : euler.y),
            Pitch = (short)(euler.x > 180 ? euler.x - 360 : euler.x)
        };
    }

    public Quaternion ToQuaternion() => Quaternion.Euler(Pitch, Yaw, 0);
}
```

### Avoid needless RPCs

```csharp
// Bad: an RPC every frame
private void Update()
{
    if (IsOwner) UpdatePositionRpc(transform.position); // 60 RPCs per second
}

// Better: NetworkTransform, or send only past a threshold
private Vector3 lastSentPosition;
private void Update()
{
    if (!IsOwner) return;
    if (Vector3.Distance(transform.position, lastSentPosition) > 0.01f)
    {
        UpdatePositionRpc(transform.position);
        lastSentPosition = transform.position;
    }
}
```

## 4. Testing locally with several instances

- **Multiplayer Play Mode** (`com.unity.multiplayer.playmode`): runs extra virtual players inside
  the Editor. The simplest option.
- **Build plus Editor**: build a standalone player, run it as a client, and run the Editor as host.
- **Multiplayer Tools** (`com.unity.multiplayer.tools`): network profiler, runtime network stats
  overlay, and a network simulator for adding latency and packet loss.
