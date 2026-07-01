# Art-Directed Arena Overhaul — Design Spec

**Goal:** Replace the current "flat biome blobs + placeholder HUD" look with an art-directed,
production-quality top-down roguelite arena — modular tiled floors with authored transitions,
clustered themed props with landmarks, and a polished visual-only HUD — reaching **≥85/100**
on the visual QA rubric.

**Scope of THIS spec (vertical slice):** the **central hub** + **one district (Garden/Park)** +
the **rebuilt HUD** + **lighting**, built on new systems and iterated to ≥85/100. Replicating the
proven tile kit + prop recipe to the other districts (sci-fi, industrial, temple, ruined/wild) is
**out of scope here** — each becomes a follow-up spec/plan reusing this recipe.

**Architecture:** Fresh, data-driven **modular 3D tile floor** (grid + pure autotile resolver +
trim/decal overlays) replaces MapBuilder's blob floor. Clustered, authored prop placement replaces
random scatter. A fresh visual-only HUD binds existing game data. All visual quality is gated by the
screenshot QA loop (`docs/notes/visual-qa-loop.md`), not unit tests.

**Tech stack:** Godot 4.7 (GDScript, 3D), angled top-down `Camera3D`, `Decal` nodes, SDXL art
pipeline (`artkit/generation/*`), GUT tests.

## Global Constraints

- **3D, angled top-down.** No 2D TileMap; "tiles" are flat 3D meshes on a grid under the existing
  MOBA-style `GameCamera3D`. Combat readability at gameplay-cam distance is mandatory.
- **Visual-only HUD.** Bind ONLY existing data (timer, kills, level, HP, XP, weapons+cooldowns,
  ultimate, passives, boss). Do NOT build coins/wave/dash gameplay systems — omit or show a tasteful
  placeholder.
- **No auto-fail conditions** from `docs/notes/visual-qa-loop.md` may be present in a passing slice
  (no flat blobs, no harsh borders, no sparse/random props, no debug-looking HUD, no undetailed floor).
- **Deterministic pure logic.** The autotile resolver and any placement math are pure and
  unit-tested (pattern: `ArenaScatter.compute_positions`), byte-stable for a fixed seed.
- **Keep the suite green.** Update or replace MapBuilder-tied tests when the floor is swapped; never
  leave the suite red.
- **Authored, not dumped.** Zone layouts and prop clusters are hand-authored data, not procedural noise.
- **North-star identity (binding).** Everything obeys the visual identity in
  `2026-06-30-lol-swarm-visual-identity-design.md`: *stylized 3D cyber-anime bullet-heaven,
  painterly League materials (baked-AO look, color-blocked, low texture noise, matte with select
  glowing tech accents), neon cyan/magenta reserved for accents & VFX.* See §0.

## 0. Visual identity alignment (north-star)

This overhaul must read as **"Final City" cyber-anime sci-fi**, not generic fantasy. The identity
doc and this brief pull in slightly different directions; the resolution:

- **Ground is a readable combat stage, not the star.** Achieve the brief's "rich floor detail"
  through **value, pattern, trims, seams and decals** — NOT loud color. The environment stays
  **lower-saturation than combat VFX** (identity §8/§16) so purple enemies and cyan/magenta
  projectiles pop. Detail ≠ saturation.
- **Districts are interpreted through the cyber-anime lens.** The Garden slice is a **neon
  cyber-park within Final City** — muted greens + gray stone paving + subtle cyan tech accents and
  glowing emissive trims — not a medieval/natural garden. Later districts (industrial, temple,
  ruined) likewise get a Final-City-sci-fi reading, keeping one coherent universe.
- **Materials:** painterly/stylized (not realistic PBR): baked soft AO, color-blocked regions,
  hand-painted gradients, controlled roughness, low noise, matte surfaces with **select** emissive
  masks. Contact AO under everything.
- **Lighting:** bright soft ambient, low-to-medium contrast, bloom **only** on emissive/tech/magic
  accents; neutral ground lighting so VFX provides the drama (identity §7).
