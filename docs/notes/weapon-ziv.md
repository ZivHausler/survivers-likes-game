---
id: weapon-ziv
title: Weapon — Ziv's "Stunning Looks" Signature Ability
tags: [weapons, ziv, charm, evolution]
links:
  - "[[weapon-system]]"
  - "[[evolution-rule]]"
  - "[[enemy]]"
created: 2026-06-28
---

# Ziv — Stunning Looks

Ziv's signature ability fires a **piercing rainbow beam** and **charms** nearby enemies, freezing them in place momentarily.

## Files

| File | Role |
|---|---|
| `weapons/ziv_stunning_looks.gd` | `ZivStunningLooks extends Weapon` — all logic |
| `weapons/ziv_stunning_looks.tscn` | Scene: root Node2D + `Beam` Area2D (400×16 px) + `CharmField` Area2D (r=150 px) |

## Tuned Values

| Parameter | Level 1 | Per level | Notes |
|---|---|---|---|
| `base_cooldown` | 3.0 s | — | Divided by `stats.fire_rate_mult` |
| `beam_damage` | 25 | +10 | Multiplied by `stats.damage_mult` at fire time |
| `charm_count` | 2 | +1 | Max enemies charmed per activation |
| `charm_duration` | 2.0 s | +0.5 s | How long each charmed enemy is frozen |
| `charm_radius` | 150 px | +20 px | Pixel radius for charm target selection |
| `MAX_LEVEL` | 5 | — | Const; used by `is_max_level()` |

## Lifecycle

Follows the [[weapon-system]] contract exactly:

```
add_child(weapon)  →  _ready() sets base_cooldown = 3.0, calls super()
                       timer created + connected; Beam monitoring ON;
                       CharmField monitoring OFF
setup(player, stats)  →  stats assigned, timer started
fire() every 3s / fire_rate_mult  →  beam damage + charm N nearest enemies
level_up()  →  beam_damage, charm_count, charm_duration, charm_radius all grow
evolve()  →  evolved=true; CharmField turned ON with body_entered auto-charm;
             beam rotation starts in _process()
```

## Beam Hitbox

`Beam` is an `Area2D` with a `RectangleShape2D` (400 × 16 px, horizontal, centered on player).  Monitoring stays on at all times so `get_overlapping_bodies()` is populated before `fire()` queries it.

## CharmField

`CharmField` is an `Area2D` with a `CircleShape2D` (radius 150 px).  It starts **off** (monitoring=false) and is activated only by `evolve()`.  Once on, it connects `body_entered` to auto-charm any enemy that walks in.

## Evolution — "Absolutely Fabulous"

Calling `evolve()`:
1. Sets `evolved = true` (base class).
2. Enables `CharmField` monitoring + connects `body_entered`.
3. Starts rotating the Beam Area2D at `TAU / 3` rad/s (~120°/s) via `_process()`.

The rotating beam continuously sweeps through overlapping enemies; the always-on CharmField keeps every enemy that enters radius frozen.

## Charm Mechanic

`charm(duration)` is added to `Enemy` in `enemies/enemy.gd`. It sets `_charm_timer = max(_charm_timer, duration)`.  While `_charm_timer > 0`, `_physics_process` zeroes velocity and returns early, completely suppressing steering and contact-damage.

See [[enemy]] for the full API.

## Placeholder Visuals

Both hitbox areas now carry a child `ColorRect` so attacks are visible at runtime:

| Node | Visual | Color |
|---|---|---|
| `Beam/BeamVisual` | ColorRect 400 × 16 px, centered on beam origin | Hot-pink, 90 % opacity |
| `CharmField/CharmFieldVisual` | ColorRect 300 × 300 px, centered | Translucent pink, 12 % opacity |

**Visibility rules (driven by `ziv_stunning_looks.gd`):**

- `_ready()` hides both visuals so nothing is drawn before the first fire.
- `fire()` (non-evolved) calls `_flash_beam()`: shows `BeamVisual` for 0.3 s then re-hides it.
- `evolve()` calls `_beam_visual.show()` and `_charm_field_visual.show()` so both stay permanently visible while the weapon is in evolved state (beam rotates, CharmField is always-on).

These are placeholder shapes — they are intentionally simple rectangles to aid debugging and will be replaced by artist-created sprites in a later milestone.

## Manual Smoke Tests

- Spawn Ziv + cluster of enemies; confirm beam flashes once every ~3 s and enemies in the beam line lose HP.
- Confirm 2 nearest enemies freeze for 2 s.
- `level_up()` four times then `evolve()`: beam sweeps continuously; enemies entering the 150 px radius pause immediately.

## Links

- [[weapon-system]] — base class contract, cooldown formula
- [[evolution-rule]] — when evolve() is triggered by the upgrade system
- [[enemy]] — `charm(duration)` method added by this task
