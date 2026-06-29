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

## Layered tasks

Later tasks build on this base:
- **Task 5** — Obstacles layer: `Obstacle3D` props (trees, rocks, water barrels) via `ArenaScatter`
- **Task 6** — Walls/boundary and navigation mesh
- Scatter, water VFX, and other environmental details are added by subsequent tasks without modifying the base ground/sky.
