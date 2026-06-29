# arena-map

`arena/arena_3d.tscn` — Realistic arena map for the 3D horde-survivor.

## Ground

A 200×200 `PlaneMesh` ground plane (`Ground/GroundMesh`) with a PBR `StandardMaterial3D`:

- **Albedo**: `art/textures/grass_diff_2k.jpg` (Poly Haven "aerial_grass_rock", CC0)
- **Normal map**: `art/textures/grass_nor_2k.jpg`
- **Roughness map**: `art/textures/grass_rough_2k.jpg`
- **UV scale**: `Vector3(40, 40, 40)` — tiles the 2 k texture 40× across the 200-unit plane
- roughness = 1.0, metallic = 0.0

## Sky

`WorldEnvironment` uses `background_mode = 2` (Sky) with a `PanoramaSkyMaterial` wrapping the HDRI `art/hdri/sky_2k.hdr` (Poly Haven "kloofendal_43d_clear_puresky", CC0). `ambient_light_source = 3` so ambient lighting is derived from the sky.

## Lighting

`DirectionalLight3D` is aimed at a moderate downward angle (roughly matching the HDRI sun direction); exact angle is playtest-tunable.

## Obstacle scatter (collidable nature props)

The arena scene carries an `ObstacleSpawner` node (script `arena/arena_scatter.gd`,
attached as a child of `Arena3D`). On `_ready` it scatters real CC0 nature props
into the arena:

1. It calls the seeded static `ArenaScatter.compute_positions(...)` to get XZ
   placements (deterministic for a fixed `rng_seed`, none within `clear_radius`
   of the spawn center, all `min_separation` apart).
2. For each position it instances `obstacles/obstacle_3d.tscn`, alternates a
   **tree** / **rock** prop by index, and uses `Obstacle3D.set_model(...)` to add
   the gltf as the visual and size the collision + nav footprint.
3. The obstacles are added under an `Obstacles` `Node3D` child of the arena.
   Because the arena is mid-setup when the spawner's `_ready` fires, the container
   is attached via `add_child.call_deferred(...)` (a direct `add_child` is rejected
   while the parent is "busy setting up children").

**Props** (multi-mesh Poly Haven gltf scenes, CC0):
- Tree: `art/models/nature/fir_tree_01/fir_tree_01_1k.gltf`
- Rock: `art/models/nature/boulder_01/boulder_01_1k.gltf`

These are full Node3D scenes (bark/trunk/twig meshes), not single `Mesh`
resources, so `Obstacle3D.set_model()` adds the instanced scene as a child visual
and hides the empty placeholder `MeshInstance3D`; `configure()` (single-`Mesh` API)
is reused internally only to size the `CylinderShape3D` + `NavigationObstacle3D`.

If a gltf fails to load, the spawner falls back to a `BoxMesh` via `configure()`
and emits `push_warning(...)` — it never crashes.

**Tunable exported params** (on the `ObstacleSpawner` node):

| Param | Default | Meaning |
|---|---|---|
| `obstacle_count` | 35 | how many props to attempt to place |
| `rng_seed` | 1 | seed for deterministic placement |
| `extent` | 88.0 | half-size of the placement square (inside the 95-unit walls) |
| `clear_radius` | 14.0 | radius around origin kept prop-free (spawn area) |
| `min_separation` | 7.0 | minimum distance between any two props |
| `tree_footprint_radius` / `tree_height` | 0.8 / 6.0 | tree collision + nav footprint |
| `rock_footprint_radius` / `rock_height` | 1.4 / 2.0 | rock collision + nav footprint |
| `model_scale` | 1.0 | uniform scale applied to instanced models |

Props sit on the **Obstacles layer (16)** so they block the player and enemies and
carry a `NavigationObstacle3D` for RVO avoidance. Skills never mask layer 16, so
projectiles pass over props unchanged.

## Layered tasks

This base ground/sky is extended by:
- **Borders** — 4 `StaticBody3D` walls on layer 16 enclosing the 200×200 arena.
- **Water** — `Water3D` ponds (decorative + movement-blocking, layer 16).
- **Obstacle scatter** — see above; `ArenaScatter` + `Obstacle3D` props.
- **Enemy RVO avoidance** — `Enemy3D` routes around obstacles/water/props.
