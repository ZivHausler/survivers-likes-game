# Ido — Toxic Trail

**Theme**: DoT poison, area denial  
**Model**: character-e  
**Color**: toxic purple (`#8C1ACC`)

## Skills

| # | Name | Type | Key params |
|---|------|------|-----------|
| 0 (sig) | Toxic Cloud | Bespoke NovaWeapon3D | dmg 8, radius 6, cooldown 1.0 — rapid tick DoT |
| 1 | Venom Orbs | OrbitWeapon3D | 3 orbs, radius 3, dmg 14, cooldown 2.5 |
| 2 | Miasma | NovaWeapon3D | dmg 16, radius 6.5, cooldown 2.5 |
| 3 | Corrosion | NovaWeapon3D | dmg 20, radius 5, cooldown 3.0 |

## Toxic Cloud (Bespoke)

`IdoToxicCloud3D` subclasses `NovaWeapon3D` and overrides `fire()` to call
`take_damage()` on every enemy within radius each tick. The low cooldown (1.0 s)
creates a rapid poison-tick effect — a trail of continuous damage. No charm, no
physics beyond `affected_enemies()` helper. Self-contained and unit-testable.

## Stats (world-scale)

- max_hp: 90, move_speed: 7.5, pickup_range: 4.0

## Playtest notes

- Toxic Cloud low cooldown may feel overwhelming at high damage_mult — tune `damage` down if needed.
- Venom Orbs orbit_speed is TAU/2.8 (~slightly faster than base) for lively feel.
