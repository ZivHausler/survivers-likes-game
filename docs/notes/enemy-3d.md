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

## Phase 2 — Real Monster Models

`Enemy3D.setup()` now checks `data.model_scene`. When set:
1. The `Model/MeshInstance3D` sphere placeholder is hidden.
2. The GLB scene is instanced and added under `Model`; `position.y = data.model_y_offset`.
3. `Model.scale = Vector3.ONE * data.model_scale`.
4. An `AnimationPlayer` is searched in the model instance (`find_child`). If found, `idle` is
   played immediately; `move` plays while moving, `idle` when still. Animation is **best-effort**
   — FBX→GLB mesh-only files rarely embed clips, so enemies display at static rest-pose.
5. `Model` is rotated toward the XZ velocity heading via `face_angle()` each physics frame
   (visual only — collision body stays upright).

When `model_scene` is null (2D .tres without model), the placeholder sphere is tinted by
`data.color` as before.

### Per-variant model assignment (Phase 2)

| Variant  | Model GLB             | `model_scale` | `model_y_offset` |
|----------|-----------------------|---------------|------------------|
| swarmer  | `bug/bug_mesh.glb`    | 1.0           | 0.0              |
| spitter  | `plant_monster/plant_mesh.glb` | 1.0  | 0.0              |
| tank     | `diatryma/diatryma_mesh.glb`   | 1.0  | 0.0              |
| boss     | `undead_serpent/serpent_mesh.glb` | 1.5–2.0 | 0.0         |

All scale/offset values are playtest-tunable directly in the `.tres` files.

## Script API

### `setup(p_data: EnemyData, p_target: Node3D)`
Store data/target, set `hp = data.max_hp`. If `data.model_scene` is set, instances the real
model under `Model` and hides the sphere placeholder; otherwise tints the sphere by `data.color`.

### `charm(duration: float)`
Suppress movement for `duration` seconds. Stacks by taking the max remaining time.

### `take_damage(amount: float)`
Reduce hp; on `hp <= 0` emit `GameEvents.enemy_killed_3d(global_position, xp_value)`
and `queue_free()`. No hit-flash yet (Task 1.5 Juice).

### `static steer_velocity(from, to, speed) -> Vector3`
Pure XZ steering helper: returns normalized direction × speed with `y = 0`.
Used inside `_physics_process` and independently unit-tested.

### `static face_angle(velocity: Vector3) -> float`
Returns Y-axis rotation in radians for the Model node to face the given XZ velocity.
Zero-length velocity returns `0.0` (never NaN). Mirrors `Player3D.face_angle()`.

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
