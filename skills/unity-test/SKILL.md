---
name: unity-test
description: Use when writing Unity tests with the Unity Test Framework (NUnit) - choosing Edit Mode or Play Mode, setting up test assembly definitions, pulling testable logic out of MonoBehaviours, writing [Test], [UnityTest], [TestCase], and async Task tests, and hand-written test doubles. Triggers include "write tests", "add a unit test", "test this script", "NUnit", "Unity Test Framework", "EditMode test", "PlayMode test", "UnityTest", "test assembly", "TDD in Unity", "make this testable". This skill writes tests; to compile the project and run them use unity-compile-and-test, and for the Unity CLI command reference use Unity's unity-cli skill.
---

Adapted from JulianKerignard/Unity-Skills (MIT); see LICENSE.

# Unity tests

Write Unity tests that are ready to commit: look at the target code, pick Edit Mode or Play Mode,
move logic out of MonoBehaviours into plain C# where needed, and write the NUnit tests.

Running the tests is not covered here. Use `unity-compile-and-test` to compile and run them (editor
open or headless), and Unity's `unity-cli` skill for the CLI command reference.

## Requirements

- **Unity Test Framework** (`com.unity.test-framework`), included in new projects. It ships NUnit.
- **Test assemblies**: tests live in their own assembly definition, never in `Assembly-CSharp`.
  The code under test must be in its own assembly too, because a test assembly cannot reference
  `Assembly-CSharp`.
- Suggested layout: `Assets/Tests/EditMode/` and `Assets/Tests/PlayMode/`, one `.asmdef` each.

## Workflow

1. Read the target code: dependencies, side effects, I/O.
2. Pick Edit Mode or Play Mode with the tree below.
3. If the logic is tied to a MonoBehaviour, extract it.
4. Write the test from the matching template in `references/test-templates.md`.
5. Run it with `unity-compile-and-test`.

## Edit Mode or Play Mode

```
The code under test...
+-- Is pure logic (math, state, data)?
|   -> Edit Mode (fast, no scene)
+-- Depends on the MonoBehaviour lifecycle (Start, Update, OnCollision)?
|   -> Play Mode
+-- Waits on frames or time (coroutines, Awaitable)?
|   -> Play Mode with [UnityTest], or an async Task test
+-- Validates a ScriptableObject?
|   -> Edit Mode (create it with ScriptableObject.CreateInstance)
+-- Tests several systems together?
    -> Play Mode integration test with a dedicated scene
```

**Main rule:** if the code can run without a MonoBehaviour, GameObject, or scene, it is an Edit Mode
test. Otherwise Play Mode.

Use NUnit `[Test]` rather than `[UnityTest]` unless you must yield: skip a frame or wait in Play
Mode, or yield Editor instructions in Edit Mode.

## Step by step

### 1. Analyze the target code

- **Inputs**: parameters, serialized fields, injected dependencies.
- **Outputs**: return values, state changes, events raised.
- **Side effects**: `Destroy`, `Instantiate`, scene changes.
- **Unity dependencies**: `MonoBehaviour`, `Transform`, `Physics`, `Time.deltaTime`.

### 2. Extract testable logic

When logic is tied to a MonoBehaviour, move it into plain C#.

```csharp
// BEFORE: logic inside the MonoBehaviour (hard to test)
public class PlayerHealth : MonoBehaviour
{
    [SerializeField] private int maxHealth = 100;
    private int currentHealth;

    private void Start() => currentHealth = maxHealth;

    public void TakeDamage(int amount)
    {
        currentHealth = Mathf.Max(0, currentHealth - amount);
        if (currentHealth <= 0) Die();
    }

    private void Die() { /* destroy, VFX, etc. */ }
}

// AFTER: pure logic, testable in Edit Mode
public static class HealthCalculator
{
    public static int CalculateDamage(int currentHealth, int damage)
        => Mathf.Max(0, currentHealth - damage);

    public static bool IsDead(int health) => health <= 0;
}

// The MonoBehaviour delegates to it
public class PlayerHealth : MonoBehaviour
{
    [SerializeField] private int maxHealth = 100;
    private int currentHealth;

    private void Start() => currentHealth = maxHealth;

    public void TakeDamage(int amount)
    {
        currentHealth = HealthCalculator.CalculateDamage(currentHealth, amount);
        if (HealthCalculator.IsDead(currentHealth)) Die();
    }

    private void Die() { /* destroy, VFX, etc. */ }
}
```

`HealthCalculator` now runs in an Edit Mode test instantly, with no scene.

### 3. Set up assembly definitions

The quickest way: select a folder, then **Assets > Create > Testing > Test Assembly Folder** (or
the Test Runner window's "Create a new Test Assembly Folder" button). This creates an `.asmdef` with
the references that make it a test assembly: `nunit.framework.dll`, `UnityEngine.TestRunner`, and
(Edit Mode only) `UnityEditor.TestRunner`.

- Edit Mode assembly: platform **Editor** only.
- Play Mode assembly: any platform, so the tests can also run in a player.
- Both reference the game's runtime assembly and set `UNITY_INCLUDE_TESTS` in `defineConstraints`.

Full `.asmdef` templates are in `references/test-templates.md`.

### 4. Write the test

Name tests `MethodName_Condition_ExpectedResult`:

- `CalculateDamage_NormalHit_ReducesHealth`
- `TakeDamage_Overkill_ClampsToZero`
- `Start_OnInitialize_SetsMaxHealth`

## Rules

1. Initialize in `[SetUp]`, clean up in `[TearDown]`.
2. Name every test `MethodName_Condition_ExpectedResult`.
3. No `Thread.Sleep`. Use `yield return null`, `WaitForSeconds`, or `await`.
4. No file system or network access in Edit Mode tests.
5. Compare floats with a tolerance: `Assert.AreEqual(expected, actual, 0.001f)`.
6. One test, one concept (one assert, or a few on the same thing).
7. Tests always live in a test assembly, never in the main assembly.
8. Destroy every GameObject and ScriptableObject you create in `[TearDown]`.
9. Use `[TestCase]` for parameterized tests instead of copying a test.
10. Tests never depend on each other. Each one passes alone and in the full run.

## Mocking without a framework

Unity ships no mocking framework. Use interfaces and hand-written test doubles: define an interface
(for example `IInputProvider`), write a double with settable properties, and inject it through a
constructor, setter, or `[SerializeField]`. Examples in `references/test-templates.md`.

## Related skills

- `unity-compile-and-test`: compile the project and run Edit Mode and Play Mode tests.
- `unity-cli` (Unity): Unity CLI command reference.
- `unity-current-api`: current Unity 6 APIs for the code under test.
- `unity-perf-audit`: static performance review of the code you are testing.

## Troubleshooting

| Problem | Likely cause | Fix |
| --- | --- | --- |
| Tests not found | Missing or misconfigured `.asmdef` | Check `references`, `defineConstraints`, and platforms |
| Test assembly cannot see game code | Game code is in `Assembly-CSharp` | Move it into its own `.asmdef` and reference that |
| Play Mode tests very slow | Heavy scene setup | Build minimal GameObjects instead of complex prefabs |
| Async test hangs | Awaited work never completes | Pass a `CancellationToken` and bound the wait |
| `NullReferenceException` right after `AddComponent` | `Start` has not run yet | `yield return null` once before asserting |
| Passes in Edit Mode, fails in a build | `#if UNITY_EDITOR` code paths | Keep editor code out of runtime code |
| `Assert.AreEqual` fails on floats | Exact float comparison | Use the tolerance overload |
