# Skill System

`SkillData` (`core/skill_data.gd`) + `SkillSystem` (`core/skill_system.gd`).
Introduced in Task 3.1. Lives alongside the 2D `UpgradeSystem`; the 2D path is unaffected.

---

## Model

Each **character** has exactly **4 skills**: 1 *signature* (owned at run start) + 3 *acquirable*.

A **skill** bundles three upgrade cards:

| Card | `Upgrade.Kind` | max_level | When offered |
|---|---|---|---|
| `skill_upgrade` | `SKILL` (4) | 5 | When `skill_level < 5` (acquire if 0, level up if 1–4) |
| `passive_upgrade` | `PASSIVE` (1) | 5 | When skill is **owned** (`skill_level ≥ 1`) AND passive not maxed |
| `synergy_upgrade` | `SYNERGY` (5) | 1 | When **skill is maxed** (level 5) AND **passive ≥ 1** AND not yet synergized |

### Skill level

- **0** = not owned (never acquired).
- **1–5** = owned. Level 0→1 is an *acquisition*; 1→5 are level-ups.
- The signature skill starts at **level 1** (owned) when `SkillSystem` is initialised.

### Synergy rule (item 5)

```
synergy_available(skill) :=
    skill_level == skill.skill_upgrade.max_level (5)
    AND passive_level >= 1
    AND NOT synergized[skill.id]
```

When `synergy_available()` is true, `build_choices` places the synergy card as a **guaranteed (golden) slot** first in the returned array. After `apply(synergy_upgrade)`, `synergized[skill.id]` is set to `true` and `GameEvents.evolution_unlocked` is emitted with `u.skill_id`.

---

## Acquisition-detection contract

`SkillSystem.apply()` does **not** instantiate weapons — that is `GameManager3D`'s job (Task 3.2).

To detect a first-time skill acquisition, the GameManager checks:

```gdscript
system.apply(upgrade)
if upgrade.kind == Upgrade.Kind.SKILL and system.skill_level(system.skill_id_of(upgrade)) == 1:
    # → instantiate weapon_scene
```

This is reliable because the SKILL upgrade level transitions 0→1 only on the very first apply.

---

## SkillSystem public API

| Method | Description |
|---|---|
| `is_owned(skill: SkillData) -> bool` | `skill_level ≥ 1` |
| `skill_level(skill_id) -> int` | SKILL upgrade current level |
| `passive_level(skill_id) -> int` | PASSIVE upgrade current level |
| `skill_id_of(u: Upgrade) -> StringName` | Returns `u.skill_id` for SKILL/PASSIVE/SYNERGY, else `&""` |
| `synergy_available(skill) -> bool` | See synergy rule above |
| `is_maxed(u: Upgrade) -> bool` | `levels[u.id] >= u.max_level` |
| `build_choices(rng, count=3) -> Array[Upgrade]` | Guaranteed synergy slots first, then normal pool |
| `has_available_choices() -> bool` | False only when fully exhausted |
| `apply(u: Upgrade) -> void` | Increments levels or synergizes + emits signal |

---

## `CharacterData.skills` field

`@export var skills: Array[SkillData] = []`

3D characters populate 4 entries; 2D characters leave it empty — the 2D code path is not affected.

---

## Relation to 2D UpgradeSystem

The 2D `UpgradeSystem` (`upgrades/upgrade_system.gd`) remains fully intact. `SkillSystem` is a separate `RefCounted` used exclusively by `GameManager3D`. The `Upgrade.Kind` enum was extended additively (SKILL=4, SYNERGY=5); existing 2D values 0–3 are unchanged.
