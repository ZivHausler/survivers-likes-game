# weapon-orbit-3d

`OrbitWeapon3D` — reusable archetype for rotating orbiter weapons (Task 3.3).

## Files

| File | Role |
|------|------|
| `weapons/orbit_weapon_3d.gd` | `class_name OrbitWeapon3D extends Weapon3D` |
| `weapons/orbit_weapon_3d.tscn` | Base archetype scene (empty Node3D, script only) |

## Subclasses (per-skill baked params)

| File | Skill |
|------|-------|
| `weapons/ziv_mirror_shards_3d.gd/.tscn` | Ziv: Mirror Shards (3 shards, damage 20) |
| `weapons/avihay_group_call_3d.gd/.tscn` | Avihay: Group Call (4 bubbles, damage 15) |
| `weapons/avihay_mass_dm_3d.gd/.tscn`   | Avihay: Mass DM (6 pings, fast, damage 9) |

## Design

Orbiters are `Area3D` nodes with `SphereShape3D` (radius 0.6) built dynamically
in `_rebuild_orbiters()`. `collision_mask = 8` targets the enemies layer.

In `_process(dt)`, the ring phase advances by `orbit_speed * dt` each frame and
each orbiter's `position` is updated via the pure `orbiter_offsets()` helper.

**Damage is a continuous grind.** The overlap scan (`_apply_orbit_damage`) runs
every physics frame from `_physics_process`, NOT gated by `base_cooldown`. The
orbiters are an always-on aura, so anything an orb sweeps through takes damage.
A per-enemy hit-cooldown dict (`_hit_cd`, `HIT_CD_MS` = 500 ms) throttles repeat
hits so a persistently-overlapping enemy is ground down at a steady rate instead
of once-per-frame. The timer-driven `fire()` still runs (cast-VFX pulse + direct
test calls) and calls the same scan — harmless, because `HIT_CD_MS` dedupes it.

> Historical note: damage used to be dealt *only* in `fire()` (once per
> `base_cooldown`, 2–2.5 s). Because enemies pass through the ring between ticks,
> that single-instant scan almost never overlapped anyone and the skills felt like
> they did no damage. The 500 ms `HIT_CD_MS` was dead code under that model — its
> existence was the tell that continuous scanning was the intent.

**Knockback.** When an orb touches an enemy it shoves that enemy **radially outward
from the character** (the ring centre, = the weapon's own `global_position`) by
`ORB_KNOCKBACK_DIST` (2.5 u, XZ plane). Outward-from-centre (not away-from-orb) avoids
flinging enemies sideways in the orb's travel direction. The shove is delivered via
`Enemy3D.apply_knockback(dir, distance)` — a short animated **hop-back arc** (see
`enemy-3d.md`), not an instant teleport; bodies without that method fall back to a
direct `global_position` nudge. Only fires on an actual orb overlap, so enemies merely
walking near the player are unaffected. Throttled by the same `HIT_CD_MS` window as the
damage.

## Pure helper — unit-tested

```gdscript
static func orbiter_offsets(count: int, radius: float, phase: float) -> Array:
    # Returns Array of Vector3 at evenly-spaced angles on XZ (Y=0).
```

Tested: count, radius, Y=0, even spacing, phase shift, single-orbiter.

## Lifecycle

| Event | Effect |
|-------|--------|
| `level_up()` | `orbit_count += 1`, `damage += 4`, rebuild ring |
| `evolve()` | `orbit_count *= 2`, `orbit_speed *= 1.5`, rebuild ring |
| `apply_passive(v)` | `damage += v` |

## Balance reference (1 unit ≈ 16 px)

- Default `orbit_radius`: 3.0 units
- Default `orbit_speed`: TAU/3 rad/s (~120°/s)
- Default `damage`: 12 (subclasses override)
- `HIT_CD_MS`: 500 ms per enemy
