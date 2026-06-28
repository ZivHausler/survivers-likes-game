---
id: stat-block
title: StatBlock — Character Statistics Resource
tags: [data, resource, stats]
links: [[character-data]], [[data-driven-characters]]
---

# StatBlock

`StatBlock` is a `Resource` subclass (`class_name StatBlock`) that holds all numerical statistics for a character or enemy. It is the single source of truth for scaling values consumed by the weapon, movement, and upgrade systems.

## File

`res://core/stat_block.gd`

## Exported Fields

| Field | Type | Default | Meaning |
|-------|------|---------|---------|
| `max_hp` | `float` | `100.0` | Maximum hit points |
| `move_speed` | `float` | `120.0` | Base movement speed (px/s) |
| `pickup_range` | `float` | `48.0` | Radius for auto-collecting pickups (px) |
| `damage_mult` | `float` | `1.0` | Multiplier applied to all outgoing damage |
| `fire_rate_mult` | `float` | `1.0` | Multiplier that reduces weapon cooldown (`cooldown / fire_rate_mult`) |
| `armor` | `float` | `0.0` | Flat damage reduction applied before HP loss |

## API

```gdscript
func duplicate_stats() -> StatBlock
```

Returns a deep copy of this resource (`duplicate(true)`). Use this when giving a run-time character their own mutable stat block so upgrades don't mutate the base asset.

## Usage Pattern

```gdscript
var live_stats: StatBlock = character_data.base_stats.duplicate_stats()
```

Upgrades modify `live_stats`; the original `base_stats` on the `CharacterData` asset remains untouched.

## Links

- [[character-data]] — `CharacterData.base_stats` is typed `StatBlock`
- [[data-driven-characters]] — How `StatBlock` fits into the character roster model
- [[weapon-system]] — Weapon timer reads `stats.fire_rate_mult`
