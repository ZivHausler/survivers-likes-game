# Matan — "Irritation Aura"

**Theme:** Enrage / distract / annoy. Sickly green color. Model: `character-d.glb`.

## Skills

| # | Name | Type | Key Params |
|---|------|------|-----------|
| 0 (sig) | Irritation Aura | Nova | damage 10, radius 7, charm 2.0, cooldown 2.5 |
| 1 | Annoyance Orbit | Orbit | 3 orbs, damage 14, cooldown 2.5 |
| 2 | Outburst | Nova | damage 20, radius 6, cooldown 3.0 |
| 3 | Pestering Swarm | Orbit | 5 orbs, fast (TAU/1.5), damage 9, cooldown 2.0 |

## Stats (base)

- max_hp: 85, move_speed: 8.0, pickup_range: 4.5

## Notes

- No bespoke `fire()` override — signature uses standard NovaWeapon3D with charm_duration > 0 (charm = distract/taunt).
- Matan is a crowd-control specialist: wide irritation aura taunts enemies while swarms and orbit provide persistent pressure.
- Playtest: Irritation Aura's charm_duration 2.0 should visibly distract enemies; Pestering Swarm's fast orbit should feel frantic/chaotic.
