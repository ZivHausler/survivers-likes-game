# ArenaScatter — Seeded Obstacle Placement

## Overview

`ArenaScatter.compute_positions()` is a pure, deterministic placement function that generates XZ positions for arena obstacles using rejection sampling with a seeded `RandomNumberGenerator`.

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

The arena scene will call `compute_positions()` with run-specific parameters (seed from RunState), then instantiate `Obstacle3D` at each returned position.

## Single-Variant Tree Selection (defect fix)

The `fir_tree_01_1k.gltf` asset contains **three** sibling tree variants as direct children of
its root node: `fir_tree_01_a_LOD0`, `fir_tree_01_b_LOD0`, `fir_tree_01_c_LOD0`, each offset
along X by ~6 units. Attaching the whole instantiated scene to an Obstacle3D would render a
cluster of 3 trees while only one has a CylinderShape3D collision and NavigationObstacle3D footprint.

`_extract_tree_variant(tree_instance)` resolves this: it picks the **first direct child** whose
name contains `"fir_tree"` (currently `fir_tree_01_a_LOD0`), resets its transform to
`Transform3D.IDENTITY`, frees the parent (which discards the other siblings), and returns the
single variant. If no matching child is found a `push_warning` is emitted and the whole instance
is used as a safe fallback.

The `tree_model_scale` export (default `0.35`) controls the scale of the extracted tree variant;
the raw mesh is ~18 units tall and the player capsule is ~2 units, so `0.35` gives ~6 units.
Rocks continue to use the existing `model_scale` export.

## Tests

`test/test_arena_scatter.gd` validates:
- Determinism (same seed → identical results)
- Count capped at request
- All positions within extent and on XZ plane
- Center clear-radius respected
- Minimum separation respected
- Over-dense requests terminate gracefully
