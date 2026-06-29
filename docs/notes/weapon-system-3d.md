# Weapon3D — 3D Weapon Base Class

**File**: `core/weapon_3d.gd`  
**Class**: `Weapon3D extends Node3D`  
**Task**: 1.4a — Weapons → 3D

## Overview

Port of the 2D `Weapon` base class onto `Node3D`. Behavior and public API are
identical; the only change is the inheritance (`Node3D` instead of `Node2D`).

All 3D gameplay takes place on the **XZ plane** (Y up). Spatial constants in
subclasses are scaled from the original 2D pixel values using **1 world unit ≈ 16 px**.

## Lifecycle

1. `_ready()` — creates `Timer`, connects `timeout → _fire_internal()`.  Does
   **not** call `_refresh_cooldown()` because `stats` is null at that point.
2. `setup(player, stats)` — stores `stats`, calls `_refresh_cooldown()`, starts
   the timer.
3. `_fire_internal()` — timer wrapper; emits `GameEvents.skill_cast` then calls `fire()`.
4. `fire()` — no-op in base; subclasses override.  Calling it directly (e.g. in tests) skips the cast signal.
5. `level_up()` — increments `level`, calls `_refresh_cooldown()`.
6. `evolve()` — sets `evolved = true`; subclasses call `super()` then add
   behavior.
7. `refresh_cooldown()` — public wrapper, delegates to `_refresh_cooldown()`.
8. `apply_passive(value)` — virtual no-op; subclasses override.

## VFX fields (Task 4.5)

```gdscript
var vfx_id: StringName = &""       # label for effect routing; archetypes set defaults
var vfx_color: Color = Color(1,1,1) # tint applied to cast/hit particles
```

The timer → `_fire_internal()` → `skill_cast` → `fire()` chain gives every
subclass cast VFX for free.  See [[skill-vfx]] for full details.

## Cooldown formula

```
timer.wait_time = max(0.05, base_cooldown / stats.fire_rate_mult)
```

The 0.05 s floor prevents runaway fire rates from passive stacking.

## Subclasses

- `ZivStunningLooks3D` — Area3D beam + XZ charm sorting (`weapons/ziv_stunning_looks_3d.gd`)
- `AvihayChatSpam3D` — XZ bubble spread with homing evolution (`weapons/avihay_chat_spam_3d.gd`)
