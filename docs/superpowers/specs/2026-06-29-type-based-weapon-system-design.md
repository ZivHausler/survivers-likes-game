# Type-Based Weapon System — Design Spec

**Date:** 2026-06-29
**Status:** Approved (design) — pending spec review
**Author:** brainstorming session

## 1. Summary

Replace the current bespoke per-character skill model with a **TemTem-style type-gated
weapon pool** ported from League of Legends *Swarm*. Every friend draws from a shared
weapon pool filtered by their **types**, plus an **exclusive ultimate** only they can use.

The result, per run:

- **10 Natural weapons** — any character can be offered them.
- **10 type-gated weapons** — offered only if the character has the matching type.
- **1 exclusive ultimate per friend** — auto-granted at run start, never offered to others.

Weapon *mechanics* are copied 1:1 from LoL Swarm; only the **names** (friend-flavored)
and the new **type tag** are original.

## 2. Goals / Non-Goals

**Goals**
- 20 shared-pool weapons + 10 exclusive ultimates, data-driven, reusing existing archetypes.
- A type system: each weapon has one type (or `natural`); each character has 1–2 types.
- Offer filtering: `offered = natural ∪ (weapons whose type ∈ character.types)`.
- Minimal change to `SkillSystem` — filtering happens when GameManager builds the run.

**Non-Goals**
- Meta-progression / unlock economy (explicitly excluded by the user).
- Reworking enemies, spawning, XP, or the upgrade-card UI.
- Net-code / co-op implementation (see §10 — team-effect ults are designed to degrade
  gracefully until a party layer exists).

## 3. The Type System

Ten themed types (one primary per friend) plus a universal `natural` type:

`charm` · `social` · `holy` · `pack` · `toxic` · `pest` · `joy` · `bomber` · `rush` · `sound` · `natural`

Types are `StringName`s. A weapon belongs to exactly one type. A character has 1–2 types.

## 4. Data Model Changes

### 4.1 `SkillData` (`core/skill_data.gd`)
Add one field:
```gdscript
## Weapon type for pool filtering. &"natural" = available to every character;
## otherwise one of the themed type ids. Ultimates use their owner's primary type.
@export var type: StringName = &"natural"
```
`is_signature` is **reused** to mark a character's ultimate (auto-owned at level 1).
No other field changes; each pool weapon keeps its `skill_upgrade` / `passive_upgrade` /
`synergy_upgrade` trio exactly as today.

### 4.2 `CharacterData` (`core/character_data.gd`)
Add:
```gdscript
## 1–2 type ids this character can roll type-gated weapons from.
@export var types: Array[StringName] = []
## This character's exclusive ultimate (is_signature = true). Auto-granted at run start.
@export var ultimate: SkillData
```
The legacy `skills: Array[SkillData]` field is **no longer the source of offered skills**.
It is removed from the run path; characters reference only `types` + `ultimate`. (The field
may remain on the resource for 2D back-compat but is ignored by the 3D run.)

### 4.3 Shared pool registry (new: `core/skill_pool.gd`)
A small loader exposing the 20 shared weapons as `Array[SkillData]`:
```gdscript
class_name SkillPool extends RefCounted
## Returns all 20 shared-pool SkillData (10 natural + 10 typed), preloaded.
static func all() -> Array  # Array[SkillData]
## Filtered for a character: natural ∪ weapons whose type ∈ types.
static func for_types(types: Array) -> Array
```
Implemented as an explicit `preload()` list (not a runtime `dir` scan) so the set is
deterministic and test-visible.

## 5. Offer Filtering (where the type gate lives)

`SkillSystem` already builds its pool from whatever `_skills` array it receives and treats
the one `is_signature` entry as owned-at-start (`core/skill_system.gd:28-35`,
`:148-161`). So the type gate lives in **GameManager3D**, at run construction:

```gdscript
var pool := SkillPool.for_types(character.types)   # 10 natural + ~2 typed
var run_skills := [character.ultimate] + pool       # ultimate is the is_signature entry
skill_system = SkillSystem.new(run_skills, generic_pool)
```

GameManager already grants/instantiates the signature weapon at start and routes
SKILL/PASSIVE/SYNERGY/GENERIC upgrades to `Player3D`; that logic is unchanged. The ultimate
is just a signature weapon with a large `base_cooldown`.

**`SkillSystem` change:** none required for filtering. (Optional: a guard so a weapon's
`type` is never re-checked at runtime — not needed for v1.)

## 6. The 20 Shared-Pool Weapons

