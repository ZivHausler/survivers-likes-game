# Enemy Attacks — strategy delegation for non-melee archetypes

`id: enemy-attacks`

## What

`EnemyAttack` (`enemies/attacks/enemy_attack.gd`) is a small **strategy object**
that lets `Enemy3D` host more than one attack archetype without bloating the
hot-path of the heavily-tested melee enemy.

```gdscript
class_name EnemyAttack extends RefCounted
func desired_velocity(enemy: Enemy3D, target: Node3D, dt: float) -> Vector3  # base: Vector3.ZERO
func attack_tick(enemy: Enemy3D, target: Node3D, dt: float) -> void          # base: no-op
```

Both methods are no-ops in the base class. Minimal stub subclasses exist now:
`RangedAttack` (`enemies/attacks/ranged_attack.gd`) and `DashAttack`
(`enemies/attacks/dash_attack.gd`) — they extend EnemyAttack and inherit the
no-op behavior. Full approach-and-hold/LOS/fire logic (RangedAttack) is added in Task 4;
full approach/windup/dash/cooldown logic (DashAttack) is added in Task 5.

### RangedAttack movement — approach-and-hold (no kiting)

`RangedAttack.approach_velocity` implements a two-state rule:

- **Beyond `attack_range`**: move toward the player at `move_speed` (approach).
- **Within `attack_range`**: return `Vector3.ZERO` — hold position and keep firing.

There is no retreat branch. If the player closes into melee range the ranged enemy
stands its ground and continues shooting. The fire threshold (`dist <= attack_range`)
matches the hold threshold exactly, so a holding enemy always satisfies the range
condition for `_can_fire`.

## The contract — and why MELEE stays inline

`Enemy3D._attack: EnemyAttack` is `null` for MELEE and set in `setup()` via the
`_make_attack(data)` factory:

- `attack_kind == MELEE` (and not legacy `is_ranged`) → `null`
- `attack_kind == RANGED`, or legacy `is_ranged == true` → `RangedAttack`
- `attack_kind == DASHER` → `DashAttack`

`_physics_process` branches on `_attack`:

- **`if _attack:`** delegate movement to `_attack.desired_velocity(...)` and the
  action to `_attack.attack_tick(...)`.
- **`else:`** run the *original, byte-identical* melee code — the
  `RANGED_STANDOFF` kite check, `steer_velocity(...)`, and the `CONTACT_RANGE`
  contact-damage block with its 0.5 s cooldown.

Rationale: the melee path (charm → velocity ZERO; post-charm chase → velocity.x > 0;
contact damage once at range) plus the RVO avoidance fallback are covered by a large
regression suite. Keeping melee as the **inline default** (rather than extracting it
into a `MeleeAttack` strategy) guarantees those tests keep exercising the exact same
code. The synchronous `velocity = ...` assignment is preserved because the avoidance
fix in `_on_velocity_computed` reads `velocity` as the desired fallback.

## Tests

- `test/test_enemy_attack_wiring.gd` — all 4 cases active: melee→null,
  RANGED→RangedAttack, DASHER→DashAttack, is_ranged=true→RangedAttack.
- `test/test_enemy_3d.gd`, `test_enemy_3d_bugfix.gd`, `test_enemy_3d_avoidance.gd` —
  the existing melee regression; all must stay green.

See also: [[enemy-3d]], [[enemy-projectile-3d]], [[enemy]].
