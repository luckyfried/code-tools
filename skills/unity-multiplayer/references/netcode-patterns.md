# Netcode for GameObjects: reference patterns

Examples use NGO 2.x `[Rpc]`. On NGO earlier than 2.7, replace
`InvokePermission = RpcInvokePermission.Owner` with `RequireOwnership = true`, and drop
`InvokePermission = RpcInvokePermission.Everyone` (that is already the default).

## 1. NetworkVariable

### Supported types

`NetworkVariable<T>` works without extra code for:

- **C# primitives**: `bool`, `byte`, `sbyte`, `char`, `decimal`, `double`, `float`, `int`, `uint`,
  `long`, `ulong`, `short`, `ushort`.
- **Unity structs**: `Vector2`, `Vector3`, `Vector2Int`, `Vector3Int`, `Vector4`, `Quaternion`,
  `Color`, `Color32`, `Ray`, `Ray2D`.
- **Enums.**
- **Fixed strings**: `FixedString32Bytes`, `FixedString64Bytes`, `FixedString128Bytes`,
  `FixedString512Bytes`, `FixedString4096Bytes`. Not `string`.
- Types that implement `INetworkSerializable`, and unmanaged structs that implement
  `INetworkSerializeByMemcpy`.

A collection inside a `NetworkVariable` is only detected as changed after you call
`CheckDirtyState()` on the variable. Call it once after a batch of changes.

### Declaration and permissions

```csharp
// Read: everyone | Write: server (the default)
private NetworkVariable<int> health = new(100);

// Read: everyone | Write: owner
private NetworkVariable<Vector3> aimDirection = new(
    Vector3.forward,
    NetworkVariableReadPermission.Everyone,
    NetworkVariableWritePermission.Owner);

// Read: owner only | Write: server
private NetworkVariable<int> secretData = new(0,
    NetworkVariableReadPermission.Owner,
    NetworkVariableWritePermission.Server);
```

Set a NetworkVariable's value only when declaring it, in `Awake`, or once its NetworkObject is
spawned.

### Change callback

```csharp
public override void OnNetworkSpawn()
{
    health.OnValueChanged += OnHealthChanged;
    // The initial value is already synced here; apply it yourself.
    UpdateHealthUI(health.Value);
}

public override void OnNetworkDespawn()
{
    health.OnValueChanged -= OnHealthChanged;
}

private void OnHealthChanged(int previousValue, int newValue)
{
    UpdateHealthUI(newValue);
    if (newValue <= 0) PlayDeathAnimation();
}
```

### Custom serialization with INetworkSerializable

```csharp
public struct PlayerStats : INetworkSerializable
{
    public int Health;
    public int Armor;
    public float Speed;
    public FixedString32Bytes DisplayName;

    public void NetworkSerialize<T>(BufferSerializer<T> serializer) where T : IReaderWriter
    {
        serializer.SerializeValue(ref Health);
        serializer.SerializeValue(ref Armor);
        serializer.SerializeValue(ref Speed);
        serializer.SerializeValue(ref DisplayName);
    }
}

private NetworkVariable<PlayerStats> stats = new();

[Rpc(SendTo.Server, InvokePermission = RpcInvokePermission.Owner)]
private void UpdateStatsRpc(PlayerStats newStats)
{
    stats.Value = newStats; // validate before accepting in real code
}
```

### NetworkList for dynamic collections

```csharp
private NetworkList<int> inventory;

private void Awake()
{
    // NetworkList must be created in Awake, not in the field initializer
    // (initializing at declaration leaks memory).
    inventory = new NetworkList<int>();
}

public override void OnNetworkSpawn()
{
    inventory.OnListChanged += OnInventoryChanged;
}

public override void OnNetworkDespawn()
{
    inventory.OnListChanged -= OnInventoryChanged;
}

private void OnInventoryChanged(NetworkListEvent<int> changeEvent)
{
    switch (changeEvent.Type)
    {
        case NetworkListEvent<int>.EventType.Add:
            Debug.Log($"Item added: {changeEvent.Value}");
            break;
        case NetworkListEvent<int>.EventType.Remove:
            Debug.Log($"Item removed: {changeEvent.Value}");
            break;
        case NetworkListEvent<int>.EventType.Clear:
            Debug.Log("Inventory cleared");
            break;
    }
    RefreshInventoryUI();
}

[Rpc(SendTo.Server, InvokePermission = RpcInvokePermission.Owner)]
private void AddItemRpc(int itemId)
{
    if (inventory.Count < 20) // server-side validation
        inventory.Add(itemId);
}
```

## 2. RPC patterns

### Client to server

Player actions the server must validate:

```csharp
[Rpc(SendTo.Server, InvokePermission = RpcInvokePermission.Owner)]
private void ShootRpc(Vector3 origin, Vector3 direction)
{
    if (!CanShoot()) return;

    // Authoritative raycast on the server
    if (Physics.Raycast(origin, direction, out var hit, 100f))
    {
        var target = hit.collider.GetComponent<PlayerController>();
        if (target != null)
            target.TakeDamage(25);
    }

    // Tell every client to play the effect
    ShootEffectRpc(origin, direction);
}
```

### Server to all clients

Cosmetic feedback for everyone:

```csharp
[Rpc(SendTo.ClientsAndHost)]
private void ShootEffectRpc(Vector3 origin, Vector3 direction)
{
    SpawnMuzzleFlash(origin);
    PlayShootSound();
    SpawnTracer(origin, direction);
}
```

### Server to one client

Use `SendTo.SpecifiedInParams` and pass the target in `RpcParams`:

