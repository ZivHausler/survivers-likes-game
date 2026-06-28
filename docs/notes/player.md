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
├── ColorRect       (16×16, centered at origin; tinted from CharacterData.color — fallback only)
├── Sprite          (AnimatedSprite2D, scale 2×, hidden by default; shown when CharacterData.sprite_frames is set)
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
| `xp_to_next(lvl: int) -> int` | `func` | XP curve: `5 + lvl*3 + lvl²*2` (superlinear) |

## XP curve

Superlinear (quadratic) formula: `5 + lvl*3 + lvl²*2`. Each level requires
progressively more XP — the game gets harder over time.

| Level | XP to next |
|---|---|
| 1 | 10 |
| 2 | 19 |
| 3 | 32 |
| 5 | 70 |
| 10 | 235 |
| n | 5 + n*3 + n²*2 |

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

## Sprite + procedural bob (Task B1)

`setup(data)` checks `data.sprite_frames`:
- **Set**: assigns to `$Sprite.sprite_frames`, calls `play("idle")`, shows `$Sprite`, hides `ColorRect`.
- **Null**: sets `ColorRect.color = data.color`, hides `$Sprite`. All existing tests use this path.

`_physics_process` drives a **procedural bob** on `$Sprite` when the sprite is visible:
- **Moving** (`velocity.length_squared() > 1`): accumulates `_bob_t` and applies `sin(_bob_t)*2px` vertical oscillation plus a slight squash/stretch (±6%/8% on x/y scale). `flip_h` follows `velocity.x` sign.
- **Idle**: resets `position.y` and `scale` to neutral; `_bob_t` resets to 0.

The bob is purely visual — velocity, collision, and stats are never altered.

Character tiles used (Kenney Tiny Dungeon, CC0):
- **Ziv**: `art/characters/Tiles/tile_0084.png` — purple-robed mage
- **Avihay**: `art/characters/Tiles/tile_0108.png` — green-armored character

SpriteFrames resources: `characters/ziv_frames.tres`, `characters/avihay_frames.tres`
(each has "idle" and "walk" animations, both using the single static tile — no multi-frame strip available).

## Related

- [[weapon-system]] — Weapon base class and timer lifecycle contract
- [[game-events]] — Signal bus: `player_hp_changed`, `player_leveled_up`, `player_died`
- [[stat-block]] — `StatBlock` resource: `max_hp`, `move_speed`, `pickup_range`, `armor`
- [[character-data]] — `CharacterData` resource passed to `setup()`
