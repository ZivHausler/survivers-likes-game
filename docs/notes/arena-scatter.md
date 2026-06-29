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

## Tests

`test/test_arena_scatter.gd` validates:
- Determinism (same seed → identical results)
- Count capped at request
- All positions within extent and on XZ plane
- Center clear-radius respected
- Minimum separation respected
- Over-dense requests terminate gracefully
