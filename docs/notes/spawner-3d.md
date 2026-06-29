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
| `apply_model_tint(node, tint)` | Texture-preserving tint: recurses MeshInstance3D children, duplicates each active material, sets `albedo_color` |
| `xp_time_mult(elapsed) -> float` | XP growth factor: `1.0 + elapsed/120.0` (+100% per 2 min) |

All factory helpers **duplicate()** the source resource — the shared `.tres` is never mutated.

## XP growth over run time

`_spawn_normal` scales the duplicated enemy's `xp_value` by `xp_time_mult(_elapsed)`:

```gdscript
scaled_data.xp_value = maxi(base_xp, int(round(float(base_xp) * xp_time_mult(_elapsed))))
```

- At `t=0 s`: multiplier = 1.0 — enemy awards its base XP (e.g. swarmer = 1 XP → blue orb).
- At `t=120 s`: multiplier = 2.0 — swarmer awards 2 XP (still blue, but approaching green boundary).
- At `t=240 s`: multiplier = 3.0 — swarmer awards 3 XP → **green orb** appears naturally.
- Boss/big-boss XP stays fixed at 50/200 (already in the top tier).

## Boss model (Phase 2)

Both mini-boss and big-boss use the **undead serpent** GLB (`art/enemies_3d/undead_serpent/serpent_mesh.glb`)
instead of the diatryma tank model, so bosses look visually distinct and imposing.

- Mini-boss: serpent at `model_scale = 1.5`, node `scale = BOSS_SCALE_MULT (3×)`
- Big boss: serpent at `model_scale = 2.0`, node `scale = BIG_BOSS_SCALE_MULT (5×)`

## Boss tinting (Phase 2 — texture-preserving)

`apply_model_tint()` is called after `enemy.setup()` so the model is already instantiated.
It recursively finds every `MeshInstance3D` under `Model`, duplicates each surface's active
material (so the original GLB material is never mutated), and sets `albedo_color` to the tint.

- Mini-boss: `Color(1, 0.15, 0.1)` (red tint over serpent texture)
- Big boss: `Color(0.5, 0, 1)` (purple tint over serpent texture)

## Setup

```gdscript
spawner.setup(player: Node3D)
```

Loads scenes/resources, activates `_process`. Call from `GameManager3D.start()`.

## See also

- [[spawner]] — 2D original
- [[difficulty-timeline]] — DifficultyTimeline (reused unchanged)
- [[game-manager-3d]] — wires Spawner3D in the run loop
