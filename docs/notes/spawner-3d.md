# Spawner3D

`spawning/spawner_3d.gd` — `class_name Spawner3D extends Node3D`

3D port of `Spawner` (Node2D). Instances `Enemy3D` on a ring around the player target, driven by `DifficultyTimeline`. All gameplay on the XZ plane (Y up).

## World scale

1 world unit ≈ 16 px.

- `SPAWN_RING_RADIUS = 25.0` (was 400 px in 2D)
- `WORLD_SCALE = 1.0 / 16.0` — applied to `move_speed` in every duplicated `EnemyData`

## Pure static helpers (testable without scene tree)

| Helper | Purpose |
|---|---|
| `ring_position(origin, angle, radius) -> Vector3` | Returns point on ring (y=0) |
| `scale_enemy_data(base, hp_mult) -> EnemyData` | Duplicate + HP scale + move_speed /16 |
| `boss_enemy_data(base, hp_mult) -> EnemyData` | Mini-boss: ×8 HP, XP=50, speed /16 |
| `big_boss_enemy_data(base, hp_mult) -> EnemyData` | Big-boss: ×40 HP, XP=200, speed /16 |

All factory helpers **duplicate()** the source resource — the shared `.tres` is never mutated.

## Boss tinting

Instead of `Sprite2D.modulate` (2D), the boss Material is set on `Model/MeshInstance3D.material_override`:
- Mini-boss: `Color(1, 0.15, 0.1)` (red)
- Big boss: `Color(0.5, 0, 1)` (purple)

## Setup

```gdscript
spawner.setup(player: Node3D)
```

Loads scenes/resources, activates `_process`. Call from `GameManager3D.start()`.

## See also

- [[spawner]] — 2D original
- [[difficulty-timeline]] — DifficultyTimeline (reused unchanged)
- [[game-manager-3d]] — wires Spawner3D in the run loop
