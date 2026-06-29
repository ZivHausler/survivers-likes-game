---
id: skill-vfx
title: "SkillVFX — Decoupled Skill Cast/Hit Effects"
tags: [autoload, vfx, signals, skills, 3d]
links: [game-events, weapon-system-3d, juice-3d]
---

# SkillVFX — Decoupled Skill Cast/Hit Effects

**Task**: 4.5 Item 8 — Skill VFX visuals (decoupled)

## Overview

`SkillVFX` is an autoload that listens to two new `GameEvents` signals and
spawns colored 3D particle effects at the relevant world position.  It is
architecturally identical to `Juice3D` — removing or disabling it leaves all
game logic completely unaffected.

## New GameEvents signals

| Signal | Parameters | Who emits | Who listens |
|--------|-----------|-----------|-------------|
| `skill_cast` | `vfx_id: StringName, color: Color, position: Vector3` | `Weapon3D._fire_internal()` | `SkillVFX` |
| `skill_hit`  | `vfx_id: StringName, color: Color, position: Vector3` | Orbit/Nova `fire()`, Ziv beam, Bubble3D `_on_hit()` | `SkillVFX` |

## How cast VFX works (uniform across all 40+ skills)

`Weapon3D._ready()` now connects the internal timer to `_fire_internal()` instead of `fire()`.

```
Timer.timeout → _fire_internal() → emit skill_cast → fire()
```

Subclasses only override `fire()`.  They get cast VFX for free without any
per-skill changes.  Calling `fire()` directly (as tests do) skips the emit,
so existing tests remain behavior-identical.

## VFX fields on Weapon3D

```gdscript
var vfx_id: StringName = &""     # label for future per-id effect routing
var vfx_color: Color = Color(1, 1, 1)  # tint applied to particles
```

Archetype defaults:

| Archetype / signature | vfx_id | vfx_color |
|----------------------|--------|-----------|
| `OrbitWeapon3D` | `orbit_cast` | Gold `Color(1.0, 0.8, 0.2)` |
| `NovaWeapon3D` | `nova_cast` | Cyan `Color(0.5, 0.8, 1.0)` |
| `ZivStunningLooks3D` | `ziv_stunning_looks` | Pink `Color(1.0, 0.4, 0.8)` |
| `AvihayChatSpam3D` | `avihay_chat_spam` | Blue `Color(0.3, 0.6, 1.0)` |
| `Bubble3D` (hit only) | `avihay_chat_spam` | Blue `Color(0.3, 0.6, 1.0)` |

Per-skill subclasses can override `vfx_id`/`vfx_color` in their `_ready()` for
finer theming without touching the archetype or base class.

## VFX scenes

| Scene | Class | Lifetime | Use |
|-------|-------|----------|-----|
| `vfx/skill_cast_fx_3d.tscn` | `SkillCastFx3D` | 0.6 s | Flourish at weapon origin on cast |
| `vfx/skill_hit_fx_3d.tscn` | `SkillHitFx3D` | 0.3 s | Spark at enemy hit position |

Both extend `GPUParticles3D` and expose `play_at(pos: Vector3, color: Color)`.
The material is duplicated per-instance so colors don't bleed between effects.

## Hit emit — where it fires

- **OrbitWeapon3D**: after `body.take_damage(dmg)`, once per enemy per fire window (throttled by `_hit_cd`).
- **NovaWeapon3D**: after `enemy.take_damage(dmg)`, once per affected enemy (only when `damage > 0`).
- **ZivStunningLooks3D**: after `body.take_damage(damage)` in `_deal_beam_damage()`.
- **Bubble3D**: after `enemy.take_damage(_damage)` in `_on_hit()`, guarded by the existing pierce/visited list (each enemy hit at most once per bubble).

## Manual playtest checklist

1. **Cast effect visibility** — each skill should show a brief colored flourish at the character's position when it activates.
2. **Hit effect visibility** — a small colored spark should appear at the enemy on damage.
3. **Per-skill color distinction** — orbit skills glow gold, nova skills glow cyan, Ziv glows pink, Avihay glows blue.
4. **Performance with many enemies** — spawn 20+ enemies and trigger nova/orbit; verify no frame-rate drop from VFX.
5. **No effect accumulation** — effects should auto-free; node count should not grow unbounded over time.
6. **Bespoke Ido/Natali (best-effort)** — these override `fire()` and call NovaWeapon3D helpers directly; they get cast VFX from the base timer wrapper but hit VFX is not guaranteed for their custom paths.
