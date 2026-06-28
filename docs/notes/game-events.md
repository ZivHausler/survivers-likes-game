---
id: game-events
title: "GameEvents — Global Signal Bus"
tags: [autoload, signals, event-bus, architecture]
links: [run-state, data-driven-characters, adr-godot]
---

# GameEvents — Global Signal Bus

`GameEvents` is an autoload singleton (`res://autoload/game_events.gd`).
Systems **emit** and **connect** here instead of holding direct references to
each other. This is the primary decoupling mechanism in Friends Swarm.

See [[adr-godot]] for why the Godot node/signal model was chosen.

## Signals

| Signal | Parameters | Who emits | Who listens |
|--------|-----------|-----------|-------------|
| `enemy_killed` | `position: Vector2, xp_value: int` | Enemy death handler | XP system, score HUD |
| `xp_collected` | `amount: int` | XP orb on body_entered | Level-up system |
| `player_leveled_up` | `level: int` | Level-up system | HUD, evolution check |
| `player_hp_changed` | `current: float, max_hp: float` | Player HP component | HP bar HUD |
| `player_died` | _(none)_ | Player HP component | Game over screen |
| `evolution_unlocked` | `weapon_id: StringName` | Evolution checker | Weapon manager |

## Usage pattern

```gdscript
# Emit (from any system):
GameEvents.enemy_killed.emit(global_position, xp_value)

# Connect (in _ready or via editor):
GameEvents.player_leveled_up.connect(_on_level_up)
```

## Related

- [[run-state]] — persists run score across scenes; listens to `enemy_killed`.
- [[data-driven-characters]] — `evolution_unlocked` carries the `weapon_id` from `CharacterData`.
