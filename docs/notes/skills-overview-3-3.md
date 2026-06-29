# skills-overview-3-3

Task 3.3 — 3 extra skills per character; both Ziv and Avihay now have 4 skills total.

## Archetypes

Two new reusable weapon archetypes (see dedicated notes):
- [[weapon-orbit-3d]] — rotating orbiter ring
- [[weapon-nova-3d]] — XZ AoE pulse (damage + optional charm)

## Ziv's skills (4 total)

| # | id | Class | Archetype | Key params |
|---|----|-------|-----------|-----------|
| 0 | `ziv_charm` | ZivStunningLooks3D | Custom | beam + XZ charm sort (signature) |
| 1 | `ziv_mirror_shards` | ZivMirrorShards3D | OrbitWeapon3D | 3 shards, r=3.5, dmg=20 |
| 2 | `ziv_selfie_flash` | ZivSelfieFlash3D | NovaWeapon3D | r=5.5, dmg=22, no charm |
| 3 | `ziv_adoring_aura` | ZivAdoringAura3D | NovaWeapon3D | r=7, dmg=8, charm=2.5s |

### Ziv upgrade files

```
upgrades/ziv/
  mirror_shards_skill.tres     (SKILL, max 5, +4dmg/+1shard per level)
  mirror_shards_passive.tres   (PASSIVE, max 5, +5 damage per passive)
  mirror_shards_synergy.tres   (SYNERGY, max 1, Hall of Mirrors)
  selfie_flash_skill.tres      (SKILL, max 5)
  selfie_flash_passive.tres    (PASSIVE, max 5, +1 radius)
  selfie_flash_synergy.tres    (SYNERGY, max 1, Paparazzi Storm)
  adoring_aura_skill.tres      (SKILL, max 5)
  adoring_aura_passive.tres    (PASSIVE, max 5, +1.5 radius)
  adoring_aura_synergy.tres    (SYNERGY, max 1, Love Bomb)
```

## Avihay's skills (4 total)

| # | id | Class | Archetype | Key params |
|---|----|-------|-----------|-----------|
| 0 | `avihay_spam` | AvihayChatSpam3D | Custom | bubble projectiles (signature) |
| 1 | `avihay_group_call` | AvihayGroupCall3D | OrbitWeapon3D | 4 bubbles, r=4, dmg=15 |
| 2 | `avihay_voice_blast` | AvihayVoiceBlast3D | NovaWeapon3D | r=6, dmg=25, no charm |
| 3 | `avihay_mass_dm` | AvihayMassDM3D | OrbitWeapon3D | 6 pings, r=2.5, spd=TAU, dmg=9 |

### Avihay upgrade files

```
upgrades/avihay/
  group_call_skill.tres        (SKILL, max 5)
  group_call_passive.tres      (PASSIVE, max 5, +5 damage)
  group_call_synergy.tres      (SYNERGY, max 1, Conference Swarm)
  voice_blast_skill.tres       (SKILL, max 5)
  voice_blast_passive.tres     (PASSIVE, max 5, +1 radius)
  voice_blast_synergy.tres     (SYNERGY, max 1, Sonic Boom)
  mass_dm_skill.tres           (SKILL, max 5)
  mass_dm_passive.tres         (PASSIVE, max 5, +4 damage)
  mass_dm_synergy.tres         (SYNERGY, max 1, Notification Apocalypse)
```

## SkillData files

```
characters/skills/
  ziv_mirror_shards.tres
  ziv_selfie_flash.tres
  ziv_adoring_aura.tres
  avihay_group_call.tres
  avihay_voice_blast.tres
  avihay_mass_dm.tres
```

## Character data changes

`ziv_3d.tres` and `avihay_3d.tres` `skills` arrays now have 4 elements each.

## Manual playtest items

- Acquire each new skill via upgrade cards and verify the weapon fires correctly.
- OrbitWeapon3D: verify orbiters visually rotate and damage enemies on contact.
- NovaWeapon3D: verify AoE radius pulse hits all enemies within range.
- AdoringAura: verify charm effect freezes enemy movement.
- Synergy evolve: verify orbit doubles / nova radius boosts on evolve().
- Balance check: compare DPS of orbit vs nova vs signature skills.
- Ensure no skill breaks the 3-choice upgrade card UI (no duplicate ids).
