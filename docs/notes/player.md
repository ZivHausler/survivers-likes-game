---
id: player
title: Player
tags: [system, core-actor]
---

# Player

`Player` (`CharacterBody2D`) is the core actor the human controls.
Source: `res://player/player.gd` | Scene: `res://player/player.tscn`

## Scene structure

```
Player (CharacterBody2D, group "player")
├── ColorRect  (16×16, centered at origin; tinted from CharacterData.color)
├── Camera2D
└── Hurtbox (Area2D)
    └── CollisionShape2D (RectangleShape2D 16×16)
```

## Public API

| Symbol | Type | Description |
|---|---|---|
| `setup(data: CharacterData)` | `func` | Apply stats, spawn weapon, emit initial `player_hp_changed` |
| `weapon` | `Weapon` | The instanced signature weapon (null until `setup` called) |
| `level` | `int` | Current player level (starts 1) |
| `xp` | `int` | XP accumulated toward next level |
| `hp` | `float` | Current HP |
| `add_xp(amount: int)` | `func` | Add XP, auto-level-up with carry-over remainder |
| `take_damage(amount: float)` | `func` | Subtract `max(0, amount − armor)` from HP; emit death if hp ≤ 0 |
| `get_pickup_range()` | `func` | Returns `stats.pickup_range` (read by [[XPGem]]) |
| `xp_to_next(lvl: int) -> int` | `func` | XP curve: `5 + lvl * 5` |

## XP curve

| Level | XP to next |
|---|---|
| 1 | 10 |
| 2 | 15 |
| 3 | 20 |
| … | … |
| n | 5 + n*5 |

## Signals emitted (via [[game-events]])

- `player_hp_changed(current: float, max_hp: float)` — on `setup()` and every `take_damage()`
- `player_leveled_up(level: int)` — once per level gained inside `add_xp()`
- `player_died()` — when HP drops to or below 0

## Movement

WASD + Arrow keys via `Input.get_vector("move_left","move_right","move_up","move_down")`.
Input actions are registered in `project.godot [input]` section.
Speed = `stats.move_speed` (default 120 px/s from [[stat-block]]).

## Weapon lifecycle

`setup()` guards with `if data.weapon_scene:` before instantiating, so a bare
`CharacterData` with no weapon is safe for testing. When a weapon exists:
1. `add_child(weapon)` — weapon's `_ready()` creates its timer
2. `weapon.setup(self, stats)` — timer starts; see [[weapon-system]] for full lifecycle

## Related

- [[weapon-system]] — Weapon base class and timer lifecycle contract
- [[game-events]] — Signal bus: `player_hp_changed`, `player_leveled_up`, `player_died`
- [[stat-block]] — `StatBlock` resource: `max_hp`, `move_speed`, `pickup_range`, `armor`
- [[character-data]] — `CharacterData` resource passed to `setup()`