Mechanics are identical to LoL Swarm. "Archetype" = which existing `Weapon3D` base to
extend (`weapons/nova_weapon_3d.gd`, `weapons/orbit_weapon_3d.gd`, the `Bubble3D`
projectile pattern, or a new `custom` subclass of `Weapon3D`).

### 6.1 Natural (10) — every character can roll
| Name | Swarm source | Mechanic | Archetype |
|---|---|---|---|
| Pew Pew | UwU Blaster | rapid projectiles at nearest enemy | projectile |
| Boomer-rang | Blade-o-rang | returning boomerang seeking nearest | custom projectile (return) |
| Crescent Kick | Lioness's Lament | crescent projectiles | projectile |
| Spin Cycle | Vortex Glove | rotating projectile stream | projectile (spiral) |
| Group Shock | Statikk Sword | lightning chains between enemies | custom (chain target) |
| Personal Space | Cyclonic Slicers | orbiting razors + knockback | OrbitWeapon3D |
| Skip Shot | Anti-Shark Sea Mine | explosive bounces between enemies | custom projectile (bounce) |
| Dad Bod Aura | Radiant Field | persistent aura, scales with Max HP | custom (always-on field) |
| Cold Shoulder | Iceblast Armor | reactive shield, freezes on break | custom (defensive trigger) |
| Hot Take | Searing Shortbow | projectiles leave lingering fire patches | projectile + ground hazard |

### 6.2 Type-gated (10) — one per type
| Name | Type | Swarm source | Mechanic | Archetype |
|---|---|---|---|---|
| Thirst Trap | charm | Battle Bunny Crossbow | random cone, pierce on crit | projectile (cone) |
| Group Chat | social | YuumiBot | drone: damages + vacuums XP | custom summon |
| Act of God | holy | The Annihilator | delayed strike, clears normal enemies | Nova (large) / custom |
| Good Boy | pack | T.I.B.B.E.R.S | summoned beast, targets high-HP | custom summon (minion AI) |
| Gym Sock Fumes | toxic | Paw Print Poisoner | poison cloud trail while moving | custom (ground trail) |
| Relentless | pest | Gatling Bunny-Guns | sustained DoT cone | custom (cone DoT) |
| Surprise Party | joy | Bunny Mega-Blast | orbital strikes on random enemies | Nova at random positions |
| Minefield | bomber | Ani-Mines | ring of timed mines | custom (mine ring) |
| Last Train Home | rush | Final City Transit | vehicle plows through enemies | custom (moving hazard) |
| Echo Chamber | sound | Echoing Batblades | spikes ricochet off terrain | projectile (bounce) |

## 7. The 10 Exclusive Ultimates

One per friend, `is_signature = true`, large `base_cooldown` (target ~30–60s, tuned later).
Each carries its owner's **primary type** for tagging consistency. O = offensive, D = defensive.

| Friend | Ultimate | O/D | Mechanic | Archetype |
|---|---|---|---|---|
| Ziv | Main Character Moment | D | halt + charm all nearby enemies for a few seconds | Nova + charm field |
| Avihay | Conference Call | D | team shield + knockback ring, then summons temp helpers | custom (team buff + summon) |
| Avinoam | Judgment Day | O | giant delayed holy beam, heavy damage + stun in a zone | Nova (large) / custom |
| Barak | Release the Hounds | O | summon a pack that chases and grinds enemies | custom (multi-summon) |
| Ido | Biohazard | O | huge expanding poison nova + lingering DoT cloud | Nova + ground hazard |
| Matan | Buzzkill | O | self-buff (dmg/speed/fire-rate) for a few seconds; all teammates slowed + reduced stats for the same duration | custom (timed stat mod) |
| Natali | Comic Relief | D | AoE "laughter" stun/disarm + team heal | Nova (stun) + team heal |
| Yinon | Carpet Bomb | O | screen-wide barrage over a few seconds | custom (sequenced Nova strikes) |
| Yoav | Express Delivery | O | repeated plow-through dashes in lines | custom (mobility/line hits) |
| Yuval | Bass Drop | O | massive shockwave, damage + knockback | Nova + knockback |

## 8. Friend → Types → Pool

| Friend | Types | Type-weapons rolled | Ultimate |
|---|---|---|---|
| Ziv | charm + social | Thirst Trap, Group Chat | Main Character Moment |
| Avihay | social + pest | Group Chat, Relentless | Conference Call |
| Avinoam | holy + sound | Act of God, Echo Chamber | Judgment Day |
| Barak | pack + rush | Good Boy, Last Train Home | Release the Hounds |
| Ido | toxic + bomber | Gym Sock Fumes, Minefield | Biohazard |
| Matan | pest + toxic | Relentless, Gym Sock Fumes | Buzzkill |
| Natali | joy + charm | Surprise Party, Thirst Trap | Comic Relief |
| Yinon | bomber + sound | Minefield, Echo Chamber | Carpet Bomb |
| Yoav | rush + bomber | Last Train Home, Minefield | Express Delivery |
| Yuval | sound + joy | Echo Chamber, Surprise Party | Bass Drop |

