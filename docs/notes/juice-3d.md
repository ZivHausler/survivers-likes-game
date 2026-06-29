# juice-3d — Juice3D Autoload and 3D VFX Layer

## Overview

`Juice3D` (`autoload/juice_3d.gd`) is the 3D companion to the 2D `Juice` autoload. It connects
to the same `GameEvents` signals and spawns 3D visual feedback without touching any game logic.
Disabling the autoload silently reverts the 3D game to pure gameplay with no visual regression.

## Architecture

The 3D Juice layer follows Option B: a fully separate autoload + new 3D effect scenes, leaving
the 2D `autoload/juice.gd`, `vfx/`, and `fx/` files completely untouched.

### Autoload: `Juice3D`

Registers in `project.godot` as `Juice3D="*res://autoload/juice_3d.gd"`. Connects six signals:

| Signal | Handler | Effects |
|---|---|---|
| `enemy_killed_3d(pos, xp)` | `_on_enemy_killed_3d` | DeathPop3D burst + DamageNumber3D + trauma 0.25 |
| `xp_collected(amount)` | `_on_xp_collected` | Small DeathPop3D burst at player position |
| `player_leveled_up(level)` | `_on_player_leveled_up` | EvolutionFlash overlay (intensity 0.4) |
| `player_hp_changed(current, max)` | `_on_player_hp_changed` | HitFlash3D on player + trauma 0.3 (decrease only) |
| `player_died()` | `_on_player_died` | No-op (death screen handled by GameManager3D) |
| `evolution_unlocked(weapon_id)` | `_on_evolution_unlocked` | Full EvolutionFlash overlay |

`register_player(p: Node3D)` and `register_camera(cam)` are called from `GameManager3D.start()`.

All handlers guard via `_safe_parent()` (returns null if no valid player), so emitting any
signal before registration is a clean no-op.

## 3D Effect Scenes

### `vfx/death_pop_3d.gd` / `death_pop_3d.tscn`
- `class_name DeathPop3D extends GPUParticles3D`
- One-shot orange burst. `play_at(pos: Vector3)` sets position, starts emitting, auto-frees
  after `lifetime + 0.2` seconds.
- Reused for the XP collect sparkle (small gold burst at player position).

### `vfx/damage_number_3d.gd` / `damage_number_3d.tscn`
- `class_name DamageNumber3D extends Label3D`
- Billboard label (no_depth_test=true) that floats upward 1.5 world units and fades out over
  0.8 s, then auto-frees. `setup(value: int, pos: Vector3)`.

### `vfx/hit_flash_3d.gd`
- `class_name HitFlash3D extends Node`
- Stateless static utility. `HitFlash3D.flash(target: Variant, dur: float)` depth-searches
  under `target` for a `MeshInstance3D`, overrides its material with a white emission material,
  then restores the original via a tween after `dur` seconds.
- No-ops safely if: target is freed, target has no mesh, target is null.

### `vfx/evolution_flash.tscn` (reused, dimension-agnostic)
- `class_name EvolutionFlash extends CanvasLayer`
- CanvasLayer renders over the viewport regardless of 2D/3D, so it works unchanged in the 3D
  game. `set_intensity(v)` for the softer level-up variant.

## Camera Shake

`core/game_camera_3d.gd` gained:

- `var _trauma: float = 0.0` — current energy level
- `func add_trauma(amount: float)` — accumulates, clamped [0, 1]
- `static func decay_trauma(trauma: float, dt: float) -> float` — pure helper, testable
- `static func shake_offset(trauma: float, seed_t: float) -> Vector3` — pure helper; returns
  Vector3.ZERO when trauma ≤ 0 so existing camera tests stay green

In `_physics_process`, the smooth-follow base position is stored in `_base_position`; the
shaken world position = `_base_position + shake_offset(...)`. This avoids feeding the shake
offset back into the lerp each frame.

## Wiring (GameManager3D)

`game/game_manager_3d.gd` `start()` now calls:
```gdscript
Juice3D.register_player(_player)
Juice3D.register_camera(cam)  # GameCamera3D sibling node
```

## Enemy Hit-Flash

`enemies/enemy_3d.gd` `take_damage()` now calls `HitFlash3D.flash(self, 0.08)` on non-lethal
hits. Lethal hits still emit `enemy_killed_3d` for Juice3D to handle the death burst.

## Manual Playtest Items

- **Camera shake feel**: trauma values (0.25 on kill, 0.3 on hit) may need tuning; evaluate
  in a real run with multiple enemies.
- **Flash visibility**: the white emission override should pop clearly; check against the
  current enemy materials (colored StandardMaterial3D from EnemyData.color).
- **Damage-number readability**: Label3D size (pixel_size=0.01, font_size=64) over the -55°
  tilted camera may need pixel_size adjustment to read comfortably at typical combat distance.
- **Death pop size**: GPUParticles3D initial_velocity 2–6 units/s may be too subtle at scale;
  compare with 2D DeathPop (40–120 px).
- **XP sparkle distinction**: currently reuses death_pop_3d (orange burst); a dedicated gold
  sparkle scene with different color would improve readability.
