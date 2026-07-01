# Splatmap Ground Blending — Design

**Date:** 2026-07-01
**Status:** Approved (design), pending implementation plan
**Related:** `2026-07-01-graphic-ui-and-map-design-spec.md` (living spec),
`2026-07-01-art-directed-arena-overhaul-design.md`, `2026-06-30-lol-swarm-visual-identity-design.md`

## Problem

Garden zone transitions do not mesh. The current floor builds **one flat quad per cell**,
each with its own opaque zone material at a slightly different `y`, then tries to hide the
seams with **alpha-faded "feather" overlay quads** (a second mesh of the neighbour's texture
faded out with vertex alpha). This fundamentally cannot blend: an alpha-faded full texture is
a *semi-transparent ghost* of one surface floating over another, not a mix of two surfaces.
User complaints all trace to this: grass tiles show straight cut lines between blocks;
grass↔pavement, flowerbed↔grass, and the pond shoreline all read as hard edges or translucent
ghosts.

## Decision

Adopt the industry-standard **splatmap** technique: **one flat ground surface** with a shader
that blends the zone textures **per-pixel** from a control map generated off the existing
`ZoneGrid`. This is how Godot terrain tools (HTerrain CLASSIC4, vertex-color splat shaders)
solve ground transitions. Chosen over (B) pre-baked half-X/half-Y transition tiles
(combinatorial art, still shows tile seams) and (C) per-tile neighbour-sampling shaders
(more code, worse corners) — see the two rejected options in the brainstorm.

Two user-requested refinements are first-class in this design:

1. **Controllable blend width, including razor-sharp.** Blending is *not* always wanted — a
   road should be able to have a clean, crisp edge. Every zone carries a `blend` width; a
   boundary blends over `min(width_A, width_B)`, so setting a zone's `blend` to **0** keeps its
   edges sharp while everything else stays soft.
2. **Faux height for the plaza.** The plaza should *look and feel* higher without being raised
   (raised walkable geometry swallows the character — hard project constraint). Achieved with
   an **edge-shadow (AO) band** painted on the low side of a tier drop plus optional
   **height/depth blending** so the higher-tier texture sits *on top of* its neighbour at the
   seam. Geometry stays dead flat at y=0.

### Hard constraint (unchanged)

The walkable floor stays flat at the entity plane (y≈0). All relief is faked via shading
(AO band, depth blend, normals) and real props — never by raising the combat floor.

## Architecture

```
garden_map.gd (recipe: zones + blend/tier/tile_scale)
      │
      ▼
ZoneGrid ──► SplatField (pure) ──► splatmap RGBA Image + edge-shadow Image
      │                                   │
      ▼                                   ▼
FloorBuilder ──► one merged flat ground ArrayMesh ──► splat_ground.gdshader
                 (+ decals, centerpiece, pond water with soft rim)
```

## Components

### 1. `arena/floor/splat_field.gd` (new — pure, `class_name SplatField`)

Pure data helper (no engine nodes beyond `Image`), so it is unit-testable. Given a `ZoneGrid`,
a channel mapping, per-zone `blend` widths, and per-zone `tier`, it produces:

