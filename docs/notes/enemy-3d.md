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
| `NavigationAgent3D` | `NavigationAgent3D` | RVO avoidance (`avoidance_enabled=true`, `radius=0.6`, `max_speed=12.0`) |

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

## RVO Avoidance (Task 7)

Enemies carry a `NavigationAgent3D` (`_agent`) so the swarm locally avoids the
`NavigationObstacle3D`s on props/walls/water (Tasks 2, 5, 6) and each other,
instead of piling up. The agent's `velocity_computed` signal is connected to
`_on_velocity_computed` in `_ready()`.

**Critical synchronous-velocity invariant.** RVO computes the collision-free
velocity *asynchronously* (the navigation server emits `velocity_computed` during
the physics step). But the unit tests call `_physics_process(dt)` and then read
`velocity` *synchronously* (charm → `Vector3.ZERO`; post-charm → `+X`). To keep
both working:

- `_physics_process` still assigns `velocity` synchronously exactly as before
  (compute desired velocity / `steer_velocity` and set `velocity`), then calls
  `_apply_movement(dt)` **in place of** the old `move_and_slide()`.
- `_apply_movement(dt)`: when an avoidance agent is present, enabled, **and** the
  node is inside the tree, it calls `_agent.set_velocity(velocity)` so the real
  move is routed through avoidance. The `velocity_computed(safe_velocity)`
  callback (`_on_velocity_computed`) then sets `velocity = safe_velocity` and
  calls `move_and_slide()`.
- Fallback: no agent, or **not** inside the tree (headless unit tests), it calls
  `move_and_slide()` directly — preserving the original behavior so the synchronous
  `velocity` reads still pass.

Never remove the synchronous `velocity = ...` assignments in `_physics_process`;
`test_enemy_3d.gd` and `test_enemy_3d_avoidance.gd` lock this in.

**No-freeze fallback (zero safe-velocity guard).** Godot's RVO only produces a
non-zero `safe_velocity` when its navigation map is *active* and the avoidance
simulation runs — which requires a `NavigationRegion3D` in the scene (the arena adds
one: see `arena-scatter.md`) and never happens in headless. If `velocity_computed`
returns a ~zero velocity (below `AVOID_EPSILON_SQ`) while the desired velocity is
real, `_on_velocity_computed` *keeps the desired velocity* instead of zeroing it, so
enemies never freeze; a meaningful safe velocity is still adopted (avoidance steers).
This was a freeze regression: without the guard, an inactive nav map zeroed every
enemy's velocity. `test_enemy_3d_avoidance.gd` covers both the unit guard and an
end-to-end "enemy actually moves over physics frames" check.

### First-frame warmup fallback (FIX 1)

The NavigationServer takes one or more frames to join a newly spawned agent to a
navigation map before it starts emitting `velocity_computed`. Until the first
callback fires, `_avoidance_active` is `false`. While false, `_apply_movement`
calls **both** `_agent.set_velocity()` (to start the handshake) **and**
`move_and_slide()` directly (so the enemy moves with its desired velocity rather
than freezing). Once `_on_velocity_computed` is received for the first time,
`_avoidance_active` is set `true` and the direct `move_and_slide()` call is
suppressed — only the callback moves the character, preventing double-moves in
the steady state.

### Stale-velocity callback guard (FIX 2)

`_on_velocity_computed` returns early (no-op) when `data == null`. This guards
against a queued callback arriving before `setup()` or after the enemy is freed.

### max_speed coupling (FIX 3)

`setup()` raises `_agent.max_speed` to `max(current, data.move_speed)` so fast
enemies (move_speed > tscn default 12.0) are not RVO-clamped. Guarded for null
agent / null data.

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
