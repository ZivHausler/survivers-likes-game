# weapon-nova-3d

`NovaWeapon3D` — reusable archetype for AoE pulse weapons (Task 3.3).

## Files

| File | Role |
|------|------|
| `weapons/nova_weapon_3d.gd` | `class_name NovaWeapon3D extends Weapon3D` |
| `weapons/nova_weapon_3d.tscn` | Base archetype scene (empty Node3D, script only) |

## Subclasses (per-skill baked params)

| File | Skill |
|------|-------|
| `weapons/ziv_selfie_flash_3d.gd/.tscn`  | Ziv: Selfie Flash (radius 5.5, damage 22, no charm) |
| `weapons/ziv_adoring_aura_3d.gd/.tscn`  | Ziv: Adoring Aura (radius 7, damage 8, charm 2.5s) |
| `weapons/avihay_voice_blast_3d.gd/.tscn` | Avihay: Voice Blast (radius 6, damage 25, no charm) |

## Design

On every `fire()` tick, the weapon:
1. Calls `affected_enemies(all_enemies, global_position)` — pure XZ distance filter.
2. For each affected enemy: `take_damage(damage * stats.damage_mult)` if `damage > 0`.
3. If `charm_duration > 0` and enemy has `charm()`: `enemy.charm(charm_duration)`.

No physics query — `get_tree().get_nodes_in_group("enemies")` returns all enemies;
XZ distance is computed in pure GDScript.

A placeholder visual ring could be added here (Phase 4.5 VFX).

## Pure helper — unit-tested

```gdscript
func affected_enemies(enemies: Array, origin: Vector3) -> Array:
    # XZ distance filter: ignores Y, returns enemies whose dist <= self.radius.
```

Tested: inclusion, exclusion, exact-boundary, Y-ignored, non-zero origin.

## Lifecycle

| Event | Effect |
|-------|--------|
| `level_up()` | `radius += 1.0`, `damage += 6`, `charm_duration += 0.3` (charm variants only) |
| `evolve()` | `radius *= 1.75` |
| `apply_passive(v)` | `radius += v` |

## Balance reference (1 unit ≈ 16 px)

- Default `radius`: 6.0 units
- Default `damage`: 18 (subclasses override)
- Default `charm_duration`: 0.0 (charm variants set > 0 in _ready)
- Default `base_cooldown`: 2.5 s
