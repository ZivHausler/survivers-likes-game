---
id: spawner
title: Spawner
tags: [spawning, scene]
links: [[difficulty-timeline]], [[enemy]]
---

# Spawner

`spawning/spawner.gd` — `class_name Spawner extends Node2D`  
Scene: `spawning/spawner.tscn`

## Responsibilities

- Accumulates elapsed run time (`_elapsed`).
- Queries [[difficulty-timeline]] each frame; spawns enemies when `_spawn_cd` expires.
- Instances `enemies/enemy.tscn`, positioned on a ring of radius 400 px around the target.
- Spawns one mini-boss per 180 s window when `boss_due` is true.
- Spawns a single big boss at t=600 (10 min) when `big_boss_due` is true.
- Scales normal enemy HP and size with time using `hp_mult` and `enemy_scale` from the timeline.

## API

```gdscript
setup(target: Node2D) -> void
```

Call once after adding Spawner to the scene tree. Passing a new target restarts the timeline.

## Normal Enemy Growth

Each normal spawn duplicates the variant resource and applies time-based scaling:

- **HP**: `scaled_data.max_hp *= hp_mult`  (see [[difficulty-timeline]] for formula)
- **Scale**: `_instance_enemy(scaled_data, enemy_scale)`

The shared `.tres` resource is never mutated — always `.duplicate()` first.

## Mini-Boss

A `tank` variant (loaded from `enemies/tank.tres`) with:
- HP multiplied by **8× × hp_mult** (`BOSS_HP_MULT = 8.0`, then scaled by current hp_mult)
- Visual scale multiplied by **3×** (`BOSS_SCALE_MULT = 3.0`)
- XP value set to **50** (`BOSS_XP_VALUE = 50`)
- Red tint (`Color(1.0, 0.15, 0.1)`) on the Sprite node

Fires every **180 s** (changed from 300 s — more frequent mini-bosses for difficulty ramp).

## Big Boss (10-Minute)

A single very tough enemy spawned **once** at t=600 (10 minutes):

| Constant             | Value |
|----------------------|-------|
| `BIG_BOSS_HP_MULT`   | 40.0  |
| `BIG_BOSS_SCALE_MULT`| 5.0   |
| `BIG_BOSS_XP_VALUE`  | 200   |

HP formula: `base_tank_hp × BIG_BOSS_HP_MULT × hp_mult`  
At t=600, hp_mult≈6, so effective HP is base×240 — very menacing.

Visual: deep purple tint (`Color(0.5, 0.0, 1.0)`) to distinguish from mini-bosses.

The resource is `.duplicate()`-d before mutation so the shared `.tres` is not modified.

## Spawn Ring

Enemies appear at `target.global_position + Vector2(cos(θ), sin(θ)) * 400` where `θ` is random.  
This keeps enemies off-screen on a typical 1280×720 viewport but they converge on the player.

## Manual Verification Required

The following cannot be unit-tested headlessly and requires an interactive playtest scene:

1. Enemies visually stream toward the player and increase in frequency over ~4 minutes.
2. Enemies visibly grow in size and toughness as time progresses.
3. A red tank (3× scale) appears near each 3-minute mark.
4. A giant purple tank (5× scale) appears at the 10-minute mark.
5. Spitters appear after 2 minutes and maintain standoff distance from the player.
6. The game remains playable at peak density (t ≥ 240 s, 0.25 s interval).

**Playtest setup**: arena throwaway scene — `Node2D` root, add `Player.tscn`, add `Spawner.tscn`, call `$Spawner.setup($Player)` in `_ready()`. Temporarily set `BOSS_PERIOD = 30.0` and `BIG_BOSS_THRESHOLD = 60.0` in `difficulty_timeline.gd` to test bosses fast, then restore.

See [[difficulty-timeline]] for the tested pure-logic layer.
