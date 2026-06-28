---
id: evolution-rule
title: Evolution Rule — When the Evolution Unlock Fires
tags: [upgrades, evolution, design]
links: [[upgrade-system]], [[weapon-system]], [[character-data]]
---

# Evolution Rule

The evolution upgrade is offered to the player (and, once chosen, fires
`GameEvents.evolution_unlocked`) only when **all three conditions** are
simultaneously true:

```
levels[signature.id] >= character.max_signature_level
AND levels.get(passive.id, 0) >= 1
AND NOT evolved
```

In plain English:

1. **Signature maxed** — the character's signature ability has been levelled to
   its maximum (`CharacterData.max_signature_level`, typically 3-5).
2. **Passive owned** — the character's dedicated passive (`CharacterData.passive_id`)
   has been acquired at least once (level ≥ 1).
3. **Not yet evolved** — `UpgradeSystem.evolved` is still `false` (evolution is
   a one-time event per run).

## Checking the condition

`UpgradeSystem.evolution_available()` encodes this rule exactly. It is called
inside `build_choices()` to decide whether to insert the golden evolution slot.

## Triggering evolution

When the player selects the evolution upgrade, `UpgradeSystem.apply()` sets
`evolved = true` and emits `GameEvents.evolution_unlocked(character.evolution_id)`.
Weapon code (see [[weapon-system]]) connects to this signal to swap the weapon
variant.

## Design rationale

Requiring **both** the maxed signature and the passive creates a skill-expression
gate: the player must invest in the character's identity abilities before the
evolution is unlocked, rather than stumbling into it via generic upgrades alone.
