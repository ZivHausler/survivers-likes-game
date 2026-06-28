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
- Instances `enemies/enemy.tscn`, positions on a ring of radius 400 px around the target.
- Spawns one mini-boss per 300 s window when `boss_due` is true.

## API

```gdscript
setup(target: Node2D) -> void
```

Call once after adding Spawner to the scene tree. Passing a new target restarts the timeline.

## Mini-Boss

A `tank` variant (loaded from `enemies/tank.tres`) with:
- HP multiplied by **8×**  (`BOSS_HP_MULT = 8.0`)
- Visual scale multiplied by **3×** (`BOSS_SCALE_MULT = 3.0`)

The resource is `.duplicate()`-d before mutation so the shared `.tres` is not modified.

## Spawn Ring

Enemies appear at `target.global_position + Vector2(cos(θ), sin(θ)) * 400` where `θ` is random.  
This keeps enemies off-screen on a typical 1280×720 viewport but they converge on the player.

## Manual Verification Required

The following cannot be unit-tested headlessly and requires an interactive playtest scene:

1. Enemies visually stream toward the player and increase in frequency over ~4 minutes.
2. A large blue tank (3× scale) appears near the 5-minute mark (or earlier if boss threshold is temporarily lowered for testing).
3. Spitters appear after 2 minutes and maintain standoff distance from the player.
4. The game remains playable at peak density (t ≥ 240 s, 0.25 s interval).

**Playtest setup**: arena throwaway scene — `Node2D` root, add `Player.tscn`, add `Spawner.tscn`, call `$Spawner.setup($Player)` in `_ready()`. Temporarily set `BOSS_PERIOD = 30.0` in `difficulty_timeline.gd` to test boss fast, then restore.

See [[difficulty-timeline]] for the tested pure-logic layer.
