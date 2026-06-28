---
id: xp-gem
title: XPGem — Pickup with Magnet Movement
tags: [system, pickup, xp, area2d]
links: [player, game-events]
---

# XPGem

`XPGem` (`Area2D`) is a collectible pickup that magnets toward the [[player]] when
within pickup range and awards XP on overlap.
Source: `res://pickups/xp_gem.gd` | Scene: `res://pickups/xp_gem.tscn`

## Scene structure

```
XPGem (Area2D, group "pickups")
├── Body        (ColorRect 12×12, gold #FFD700)
└── CollisionShape2D (CircleShape2D radius=6)
```

## Public API

| Symbol | Type | Description |
|---|---|---|
| `setup(value: int, player: Node2D)` | `func` | Initialise gem value + player ref; connects `body_entered` |
| `_collect()` | `func` | Call player.add_xp, emit xp_collected, free self. Safe to call from tests |

## Magnet behaviour

Each `_process` frame, if `global_position.distance_to(player.global_position) ≤ player.get_pickup_range()`:
- Direction vector toward player is computed.
- Speed is interpolated from 60 px/s (edge of range) to 300 px/s (at player position).
- `global_position` is nudged directly (no physics body — Area2D is a sensor).

## Collection logic

On `body_entered` (player body enters the gem's CollisionShape2D):
1. `_collect()` is called.
2. Guard: `if _collected: return` — prevents double-collection.
3. `player.add_xp(value)` — only if `is_instance_valid(player)`.
4. `GameEvents.xp_collected.emit(value)` — always emitted.
5. `queue_free()` — gem removed from scene.

`_collect()` is public so unit tests can trigger it directly without needing physics.

## Guards

- `_collected: bool` flag prevents duplicate execution if signal fires twice.
- `is_instance_valid(_player)` guards every access to the player reference.
- `_process` short-circuits if `_collected` is true.

## Signals emitted (via [[game-events]])

- `xp_collected(amount: int)` — emitted once per gem, on collection.

## Spawning

Gems are spawned by the game manager when `GameEvents.enemy_killed` fires.
`setup(xp_value, player)` must be called immediately after instantiation.

## Visual pulse (Task B3)

On `_ready`, a looping `Tween` oscillates `scale` between `(0.85, 0.85)` and `(1.15, 1.15)`
at 0.6 s per half-cycle using `TRANS_SINE / EASE_IN_OUT`. This makes the gem appear to
breathe/glow without changing any gameplay logic. The CollisionShape2D scales with the
Area2D (~±0.9 px on a 6 px radius) — negligible for collection.

The gold `ColorRect` ("Body") is retained; no external sprite asset was required.

## Testing

`res://test/test_xp_gem.gd` covers collection logic via `_collect()` directly:
- XP added to stub player
- `xp_collected` signal emitted with correct value
- No double-collection on repeated `_collect()` calls
- Safe with null player reference

Magnet movement is interactive-only (manual playtest).

## Related

- [[player]] — Provides `get_pickup_range()` and `add_xp(amount)`
- [[game-events]] — Signal bus: `xp_collected`
