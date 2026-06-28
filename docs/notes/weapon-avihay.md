---
id: weapon-avihay
title: Weapon — Avihay's "Chat Spam" Signature Ability
tags: [weapons, avihay, bubble, projectile, homing, evolution]
links:
  - "[[weapon-system]]"
  - "[[evolution-rule]]"
  - "[[enemy]]"
created: 2026-06-28
---

# Avihay — Chat Spam

Avihay's signature ability fires **message-bubble projectiles** (Area2D) toward the nearest enemy
in a directional spread. Each bubble pierces through enemies, dealing damage to each one it passes
through before expiring. Scaling per level adds more bubbles, more pierce, and higher damage.

## Files

| File | Role |
|---|---|
| `weapons/bubble.gd` | `Bubble extends Area2D` — projectile logic |
| `weapons/bubble.tscn` | Scene: Area2D root + CircleShape2D (r=8 px) |
| `weapons/avihay_chat_spam.gd` | `AvihayChatSpam extends Weapon` — all spawning logic |
| `weapons/avihay_chat_spam.tscn` | Scene: Node2D root (no child nodes required) |

## Tuned Values

### AvihayChatSpam

| Parameter | Level 1 | Per level | Notes |
|---|---|---|---|
| `base_cooldown` | 2.0 s | — | Divided by `stats.fire_rate_mult` |
| `bubble_count` | 3 | +1 | Bubbles per fire() activation |
| `bubble_damage` | 15 | +5 | Multiplied by `stats.damage_mult` at fire time |
| `bubble_pierce` | 1 | +1 | How many enemies each bubble can pass through |
| `SPREAD_HALF_ANGLE` | 45° (TAU/8) | — | Const; half-width of the fire cone |
| `MAX_LEVEL` | 5 | — | Const; used by `is_max_level()` |

### Bubble

| Parameter | Value | Notes |
|---|---|---|
| `SPEED` | 220 px/s | Const travel speed |
| `MAX_LIFETIME` | 4.0 s | Auto-despawn after this duration |
| Collision layer | 4 | Bubble physics layer |
| Collision mask | 2 | Enemy CharacterBody2D layer |

## Lifecycle

Follows the [[weapon-system]] contract exactly:

```
add_child(weapon)  →  _ready() sets base_cooldown = 2.0, calls super()
                       loads bubble.tscn; Timer created+connected; does NOT start
setup(player, stats)  →  player ref stored, stats assigned, timer started
fire() every 2s / fire_rate_mult  →  spawn bubble_count bubbles in spread cone
level_up()  →  bubble_count, bubble_pierce, bubble_damage all grow
evolve()  →  evolved=true; _homing_mode=true; fire() switches to 360° dense pattern
```

### Bubble lifecycle

```
Weapon.fire()  →  instantiate Bubble, add_child to spawn_parent, call bubble.setup()
setup()  →  stores direction/damage/pierce/homing; connects body_entered
_physics_process(dt)  →  calls _advance(dt) every frame
_advance(dt)  →  ticks lifetime; steers if homing; translates position
body_entered  →  calls _on_hit(enemy)
_on_hit()  →  guard double-hit; call take_damage; decrement pierce; queue_free if 0
```

## Fire Pattern

### Non-evolved (Chat Spam)

Finds the nearest enemy via `get_nodes_in_group("enemies")`. Spawns `bubble_count` bubbles
spread across a cone of ±`SPREAD_HALF_ANGLE` (45°) around that direction. When there are
no enemies, falls back to `Vector2.RIGHT`.

### Evolved (Reply-All Apocalypse)

Spawns `bubble_count × 2` bubbles in a uniform 360° ring (step = TAU / total).
Every bubble has `homing = true`, causing it to steer toward the nearest enemy at 5 rad/s
angular velocity per second. The screen fills with tracking messages.

## Double-Hit Guard

