# 2D Gameplay Patterns

Complete 2D gameplay patterns for Unity 6. Each one is ready to copy and uses Unity 6 APIs
(`linearVelocity`, the Input System).

## Input setup used by these controllers

The controllers read the **project-wide actions** through `InputSystem.actions`. A new Unity 6
project has these (Project Settings > Input System Package), including `Move` (Vector2) and `Jump`
(Button). Look actions up once in `Awake`, then read them every frame. Project-wide actions are
enabled automatically.

Two other ways work just as well; pick one per project and stay with it:

- **PlayerInput component:** add `PlayerInput`, assign the actions asset, and choose a notification
  behavior. With *Send Messages*, it calls `OnMove(InputValue value)` and reads `value.Get<Vector2>()`.
- **Generated C# class:** tick *Generate C# Class* on the actions asset. Create an instance, call
  `Enable()` on the action map, and read actions by property instead of by string.

Package docs: `https://docs.unity3d.com/Packages/com.unity.inputsystem@<version>/manual/`.

---

## 1. Platformer controller

Ground check, coyote time, jump buffer, variable jump height, and heavier gravity when falling.

```csharp
using UnityEngine;
using UnityEngine.InputSystem;

public class PlatformerController2D : MonoBehaviour
{
    [Header("Input")]
    [SerializeField] private string moveActionName = "Move";
    [SerializeField] private string jumpActionName = "Jump";

    [Header("Movement")]
    [SerializeField] private float moveSpeed = 8f;
    [SerializeField] private float acceleration = 60f;
    [SerializeField] private float deceleration = 50f;

    [Header("Jump")]
    [SerializeField] private float jumpForce = 14f;
    [SerializeField] private float fallGravityMultiplier = 2.5f;
    [SerializeField] private float lowJumpGravityMultiplier = 2f;
    [SerializeField] private float maxFallSpeed = -20f;

    [Header("Coyote Time & Jump Buffer")]
    [SerializeField] private float coyoteTime = 0.12f;
    [SerializeField] private float jumpBufferTime = 0.1f;

    [Header("Ground Check")]
    [SerializeField] private Transform groundCheckPoint;
    [SerializeField] private float groundCheckRadius = 0.15f;
    [SerializeField] private LayerMask groundLayer;

    private Rigidbody2D rb;
    private SpriteRenderer spriteRenderer;
    private InputAction moveAction;
    private InputAction jumpAction;
    private float moveInput;
    private bool jumpHeld;
    private float coyoteTimer;
    private float jumpBufferTimer;
    private bool isGrounded;
    private float defaultGravityScale;

    private void Awake()
    {
        rb = GetComponent<Rigidbody2D>();
        spriteRenderer = GetComponent<SpriteRenderer>();
        defaultGravityScale = rb.gravityScale;

        moveAction = InputSystem.actions.FindAction(moveActionName);
        jumpAction = InputSystem.actions.FindAction(jumpActionName);
    }

    private void Update()
    {
        // Read input in Update, never in FixedUpdate
        moveInput = moveAction.ReadValue<Vector2>().x;
        jumpHeld = jumpAction.IsPressed();

        isGrounded = Physics2D.OverlapCircle(
            groundCheckPoint.position, groundCheckRadius, groundLayer);

        // Coyote time
        if (isGrounded)
            coyoteTimer = coyoteTime;
        else
            coyoteTimer -= Time.deltaTime;

        // Jump buffer
        if (jumpAction.WasPressedThisFrame())
            jumpBufferTimer = jumpBufferTime;
        else
            jumpBufferTimer -= Time.deltaTime;

        // Jump when both the buffer and coyote window are open
        if (jumpBufferTimer > 0f && coyoteTimer > 0f)
        {
            rb.linearVelocityY = jumpForce;
            jumpBufferTimer = 0f;
            coyoteTimer = 0f;
        }

        // Variable jump height: releasing the button cuts upward speed
        if (jumpAction.WasReleasedThisFrame() && rb.linearVelocityY > 0f)
            rb.linearVelocityY *= 0.5f;

        if (moveInput != 0f)
            spriteRenderer.flipX = moveInput < 0f;
    }

    private void FixedUpdate()
    {
        // Horizontal movement with acceleration and deceleration
        float targetSpeed = moveInput * moveSpeed;
        float speedDiff = targetSpeed - rb.linearVelocityX;
        float accelRate = Mathf.Abs(targetSpeed) > 0.01f ? acceleration : deceleration;
        rb.linearVelocityX += speedDiff * accelRate * Time.fixedDeltaTime;

        // Heavier when falling, lighter while jump is held
        if (rb.linearVelocityY < 0f)
            rb.gravityScale = defaultGravityScale * fallGravityMultiplier;
        else if (rb.linearVelocityY > 0f && !jumpHeld)
            rb.gravityScale = defaultGravityScale * lowJumpGravityMultiplier;
        else
            rb.gravityScale = defaultGravityScale;

        // Clamp fall speed
        if (rb.linearVelocityY < maxFallSpeed)
            rb.linearVelocityY = maxFallSpeed;
    }

    private void OnDrawGizmosSelected()
    {
        if (groundCheckPoint == null) return;
        Gizmos.color = Color.red;
        Gizmos.DrawWireSphere(groundCheckPoint.position, groundCheckRadius);
    }
}
```