```csharp
[Rpc(SendTo.SpecifiedInParams)]
private void ShowMessageRpc(FixedString64Bytes message, RpcParams rpcParams)
{
    ShowNotification(message.ToString());
}

// Server side
private void NotifyPlayer(ulong clientId, string message)
{
    ShowMessageRpc(message, RpcTarget.Single(clientId, RpcTargetUse.Temp));
}
```

`RpcTargetUse.Temp` reuses a cached target object to avoid an allocation. Use
`RpcTargetUse.Persistent` if you keep the target around. `RpcTarget.Group(...)` and
`RpcTarget.Not(...)` send to or exclude several client IDs.

### Any client may call

`[Rpc]` defaults to letting any client invoke it. Read the sender from `RpcParams`:

```csharp
// Interacting with a world object nobody owns
[Rpc(SendTo.Server, InvokePermission = RpcInvokePermission.Everyone)]
private void InteractRpc(RpcParams rpcParams = default)
{
    ulong senderId = rpcParams.Receive.SenderClientId;
    Debug.Log($"Client {senderId} interacted with {gameObject.name}");
    ProcessInteraction(senderId);
}
```

### Full pattern: validated action with a reply to the caller

```csharp
[Rpc(SendTo.Server, InvokePermission = RpcInvokePermission.Owner)]
private void PurchaseItemRpc(int itemId, RpcParams rpcParams = default)
{
    ulong clientId = rpcParams.Receive.SenderClientId;
    var replyTo = RpcTarget.Single(clientId, RpcTargetUse.Temp);

    if (!shopInventory.Contains(itemId))
    {
        PurchaseResultRpc(false, "Item not available", replyTo);
        return;
    }

    int price = GetItemPrice(itemId);
    if (playerGold.Value < price)
    {
        PurchaseResultRpc(false, "Not enough gold", replyTo);
        return;
    }

    playerGold.Value -= price;
    AddItemToInventory(clientId, itemId);
    PurchaseResultRpc(true, "Purchase successful", replyTo);
}

[Rpc(SendTo.SpecifiedInParams)]
private void PurchaseResultRpc(bool success, FixedString64Bytes message, RpcParams rpcParams)
{
    if (success) PlayPurchaseSound();
    ShowNotification(message.ToString());
}
```

## 3. Spawning

### Player prefab

The player prefab set on the NetworkManager is spawned automatically for each client that
connects. No code needed.

### Dynamic spawning (server only)

```csharp
[SerializeField] private NetworkObject projectilePrefab; // must be in the network prefab list

[Rpc(SendTo.Server, InvokePermission = RpcInvokePermission.Owner)]
private void SpawnProjectileRpc(Vector3 position, Vector3 direction)
{
    var netObj = Instantiate(projectilePrefab, position, Quaternion.LookRotation(direction));
    netObj.Spawn(); // appears on every client

    // Or give the shooter ownership at spawn:
    // netObj.SpawnWithOwnership(OwnerClientId);
}
```

`NetworkManager.SpawnManager.InstantiateAndSpawn(prefab, ownerId, ...)` does both steps in one call
and also handles prefab overrides.

### Despawning

```csharp
// Server only: despawns on every client
[Rpc(SendTo.Server, InvokePermission = RpcInvokePermission.Owner)]
private void DespawnObjectRpc()
{
    NetworkObject.Despawn();       // despawn and destroy
    // NetworkObject.Despawn(false); // despawn but keep the GameObject (pooling)
}
```

Only the authority despawns. A non-authority client must never call `Destroy` on a spawned
NetworkObject; it sends an RPC to the server instead.

### Pooling

See `netcode-advanced.md`.

## 4. Ownership

### Checking roles

```csharp
if (IsOwner)       { /* this client owns the object */ }
if (IsServer)      { /* running on the server (or host) */ }
if (IsHost)        { /* running on the host (server + client) */ }
if (IsClient)      { /* running on a client (or host) */ }
if (IsLocalPlayer) { /* this is the local client's player object */ }
```

### Transferring ownership

```csharp
[Rpc(SendTo.Server, InvokePermission = RpcInvokePermission.Everyone)]
private void RequestOwnershipRpc(RpcParams rpcParams = default)
{
    ulong requesterId = rpcParams.Receive.SenderClientId;

    if (!isLocked) // is the object available?
    {
        NetworkObject.ChangeOwnership(requesterId);
        isLocked = true;
    }
}
```

### Pattern: pickup item

```csharp
public class PickupItem : NetworkBehaviour
{
    private NetworkVariable<bool> isPickedUp = new(false,
        NetworkVariableReadPermission.Everyone,
        NetworkVariableWritePermission.Server);

    public override void OnNetworkSpawn()
    {
        isPickedUp.OnValueChanged += OnPickedUpChanged;
        SetVisible(!isPickedUp.Value);
    }

    public override void OnNetworkDespawn()
    {
        isPickedUp.OnValueChanged -= OnPickedUpChanged;
    }

    private void OnPickedUpChanged(bool previous, bool picked) => SetVisible(!picked);

    [Rpc(SendTo.Server, InvokePermission = RpcInvokePermission.Everyone)]
    public void PickUpRpc(RpcParams rpcParams = default)
    {
        if (isPickedUp.Value) return;

        isPickedUp.Value = true; // hides the visual on every client, including late joiners
        NetworkObject.ChangeOwnership(rpcParams.Receive.SenderClientId);
    }

    private void SetVisible(bool visible)
    {
        GetComponent<Renderer>().enabled = visible;
        GetComponent<Collider>().enabled = visible;
    }
}
```

Driving visibility from a NetworkVariable rather than a one-off RPC means clients that join later
see the correct state.
