# Yinon — Rocket Artillery

**Theme:** Heavy ordnance / military bombardment  
**Model:** `character-i.glb`  
**Color:** Orange-red `Color(1.0, 0.4, 0.1)`

## Stats
| Stat | Value |
|------|-------|
| max_hp | 95 |
| move_speed | 7.5 |
| pickup_range | 4.0 |
| damage_mult | 1.0 |

## Skills (signature first)

| # | ID | Type | Key params |
|---|----|------|------------|
| 0 | `yinon_rocket_barrage` | Nova (sig) | dmg 24, radius 6, cd 3.0 |
| 1 | `yinon_cluster_bomb` | Orbit | 4 orbs, dmg 14, cd 2.5 |
| 2 | `yinon_airstrike` | Nova | dmg 28, radius 5, cd 3.0 |
| 3 | `yinon_bombardment` | Nova | dmg 18, radius 7, cd 2.5 |

## Design notes
- Yinon is a high-damage burst artillery character — slow cooldowns but devastating hits.
- Airstrike has the highest single-hit damage in the kit; Bombardment covers the widest area.
- Cluster Bomb provides continuous pressure via orbiting shells between nova bursts.
- Playtest: verify nova timing doesn't leave too many dead zones; Airstrike's tight radius (5) benefits from player positioning.
