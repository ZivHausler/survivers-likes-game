---
id: enemy-3d
title: "Enemy3D — 3D Enemy Actor (CharacterBody3D)"
tags: [enemy, 3d, character-body-3d, steering, contact-damage, xz-plane]
links: [enemy, game-events, player-3d, arena-3d]
---

# Enemy3D — 3D Enemy Actor (CharacterBody3D)

`Enemy3D` (`res://enemies/enemy_3d.gd`) is the 3D port of [[enemy]].
It steers toward a `Node3D` target on the **XZ plane** (Y up), deals contact
damage on proximity, and emits `GameEvents.enemy_killed_3d` on death.

The 2D `Enemy` (`CharacterBody2D`) is **not removed** — both coexist during the
transition; 2D cleanup is a later task.

## Scene

`res://enemies/enemy_3d.tscn` — `CharacterBody3D`, group `"enemies"`.

| Child | Type | Purpose |
|-------|------|---------|
| `CollisionShape3D` | `SphereShape3D` r=0.5 | Physics body |
| `Model` | `Node3D` | Model root; Phase 2 swaps real mesh in |
| `Model/MeshInstance3D` | `SphereMesh` r=0.5 | Placeholder; tinted by `data.color` |

**Collision**: `layer = 8` (physics layer 4 — dedicated enemy layer, separate from player layer 1 so XP gem pickup can target the player cleanly), `mask = 0` (enemies pass through each other — swarm).

## Script API

### `setup(p_data: EnemyData, p_target: Node3D)`
Store data/target, set `hp = data.max_hp`, tint placeholder mesh by `data.color`.

### `charm(duration: float)`
Suppress movement for `duration` seconds. Stacks by taking the max remaining time.

### `take_damage(amount: float)`
Reduce hp; on `hp <= 0` emit `GameEvents.enemy_killed_3d(global_position, xp_value)`
and `queue_free()`. No hit-flash yet (Task 1.5 Juice).

### `static steer_velocity(from, to, speed) -> Vector3`
Pure XZ steering helper: returns normalized direction × speed with `y = 0`.
Used inside `_physics_process` and independently unit-tested.

## Tuning Constants

| Constant | Value | Replaces 2D |
|----------|-------|-------------|
| `RANGED_STANDOFF` | `6.0` world-units | 140 px |
| `CONTACT_RANGE` | `1.5` world-units | `radius + 12` px |

Both are marked playtest-tunable in the source.

## EnemyData Resources

Reuses existing `swarmer.tres`, `spitter.tres`, `tank.tres` as-is.
The `texture` field (Texture2D) is simply unused in 3D — real models wired in Phase 2.

## Signals Emitted

| Signal | Bus | Consumed by |
|--------|-----|-------------|
| `enemy_killed_3d(position: Vector3, xp_value: int)` | `GameEvents` | XP gem spawner (Task 1.4) |

## Related

- [[enemy]] — 2D counterpart (CharacterBody2D); logic mirrored verbatim
- [[game-events]] — signal bus; `enemy_killed_3d` added additively
- [[player-3d]] — `Node3D` target; exposes `take_damage(float)`