Each character's effective offer pool = **10 Natural + 2 type-weapons + their ultimate**.

## 9. Weapon-Slot Cap (DECISION — default chosen, confirm in review)

Today each character has exactly 4 skills, so there is an implicit 4-slot cap. The shared
pool exposes ~12 acquirable weapons per character, so we need an explicit cap or runs become
weapon-soup. **Default: cap active weapons at 6** (Swarm-like feel: a handful of weapons,
deepened by passives/synergy). The ultimate does **not** count against the cap.

**Enforcement (the one real `SkillSystem` change):** in `_normal_pool()`, when the count of
owned non-signature SKILL upgrades has reached the cap, stop appending *not-yet-owned* SKILL
upgrades. Owned weapons' level-ups, passives, synergies, and generics are unaffected. The cap
value is a constructor arg so it is test-injectable. (This is separate from the type filtering
in §5, which needs no `SkillSystem` change.)

> Open to changing the cap number, or removing the cap entirely, during spec review.

## 10. Co-op / Team-Effect Caveat

Three ultimates affect "the team": **Buzzkill** (debuff teammates), **Conference Call**
(team shield), **Comic Relief** (team heal). The project is currently single-player; no party
layer exists yet. v1 approach:

- Team-affecting ults query a `players` group (Godot group) for "other players".
- Solo: that query returns empty → team effects no-op, self effects still apply.
- **Buzzkill solo balance:** with no teammates the downside never fires, so it is a pure
  self-buff in solo. **Default: leave it** (the co-op joke stays clean); the self-buff is
  the solo identity. Flagged for confirmation.

When a real co-op layer lands later, these ults work unchanged via the `players` group.

## 11. Migration — what gets replaced

Replaced by the new pool (the bespoke per-character skills and their weapons):
- `characters/skills/*.tres` (e.g. `ziv_charm.tres`, `avihay_spam.tres`, … — 40+ files)
- The matching `upgrades/<friend>/*.tres` skill/passive/synergy resources
- The per-friend custom weapon scripts/scenes in `weapons/` that are no longer referenced
  (e.g. `ziv_stunning_looks_3d`, `avihay_chat_spam_3d`, …)

**Kept and reused:** the archetype bases (`Weapon3D`, `NovaWeapon3D`, `OrbitWeapon3D`,
`Bubble3D`), `Upgrade`, `StatBlock`, `EnemyData`, the spawner, and the upgrade-card UI.

New content authored:
- 20 pool `SkillData` `.tres` + their 60 upgrade resources (3 per weapon)
- 10 ultimate `SkillData` `.tres` + their upgrade resources
- Weapon scripts/scenes per the archetype column (many reuse Nova/Orbit/projectile)
- `core/skill_pool.gd`; `types` + `ultimate` set on each `characters/<friend>_3d.tres`

## 12. Testing

Follow the existing pure-helper + headless pattern (`test/`):
- `SkillPool.for_types()` — unit test: natural always present; type filter correct;
  unknown type → natural only.
- GameManager run construction — the assembled `run_skills` for each friend matches §8.
- Each weapon archetype keeps its existing pure-helper tests (offsets, advance, scaling).
- New ultimates: cooldown gating, and team-effect ults no-op in solo (empty `players` group).
- Weapon-slot cap: once at cap, no new SKILL-acquire upgrades are offered.

## 13. Suggested Phasing (for the implementation plan)

1. Data model: `SkillData.type`, `CharacterData.types`+`ultimate`, `SkillPool`, GameManager
   wiring + slot cap. (No new weapons yet — validate filtering with existing weapons.)
2. The 10 Natural weapons (data + scripts + upgrades), mostly projectile/orbit archetypes.
3. The 10 type-weapons.
4. The 10 ultimates (incl. team-effect `players`-group plumbing).
5. Migration: remove replaced bespoke skills; set each friend's `types`+`ultimate`.
6. Balance pass: cooldowns, slot cap number, Buzzkill solo.

## 14. Open Decisions (confirm in review)
- **Weapon-slot cap:** default 6 — keep, change number, or remove?
- **Buzzkill solo:** default leave as pure self-buff — keep or add a self-cost?
- **Weapon names:** all are first-draft friend jokes — flag any to rewrite.
