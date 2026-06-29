# AvihayChatSpam3D + Bubble3D — 3D "Chat Spam" Weapon

**Files**: `weapons/avihay_chat_spam_3d.gd`, `weapons/avihay_chat_spam_3d.tscn`,
           `weapons/bubble_3d.gd`, `weapons/bubble_3d.tscn`  
**Classes**: `AvihayChatSpam3D extends Weapon3D`, `Bubble3D extends Area3D`  
**Task**: 1.4a — Weapons → 3D

## Overview

3D port of `AvihayChatSpam` + `Bubble`. All projectile directions are XZ unit
vectors (`Vector3(cos a, 0, sin a)`). Speed and timing constants are rescaled
from 2D pixel values (1 world unit ≈ 16 px).

## AvihayChatSpam3D

### Starting values

| Var | Value | 2D equivalent |
|-----|-------|---------------|
| `base_cooldown` | 2.0 s | same |
| `bubble_count` | 3 | same |
| `bubble_damage` | 15.0 | same |
| `bubble_pierce` | 1 | same |
| `SPREAD_HALF_ANGLE` | TAU/8 (45°) | same |

### Level-up deltas

| Var | Per level |
|-----|-----------|
| `bubble_count` | +1 |
| `bubble_pierce` | +1 |
| `bubble_damage` | +5.0 |

### Direction generation — `_get_fire_directions() -> Array[Vector3]`

**Non-evolved**: `bubble_count` directions spread ±`SPREAD_HALF_ANGLE` around
the XZ direction toward the nearest enemy. Each direction is
`Vector3(cos(angle), 0, sin(angle))`.

Base angle is derived from `_nearest_enemy_direction()` via `atan2(dir.z, dir.x)`.
Spread uses the same linear t-interpolation as the 2D version.

**Evolved**: Dense ring of `bubble_count * 2` directions evenly spaced at
`TAU * i / total` radians around the full 360°.

### Evolution — "Reply-All Apocalypse"

- `_homing_mode = true` — spawned Bubble3D nodes steer toward nearest enemy.
- Fire pattern switches to full 360° ring.

## Bubble3D

### Scene structure

```
Bubble3D (Area3D, layer=4, mask=8)
└── CollisionShape3D (SphereShape3D radius=0.5)
```

### Constants

| Const | Value | 2D equivalent |
|-------|-------|---------------|
| `SPEED` | 14.0 units/s | 220 px/s ÷ 16 ≈ 13.75 → 14.0 |
| `MAX_LIFETIME` | 4.0 s | same |

### Movement — `_advance(dt)`

Each frame: accumulate `_lifetime`; cull if ≥ `MAX_LIFETIME`; if homing, lerp
`_direction` toward nearest enemy at rate `5.0*dt` then normalise; translate
`global_position += _direction * SPEED * dt`. The Y component of `_direction`
is always 0, so the bubble stays on the XZ ground plane.

### Hit logic — `_on_hit(enemy)`

- Guard against double-hit via `_hit_enemies` set.
- Group check: must be in "enemies".
- Call `take_damage(_damage)`.
- Decrement `_pierce`; `queue_free()` when `_pierce <= 0`.
- Hit VFX (DeathPop equivalent) is Phase 4.5 — no visual effect here.