**Setup:**
- Rigidbody2D: Dynamic, Freeze Rotation Z, Interpolate
- Collider: CapsuleCollider2D
- An empty child `GroundCheck` placed at the character's feet
- `groundLayer` set to the layer of the level collision

---

## 2. Top-down 8-direction movement

Eight-direction movement with smooth rotation toward the move direction. Suits action-adventure,
twin-stick, and action RPG games.

```csharp
using UnityEngine;
using UnityEngine.InputSystem;

public class TopDownController2D : MonoBehaviour
{
    [SerializeField] private string moveActionName = "Move";
    [SerializeField] private float moveSpeed = 6f;
    [SerializeField] private float rotationSpeed = 720f;

    private Rigidbody2D rb;
    private InputAction moveAction;
    private Vector2 moveInput;
    private Vector2 smoothedInput;
    private Vector2 inputVelocity;

    private void Awake()
    {
        rb = GetComponent<Rigidbody2D>();
        rb.gravityScale = 0f; // no gravity in top-down
        moveAction = InputSystem.actions.FindAction(moveActionName);
    }

    private void Update()
    {
        // Clamp so diagonals are not faster; keeps analog-stick magnitude below 1
        moveInput = Vector2.ClampMagnitude(moveAction.ReadValue<Vector2>(), 1f);

        // Smooth input to avoid abrupt changes
        smoothedInput = Vector2.SmoothDamp(
            smoothedInput, moveInput, ref inputVelocity, 0.05f);
    }

    private void FixedUpdate()
    {
        rb.linearVelocity = smoothedInput * moveSpeed;

        // Rotate toward the move direction
        if (moveInput.sqrMagnitude > 0.01f)
        {
            float targetAngle = Mathf.Atan2(moveInput.y, moveInput.x) * Mathf.Rad2Deg - 90f;
            float angle = Mathf.MoveTowardsAngle(
                rb.rotation, targetAngle, rotationSpeed * Time.fixedDeltaTime);
            rb.MoveRotation(angle);
        }
    }
}
```

**Setup:**
- Rigidbody2D: Dynamic, Gravity Scale = 0, Interpolate
- Collider: CircleCollider2D or CapsuleCollider2D
- Physics Material 2D: Friction = 0, Bounciness = 0

---

## 3. Parallax scrolling

Parallax with infinite looping. Each layer moves at a different speed according to its depth.

```csharp
using UnityEngine;

public class ParallaxLayer : MonoBehaviour
{
    [Tooltip("0 = fixed (far background), 1 = moves with the camera (foreground)")]
    [Range(0f, 1f)]
    [SerializeField] private float parallaxEffect = 0.5f;

    [SerializeField] private bool infiniteLoop = true;

    private Transform cameraTransform;
    private float spriteWidth;
    private Vector3 lastCameraPos;

    private void Start()
    {
        cameraTransform = Camera.main.transform;
        lastCameraPos = cameraTransform.position;

        if (infiniteLoop)
            spriteWidth = GetComponent<SpriteRenderer>().bounds.size.x;
    }

    private void LateUpdate()
    {
        Vector3 cameraDelta = cameraTransform.position - lastCameraPos;
        transform.position += new Vector3(
            cameraDelta.x * parallaxEffect, cameraDelta.y * parallaxEffect, 0f);
        lastCameraPos = cameraTransform.position;

        // Infinite loop: jump by one sprite width when the camera passes half of it
        if (!infiniteLoop) return;

        float relativePos = cameraTransform.position.x - transform.position.x;
        if (relativePos > spriteWidth * 0.5f)
            transform.position += new Vector3(spriteWidth, 0f, 0f);
        else if (relativePos < -spriteWidth * 0.5f)
            transform.position -= new Vector3(spriteWidth, 0f, 0f);
    }
}
```

**Setup:**
- Create 3 to 5 background sprites on separate sorting layers
- Give each a rising `parallaxEffect` (0.1 for the sky, 0.9 for the foreground)
- Turn on `infiniteLoop` for layers that must repeat