- **HUD:** League DNA — dark panels, bright painterly icons, compact functional layout, no ornate
  borders (identity §12).
- **Camera/composition:** top-down slightly-iso tactical field; combat center open; big readable
  shapes first, small detail second (identity §9).

## 1. Floor — modular 3D tile system (new)

### 1.1 Grid + zone map
- The arena is a grid of cells (**4×4 world units**/cell; arena ≈ 190×190 → ~48×48 cells).
- A hand-authored **zone map** assigns each cell a `zone_id`. Garden slice zones:
  `grass`, `stone_plaza` (hub), `stone_path`, `dirt_path`, `flowerbed`, `pond`.
- Authored as an **ASCII string-grid** in a recipe file (one char per cell → zone id, roguelike-map
  style: diff-able, hand-editable, fast to iterate). Central hub = a radial `stone_plaza` disc;
  garden = grass with winding `stone_path`/`dirt_path` connecting hub → district; a small `pond`.

### 1.2 Autotile resolver (pure, unit-tested)
- Input: the zone grid + a cell. Reads the 8-neighbourhood, computes a bitmask of "which neighbours
  differ / are lower priority," returns `{piece_id, rotation_quarters}`:
  `base`, `edge`, `outer_corner`, `inner_corner`.
- **Zone priority** breaks seams: the higher-priority zone owns the transition (e.g., `stone_plaza`
  overlays `grass`). Priority order (high→low): `stone_plaza > stone_path > dirt_path > flowerbed >
  grass`; `pond` is a special inset (its own rim). Deterministic; no engine calls in the resolver.

