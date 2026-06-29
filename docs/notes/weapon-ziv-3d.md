# ZivStunningLooks3D — 3D "Stunning Looks" Weapon

**Files**: `weapons/ziv_stunning_looks_3d.gd`, `weapons/ziv_stunning_looks_3d.tscn`  
**Class**: `ZivStunningLooks3D extends Weapon3D`  
**Task**: 1.4a — Weapons → 3D

## Overview

3D port of `ZivStunningLooks`. Behavior is identical to the 2D version; spatial
constants are rescaled (1 world unit ≈ 16 px) and 2D Area/rotation are replaced
with 3D equivalents on the XZ plane.

## Scene Structure

```
ZivStunningLooks3D (Node3D)
├── Beam (Area3D)  — monitoring=true, mask=8 (enemies)
│   └── CollisionShape3D (BoxShape3D 1.5×1.0×8.0, offset z=-4)
└── CharmField (Area3D) — monitoring=false until evolve, mask=8
    └── CollisionShape3D (SphereShape3D radius=9.0)
```

The Beam extends 8 world units forward along -Z, positioned so its near edge
starts at the weapon origin.

## Constants and Starting Values

| Var | Value | 2D equivalent |
|-----|-------|---------------|
| `base_cooldown` | 3.0 s | same |
| `beam_damage` | 25.0 | same |
| `charm_count` | 2 | same |
| `charm_duration` | 2.0 s | same |
| `charm_radius` | 9.0 units | 150 px ÷ 16 |
| `_BEAM_ROTATION_SPEED` | TAU/3 rad/s | same |

## Level-up deltas

| Var | Per level | 2D equivalent |
|-----|-----------|---------------|
| `beam_damage` | +10.0 | same |
| `charm_count` | +1 | same |
| `charm_duration` | +0.5 s | same |
| `charm_radius` | +1.25 units | +20 px ÷ 16 |

## Evolution — "Absolutely Fabulous"

- Beam rotates continuously about **Y axis** at `_BEAM_ROTATION_SPEED` (driven by `_process`).
- CharmField monitoring turns on; `body_entered` auto-charms entering enemies.
- Each `fire()` tick also re-charms all bodies currently overlapping CharmField.

## XZ distance math

`_charm_nearby_enemies()` uses `Node3D.global_position.distance_to()` on the XZ
plane directly — since all actors share the same ground Y, the 3D distance
equals the XZ distance.

## VFX

Beam flash and particle effects are Phase 4.5 work. Minimal visuals only in this phase.
