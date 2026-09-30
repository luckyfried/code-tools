---
name: unity-multiplayer
description: Use when writing or reviewing Netcode for GameObjects (NGO) gameplay code in Unity 6 - NetworkBehaviour scripts, NetworkVariable and NetworkList state, RPCs with the [Rpc(SendTo...)] attribute, ownership checks and transfer, and spawning or despawning NetworkObjects. Also use when migrating old [ServerRpc]/[ClientRpc] methods to [Rpc]. Triggers include "NetworkBehaviour", "NetworkVariable", "NetworkList", "Rpc", "ServerRpc", "ClientRpc", "SendTo.Server", "IsOwner", "IsServer", "OnNetworkSpawn", "NetworkObject.Spawn", "ChangeOwnership", "Netcode for GameObjects", "NGO", "host mode", "sync state across clients". For lobby, relay, matchmaking, sessions, or hosting, use Unity's setup-multiplayer-services skill instead.
---

Adapted from JulianKerignard/Unity-Skills (MIT); see LICENSE.

# Unity multiplayer: Netcode for GameObjects gameplay code

This skill covers the gameplay code of a **Netcode for GameObjects** (NGO) game: NetworkBehaviours,
synchronized state, RPCs, ownership, and spawning. It targets NGO 2.x, the version line used with
Unity 6.

Out of scope:

- Choosing a topology, player grouping, lobby, relay, matchmaking, sessions, dedicated server
  hosting, and the Multiplayer Center: use Unity's `setup-multiplayer-services` skill.
- Netcode for Entities, Mirror, Photon, and other networking stacks.

## Before writing code

1. Read the installed NGO version in `Packages/manifest.json` (`com.unity.netcode.gameobjects`).
   RPC attribute options changed inside 2.x (see "RPC permissions" below).
2. When unsure an API exists, check the package docs for that version:
   `https://docs.unity3d.com/Packages/com.unity.netcode.gameobjects@<major.minor>/manual/index.html`.
   Never guess a member name.
3. The scene needs a `NetworkManager` with a transport (Unity Transport), and every networked prefab
   needs a `NetworkObject` and must be registered in the NetworkManager's prefab list.

Start a session from code:

```csharp
NetworkManager.Singleton.StartHost();   // server and client in one process
NetworkManager.Singleton.StartServer(); // server only
NetworkManager.Singleton.StartClient(); // client only
```

## A NetworkBehaviour

```csharp
using Unity.Netcode;
using UnityEngine;
using UnityEngine.InputSystem;

public class PlayerController : NetworkBehaviour
{
    [SerializeField] private float speed = 5f;

    // Synced from the server to every client.
    private NetworkVariable<int> score = new(0,
        NetworkVariableReadPermission.Everyone,
        NetworkVariableWritePermission.Server);

    private InputAction move;

    public override void OnNetworkSpawn()
    {
        if (IsOwner)
            move = InputSystem.actions.FindAction("Move"); // project-wide input actions
        score.OnValueChanged += OnScoreChanged;
    }

    public override void OnNetworkDespawn()
    {
        score.OnValueChanged -= OnScoreChanged;
    }

    private void Update()
    {
        if (!IsOwner) return; // only the owner drives its own character

        Vector2 m = move.ReadValue<Vector2>();
        transform.position += new Vector3(m.x, 0, m.y) * (speed * Time.deltaTime);
    }

    // Called by the owning client, runs on the server.
    [Rpc(SendTo.Server)]
    public void AddScoreRpc(int points)
    {
        score.Value += points;
    }

    private void OnScoreChanged(int oldValue, int newValue)
    {
        Debug.Log($"Score: {oldValue} -> {newValue}");
    }
}
```

Moving `transform` on the owner only syncs if the prefab's `NetworkTransform` has its **Authority
Mode** set to Owner. The default is server authority, where the server's transform wins. Input here
uses the Input System package; see `unity-current-api` for the Input Manager mapping.

## RPCs

Declare an RPC with `[Rpc(SendTo.X)]`. The method name must end in `Rpc`.

