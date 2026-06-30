# ArenaScatter — Seeded Obstacle Placement

## Overview

`ArenaScatter.compute_positions()` is a pure, deterministic placement function that generates XZ positions for arena obstacles using rejection sampling with a seeded `RandomNumberGenerator`.

The instance-side spawner scatters two sci-fi prop types into the arena: **pylons** (tall, even-indexed slots, ~6 units) and **barriers** (low, odd-indexed slots, ~2 units). Both are primitive Godot scenes — no external gltf assets required.

**File:** `arena/arena_scatter.gd`

**Class:** `class_name ArenaScatter extends Node`

## Interface

```gdscript
static func compute_positions(
    rng_seed: int,           # Seed for determinism
    count: int,              # Target number of obstacles
    extent: float,           # Half-width/height of placement arena ([-extent, extent])
    clear_radius: float,     # Minimum distance from origin (spawn protection)
    min_separation: float,   # Minimum pairwise distance between obstacles
    attempts_per: int = 30   # Attempt budget before terminating early (over-dense case)
) -> Array                   # Returns Array[Vector3] with y=0
```

## Guarantees

- **Deterministic:** same seed → identical output
- **Extent:** all positions within `[-extent, extent]` on X and Z
- **Clear radius:** no position within `clear_radius` of origin (0, 0, 0)
- **Separation:** all pairwise distances ≥ `min_separation`
- **Capped count:** returns ≤ `count` positions
- **Termination:** rejects after `attempts_per` failed tries; gracefully returns fewer (no hang)
- **Height:** all positions on XZ plane (y = 0)

## Implementation

Uses **rejection sampling**:

1. For each of `count` attempts:
   - Generate random (x, z) in `[-extent, extent]`
   - Skip if within `clear_radius` of origin
   - Check pairwise distance against all placed obstacles
   - If acceptable, append and move to next
   - If rejected `attempts_per` times, area is saturated; terminate

2. Return array of placed positions

This design prevents infinite loops while allowing graceful degradation when the request is geometrically impossible (e.g., fitting 1000 obstacles with tight separation in a small area).

## Usage (Task 8)

The arena scene calls `compute_positions()` with the seed and placement knobs, then instantiates
`Obstacle3D` at each returned position with either a pylon (even index) or barrier (odd index).

## Sci-Fi Props (Phase 4.3)

The spawner places two primitive Godot-native prop types instead of external gltf assets:

- **Pylon** (`obstacles/sci_fi_pylon_3d.tscn`): tall slim column (~6 units), dark metal body
  (`Color(0.12, 0.13, 0.16)`) with two emissive rings — cyan (`Color(0.3, 0.8, 1.0)`) at mid-height
  and magenta (`Color(1.0, 0.2, 0.6)`) near the top. `emission_energy_multiplier = 3.0/2.5`
  so the WorldEnvironment bloom fires above the HDR threshold (1.0). Fills the even-indexed slot
  with `tree_footprint_radius=0.8`, `tree_height=6.0`.
- **Barrier** (`obstacles/sci_fi_barrier_3d.tscn`): wide angular block (~2 units), dark metal body
  with a cyan emissive top stripe (`emission_energy_multiplier = 2.5`). Fills the odd-indexed slot
  with `rock_footprint_radius=1.4`, `rock_height=2.0`.

Both scenes are visual-only `Node3D` roots (no collision/nav); `Obstacle3D.set_model()` wraps them
with the `CylinderShape3D` + `NavigationObstacle3D` footprint. `model_scale = 1.0` for both since
they are pre-sized at game scale. The `_extract_tree_variant()` helper that dug into the gltf
sibling structure is removed — no longer needed.

## Navigation Map Activation

`_ready()` also calls `_activate_navigation(parent)`, which adds a flat
`NavigationRegion3D` (`ArenaNavRegion`, a single 200×200 quad navmesh, no baking) to
the arena. This is required because enemy `NavigationAgent3D` RVO avoidance only
produces a non-zero `safe_velocity` when its navigation map is **active**, and the
world's default map stays inactive until a region exists. Without it, every enemy's
`velocity_computed` returned zero and the swarm froze (the enemy-side
`AVOID_EPSILON_SQ` fallback in `enemy-3d.md` is the second line of defense). Pure
avoidance needs only an active map — pathfinding-quality navmesh detail is not
required.

## Tests

`test/test_arena_scatter.gd` validates:
- Determinism (same seed → identical results)
- Count capped at request
- All positions within extent and on XZ plane
- Center clear-radius respected
- Minimum separation respected
- Over-dense requests terminate gracefully

`test/test_arena_3d_map.gd` validates runtime spawning and prop mesh presence (pylon Obstacle3D
contains at least one visible MeshInstance3D). `test/test_scifi_props.gd` validates that both
prop scenes load as `Node3D` with at least one `MeshInstance3D` child.
