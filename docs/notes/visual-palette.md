---
id: visual-palette
title: "VisualPalette — League of Legends: Swarm Color Palette"
tags: [autoload, visual, color, stylized-render]
links: [juice-3d, game-events]
---

# VisualPalette — Palette Autoload

`VisualPalette` is an autoload singleton (`res://core/visual_palette.gd`) that defines all gameplay colors used in the stylized render layer (League of Legends: Swarm visual remake).

**Palette is law**: No other code should hardcode gameplay colors. Every visual (VFX, damage numbers, HUD tints, material overlays, projectiles) must read from this palette.

## Roles

| Role | RGB | Use |
|------|-----|-----|
| `player_primary` | (0.3, 0.8, 1.0) | Player character glow, abilities |
| `player_secondary` | (1.0, 0.8, 0.2) | Player secondary accent, orbs |
| `enemy_primary` | (0.6, 0.3, 1.0) | Enemy character glow |
| `enemy_secondary` | (1.0, 0.2, 0.6) | Enemy secondary accent |
| `danger` | (1.0, 0.35, 0.1) | Hazards, danger zones |
| `pickup_low` | (0.3, 0.6, 1.0) | XP tier 0 (blue) |
| `pickup_mid` | (0.3, 1.0, 0.4) | XP tier 1 (green) |
| `pickup_high` | (1.0, 0.9, 0.2) | XP tier 2 (yellow) |
| `pickup_higher` | (1.0, 0.55, 0.1) | XP tier 3 (orange) |
| `pickup_top` | (1.0, 0.2, 0.6) | XP tier 4 (magenta) |
| `env_neutral` | (0.45, 0.47, 0.5) | Terrain, neutrals |

## Usage

```gdscript
# Get a color by role name:
var damage_number_color = VisualPalette.role(&"player_primary")

# Unknown roles return Color.MAGENTA (sentinel):
var fallback = VisualPalette.role(&"undefined")  # → Color.MAGENTA
```

## Related

- [[juice-3d]] — 3D VFX system: DamageNumber3D, HitFlash3D, etc. all read from VisualPalette
- [[game-events]] — Signals carry `color: Color` for SkillVFX to look up and apply palette tints
