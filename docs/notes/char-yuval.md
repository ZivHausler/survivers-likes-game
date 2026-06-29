# Yuval — Soundwave Stun

**Theme**: Sonic stun, area control  
**Model**: character-f  
**Color**: cyan (`#00E5E5`)

## Skills

| # | Name | Type | Key params |
|---|------|------|-----------|
| 0 (sig) | Soundwave | NovaWeapon3D | dmg 15, radius 6, charm 2.0, cooldown 2.5 |
| 1 | Echo Orbit | OrbitWeapon3D | 3 orbs, radius 3, dmg 15, cooldown 2.5 |
| 2 | Bass Drop | NovaWeapon3D | dmg 24, radius 5, cooldown 3.0 |
| 3 | Resonance | NovaWeapon3D | dmg 12, radius 7, charm 1.5, cooldown 3.0 |

## Soundwave (Signature)

`YuvalSoundwave3D` uses `NovaWeapon3D` with `charm_duration = 2.0` — the charm
mechanic represents a sonic stun that disorients enemies. Wide radius, moderate
damage, reliable 2.5 s cooldown.

## Stats (world-scale)

- max_hp: 100, move_speed: 8.0, pickup_range: 4.5

## Playtest notes

- Two skills (Soundwave + Resonance) apply charm/stun — combine for maximum crowd control.
- Bass Drop is the burst-damage option for when charm isn't needed.
