---
id: enemy
title: Enemy — base class, variants, and steering
created: 2026-06-28
links:
  - "[[game-events]]"
  - "[[spawner]]"
---

# Enemy

`Enemy` (`CharacterBody2D`) is the base enemy node.  It belongs to group `"enemies"` and is configured at runtime via `EnemyData`.

## Files

| File | Role |
|---|---|
| `enemies/enemy_data.gd` | `EnemyData` Resource — all per-variant stats |
| `enemies/enemy.gd` | `Enemy` CharacterBody2D — steering, contact damage, death |
| `enemies/enemy.tscn` | Scene: `Enemy` root + `Body` ColorRect + `Sprite` Sprite2D + `CollisionShape2D` + `ContactArea` Area2D |
| `enemies/swarmer.tres` | Swarmer variant data |
| `enemies/tank.tres` | Tank variant data |
| `enemies/spitter.tres` | Spitter variant data |

## API Contract

### EnemyData (Resource)

| Field | Type | Description |
|---|---|---|
| `id` | `StringName` | Unique variant identifier |
| `color` | `Color` | Body tint |
| `max_hp` | `float` | Starting hit-points |
| `move_speed` | `float` | Pixels / second toward target |
| `contact_damage` | `float` | Damage dealt on overlap |
| `xp_value` | `int` | XP emitted to [[game-events]] on death |
| `is_ranged` | `bool` | If true, stops at 140 px from target |
| `radius` | `float` | Collision/contact radius |
| `texture` | `Texture2D` | Optional sprite texture; `null` → use ColorRect "Body" placeholder |

### Enemy (CharacterBody2D)

```gdscript
func setup(p_data: EnemyData, p_target: Node2D) -> void
func take_damage(amount: float) -> void
func charm(duration: float) -> void
```

- On death: `GameEvents.enemy_killed.emit(global_position, data.xp_value)` then `queue_free()`.
- Contact damage: cooldown 0.5 s per hit, calls `target.take_damage(data.contact_damage)`.
- `_physics_process` guards against `data == null` and invalid target before running.
- `charm(duration)`: suppresses enemy movement for `duration` seconds. Sets an internal `_charm_timer` (takes the max of current remaining time and the new duration, so charms stack by keeping the longest). While the timer is active, `_physics_process` sets `velocity = Vector2.ZERO` and returns early. Added in task 2C (see [[weapon-ziv]]).

## Sprite / Wobble / Fallback (Task B2)

`enemy.tscn` has a `Sprite2D` child named `"Sprite"` (hidden by default at scene level).

In `setup()`:
- If `data.texture != null`: assigns it to `$Sprite`, sets a subtle tint blended from `data.color` toward white, shows `$Sprite`, hides `$Body`.
- Otherwise: keeps `$Body` visible (tinted with `data.color`), keeps `$Sprite` hidden.

**Procedural wobble**: in `_physics_process`, when `$Sprite.visible`, a per-enemy `_wobble_phase` (initialized via `randf() * TAU` in `setup()`) accumulates at 4 rad/s and drives a sine-based squash/stretch on `$Sprite.scale` (±6%). Movement, velocity, and damage logic are untouched.

**Boss visual**: `spawner.gd _spawn_boss` applies `Color(1.0, 0.15, 0.1)` to the boss's `$Sprite.modulate` after the existing ×8 HP and ×3 scale logic.

**Texture choices** (Kenney Monster Builder, CC0):
| Variant | Body file |
|---|---|
| swarmer | `body_greenA.png` |
| tank | `body_darkB.png` |
| spitter | `body_blueB.png` |

## Variants

| Variant | HP | Speed | Contact Dmg | XP | Ranged | Radius | Color |
|---|---|---|---|---|---|---|---|
| swarmer | 10 | 120 | 4 | 1 | false | 8 | Red `(1, 0.3, 0.3)` |
| tank | 80 | 50 | 14 | 5 | false | 14 | Blue `(0.4, 0.4, 1)` |
| spitter | 20 | 80 | 8 | 3 | true | 8 | Green `(0.2, 0.9, 0.3)` |

> **Ranged note (v1):** Spitter stops at 140 px and deals contact damage only. Projectile firing is a follow-up task.

## Integration

- [[game-events]] — enemy death emits `enemy_killed(position, xp_value)`
- [[spawner]] (future) — instances `enemy.tscn` and calls `enemy.setup(variant_data, target)`

## Manual Smoke Test

Scene with a static `Node2D` target + 20 enemies placed around it. Confirm:
1. Enemies converge on the target.
2. Spitter stops at ~140 px.
3. Pressing a debug key calls `take_damage(999)` on all enemies — they despawn and `GameEvents.enemy_killed` fires for each.
