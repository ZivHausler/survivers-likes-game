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

Damage is dealt on the timer-driven `fire()` call (once per `base_cooldown`),
not every frame. A per-enemy hit-cooldown dict (`_hit_cd`) prevents burst damage
when multiple orbiters overlap the same enemy.

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
