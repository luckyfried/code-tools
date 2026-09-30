# Unity test templates

Copy and adapt.

## 1. Edit Mode: pure logic

```csharp
using NUnit.Framework;

[TestFixture]
public class HealthCalculatorTests
{
    [Test]
    public void CalculateDamage_NormalHit_ReducesHealth()
    {
        Assert.AreEqual(70, HealthCalculator.CalculateDamage(100, 30));
    }

    [Test]
    public void CalculateDamage_Overkill_ClampsToZero()
    {
        Assert.AreEqual(0, HealthCalculator.CalculateDamage(10, 50));
    }

    [TestCase(100, 0, 100)]
    [TestCase(100, 100, 0)]
    [TestCase(0, 10, 0)]
    public void CalculateDamage_Parameterized(int health, int damage, int expected)
    {
        Assert.AreEqual(expected, HealthCalculator.CalculateDamage(health, damage));
    }
}
```

## 2. Edit Mode: ScriptableObject validation

```csharp
using NUnit.Framework;
using UnityEngine;

[TestFixture]
public class WeaponDataTests
{
    private WeaponData weapon;

    [SetUp]
    public void SetUp() => weapon = ScriptableObject.CreateInstance<WeaponData>();

    [TearDown]
    public void TearDown() => Object.DestroyImmediate(weapon);

    [Test]
    public void Damage_DefaultValue_IsPositive()
    {
        Assert.Greater(weapon.Damage, 0);
    }

    [Test]
    public void FireRate_DefaultValue_IsWithinRange()
    {
        Assert.That(weapon.FireRate, Is.InRange(0.1f, 10f));
    }
}
```

## 3. Edit Mode: state machine

```csharp
using NUnit.Framework;

[TestFixture]
public class EnemyStateMachineTests
{
    private EnemyStateMachine sm;

    [SetUp]
    public void SetUp() => sm = new EnemyStateMachine();

    [Test]
    public void InitialState_IsIdle()
        => Assert.AreEqual(EnemyState.Idle, sm.CurrentState);

    [Test]
    public void Transition_IdleToPatrol_OnPatrolCommand()
    {
        sm.OnPatrolCommand();
        Assert.AreEqual(EnemyState.Patrol, sm.CurrentState);
    }

    [Test]
    public void Transition_Dead_IgnoresAllCommands()
    {
        sm.OnDeath();
        sm.OnPatrolCommand();
        Assert.AreEqual(EnemyState.Dead, sm.CurrentState);
    }
}
```

## 4. Play Mode: MonoBehaviour lifecycle

```csharp
using System.Collections;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

public class PlayerHealthTests
{
    private GameObject go;
    private PlayerHealth hp;

    [SetUp]
    public void SetUp()
    {
        go = new GameObject("Player");
        hp = go.AddComponent<PlayerHealth>();
    }

    [TearDown]
    public void TearDown() => Object.Destroy(go);

    [UnityTest]
    public IEnumerator Start_OnInitialize_SetsMaxHealth()
    {
        yield return null; // let Start() run
        Assert.AreEqual(100, hp.CurrentHealth);
    }

    [UnityTest]
    public IEnumerator TakeDamage_Lethal_TriggersDeathEvent()
    {
        yield return null;
        bool died = false;
        hp.OnDeath += () => died = true;
        hp.TakeDamage(100);
        Assert.IsTrue(died);
    }
}
```

## 5. Play Mode: time-based behaviour

```csharp
using System.Collections;
using NUnit.Framework;
using UnityEngine;
using UnityEngine.TestTools;

public class ProjectileTests
{
    private GameObject go;

    [SetUp]
    public void SetUp()
    {
        go = new GameObject("Projectile");
        go.AddComponent<Projectile>();
    }

    [TearDown]
    public void TearDown() { if (go != null) Object.Destroy(go); }

    [UnityTest]
    public IEnumerator Lifetime_AfterDuration_DestroysItself()
    {
        go.GetComponent<Projectile>().SetLifetime(0.1f);
        yield return null;
        yield return new WaitForSeconds(0.2f);
        Assert.IsTrue(go == null); // Unity's null check: destroyed objects compare equal to null
    }
}
```

## 6. Async tests

The Test Framework runs `async Task` tests on the main thread and awaits them each update (each
`EditorApplication.update` in Edit Mode), so Unity APIs are safe to call inside them. Failing log
messages are only evaluated after the async test completes.