- **Splatmap (RGBA `Image`).** Channel mapping is fixed and documented:
  `R = stone_plaza, G = stone_path, B = dirt_path, A = flowerbed`. **Grass is the base**:
  its weight is `1 − (R+G+B+A)`. That covers all 5 walkable zones in 4 channels + base.
  - Weights come from a **signed distance field** per zone (distance in world units from a
    texel to that zone's region edge, positive inside), converted with
    `weight = smoothstep(−w/2, +w/2, distance)`, where `w` is the boundary blend width.
  - Boundary width between zones A and B is `min(blend_A, blend_B)`. `blend = 0` ⇒ the
    smoothstep degenerates to a hard step ⇒ a crisp edge.
  - After per-zone weights are computed, they are normalised so the 5 weights (incl. grass
    base) sum to 1 at every texel.
  - Resolution: `K` texels per cell (start `K = 8`; tune). Filter LINEAR, no repeat (clamp).
  - `pond` and `void` map to the grass base (weight 0 in all channels). Ground is rendered
    *under* the pond so the water's soft rim can reveal grass at the shore; `void` cells emit
    no ground geometry, so their splat values are never sampled.

- **Edge-shadow / AO map (single-channel `Image`, stored in an unused channel or its own
  texture).** For every boundary where `tier` drops from high to low, write a soft dark band
  (a short falloff in world units) on the **low** side. Plaza is `tier 1`, everything else
  `tier 0`, so the plaza gets a shadow moat that makes it read as a low plateau.

### 2. `arena/floor/splat_ground.gdshader` (new — spatial shader)

- **Uniforms:** `sampler2D splatmap`, `sampler2D ao_map`, five albedo samplers
  (`grass_tex, plaza_tex, path_tex, dirt_tex, flowerbed_tex`), `vec2 tile_scale` (world→tile
  UV factor; can be promoted to per-zone later), `float roughness`, `bool height_blend`.
- **Fragment:**
  1. Sample `splatmap` at UV (UV = world-XZ mapped to [0,1] across the map extent).
  2. Derive the 5 weights (grass = 1 − sum of the 4 channels), clamped ≥ 0.
  3. **Optional height/depth blend** (`height_blend`): bias each weight by a cheap height
     proxy (albedo luminance of that layer) so the "taller" texture wins near a seam — plaza
     cobbles visibly overlay grass instead of cross-fading. No new art required.
  4. `ALBEDO = mix of the 5 zone albedos by (biased) weight`, each sampled at
     `UV * tile_scale` to keep each texture at its intended real-world scale.
  5. Multiply `ALBEDO` by the `ao_map` sample (the faux-elevation edge shadow).
  6. `ROUGHNESS = roughness` (uniform; matches current ~0.92).

### 3. `arena/floor/floor_builder.gd` (rewrite of the floor build)

- **Remove:** `_feather_edge`, `_feather_mat`, `_FEATHER_ONTO`, `_pond_fringe`, the
  `SeamScatter` container, and the elevation **curbs** (`_lay_curbs` skirt/cap — with all zone
  `y` equal there are no steps, so curbs are gone; remove the call and the now-dead helper +
  `_skirt_mat`/`_curb_mat` if unused elsewhere).
- **Replace** the per-cell `base_tiles` loop with **one merged ground `ArrayMesh`**: iterate
  all non-`void` cells (including `pond` cells), emit each cell's flat quad at `y = 0` into a
  single `SurfaceTool`, with `UV = (world.x, world.z)` mapped to `[0,1]` across the full map
  rectangle (`width*cs` × `height*cs`). Commit once, assign the splat `ShaderMaterial` built
  from the two generated `ImageTexture`s + the zone albedo textures.
- **Keep:** `_build_decals`, `_build_centerpiece` (medallion inlay on the plaza),
  `_tile_mesh`/`_disc_mesh` helpers (used by the centerpiece).
- **Pond water:** keep the opaque water disc, but give it a **soft radial alpha rim** (vertex
  alpha or a small shader) that fades the water out over its last ~1–2 world units, so it
  blends into the grass now rendered beneath it — a real shoreline. Replaces `_pond_fringe`.

### 4. `arena/maps/garden_map.gd` (recipe changes)

- Flatten every walkable zone `y` to `0.0` (draw-order steps are unnecessary on one surface).
- Add per-zone fields: `blend` (world units; e.g. grass/flowerbed ~3.0 soft, a path can be
  `0.0` for a crisp road), `tier` (plaza `1`, others `0`), optional `tile_scale`.
- Textures and colours are unchanged. The `priority` map (seam ownership) is no longer used
  by the floor build and may be removed if nothing else reads it.

### 5. TileVariants

Per-cell tint variation no longer applies to one blended surface, so the floor stops calling
`TileVariants.variant_for`. If the blended ground looks flat/repetitive, add a **cheap noise
tint** in the shader (a low-frequency value multiply) rather than reintroducing per-tile
materials. `TileVariants` stays for any non-floor caller.

## Testing

- **New `test/test_splat_field.gd`** (pure, headless):
  - Weights at every sampled texel sum ≈ 1 (within tolerance).
  - A texel deep inside a zone = that zone's weight ≈ 1 (pure).
  - A texel on a soft boundary = intermediate weights for both zones.
  - A zone with `blend = 0` produces a **hard step** across its edge (no intermediate texel).
  - The AO band is darker only on the **low** side of a tier drop (and absent on same-tier
    boundaries).
- **Update `test/test_arena_regions.gd`**: the `TransitionTrims`/curb assertion is obsolete
  (curbs removed). Replace with assertions that the merged splat ground mesh exists and the
  splat control texture is present on its material.
- **Regression:** `test_garden` and `test_prop` must still pass. Prop scatter reads zones (not
  `y`), so flattening `y` should not move props — confirm during implementation.

## Non-goals / later

- Blending the 5 **normal maps** too (v1 is albedo + depth-blend + AO for relief).
- Per-zone `tile_scale` as a full array (v1 may use one shared `tile_scale`).
- Reworking pond as a splat "wet sand" layer (v1 keeps a water disc with a soft rim).

## Change log

- 2026-07-01: Initial design. Approved: splatmap (option A) with per-zone `blend` width
  (0 = sharp) and faux-height plaza via AO edge-shadow + optional depth blend.
