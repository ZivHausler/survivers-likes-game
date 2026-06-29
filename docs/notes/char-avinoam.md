# Avinoam — "Divine Smite"

**Theme:** Holy / divine punishment. Gold color. Model: `character-c.glb`.

## Skills

| # | Name | Type | Key Params |
|---|------|------|-----------|
| 0 (sig) | Holy Smite | Nova | damage 26, radius 6, cooldown 3.0 |
| 1 | Smite Orbs | Orbit | 3 orbs, damage 16, cooldown 2.5 |
| 2 | Radiant Pulse | Nova | damage 18, radius 6.5, cooldown 2.5 |
| 3 | Judgment | Nova | damage 22, radius 5, cooldown 2.5 |

## Stats (base)

- max_hp: 95, move_speed: 7.5, pickup_range: 4.0

## Notes

- No bespoke `fire()` override — all skills use standard OrbitWeapon3D / NovaWeapon3D behavior.
- Avinoam is a high-damage holy caster: signature smites hard, orbs provide constant pressure, pulse and judgment offer radius/damage trade-off variety.
- Playtest: verify Holy Smite feels punchy at cooldown 3.0; Judgment's tighter radius should feel "focused" vs Radiant Pulse's width.