| Target | Runs on |
| --- | --- |
| `SendTo.Server` | The server (locally if already on the server) |
| `SendTo.NotServer` | Every client except the server; a host is treated as the server |
| `SendTo.ClientsAndHost` | Every client, including the host's client |
| `SendTo.Everyone` | Everyone, including the caller |
| `SendTo.Owner` / `SendTo.NotOwner` | The object's owner / everyone else |
| `SendTo.Me` / `SendTo.NotMe` | The caller only / everyone but the caller |
| `SendTo.SpecifiedInParams` | Targets passed at call time in `RpcParams` |

- Add `RpcParams rpcParams` as the **last** parameter to read the sender
  (`rpcParams.Receive.SenderClientId`) or pass a runtime target such as
  `RpcTarget.Single(clientId, RpcTargetUse.Temp)`.
- `[ServerRpc]` and `[ClientRpc]` are the older attributes. NGO 2.x deprecates `ServerRpc` with
  `RequireOwnership`. Write `[Rpc]` in new code and convert old methods when you touch them:
  `[ServerRpc]` becomes `[Rpc(SendTo.Server)]`, `[ClientRpc]` becomes `[Rpc(SendTo.ClientsAndHost)]`,
  and the `ServerRpc`/`ClientRpc` suffix becomes `Rpc`.

### RPC permissions

An `[Rpc]` can be called by any client unless you restrict it. How you restrict it depends on the
NGO version:

- **NGO 2.7 and later:** `[Rpc(SendTo.Server, InvokePermission = RpcInvokePermission.Owner)]`.
  Options are `Everyone` (default), `Owner`, and `Server`. `RequireOwnership` is deprecated.
- **Earlier 2.x:** `[Rpc(SendTo.Server, RequireOwnership = true)]` (default `false`).

Whatever the permission, the server validates every request it receives.

## Rules

**Always:**

- Check `IsOwner` before reading player input.
- Check `IsServer` before changing authoritative state.
- Use `NetworkVariable` (or `NetworkList`) for state that must be synced, not plain fields.
- Put network setup in `OnNetworkSpawn` / `OnNetworkDespawn`, not `Start` / `OnDestroy`.
- Unsubscribe `OnValueChanged` in `OnNetworkDespawn`.
- Validate RPC arguments on the server.

**Never:**

- `Instantiate` a networked prefab and expect clients to see it. Spawn it on the server with
  `NetworkObject.Spawn()` (or `SpawnWithOwnership`).
- `Destroy` a spawned NetworkObject on a non-authority client. Ask the server to `Despawn` it.
- Use `NetworkVariable<string>`. Use a `FixedString...Bytes` type.
- Let client code change server state directly.
- Run expensive `Update` work on non-owner objects without a reason.

**Prefer:**

- `NetworkVariable` for continuous state (health, score, flags).
- `[Rpc(SendTo.Server)]` for one-off player actions (shoot, buy, interact).
- `[Rpc(SendTo.ClientsAndHost)]` for cosmetic feedback (effects, sounds).
- `NetworkTransform` over hand-written position sync.

## References

- `references/netcode-patterns.md`: NetworkVariable types and permissions, custom serialization,
  NetworkList, RPC patterns with validation and targeted replies, spawning, ownership.
- `references/netcode-advanced.md`: pooling, basic client prediction and reconciliation,
  interpolation, bandwidth, local multi-instance testing.

## Related skills

- `setup-multiplayer-services` (Unity): topology, sessions, lobby, relay, matchmaking, hosting.
- `unity-current-api`: current Unity 6 APIs, including Input System usage.
- `unity-test`: writing tests for extracted gameplay logic.
- `unity-profiling-workflow`: finding the cost of network-heavy frames.

## Troubleshooting

| Problem | Fix |
| --- | --- |
| "NetworkObject is not spawned" | The prefab needs a `NetworkObject`, must be in the prefab list, and must be spawned on the server. |
| RPC not called | The method needs `[Rpc(...)]` and the `Rpc` suffix. Check the invoke permission (or `RequireOwnership`) against the caller. |
| State out of sync | Use a `NetworkVariable` instead of a local field. Check its read and write permissions. |
| Visible latency on your own player | Owner-authority `NetworkTransform`, or client prediction (see `references/netcode-advanced.md`). |
| "Object already spawned" | Spawn once. Trace where `Spawn()` is called twice. |
| Client does not connect | Check address and port on `UnityTransport`. Relay join codes belong to `setup-multiplayer-services`. |
| NetworkVariable write ignored or throws | Only the writer allowed by `WritePermission` (server by default) may set `.Value`. |
