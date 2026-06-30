# ArenaScatter — Seeded Obstacle Placement

## Overview

`ArenaScatter.compute_positions()` is a pure, deterministic placement function that generates XZ positions for arena obstacles using rejection sampling with a seeded `RandomNumberGenerator`.

The instance-side spawner places biome-themed props across four regions (NW Forest, NE City, SW Tech, SE Beach) plus a central plaza hub and road lamps — all deterministic via per-region seeded calls to `compute_positions`.

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

## Region-based Spawner (_ready)

`_ready()` builds the arena layout in four phases:

### 1. Plaza Hub (fixed positions)
- **Fountain** (Obstacle3D, footprint r=1.5) at (0, 0, 16) — named `"Fountain"` so tests can find it.
- **6 Pillars** (Obstacle3D, r=0.5) in a ring at radius 20: (±20,0,0), (±10,0,±17).
- **4 Braziers** (Decor, no collision) at radius ~14: (±10, 0, ±10).

### 2. Road Lamps (Decor, no collision)
32 `prop_lamp_3d` instances at d ∈ {30, 52, 74, 96} on each of the 4 road arms, offset ±7 to either side of the road centreline.

### 3. Regional Props
Each region calls `compute_positions` twice (obstacle seed and decor seed are offset by 50 for independence), offsets results to the region center, and spawns:

| Region | Center (x,z) | Extent | Obstacle Props | Decor Props |
|--------|-------------|--------|----------------|-------------|
| NW Forest | (-50,-50) | 34 | tree×4, rock×2 | bush×3, flowers×2, tall_grass×2, mushroom×1 |
| NE City | (50,-50) | 34 | crate×3, barrel×2, dumpster×1, fence×2, barrier×2 | cone×2, holo_sign×1 |
| SW Tech | (-50,50) | 34 | pylon×3, sci_fi_barrier×2, generator×2 | holo_sign×2 |
| SE Beach | (50,50) | 34 | rock×3, barrier×2, crate×2, barrel×2, pillar×2 | — |

### 4. Navigation Map Activation
`_ready()` also calls `_activate_navigation(parent)`, which adds a flat
`NavigationRegion3D` (`ArenaNavRegion`, a single 200×200 quad navmesh, no baking) to
the arena. This is required because enemy `NavigationAgent3D` RVO avoidance only
produces a non-zero `safe_velocity` when its navigation map is **active**, and the
world's default map stays inactive until a region exists. Without it, every enemy's
`velocity_computed` returned zero and the swarm froze. Pure avoidance needs only an
active map — pathfinding-quality navmesh detail is not required.

## Obstacle vs Decor

- **Obstacle3D wrapper** (collision layer 16 + `NavigationObstacle3D`): trees, rocks, crates,
  barrels, dumpsters, fences, concrete_barriers, pillars, fountain, pylons, sci_fi_barriers,
  generators.
- **Plain visual (no collision)**: flowers, bushes, tall_grass, mushrooms, cones, holo_signs,
  lamps, braziers.

Footprint data lives in the `_FP` constant dictionary in `arena_scatter.gd`.

## Spawn Clearance

Regional extents of 34 with centers at ±50 mean the closest any regional prop can get
to the global origin is 50 − 34 = 16 units — well outside the 10-unit spawn disc.
Plaza hub props are placed at explicit positions all ≥ 12 units from origin
(pillars at r=20, braziers at r≈14, fountain at z=16).

## Tests

`test/test_arena_scatter.gd` validates the pure `compute_positions` logic:
- Determinism, count cap, extent bounds, center clear-radius, min separation, over-dense termination.

`test/test_arena_3d_map.gd` validates runtime spawning and obstacle mesh presence.

`test/test_arena_regions.gd` validates the Final City map layout:
- `Ground/GroundRegions` node and named sub-planes (PlazaCenter, RoadNS, RoadEW, QuadrantNE/SW/SE).
- All region planes have albedo textures.
- Fountain centerpiece in Obstacles node.
- Obstacle count ≥ 20.
- No obstacle within the 10-unit spawn disc.
