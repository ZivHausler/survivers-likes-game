---
id: upgrade-system
title: Upgrade System — Pool Generation & API
tags: [upgrades, architecture, level-up]
links: [[game-events]], [[character-data]], [[evolution-rule]], [[weapon-system]]
---

# Upgrade System

Manages per-run upgrade state: what has been levelled up, what is eligible for
selection, and the moment evolution fires.

**Files:** `upgrades/upgrade.gd`, `upgrades/upgrade_system.gd`

---

## Upgrade (Resource)

```gdscript
class_name Upgrade extends Resource

enum Kind { SIGNATURE, PASSIVE, GENERIC, EVOLUTION }

var id: StringName
var display_name: String
var kind: int          # one of Kind.*
var max_level: int
# Wave 3 additions (backward-compatible, default values safe):
var effect_kind: StringName  # for GENERIC: &"move_speed", &"max_hp", etc.
var effect_value: float      # per-level delta applied by the router
```

| Kind      | Description                                           |
|-----------|-------------------------------------------------------|
| SIGNATURE | Character's primary scaling ability (weapon-level)    |
| PASSIVE   | Dedicated passive bonus unique to the character       |
| GENERIC   | Shared ability from the global pool                   |
| EVOLUTION | One-shot unlock that transforms the signature weapon  |

---

## UpgradeSystem (RefCounted)

### Construction

```gdscript
UpgradeSystem.new(
    character: CharacterData,
    generic_pool: Array,          # Array[Upgrade] of GENERIC kind
    signature_upgrade: Upgrade,
    passive_upgrade: Upgrade,
    evolution_upgrade: Upgrade
)
```

### State

| Field     | Type       | Description                                 |
|-----------|------------|---------------------------------------------|
| `levels`  | Dictionary | StringName (upgrade id) → int (level)       |
| `evolved` | bool       | True once the evolution has been applied    |

### Methods

#### `evolution_available() -> bool`

Returns `true` when all three conditions hold — see [[evolution-rule]].

#### `build_choices(rng: RandomNumberGenerator, count := 3) -> Array`

Returns an array of up to `count` non-maxed `Upgrade` objects for the player
to choose from.

**Pool-generation rules:**

1. If `evolution_available()` is true, the evolution upgrade is guaranteed as
   the first element ("golden slot"). The remaining `count - 1` slots are filled
   from the non-maxed pool of {signature, passive, generics} (shuffled).
2. Otherwise, draw `count` upgrades from {signature, passive, generics} that
   are not maxed, shuffled with Fisher-Yates using the provided RNG.
3. No duplicate ids appear in a single choice list.

#### `apply(u: Upgrade) -> void`

Increments `levels[u.id]`. If `u.kind == Upgrade.Kind.EVOLUTION`, sets
`evolved = true` and emits `GameEvents.evolution_unlocked(character.evolution_id)`.

#### `is_maxed(u: Upgrade) -> bool`

Returns `true` when `levels.get(u.id, 0) >= u.max_level`.

---

## Upgrade-Effect Router (Wave 3)

`GameManager._apply_upgrade(u: Upgrade)` translates an `Upgrade` resource into
concrete player/weapon calls **after** `upgrade_system.apply(u)` has run:

| u.kind    | Call made                                                     |
|-----------|---------------------------------------------------------------|
| SIGNATURE | `player.weapon.level_up()`                                    |
| EVOLUTION | `player.weapon.evolve()`                                      |
| PASSIVE   | `player.weapon.apply_passive(u.effect_value)`                 |
| GENERIC   | `player.apply_stat_upgrade(u.effect_kind, u.effect_value)`    |

`Player.apply_stat_upgrade(kind, value)` handles: `move_speed`, `max_hp`,
`pickup_range`, `fire_rate`, `damage`, `armor`.

`Weapon.apply_passive(value)` is a virtual no-op in the base class; each
weapon subclass overrides it with its own passive logic:
- `ZivStunningLooks` — adds `value` seconds to `charm_duration`
- `AvihayChatSpam`  — adds `value` to `stats.fire_rate_mult` then refreshes cooldown

See [[game-manager]] for the full router implementation.

## Integration Notes

- `UpgradeSystem` is constructed fresh each run (not persisted).
- `build_choices` is deterministic given the same RNG seed — use for
  replays/testing.
- Call `apply()` exactly once per player choice before building the next
  choice set.
- Downstream weapon code listens to `GameEvents.evolution_unlocked` to swap
  the weapon variant — see [[weapon-system]].

## 3D Skill System

The 3D game uses a parallel `SkillSystem` (`core/skill_system.gd`) instead of
`UpgradeSystem`. Both extend `RefCounted` and expose the same conceptual API
(`build_choices`, `apply`, `has_available_choices`). `UpgradeSystem` is NOT
modified and remains the exclusive system for the 2D game path. The `Upgrade.Kind`
enum was extended additively with `SKILL = 4` and `SYNERGY = 5`; all existing
2D values (0–3) are unchanged. See [[skill-system]] for the full 3D model.
