---
id: player-3d
title: Player3D
tags: [system, core-actor, 3d]
---

# Player3D

`Player3D` (`CharacterBody3D`) is the 3D version of the player actor.
Source: `res://player/player_3d.gd` | Scene: `res://player/player_3d.tscn`

Built alongside the existing 2D `Player` (Option B migration strategy). The 2D
player is kept intact; Player3D owns all the same logic ported verbatim.

## Scene structure

```
Player3D (CharacterBody3D, group "player", layer=1, mask=0)
├── CollisionShape3D  (CapsuleShape3D radius=0.5, height=2.0)
├── Model (Node3D)    ← visual root; rotated to face movement (collision stays upright)
│   ├── MeshInstance3D (CapsuleMesh placeholder — hidden by setup() when model_scene is set)
│   └── <GLB instance>  (instanced from CharacterData.model_scene, scaled by model_scale)
│       └── AnimationPlayer  (found via find_child; plays "idle" / "walk")
└── Hurtbox (Area3D, layer=2, mask=0)
    └── CollisionShape3D (CapsuleShape3D radius=0.5, height=2.0)
```

No Camera3D inside the player — the camera (`GameCamera3D`) lives in `main_3d.tscn`
and follows the Player3D node via its `target` export.

## Collision layers

| Layer | Who | Purpose |
|---|---|---|
| 1 | Player3D body | XP gems detect the player via body_entered |
| 2 | Hurtbox Area3D | Enemy contact damage (enemy task sets mask to match) |

## Public API

| Symbol | Type | Description |
|---|---|---|
| `setup(data: CharacterData)` | `func` | Apply stats, optionally spawn weapon/model, emit initial `player_hp_changed` |
| `move_to_velocity(dir, speed)` | `static func` | Pure XZ mapping helper; unit-testable without Input/tree |
| `face_angle(velocity: Vector3) -> float` | `static func` | Y-axis heading (radians) for a velocity; returns 0 for zero vector (never NaN) |
| `weapon` | `Weapon` | Null until a 3D weapon scene is wired (future task) |
| `level` | `int` | Current level (starts 1) |
| `xp` | `int` | XP accumulated toward next level |
| `hp` | `float` | Current HP |
| `add_xp(amount: int)` | `func` | Add XP, auto-level-up with carry-over remainder |
| `take_damage(amount: float)` | `func` | Subtract `max(0, amount − armor)`; emit death if hp ≤ 0 |
| `get_pickup_range()` | `func` | Returns `stats.pickup_range` |
| `xp_to_next(lvl: int) -> int` | `func` | XP curve: `5 + lvl*3 + lvl²*2` |
| `apply_stat_upgrade(kind, value)` | `func` | Mutates the matching stat (mirrors 2D Player exactly) |

## Movement mapping

`Input.get_vector("move_left","move_right","move_up","move_down")` → `Vector2 dir`
is mapped to 3D via the static helper:

```
Vector3(dir.x, 0.0, dir.y) * speed
```

"Up" action (dir.y = -1) → -Z (away from the tilted camera). Y is always 0
(XZ-plane movement). The helper is static so it can be unit-tested directly.

## Weapon guard

`setup()` guards weapon instantiation with:
1. `if data.weapon_scene:` — skip if null (safe for tests and main_3d.gd)
2. `if inst is Node3D:` — reject 2D weapons (all current `Weapon` subclasses extend
   `Node2D`); the instantiated node is freed without being added to the tree.

This means `weapon` stays null for the entire vertical slice until 3D weapons exist.

## XP curve

Identical to 2D Player: `5 + lvl*3 + lvl²*2`

| Level | XP to next |
|---|---|
| 1 | 10 |
| 2 | 19 |
| 3 | 32 |
| 5 | 70 |
| 10 | 235 |

## Signals emitted (via [[game-events]])

- `player_hp_changed(current, max_hp)` — on `setup()` and every `take_damage()`
- `player_leveled_up(level)` — once per level gained inside `add_xp()`
- `player_died()` — when HP drops to or below 0

## Model rendering (Task 2.1)

When `CharacterData.model_scene` is set, `setup()`:
1. Hides the capsule `MeshInstance3D` placeholder under `$Model`.
2. Instances the GLB and adds it under `$Model`; applies `model_scale` via `$Model.scale`.
3. Optionally applies `model_tint` (albedo override on all `MeshInstance3D` surfaces).
4. Searches for an `AnimationPlayer` via `find_child("AnimationPlayer", true, false)`
   and plays `"idle"` if found.

In `_physics_process()`:
- When `velocity.length() > WALK_THRESHOLD` (0.05), rotates `$Model.rotation.y` to
  `face_angle(velocity)` and plays `"walk"`.
- Otherwise plays `"idle"`.
- `face_angle()` is `atan2(v.x, v.z)` — a pure static helper that never returns NaN.
- The collision body (CharacterBody3D) is never rotated; only the visual Model node turns.

### Playtest-tunable values

| Variable | Current value | Location | Note |
|---|---|---|---|
| `model_scale` | `1.0` | `ziv_3d.tres` / `avihay_3d.tres` | Kenney GLB native size ≈ 1.8 m; adjust here |
| Model Y offset | `0` | `player_3d.tscn` → Model node position | If feet float, shift Model.position.y down |
| `WALK_THRESHOLD` | `0.05` | `player_3d.gd` const | Raise if idle flickers at rest |

## Wiring in main_3d

`main_3d.gd._ready()` creates a bare `CharacterData` (null weapon_scene, default
`StatBlock`) and calls `_player.setup(cd)`. The `GameCamera3D.target` NodePath in
`main_3d.tscn` points to the Player node — no code wiring needed.

## Related

- [[player]] — 2D counterpart; identical stat/XP/damage logic
- [[game-camera-3d]] — follows Player3D on XZ
- [[game-events]] — signal bus
- [[stat-block]] — numeric stats resource
- [[character-data]] — full friend definition passed to `setup()`