### 1.3 Tile & transition meshes
- **Base tile:** a flat textured quad (the zone's base material) at the cell, tiny Y-step per layer to
  avoid z-fighting.
- **Transition:** the higher-priority zone lays, at the seam, (a) a **trim-strip mesh** (a low beveled
  curb, oriented per the resolver) and (b) a soft **alpha edge-decal** of that zone bleeding onto the
  lower zone (grass-creep onto stone, stone-curb into dirt). This avoids authoring N² pair textures.
- **Curved paths** use the same resolver on `stone_path`/`dirt_path` cells; corners get the
  `outer/inner_corner` pieces so paths read as designed, not blocky.

### 1.4 Variation & decals
- Each zone has **2–3 base texture variants** (clean / worn / cracked) chosen by a hash of cell
  coords so repeated areas never look flat.
- **`Decal` nodes** overlay authored detail: cracks, stains, moss, fallen leaves, path-wear, hazard
  motifs, and a **central plaza medallion** at the hub. Decals cluster around props/landmarks and along
  path centers.

### 1.5 Assets (SDXL + primitives)
- **Generated (tileable, seamless):** `grass_garden`, `stone_plaza`, `stone_path`, `dirt_path` base
  textures (+ worn/cracked variants); a stone **curb trim** texture.
- **Generated (alpha decals):** crack, moss, grass-creep edge, fallen-leaves, path-wear, plaza
  medallion, soft round **contact shadow**.
- **Meshes (primitives/code):** tile quad, beveled curb-trim strip, pond surface + bright shoreline rim.

## 2. Props — clustered & art-directed (Garden)

- **Prop budget per district:** **1 landmark**, **3–6 medium**, **10–25 small**. Garden = a
  **neon cyber-park** (Final City lens): natural greenery + sleek sci-fi civic props + subtle glowing
  tech accents, muted palette so VFX pop.
  - Garden landmark: a large **bioluminescent hero tree** with cyan emissive veins **or** a
    holo-shrine / small power-core on a raised stone-plaza plinth.
  - Medium: sleek sci-fi benches, glowing planters, a neon lamp cluster, a small pond/water feature
    with a bright rim, a tech-trellis arch.
  - Small: stylized bushes, tall grass tufts, low glow-flowers, pebbles, fallen leaves, holo-signage,
    low sci-fi fences/bollards.
- **Placement (authored clusters, not scatter):** a `PropClusters` data structure lists named clusters
  at **designed anchors** — near the landmark, along path edges, in corners, against the arena rim —
  each a themed set with bounded jitter and min-separation. Combat center stays open (respect the spawn
  disc + keep lanes).
- **Grounding:** every prop gets a soft **contact-shadow decal** and, for clusters, surrounding floor
  decals (dirt ring, scattered leaves). No floating props; varied prop scale.

## 3. HUD — fresh, visual-only

- **Top strip:** timer, kills, level; boss/elite indicator when a boss is active. **Wave counter is
  omitted** (no wave system) — do not fake it.
- **Bottom-center cluster:** framed **HP bar** + **EXP bar** + level; **ability icons** with **cooldown
  rings**; **ultimate** status slot (ready-glow + keybind). **Dash and coins are omitted** (no backing
  system) — no empty placeholder panels, per the QA rubric's "no debug/empty UI" rule.
- **Side:** passives / temporary buffs (bind `player.passives`).
- **Top-right:** radar **minimap** + a settings/pause button.
- **Style:** dark translucent framed panels, consistent icon frames, cooldown overlays, colored bars,
  subtle ready-glows, one consistent type system — matching the arena's art style.
- **Reuse primitives:** `RadialCooldown`, `ui/minimap.gd`, `HUDIcon`, and the ability-icon
  filename convention (`art/icons/abilities/<skill_id>.png`, portrait `<char_id>.png`) if kept.
- Fresh `hud.gd`/`hud.tscn`; bind via existing signals/duck-typed accessors.

## 4. Lighting & rendering

- Soft **directional key** + **ambient fill** (WorldEnvironment), gentle **bloom** on emissive/magic/
  sci-fi accents only, **contact shadows** under props, controlled saturation, top-down-readable
  contrast. No harsh realistic darkness, no flat unlit look, no blown-out glow.

## 5. Scene hierarchy

```
Arena3D
  Environment        (WorldEnvironment + DirectionalLight)
  Floor              (driven by the zone grid + autotile resolver)
    BaseTiles / TransitionTrims / Decals
  Props
    Landmarks / MediumProps / SmallDetails   (+ contact-shadow decals)
  Gameplay           (Player, EnemySpawnZones, Navigation)   [existing]
HUD                  (CanvasLayer, separate)
```

## 6. Tooling — the QA loop

- Governed by `docs/notes/visual-qa-loop.md`: render → score → fix top-5 → repeat to **≥85/100**.
- Screenshots: **(a)** full-map overview, **(b)** a NEW **gameplay-cam** shot (angled top-down at
  player height, hub+garden) to judge combat readability, **(c)** HUD preview over the arena.
- Every review writes the verbatim `VISUAL QA REPORT`. Fixes follow the priority order
  (map/transitions → floor detail → prop clusters → HUD → lighting).

## 7. Testing

- **Unit (GUT):** the pure **autotile resolver** (bitmask → piece + rotation, priority tie-breaks,
  rotation invariants) and **zone-grid** access; deterministic prop-cluster math. Keep them green.
- **Visual:** gated by the QA loop, not unit tests.
- **Migration:** MapBuilder-tied structural tests (`test_arena_regions`, `test_arena_3d_map` water/
  ground assertions) are updated to assert the new tiled floor, or retired with the blob floor.

## 8. Success criteria

- Hub + Garden reach **≥85/100** on the QA rubric for both the overview and the gameplay-cam shot.
- No auto-fail condition present. HUD instantly communicates HP/EXP/level/timer/kills/abilities/boss.
- Suite green. Tile kit + prop recipe are documented/data-driven enough to **replicate** to the next
  district by authoring new zone data + a themed prop cluster set (proving the recipe).

## 9. Out of scope (follow-ups)

- The other districts (sci-fi, industrial, temple, ruined/wild) — each a follow-up spec reusing the kit.
- New gameplay systems (coins, waves, dash). Alien enemy/boss meshes (separate phase).
- The paused/parked ability-icon roster batch (54 prompts already drafted) — revisit if the new HUD
  keeps per-skill icons.
