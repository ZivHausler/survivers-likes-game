---
id: character-data
title: CharacterData — Friend Definition Resource
tags: [data, resource, characters]
links: [[stat-block]], [[data-driven-characters]], [[weapon-system]]
---

# CharacterData

`CharacterData` is a `Resource` subclass (`class_name CharacterData`) that completely describes a playable friend. One `.tres` file per character; no per-character code required.

## File

`res://core/character_data.gd`

## Exported Fields

| Field | Type | Default | Meaning |
|-------|------|---------|---------|
| `id` | `StringName` | — | Unique machine identifier (e.g. `&"alex"`) |
| `display_name` | `String` | `""` | Human-readable name shown in UI |
| `color` | `Color` | `Color.WHITE` | Placeholder art tint until sprite is final |
| `base_stats` | `StatBlock` | — | Starting stat values; duplicate before modifying at run-time |
| `weapon_scene` | `PackedScene` | — | The friend's signature weapon scene to instantiate |
| `passive_id` | `StringName` | — | ID of the passive ability associated with this character |
| `evolution_id` | `StringName` | — | ID of the evolved form unlocked at max signature level |
| `max_signature_level` | `int` | `5` | Signature weapon levels before evolution becomes available |
| `model_scene` | `PackedScene` | `null` | Kenney Blocky Character GLB to instance for 3-D play (null → capsule placeholder) |
| `model_scale` | `float` | `1.0` | Uniform scale applied to the Model Node3D after instancing |
| `model_tint` | `Color` | `Color.WHITE` | Optional albedo override to distinguish friends sharing one base model |
| `skills` | `Array[SkillData]` | `[]` | 3D skill roster: 4 `SkillData` entries for 3D characters; 2D characters leave empty — 2D path unaffected. See [[skill-system]]. |

## Usage Pattern

```gdscript
# CharacterSelectScreen (future)
var data: CharacterData = preload("res://data/characters/alex.tres")
var live_stats := data.base_stats.duplicate_stats()
var weapon := data.weapon_scene.instantiate() as Weapon
player.add_child(weapon)           # _ready() runs; _timer created
weapon.setup(player, live_stats)   # stats assigned; timer started
```

## Links

- [[stat-block]] — `base_stats` field type
- [[weapon-system]] — `weapon_scene` is instantiated and set up via `Weapon.setup()`
- [[data-driven-characters]] — ADR on why characters are data-driven
