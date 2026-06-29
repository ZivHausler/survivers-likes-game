# Natali — "Laughter / Support"

**Model**: character-g | **Color**: pink (Color(1.0, 0.5, 0.7)) | **Theme**: healing & joy

## Skills

| # | ID | Type | Params |
|---|-----|------|--------|
| 0 | `natali_laughter` | BESPOKE (NovaWeapon3D) | Heals player +6 hp/pulse (clamped to max_hp), AoE damage 6, radius 6, cooldown 3.0 |
| 1 | `natali_joy_orbit` | OrbitWeapon3D | 3 orbs, radius 3, damage 14, cooldown 2.5 |
| 2 | `natali_comic_relief` | NovaWeapon3D | damage 16, radius 6, cooldown 2.5 |
| 3 | `natali_giggle_burst` | NovaWeapon3D | damage 18, radius 6.5, cooldown 3.0 |

## Bespoke: Laughter fire() override

`NataliLaughter3D` subclasses `NovaWeapon3D` and overrides `fire()`:
1. Stores player reference via `setup()` override.
2. If player has `hp` property: heals `hp += HEAL_AMOUNT` clamped to `stats.max_hp`.
3. Then calls `affected_enemies()` and deals light AoE damage to enemies in radius.
4. Guard: `has_method("_on_hp_changed")` before calling player callback (optional).

All heal tests use a `StubPlayer` with `hp` and `stats.max_hp`.

## Stats

- max_hp: 95 | move_speed: 7.5 | pickup_range: 4.0 | damage_mult: 1.0

## Playtest notes

- Natali excels at sustained fighting; heal-per-pulse of 6 at cooldown 3 s = ~2 hp/s sustain.
- Joy Orbit provides consistent contact damage while the player moves.
- Giggle Burst is the wide-area nuke of the kit.
- Check that heal capping feels correct — should not make Natali feel unkillable.
