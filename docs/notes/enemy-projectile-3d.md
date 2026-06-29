# `EnemyProjectile3D` — Enemy Ranged Attack Projectile

## Purpose

`EnemyProjectile3D` is a traveling enemy attack that ranged enemies (e.g., Spitter variants) fire at the player. It moves along a fixed XZ direction, damages the player on contact with their hurtbox, and despawns on terrain collision so trees/rocks/walls act as cover.

## Physics Layers

- **collision_layer**: 0 (invisible to physics queries)
- **collision_mask**: 18 (detects layer 2 + layer 16)
  - Layer 2: Player hurtbox (`Hurtbox3D` Area3D)
  - Layer 16: Terrain obstacles (trees, rocks, walls)
  - Excludes layer 8 (enemies) so projectiles don't block each other
  - Excludes layer 1 (ground) so projectiles pass through the arena

## Behavior

- `setup(direction: Vector3, speed: float, damage: float)`: Configure the projectile. Direction is flattened to XZ plane and normalized.
- `_advance(dt: float)`: Pure movement step (testable without signals). Moves along direction × speed × dt.
- Signals: `area_entered` (player hurtbox hit) → deal damage + despawn
- Signals: `body_entered` (terrain hit) → despawn (cover mechanic)
- Lifetime cap: `MAX_LIFETIME = 6.0 s` (prevents accumulation of stray projectiles)

## Visibility

The scene includes a `MeshInstance3D` placeholder (no mesh assigned by default). VFX/mesh assignment happens via a decoupled system (Task 4.5 or later).

---

Used by: `Spawner3D` / ranged enemy variants (Task 2+)