```csharp
using System.Threading.Tasks;
using NUnit.Framework;

public class DataServiceTests
{
    [Test]
    public async Task LoadData_ValidKey_ReturnsData()
    {
        var result = await new DataService().LoadDataAsync("key");
        Assert.IsNotNull(result);
    }
}
```

Do not wrap test bodies in `Task.Run`: that moves the work off the main thread, where most Unity
APIs throw.

## 7. Event channel: ScriptableObject events

```csharp
using NUnit.Framework;
using UnityEngine;

[TestFixture]
public class GameEventTests
{
    private GameEvent evt;

    [SetUp]
    public void SetUp() => evt = ScriptableObject.CreateInstance<GameEvent>();

    [TearDown]
    public void TearDown() => Object.DestroyImmediate(evt);

    [Test]
    public void Raise_WithListener_NotifiesListener()
    {
        bool received = false;
        evt.OnRaised += () => received = true;
        evt.Raise();
        Assert.IsTrue(received);
    }

    [Test]
    public void Raise_NoListeners_DoesNotThrow()
        => Assert.DoesNotThrow(() => evt.Raise());
}
```

## 8. Test doubles

### Interface and stub

```csharp
// Production interface
public interface IInputProvider { Vector2 GetMovement(); bool GetJump(); }

// Stub for tests
public class StubInputProvider : IInputProvider
{
    public Vector2 Movement { get; set; }
    public bool Jump { get; set; }
    public Vector2 GetMovement() => Movement;
    public bool GetJump() => Jump;
}

[Test]
public void CalculateVelocity_RightInput_MovesRight()
{
    var input = new StubInputProvider { Movement = Vector2.right };
    var movement = new PlayerMovement();
    movement.SetInputProvider(input);
    Assert.AreEqual(5f, movement.CalculateVelocity(speed: 5f).x, 0.001f);
}
```

The production `IInputProvider` wraps the Input System (for example an `InputAction` read with
`ReadValue<Vector2>()`), so gameplay logic can be tested without devices.

### Spy: records calls for later checks

```csharp
public class SpyAudioService : IAudioService
{
    public List<string> PlayedSounds { get; } = new();
    public void PlaySound(string clip) => PlayedSounds.Add(clip);
}

[Test]
public void TakeDamage_PlaysHurtSound()
{
    var spy = new SpyAudioService();
    new CombatSystem(spy).TakeDamage(10);
    Assert.Contains("hurt", spy.PlayedSounds);
}
```

## 9. Assembly definition templates

Creating the folder with **Assets > Create > Testing > Test Assembly Folder** generates these
references for you. Hand-written versions:

**Edit Mode**: `Game.Tests.EditMode.asmdef`

```json
{
  "name": "Game.Tests.EditMode",
  "references": ["Game.Runtime", "UnityEngine.TestRunner", "UnityEditor.TestRunner"],
  "includePlatforms": ["Editor"],
  "overrideReferences": true,
  "precompiledReferences": ["nunit.framework.dll"],
  "defineConstraints": ["UNITY_INCLUDE_TESTS"],
  "autoReferenced": false
}
```

**Play Mode**: `Game.Tests.PlayMode.asmdef`

```json
{
  "name": "Game.Tests.PlayMode",
  "references": ["Game.Runtime", "UnityEngine.TestRunner"],
  "includePlatforms": [],
  "overrideReferences": true,
  "precompiledReferences": ["nunit.framework.dll"],
  "defineConstraints": ["UNITY_INCLUDE_TESTS"],
  "autoReferenced": false
}
```

`UnityEditor.TestRunner` is only available to Edit Mode test assemblies, so the Play Mode assembly
does not reference it. References may be names (as here) or `GUID:<guid>` entries; the Inspector
writes GUIDs when "Use GUIDs" is on.

**Runtime**: `Game.Runtime.asmdef`

```json
{ "name": "Game.Runtime", "references": [], "includePlatforms": [], "autoReferenced": true }
```

## 10. Checklist before submitting

- [ ] Names follow `MethodName_Condition_ExpectedResult`
- [ ] `[SetUp]` creates everything, `[TearDown]` destroys everything
- [ ] No test depends on another
- [ ] No `Thread.Sleep`: `yield return null` or `await`
- [ ] Floats compared with a tolerance
- [ ] Created GameObjects and ScriptableObjects are destroyed
- [ ] Assembly definitions set up correctly
- [ ] The test passes alone and with all the others
