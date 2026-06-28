---
id: data-driven-characters
title: "How a Friend is Modelled"
tags: [characters, CharacterData, resource, weapons, evolution]
links: [adr-data-driven-roster, adr-godot, run-state]
---

# How a Friend is Modelled

A "friend" in Friends Swarm is the intersection of four things:

1. **`CharacterData` resource** (`.tres`) — the schema below.
2. **Weapon scene** (`PackedScene`) — the starting weapon instantiated at run start.
3. **Passive bonus** — stat modifiers stored on `CharacterData`.
4. **Evolution path** — conditions + target weapon ID that trigger [[game-events]]`evolution_unlocked`.

## `CharacterData` Field Spec (planned)

```gdscript
class_name CharacterData
extends Resource

@export var id: StringName           # unique key, e.g. &"alex"
@export var display_name: String
@export var portrait: Texture2D
@export var max_hp: float = 100.0
@export var move_speed: float = 120.0
@export var weapon_scene: PackedScene  # starting weapon
@export var passive_label: String      # human-readable passive description
@export var evolution_weapon_id: StringName  # emitted via GameEvents when unlocked
```

## Runtime flow

1. **Character select screen** sets `RunState.selected_character` (see [[run-state]]).
2. **Main scene** reads `selected_character` and instantiates `weapon_scene`.
3. On evolution condition met → emit `GameEvents.evolution_unlocked(evolution_weapon_id)` (see [[game-events]]).
4. Weapon manager swaps the active weapon.

## Adding a new friend

1. Create `CharacterData` resource class (once, in Task 0.2).
2. Duplicate an existing `.tres`, fill in fields, drop portrait in `assets/portraits/`.
3. No code changes needed — the roster is auto-discovered via `ResourceLoader`.

See [[adr-data-driven-roster]] for the decision rationale.