Each `Bubble` instance holds a `_hit_enemies: Array[Node]` set. When `_on_hit(enemy)` is
called, the enemy is checked against this set. If already present, the call is a no-op.
This ensures one bubble instance can hit each enemy at most once, regardless of how many
physics frames the enemy overlaps the bubble's CollisionShape2D.

## Homing Steering

In `_advance(dt)`, if `_homing` is true:
```gdscript
var to_enemy := (nearest.global_position - global_position).normalized()
_direction = _direction.lerp(to_enemy, 5.0 * dt).normalized()
```
This gives a smooth turn rate; the bubble cannot instantly reverse direction. At `dt=0.016`
(60 fps), it turns ~8 % of the angular gap per frame, producing a gentle homing arc.

## Testability Design

`Bubble._advance(dt)` and `Bubble._on_hit(enemy)` are public methods that the physics
callbacks (`_physics_process` and `body_entered`) also call. Tests drive these directly,
avoiding reliance on the physics engine:

- Movement tested via `_advance(dt)` → check `position` delta.
- Pierce and damage tested via `_on_hit(stub_enemy)` where `stub_enemy` is an inline
  `StubEnemy extends Node2D` that records `take_damage` calls.

Physics overlap (bubbles physically hitting `Enemy` CharacterBody2D nodes in a live scene)
is **manual-only**.

`AvihayChatSpam._get_fire_directions()` is also public, allowing tests to verify direction
count and unit-vector correctness without triggering `fire()` (which requires a player node
and live spawn parent).

## Placeholder Visual

`bubble.tscn` now contains a child `ColorRect` (`BubbleVisual`) sized 16 × 16 px (matching the Circle radius of 8 px) tinted blue (Color 0.3, 0.5, 1.0, 0.85). The rect is centered on the bubble origin and is visible for the full lifetime of the projectile — no script changes required since the bubble despawns via `queue_free()` when its pierce count hits zero or its lifetime expires.

This is a placeholder shape; it will be replaced by a sprite in a later milestone.

## Manual Smoke Tests

- Place Avihay weapon on player; confirm 3 bubbles fire per ~2 s toward the nearest enemy
  in a 90° spread cone; bubbles travel and despawn after 4 s.
- Confirm bubbles call `take_damage` on enemies they pass through; pierce=1 means each
  bubble dies on the first hit.
- `level_up()` 4 times: bubble count rises to 7, pierce to 5.
- `evolve()`: fire pattern becomes a dense 360° ring of 14 homing bubbles that curve
  toward enemies — "Reply-All Apocalypse".

## VFX Layer (Task C2)

Two pure-visual additions to `Bubble` — no logic changed.

### Travel Trail (`_trail`)

A `CPUParticles2D` created at the end of `setup()` and added as a child of the Bubble
node. Emits continuously (`one_shot = false`) while the bubble is alive, leaving a light
blue vapour streak behind it.

| Property | Normal | Evolved (homing) |
|---|---|---|
| `amount` | 6 | 12 |
| `lifetime` | 0.3 s | 0.3 s |
| `color` | `Color(0.5, 0.7, 1, 0.5)` | same |
| `spread` | 90° | 90° |

When `setup()` is called with `homing = true` (evolved mode), `_trail.amount` is
immediately set to 12 for a denser streak.

### Hit Pop (`_spawn_hit_pop`)

When a bubble's pierce count drops to 0, `_spawn_hit_pop()` is called **before**
`queue_free()`. It instantiates `vfx/death_pop.tscn` at the bubble's `global_position`
and adds it to the bubble's parent — producing the same warm-orange burst as enemy death.
The pop auto-frees itself via `SceneTreeTimer` (same as `DeathPop`).

## Links

- [[weapon-system]] — base class contract, cooldown formula, lifecycle hooks
- [[evolution-rule]] — when evolve() is triggered by the upgrade system
- [[enemy]] — `take_damage(amount)` method and `"enemies"` group contract
