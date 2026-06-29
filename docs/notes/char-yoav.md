# Yoav — Wolt-Scooter Strafe

**Theme:** Food delivery scooter / rapid strafe  
**Model:** `character-j.glb`  
**Color:** Wolt-blue `Color(0.0, 0.56, 0.9)`

## Stats
| Stat | Value |
|------|-------|
| max_hp | 85 |
| move_speed | 8.5 |
| pickup_range | 3.5 |
| damage_mult | 1.0 |

## Skills (signature first)

| # | ID | Type | Key params |
|---|----|------|------------|
| 0 | `yoav_drive_by` | Nova (sig) | dmg 18, radius 5.5, cd 2.0 |
| 1 | `yoav_delivery_orbit` | Orbit | 4 orbs, dmg 13, cd 2.5 |
| 2 | `yoav_hot_meal` | Nova | dmg 20, radius 6, cd 2.5 |
| 3 | `yoav_express_run` | Orbit | 6 orbs (fast), dmg 9, cd 2.0 |

## Design notes
- Yoav is the fastest character in the roster (move_speed 8.5) — a true scooter strafe playstyle.
- Drive-By fires at a fast 2.0s cooldown matching the "quick passes" fantasy.
- Express Run with 6 fast-spinning drones (orbit_speed = TAU/1.5) provides a dense contact zone.
- Playtest: Express Run's light damage per hit (9) compensates with 6 contacts; verify overall DPS feels competitive with other orbit skills.
