---
id: data-driven-characters
title: "How a Friend is Modelled"
tags: [characters, CharacterData, resource, weapons, evolution]
links: [adr-data-driven-roster, adr-godot, run-state, character-data, upgrade-system, how-to-add-a-character]
---

# How a Friend is Modelled

A "friend" in Friends Swarm is the intersection of:

1. **`CharacterData` resource** (`.tres`) — the schema below.
2. **Weapon scene** (`PackedScene`) — the signature weapon instantiated at run start.
3. **Three `Upgrade` resources** — the character's signature, passive, and evolution upgrades.
4. **`StatBlock` resource** — base numeric stats (HP, speed, etc.).

## `CharacterData` Field Spec (as shipped)

See `core/character_data.gd` and [[character-data]]:

```gdscript
class_name CharacterData extends Resource

@export var id: StringName                  # unique key, e.g. &"ziv"
@export var display_name: String = ""
@export var color: Color = Color.WHITE       # placeholder art tint
@export var base_stats: StatBlock            # StatBlock .tres (see [[stat-block]])
@export var weapon_scene: PackedScene        # signature weapon scene
@export var passive_id: StringName           # dedicated passive's id
@export var evolution_id: StringName         # evolved ability id (emitted on unlock)
@export var max_signature_level: int = 5
# Upgrade resources fed into UpgradeSystem (see [[upgrade-system]]):
@export var signature_upgrade: Upgrade
@export var passive_upgrade: Upgrade
@export var evolution_upgrade: Upgrade
```

There is **no** `portrait`, `max_hp`, `move_speed`, `passive_label`, or
`evolution_weapon_id` field — HP/speed live on the `StatBlock` (`base_stats`),
and the evolution id is `evolution_id`.

## Runtime flow

1. **Character select** (`ui/character_select.gd`) sets `RunState.selected_character` (see [[run-state]]).
2. **GameManager** (`game/game_manager.gd`) reads `selected_character` in `_ready`:
   - `player.setup(character)` — duplicates `base_stats`, instantiates `weapon_scene`.
   - Builds an `UpgradeSystem` from the generic pool + the character's
     `signature_upgrade` / `passive_upgrade` / `evolution_upgrade`.
3. On level-up the player picks an `Upgrade`; the **upgrade-effect router**
   (`GameManager._apply_upgrade`) translates it to player/weapon calls — see [[upgrade-system]].
4. When the signature is maxed and the passive is owned, the evolution becomes
   available; applying it emits `GameEvents.evolution_unlocked(evolution_id)`
   (see [[game-events]], [[evolution-rule]]).

## Adding a new friend

Follow the runbook: [[how-to-add-a-character]] — author the weapon scene, three
`Upgrade` `.tres`, a `StatBlock` sub-resource, the `CharacterData` `.tres`, and
register a button in `ui/character_select.gd`.

See [[adr-data-driven-roster]] for the decision rationale.
