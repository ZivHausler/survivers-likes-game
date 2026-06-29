# Barak — "Dog Summon / Pack"

**Model**: character-h | **Color**: brown (Color(0.6, 0.35, 0.1)) | **Theme**: summoned hounds

## Skills

| # | ID | Type | Params |
|---|-----|------|--------|
| 0 | `barak_loyal_hounds` | OrbitWeapon3D | 3 hounds, orbit_radius 3, damage 16, cooldown 2.5 (signature) |
| 1 | `barak_pack_tactics` | OrbitWeapon3D | 5 pack members, orbit_radius 3.5, damage 12, cooldown 2.0 |
| 2 | `barak_howl` | NovaWeapon3D | damage 12, radius 6.5, charm_duration 1.5, cooldown 3.0 |
| 3 | `barak_fetch` | NovaWeapon3D | damage 20, radius 5.5, cooldown 3.5 |

## Design intent

Loyal Hounds uses `OrbitWeapon3D` where orbiting `Area3D` bodies represent summoned dog companions.
Pack Tactics adds more flanking members with faster rotation.
Howl disorients groups via charm mechanic, enabling safe follow-up.
Fetch is the high-damage finisher with a longer cooldown.

## Stats

- max_hp: 105 | move_speed: 8.0 | pickup_range: 3.5 | damage_mult: 1.0

## Playtest notes

- Two orbit weapons at once = excellent up-close coverage.
- Howl + Fetch combo: howl the group, then Fetch for burst.
- Consider tuning orbit_speed on Pack Tactics for visual clarity vs. the Loyal Hounds ring.
