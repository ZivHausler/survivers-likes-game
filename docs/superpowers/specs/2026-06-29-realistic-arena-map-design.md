# Realistic Arena Map — Design Spec

> Date: 2026-06-29 · Branch: `feature/v1-vertical-slice` · Status: approved for planning

## Goal

Replace the flat brown arena ground/background with a **realistic-looking outdoor map** (PBR
grass, sky with distant mountains, trees, rocks, water) for the Godot 4.7 horde-survivor
**Friends Swarm**, and make the map **interactive**: trees/rocks/water are obstacles that
**block** the player and enemies (who must route *around* them), and the arena has **border
walls** so neither can leave.

This is a visual + light-gameplay change. It must **not** alter the core game feel: the
playfield stays flat (camera locked at −55° tilt, gameplay on the XZ plane), and skills behave
exactly as before.

## Decisions (locked during brainstorming)

| Question | Decision |
|---|---|
| Terrain height | **None.** Flat playfield. Realism comes from textures + props, not sculpting. |
| Obstacles | Trees / rocks / water **block** player and enemies; both must go around. |
| Borders | Add perimeter walls so the player (and enemies) cannot leave the arena. |
| Enemy navigation | **Lightweight RVO avoidance** (Godot `NavigationAgent3D` avoidance, no baked navmesh) — enemies flow around obstacles and each other. |
| Art style | **Realistic PBR** (Poly Haven / ambientCG, all CC0). |
| Build approach | Scene edits in `arena_3d.tscn` for deterministic parts + a **seeded scatter script** for obstacles (tunable count / seed / clear-radius, unit-testable). |

## Current state (verified)

- `arena/arena_3d.tscn`: a 200×200 `PlaneMesh` ground with a flat brown `StandardMaterial3D`
  (`albedo 0.33,0.22,0.13`), a box collision floor (layer 1), one `DirectionalLight3D`, and a
  `WorldEnvironment` with a **solid brown** background (`background_mode = 1`).
- `enemies/enemy_3d.gd`: `CharacterBody3D` that steers straight at the player
  (`steer_velocity`) and calls `move_and_slide()`. **No pathfinding.**
- **Collision reality:** `player_3d` body `collision_layer=1, collision_mask=0`; `enemy_3d`
  body `collision_layer=8, collision_mask=0`. **Both masks are 0** → today they collide with
  nothing and move purely kinematically. To make obstacles block them, their `collision_mask`
  must include the new obstacle layer.
- World scale: 1 unit ≈ 16 px. Visuals are decoupled (`Juice3D`, `SkillVFX` react to
  `GameEvents`); logic/tests stay green regardless of visuals. Suite: 879/879 green.
- Assets already CC0: Kenney characters, VFX lib. (MDA enemy pack license unconfirmed —
  unrelated to this work.)

## Architecture

### Physics / navigation layers

Introduce a dedicated **Obstacles** collision layer (proposed **layer 5**, value `16`;
final bit confirmed against the project layer map during implementation):

- `Obstacle3D` static bodies and border walls: `collision_layer = Obstacles`.
- `player_3d` body and `enemy_3d` body: add `Obstacles` to their `collision_mask`
  (currently `0`). Nothing else changes about their layers.
- **Skills/projectiles do NOT mask `Obstacles`** → beams, novas, orbits, bubbles pass over
  props exactly as today. No skill-behavior change.

### Components

1. **Ground material (visual).** Replace the brown `StandardMaterial3D` with a realistic PBR
   grass material: albedo + normal + roughness (+ AO if available), UV-tiled across 200×200.
   Sourced from Poly Haven / ambientCG (CC0). Stored under `art/` with import settings.

2. **Sky (visual).** Replace the solid-brown background with an **HDRI panorama sky**
   (Poly Haven, CC0) via `Sky` + `PanoramaSkyMaterial` on the `WorldEnvironment`
   (`background_mode = Sky`). Provides realistic sky, a distant mountainous horizon (no
   mountain geometry needed), and ambient lighting. The existing `DirectionalLight3D` is
   re-aimed to match the HDRI sun direction; ambient set to use the sky.

3. **`Obstacle3D` scene (gameplay).** Reusable: `StaticBody3D` (`collision_layer = Obstacles`)
   + `MeshInstance3D` (realistic PBR rock/tree) + `CollisionShape3D` (cylinder/box footprint)
   + `NavigationObstacle3D` (radius ≈ footprint, so RVO routes enemies around it). Variants
   chosen by a small data list (mesh + footprint radius + nav radius per prop type).

4. **Water (decorative + blocking).** One or two flat water meshes with a simple realistic
   water material, each wrapped with blocking collision + a `NavigationObstacle3D` so
   player/enemies path around the pond. Decorative ripple only — no fluid sim.

5. **Border walls (gameplay).** Four perimeter `StaticBody3D` walls just inside the plane
   edge (`collision_layer = Obstacles`) so neither player nor enemies leave. Visually dressed
   with cliff/rock meshes or left invisible behind the HDRI horizon — collision is the point.
   Walls rely on collision-slide (no nav obstacle needed; enemies chase inward).

6. **`arena_scatter.gd` (gameplay placement).** Attached in `arena_3d.tscn`. On `_ready`,
   deterministically scatters N `Obstacle3D` instances using a seeded RNG. Pure placement
   logic (the part under test) is separated from node instantiation so it can run headless.
   - **Inputs (exported, tunable):** `obstacle_count`, `rng_seed`, `clear_radius` (keep the
     center spawn open), `min_separation`, `arena_extent` (inside the border walls).
   - **Output:** a list of `{position, prop_type}`. Rejects positions within `clear_radius`
     of origin, within `min_separation` of an already-placed prop, or outside `arena_extent`.

7. **Enemy avoidance (the one change to an existing system).** Add a `NavigationAgent3D`
   (`avoidance_enabled = true`, `radius` ≈ enemy footprint) to `enemy_3d`. Per physics frame:
   - compute desired velocity with the existing `steer_velocity` toward the target,
   - `agent.set_velocity(desired)`,
   - in the `velocity_computed(safe_velocity)` callback, set `velocity = safe_velocity` and
     `move_and_slide()`.
   No baked navmesh is required — avoidance uses the RVO server with `NavigationObstacle3D`
   for static props and agent-agent avoidance for the swarm. Player movement is unchanged
   (single-body collision-slide is sufficient).

## Data flow

```
arena_3d.tscn (_ready)
  └─ arena_scatter.gd → placement logic (seed, clear_radius, min_sep) → [{pos, type}]
        └─ instantiate Obstacle3D per entry (mesh + collision + NavigationObstacle3D)

enemy_3d._physics_process
  desired = steer_velocity(self, player)        # existing logic, unchanged
  agent.set_velocity(desired)                   # RVO in
  └─ velocity_computed(safe) → velocity = safe; move_and_slide()   # RVO out, avoids props+peers
```

## Error handling / edge cases

- **Missing asset (texture/HDRI/mesh fails to load):** fall back to the current flat material /
  procedural sky so the scene never hard-crashes; log a warning.
- **Scatter can't place all N** (too dense for `arena_extent`/`min_separation`): place as many
  as fit after a bounded number of attempts, log the shortfall — never infinite-loop.
- **Clear radius:** guarantee no obstacle within `clear_radius` of origin so the player never
  spawns inside a rock.
- **Avoidance latency:** `velocity_computed` arrives the next physics frame; on the very first
  frame fall back to the desired velocity so enemies never freeze.
- **Obstacle vs. skills:** verified by layer separation — skills must not gain the Obstacles
  mask.

## Testing

Headless, GUT (remember: use `assert_true(x <= y)`, never `assert_le`/`assert_ge`).

- **Scatter placement (pure logic):** deterministic for a fixed seed; no position within
  `clear_radius` of origin; all positions within `arena_extent`; pairwise distance ≥
  `min_separation`; returns ≤ `obstacle_count`; graceful when over-dense.
- **Collision wiring:** `Obstacle3D` and border walls carry the Obstacles layer; `player_3d`
  and `enemy_3d` masks include Obstacles; skill projectile scenes do **not**.
- **Avoidance config:** `enemy_3d` has a `NavigationAgent3D` with avoidance enabled and the
  `velocity_computed` path sets velocity (smoke-level, since RVO motion is hard to unit-test).
- Full suite must stay green (currently 879). Visual-only changes add no logic risk.

## Asset sourcing (CC0)

| Asset | Source | Notes |
|---|---|---|
| Grass / dirt PBR texture | Poly Haven · ambientCG | Plentiful, photoreal, CC0. |
| HDRI sky (mountainous horizon) | Poly Haven | Sky + distant mountains + ambient in one. |
| Rocks / boulders / cliffs | Poly Haven | Good realistic CC0 coverage. |
| Water material | Built shader / simple PBR | Decorative ripple, no sim. |
| **Trees (realistic)** | **RISK** | Realistic CC0 tree models are scarce. Source best available; **fallback: stylized tree** rather than blocking the feature. Will flag what was used. |

Assets land under `art/` with Godot `.import` files; licenses recorded in
`docs/notes/asset-licenses.md`.

## Out of scope (YAGNI)

- Terrain height / sculpting / heightmaps.
- Full navmesh global pathfinding (avoidance only).
- Obstacles blocking skills/projectiles.
- Destructible obstacles, biomes, day/night, weather, fluid simulation.
- Touching the legacy 2D scenes.

## Known tradeoffs

- Realistic PBR props will visually contrast with the blocky Kenney characters (user-chosen).
- RVO is *local* avoidance: enemies won't globally path around a large concave obstacle.
  Acceptable for small convex props (trees/rocks); border walls use collision-slide.
- Avoidance adds modest CPU per enemy; acceptable for the current swarm scale, revisit if
  large waves stutter.
