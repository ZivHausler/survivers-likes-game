# Graphic UI & Map Design Spec — Friends Swarm

> **Status:** LIVING DOCUMENT. Update this whenever we make UI/map design decisions
> (see the maintenance rule in the project `CLAUDE.md`). It is the cross-session memory
> for how maps and the HUD should look and be built.
>
> **Relationship to other docs:**
> - North-star colours/style: `docs/superpowers/specs/2026-06-30-lol-swarm-visual-identity-design.md`
> - Overhaul architecture + decoupling: `docs/superpowers/specs/2026-06-28-friends-swarm-visual-overhaul-design.md`
> - Remake plan: `docs/superpowers/plans/2026-06-30-lol-swarm-visual-remake.md`
> - This doc = **map/environment composition + HUD layout + asset inventory + authoring recipes.**

---

## 0. Locked decisions (the rules everything else follows)

- **New design only on new assets.** Do NOT re-skin existing mobs / existing Kenney
  character models with the neon cel/rim overlay. The neon treatment is reserved for NEW
  assets we create. (`stylize_model` defaults OFF; enemies render native.)
- **Native-resolution rendering.** `project.godot` stretch mode = `disabled`, maximized,
  MSAA 4× + FXAA + 16× anisotropic. Primary dev display is **3440×1440 ultrawide**.
- **HUD layout = "command bar" (Battlerite-style)** — see §4.
- **Meshes: primitives now, Hunyuan later.** Props are built from Godot primitives; bespoke
  Hunyuan meshes are a deliberate future pass.
- **Performance note:** SDXL texture/mesh generation saturates the GPU — never run the game
  while a generation job is running (that was the "lag"). Serialize Godot tasks (only one
  Godot instance — game or headless — at a time) to avoid import-cache clashes.

---

## 1. Map / Environment Design Language

The single biggest lesson from the references: **the FLOOR carries the richness, not blocking
props.** Much of a map should be walkable yet visually rich, achieved through decorative floors,
decals, inlays and small non-blocking scatter — not only by filling space with collidable objects.

**Overarching goal: the whole map should feel VIBRANT and INTERESTING — not uniformly busy.**
- **Blocking spaces are fine** (walls, buildings, dense rock formations, fenced gardens, interiors)
  — they add structure, landmarks and tactical variety. Just keep *enough* open play space and
  clear lanes that the bullet-heaven stays playable.
- **Not every area must be dense.** Vary the rhythm: pack some zones with decorative detail, and
  leave others calmer/open. Contrast (busy ↔ calm, decorated ↔ plain, tight ↔ wide) is what makes
  a map read as designed and vibrant rather than either empty or exhaustingly cluttered.
- The failure modes to avoid are the extremes: **huge flat single-texture emptiness** with one prop
  in the middle, AND **wall-to-wall clutter** with no breathing room.

### 1.1 Core principles
1. **Floor-first density.** Make open, walkable floor *interesting* with decorative tiles,
   medallions, decals, patterns, inlays — not with obstacles. (Ref #7: a huge open plaza made
   dense purely by floor medallions + cloud decals + tile patterns; only a wall + a roof block.)
2. **Mostly non-blocking.** Keep interiors open to move and fight. Blocking props belong at
   **edges** or as deliberate **landmarks** (walls, building/pagoda facades, rock clusters,
   the fountain). Always preserve clear movement lanes and the spawn-clear disc (~10u).
3. **No copy-paste.** Never tile one texture flatly across a large area. Break it up with:
   patches of alternate ground, winding paths, geometric inlays, decals, and scatter — so the
   same nominal floor type reads as varied. (Ref #2 grass has shade patches + mowed stripes.)
4. **Organic shapes, not grids.** Paths **wind** (non-linear); water is **irregular blobs**
   with a bright **shoreline rim**; layouts favour **radial/curved** over axis-aligned grids.
   (Refs #2 river, #3 oasis, #1/#5 radial plazas.)
5. **Decorative floor features** are the main density driver: concentric **ring medallions /
   capture-circles** (emissive), **ritual/rune rings** on grass, **plaza rings** around
   centerpieces, **worn dirt paths radiating** from features, **cloud/swirl decals**,
   **geometric inlays** (grass-in-paving, hex/brick insets), **rugs**. (Refs #1,#4,#5,#7.)
6. **Dense tiny scatter** (non-blocking): flowers, grass tufts, pebbles, crystal shards,
   mushrooms, rubble — sprinkled to kill any "empty field" feel. (Refs #2,#4.)
7. **Clustered placement.** Group rocks+trees+bushes into clumps; do not evenly sprinkle.
   (Refs #2,#3.)
8. **Hero centerpieces.** A BIG fountain or statue on a concentric plaza anchors the map.
   (Refs #1 green fountain, #5 statue plaza.)
9. **Distinct biomes, batched.** Divide the map into a few themed regions; batch each region's
   own coherent props + ground. Do NOT mix all prop/floor types together (crowded/weird).
10. **Colour harmony + lighting per biome.** Each biome has a coherent palette; lighting can
    tint zones (warm desert, cool forest, neon tech).

### 1.2 Floor composition toolkit (how to build the above in Godot)
- **Layered ground planes** with small Y-steps to control draw order & avoid z-fighting
  (base 0, region quads 0.05, patches 0.06, roads 0.10, plaza 0.15, decals on top).
  Region/decorative planes are **visual `MeshInstance3D` with NO colliders**; a single flat
  floor collider (200×200) covers movement.
- **Decorative floor GEOMETRY** (reliable, no new textures): concentric `TorusMesh`/annulus
  **rings**, **capture medallions** = stacked emissive discs + gold torus border + center glow,
  **worn paths** = curved chains of tapered quad segments, **inlay patches** = small rotated
  planes of an alternate ground texture.
- **Decals (future tooling):** Godot `Decal` nodes projecting glowing-on-dark patterns
  (magic circles, runes, hazard markings, glyphs). Generate pattern on black bg → derive alpha
  from luminance (bright = opaque). Best for emissive/sci-fi/fantasy floor marks. (Not yet built.)
- **Organic water:** irregular water mesh(es) + a thin **lighter shoreline rim ring** around the
  edge (the white foam border in ref #3).
- **Raised mounds / curbs:** low platforms (e.g. a rock on a grass mound ringed by a dirt
  circle, ref #2; a curbed grass planter, ref #7) add elevation interest cheaply.

### 1.3 Prop placement rules
- **Obstacles** (get `Obstacle3D` collision + nav): trees, rocks, crates, barrels, dumpsters,
  generators, concrete barriers, pillars, fences, pylons, sci-fi barriers, fountain, walls,
  building facades.
- **Decoration** (NO collision, placed directly): flowers, bushes, tall grass, mushrooms,
  cones, holo-signs, lamps, braziers, crystals, pebbles, floor decals/inlays.
- Cluster blocking props at **edges/landmarks**; keep interiors open. Honour the spawn-clear
  disc. Deterministic seeded placement (no time/random without seed).

### 1.4 Biome catalogue (themes → ground + signature props + palette)
| Biome | Ground textures | Signature props / floor | Palette |
|---|---|---|---|
| **Forest / Park** | grass (+ dirt patches/paths) | trees, bushes, flowers, mushrooms, tall grass, rocks; dirt rings, ritual rings, pond | greens, brown, teal foliage |
| **City / Plaza** | cobble, brick, pavement | crates, barrels, dumpsters, fences, cones, concrete barriers, holo-signs, lamps; medallions, cloud decals, tile inlays | grey + warm brick red + neon signage |
| **Tech / Corrupted** | tech-floor, hex, concrete, corrupted | pylons, sci-fi barriers, generators, holo-signs; hazard markings, corrupted glow patches | cyan/magenta neon + dark metal + purple corruption |
| **Beach / Oasis** | sand | rocks, palms, crates/barrels (debris), pillars (ruins); organic water + white shoreline | warm sand + teal water + coral rock |
| **Frozen** (reserved) | snow | rocks, ice; ice river, blue-tint | white/ice-blue |
| **Arena / Stone** | plaza, brick | statue/fountain centerpiece, pillars, braziers; concentric stone rings, radiating dirt paths, rubble | stone grey + gold + grass |
| **Interior** (stretch) | wood plank | walls/beams (roof cutaway), rugs, furniture | warm wood + lamp glow |

---

## 2. Reference board

Stored in `assets/map-refs/` (copied into the repo so they persist across sessions).

| Ref | File | Key lesson |
|---|---|---|
| LoL Swarm — Final City map | `assets/map-refs/ref-lolswarm-finalcity-map.png` | Radial layout; themed sectors (park/plaza/industrial/waterfront) divided by curved roads; central glowing fountain; layered paving (brick+hex+concrete+grass inlays); packed but readable. |
| Temtem — grass/river | `assets/map-refs/ref-temtem-grass-river.png` | Grass with shade/stripe variation; winding ice river w/ cobble banks; rocks on dirt-ringed mounds; scattered tiny crystals; HUD: top XP bar+level, item/skill slots, timer, kills+gold. |
| Temtem — desert oasis | `assets/map-refs/ref-temtem-desert-oasis.png` | Organic water blobs w/ bright shoreline rim; clustered rocks+palms; rugs as floor accents; winding paths; warm colour harmony. |
| Battlerite — forest clearing | `assets/map-refs/ref-battlerite-forest-clearing.png` | Decorative concentric ground rings on grass; rune-rocks w/ glowing cracks; glowing mushroom clusters; lit-center lighting. |
| Battlerite — statue plaza | `assets/map-refs/ref-battlerite-statue-plaza.png` | Concentric circular stone plaza around a big statue; dirt paths radiating into grass; scattered rubble. |
| Battlerite — interior + HUD | `assets/map-refs/ref-battlerite-interior-hud.png` | Enterable interior (wood floor, roof cutaway); **gold-standard HUD**: bottom command bar w/ portrait+HP, ability row w/ keybinds, ultimate highlight + "Ultimate Ready!" popup, item slots, stats; top-center enemy-count+timer+kills; minimap. |
| LoL Swarm — plaza floor decals | `assets/map-refs/ref-lolswarm-plaza-floordecals.png` | **Open walkable floor made dense purely by decorative decals** (dragon medallion, cloud decals, tile patterns); only wall + roof block. |

---

## 3. Asset inventory (current)

### 3.1 Ground textures — `art/textures/final_city_*_albedo.png` (12)
Seamless tiling (SDXL circular-padding, `artkit/generation/gen_texture.py`), except `corrupted`
(patch-use only). `grass, plaza, dirt, pavement, floor` (tech, cyan-glow), `sand, snow,
corrupted` (alien purple-veined), `cobble` (stylised), `brick` (terracotta), `hex` (vibrant
tech panels — accent only), `concrete` (weathered industrial).

### 3.2 Props — `obstacles/*.tscn` (~20, visual-only primitive scenes)
Kit: `prop_crate, prop_barrel, prop_lamp` (+OmniLight), `prop_fence, prop_flowers`.
Expansion: `prop_rock, prop_tree, prop_bush, prop_tall_grass, prop_mushroom, prop_cone,
prop_dumpster, prop_holo_sign, prop_generator, prop_concrete_barrier, prop_pillar,
prop_brazier` (+OmniLight), `prop_fountain` (+OmniLight, centerpiece).
Sci-fi: `sci_fi_pylon, sci_fi_barrier`.
**Still needed for v2:** crystal shard, pebble/rubble scatter, building facade, billboard,
statue; decorative floor-decal meshes (rings/medallions/paths).

### 3.4 Map system (IMPLEMENTED — the replicable engine)
Data-driven, so a new map = a new recipe file (no engine edits):
- **`arena/map_builder.gd`** (`MapBuilder` node) — reads a recipe `GDScript` exposing
  `const RECIPE` and builds, as flat `MeshInstance3D`s under a `GeneratedGround` node:
  **blob biomes** (`_blob_mesh`: overlapping circle fans → organic non-grid outlines),
  **winding paths** (`_ribbon_mesh`: polyline ribbon of constant width), **water + bright
  shoreline rim** (a larger rim blob under the water blob), and **decorative features**
  (`disc` + `ring`/annulus, optionally emissive). World-space UVs keep tiling consistent;
  small ascending `y` per layer avoids z-fighting; duplicate node names rely on
  `add_child(node, true)` for unique readable names (`Biome`, `Biome2`, …).
- **`arena/maps/final_city_map.gd`** — the Final City `RECIPE` (data only): biome blobs,
  paths, water, plaza medallion + capture rings. Copy this file to author a new map.
- **`arena/arena_scatter.gd`** — props/flora on top: `_OBSTACLE_CLUSTERS` (collision) +
  `_DECOR_CLUMPS` (no collision), tight clusters with calm gaps for rhythm; aligned plaza
  hub (bigger fountain, pillar/lamp rings). `compute_positions` is unit-tested — keep it
  byte-identical. The arena scene wires a `GroundBuilder` (MapBuilder) + `ObstacleSpawner`.
- **`tools/screenshot.{gd,tscn}`** — renders the arena to `_shots/*.png` (gitignored) for
  visual critique loops: `godot47.exe res://tools/screenshot.tscn`.

### 3.3 Generation pipeline
External artkit at `C:\Users\avino\swarm\artkit` (WSL venv `/root/sdgen/.venv/bin/python`,
RTX 4080). Textures: `gen_texture.py` (tiling). Meshes: primitives in-engine now; Hunyuan
(`gen_prop.py`/`gen_character.py`) later. Run via `MSYS_NO_PATHCONV=1 wsl bash -lc '...'`
single-line (see `docs/notes/asset-pipeline.md`).

---

## 4. HUD spec

### 4.1 Layout — "command bar" (chosen)
- **Top status strip** (full width): timer, kills (+ skull icon), level badge, and a **full-width
  XP bar**. Add **enemy-count** (ref #6) and optionally a **minimap** (top-right, also serves the
  "explore the map" goal).
- **Bottom command bar** (2026-07-01 REVISED — now **no panel background**, transparent; holds
  ONLY skill/passive/ult slots): **ultimate centered**; **weapon (skill) slots grow rightward**
  from the ult (skill #1 adjacent to it); **passive slots grow leftward** from the ult (passive #1
  adjacent, so the passives box is END-aligned and its children are inserted in reverse).
  Weapon slots keep fill/radial sweep + READY glow + icon + keybind; the ult keeps its radial +
  gold ready-glow + SPACE. **HP is no longer in the command bar** — see below.
- **Player HP** (2026-07-01 NEW): a **world-space `HealthBar3D`** floating above the player's head
  (`player_3d.gd`: offset `HP_BAR_OFFSET_Y`, `bar_scale` bigger than the mini-boss bar, black
  border for contrast), driven by `player_hp_changed`. The shared `HealthBar3D` widget gained a
  `bar_scale` multiplier (applied to the billboard basis) and a black border frame.
- **Boss bar** top-center during boss fights (magenta/danger fill + name + cur/max).
- **Evolve banner** popup (existing fade tween).
- **Level-up upgrade cards** (2026-07-01 NEW — `upgrades/upgrade_ui.*` + `upgrade_card.gd`):
  premium LoL-Swarm-style picker over a dark scrim (no full dim). Each card = a custom-drawn
  `UpgradeCard` (chamfered rounded rect, ONE fat smooth neon border + soft glow, corner "+" ticks,
  header divider). Top→bottom: level badge (`NEW` / `Lv cur / max`) · rarity-tinted icon plate ·
  name · description · stat · synergy hint. Accent hue per kind: **teal** weapon/skill, **purple**
  passive/stat, **gold** evolution/synergy (featured = scaled up + stronger glow). A PASSIVE card
  that advances an owned skill toward its synergy shows a "▲▲ [skill icon]" tab at the bottom
  (`SkillSystem.synergy_pending`/`skill_for`). *Deferred:* deal-in/shine/count-up/particle motion;
  true multi-stat `60›80` rows (needs per-stat before/after data on `Upgrade`, which today carries
  only a single `stat_text`).

### 4.2 Data bindings (preserve all — `ui/hud.gd`)
Signals: `player_hp_changed, player_leveled_up, evolution_unlocked, boss_spawned,
boss_hp_changed, boss_died`. Duck-typed: `_game_manager.get_elapsed()/get_kills()`;
`_player.xp/level/xp_to_next()/weapons/ultimate/passives`. Helpers `collect_cooldowns`,
`collect_passives`. Reuse `RadialCooldown` for the ultimate ring. `process_mode = ALWAYS`.

### 4.3 v2 additions (from ref #6) — SHIPPED
Done (commit on `feature/arena-floor-first`): centered **portrait** + capped HP cluster
(no more full-width HP slab); weapon-slot **keybind badges** (1..N) + SPACE on ult;
**"ULTIMATE READY"** popup on the ult's rising edge (`HUD._flash_ult_ready`); live
**enemy-count** (group `enemies`) in the top strip; circular **radar minimap**
(`ui/minimap.gd`, player-centered, plots the `enemies` group). Node skeleton kept so all
HUD tests still pass. *Still open:* per-skill **ability icons** (Phase 6.2) to replace the
slot text abbreviations; a real character **portrait** texture (placeholder letter now);
ornate frame chrome; wiring the minimap `world_radius` to actual arena bounds.

### 4.5 Ability icons + portraits — SHIPPED (full roster)
Per-skill **ability icons** and per-character **command-bar portraits** for all 10 characters,
generated with SDXL (DreamShaper-XL). Each icon is a single centered glowing emblem tinted to
the character's theme colour (Avinoam gold, Barak amber, Ido toxic-violet, Matan lime, Natali
rose-pink, Yinon fiery-orange, Yoav sky-blue, Yuval cyan, Ziv magenta), themed off the ability's
own description. The HUD + upgrade cards **auto-resolve by convention** — icon
`art/icons/abilities/<skill_id>.png`, portrait `art/icons/portraits/<char_id>.png` — so new art
needs no `.tres` edits (`SkillData.icon` / `CharacterData.portrait` still win if set; text
abbreviation is the fallback). Where an ultimate shares a skill id (Natali `comic_relief`, Yuval
`bass_drop`) one icon serves both. **The generation pipeline now lives in-repo** at
`tools/icons/` (`gen_icon.py` + per-character prompt manifests) — no external `/swarm`
dependency; only the WSL venv + model weights stay outside git. Commit only the final PNGs
(`.import` is regenerated on import).

### 4.4 Styling
Dark neon theme `ui/theme/swarm_hud_theme.tres`. Palette (`core/visual_palette.gd`): HP
`danger`; XP/weapons `player_primary` cyan; ultimate-ready `player_secondary` gold; boss
`enemy_secondary` magenta; panels dark + thin neon border. Icons must be **crisp** (drawn
`_draw` vector / glyphs for chrome; generated art for ability slots). Anchors must work at
native 3440×1440 (top-full / bottom-full presets, not 1080p pixel positions).

---

## 5. Roadmap / open items
- [x] **Arena v2** — floor-first rebuild SHIPPED via the data-driven MapBuilder (§3.4):
  organic blob biomes, winding paths, glowing plaza medallion + capture rings, water +
  shoreline rim, grass tonal variation, dense clustered scatter. *Remaining polish:* glowing
  `Decal`s, more flora color, AI-painted hero textures, prettier grass at distance.
- [x] **HUD v2** — SHIPPED (§4.3): portrait, keybinds, ultimate popup, enemy count, radar
  minimap. *Remaining:* ability icons (Phase 6.2), real portrait art, frame chrome.
- [ ] **Decal pipeline** — generate glowing floor-decal textures + alpha-key + `Decal` placement.
- [ ] **New decoration props** — crystal shard, pebble/rubble, building facade, billboard, statue.
- [ ] **More maps / biomes** — each map = pick biomes from §1.4, compose per §1.1–1.3.
- [ ] **Interiors** (stretch) — enterable building with roof cutaway (ref #6).
- [x] **Ability icons + portraits** — SHIPPED for the full 10-character roster (§4.5).
      *Remaining:* counter/status icons.
- [ ] **Lobby / character-select screen v2** — `ui/lobby_3d.tscn` (Task D1, Co-op Foundation)
      is functional-only right now: default `Button`/`Label`/`CheckButton` controls, no
      theme/art pass. Needs a visual pass (matches HUD's "command bar" language, uses the
      existing character portraits/colors from §4.5) once co-op networking stabilizes.

## 6. Change log
- 2026-07-01 — Created. Captured map design language (floor-first density, non-blocking,
  organic shapes, decorative floors, biome catalogue), 7-image reference board, asset
  inventory, command-bar HUD spec + v2 plan. Derived from LoL Swarm / Temtem Swarm /
  Battlerite references discussed in session.
- 2026-07-01 — Added vibrancy nuance: blocking spaces are acceptable; not every area must be
  dense; vary rhythm (busy ↔ calm); overarching goal = vibrant & interesting, avoid both flat
  emptiness and wall-to-wall clutter. Added the spec-maintenance rule to project `CLAUDE.md`.
- 2026-07-01 — Built the replicable map system (§3.4): `MapBuilder` engine + `final_city_map`
  recipe + clustered scatter + screenshot harness. Replaced the 4-square grid arena with an
  organic floor-first composition. Arena structure tests updated; suite 1067/1067 green.
  Committed on branch `feature/arena-floor-first`. Approach chosen with user: best visual
  quality + modifiable/replicable per map.
- 2026-07-01 — HUD v2 shipped (§4.3): centered portrait + capped HP, keybind badges,
  ULTIMATE-READY popup, live enemy count, radar minimap (`ui/minimap.gd`). Kept the tested
  node skeleton; suite 1067/1067. Added `tools/hud_preview.*` harness. User picked "HUD v2
  now" after the arena rebuild.
- 2026-07-01 — NEW DIRECTION: user still dislikes the visuals; kicked off a full art-directed
  overhaul. Decisions: **3D modular tile-kit floor** (base/edge/corner/transition/trim/variation
  + decals), **fresh rebuild** (retire MapBuilder's blob floor + current HUD), **visual-only HUD**
  (bind existing data, no new systems), **vertical-slice-first** (central hub + Garden district +
  HUD → ≥85/100, then replicate). See `2026-07-01-art-directed-arena-overhaul-design.md` and the
  new screenshot self-iteration process at `docs/notes/visual-qa-loop.md`. This supersedes the
  blob-map approach in §1.2/§3.4.
- 2026-07-01 — Garden vertical slice SHIPPED to QA ≥85 (scored 87/100). Data-driven modular
  floor (`arena/floor/`: `ZoneGrid`→`Autotile`→`TileVariants`→`FloorBuilder`) + clustered
  props (`GardenScatter`) driven by `arena/maps/garden_map.gd` (24×24 ASCII recipe). Five
  **stylized (not photoreal) SDXL floor textures** — grass / stone_plaza / stone_path /
  dirt_path / flowerbed — generated via `artkit/generation/gen_garden_batch.py` (DreamShaper
  XL + circular-padding seamless tiling), imported with mipmaps and sampled with anisotropic
  filtering for the angled MOBA cam. Central flagstone combat plaza with a faint cyan
  "garden-seal" `plaza_medallion` decal as the focal point; cross of cobble paths to
  pond / flowerbeds / hero-tree landmark. Procedural RGBA decals (`art/decals/`:
  contact_shadow, plaza_medallion, path_wear, leaves, moss, crack) — props grounded with
  contact shadows. Fresh visual-only HUD (`ui/hud.*`). Suite 1103/1103. Remaining polish
  (non-blocking): plaza prop density, dirt/stone path contrast, grass tiling repetition.
- 2026-07-01 — Mirrored the external artkit **asset-creation workflow docs** into this repo
  at `docs/notes/artkit/` (Hunyuan3D 3D-character track only: `CHARACTER-GUIDE.md`,
  `WORKFLOW.md`, cyber-anime PROMPTS + STYLE-GUIDE, pipeline design + plan). Docs-only —
  toolkit code/env/models stay external. See `docs/notes/asset-pipeline.md` +
  `docs/notes/artkit/README.md` (this-repo deltas). No visual/gameplay change.
- 2026-07-01 — QA PROCESS correction. The earlier 87/100 and a later "the scorer is
  unreliable" dismissal were both builder error, not scorer error — verified by finally
  opening the actual scored PNGs, where the greybox overview + washed near-white centerpiece
  + straight seams trip the auto-fails exactly as scored. Hardened `docs/notes/visual-qa-loop.md`:
  the screenshot+score is authoritative and the builder's impression never overrides it
  ("scorer is unreliable" is now a banned conclusion); must view the exact scored PNG next to
  refs before judging; grade the frame not the asset; monotonic score movement is signal; the
  overview shot is a real gate. Next visual work: revert near-white zone albedo, fix centerpiece
  integration + straight seams.
- 2026-07-01 — Skill-cast VFX cleanup: removed the expanding `AoeTelegraph3D` ring that
  `SkillVFX` spawned around the character on EVERY `skill_cast` (a big growing circle each
  cooldown tick — unwanted noise, and it couldn't distinguish real AoE skills). Cast now shows
  only the small `SkillCastFx3D` burst; genuine AoE skills still draw their own telegraph sized
  to their real blast radius (e.g. `NovaWeapon3D`). `AoeTelegraph3D` remains a reusable,
  unit-tested component. See `docs/notes/skill-vfx.md`.
- 2026-07-01 — Upgrade-card width fix (§4.1): the SYNERGY card rendered wider than the others
  and its image stretched. Root cause — `NameLabel`/`StatLabel` in `upgrade_ui.tscn` had no
  `autowrap_mode`, so long synergy text ("SYNERGY: Notification Apocalypse", "Doubles pings,
  speeds orbit") forced the card's minimum width past the shared 268 px, and the fill-to-plate
  icon stretched with it. Enabled `autowrap_mode = 3` on both labels for all three cards; cards
  are now equal width and the image no longer over-stretches.
- 2026-07-01 — Ran the auto-fix loop (each pass re-rendered + judged vs refs): (1) stone zones
  tinted mid-grey so the floor stops reading washed; (2) dense overhanging grass creep + darker
  curb break the straight zone seams; (3) flat cyan ring replaced by a layered flush inlaid
  medallion (teal/gold bands + glow ring + emblem); (4) surround ground plane + light distance
  fog kill the floating-slab overview. Arena tests 17/17. **Also fixed the screenshot harness:
  the `gameplay` shot was ~2× too far out; corrected `tools/screenshot.gd` to mirror
  `GameCamera3D` exactly (pitch -65°, distance 15.4, fov 75, pivot origin → pos ≈ (0,13.96,6.51))
  so QA judges the true player view.** See `docs/notes/visual-qa-loop.md` rule 9.
- 2026-07-01 — ZONE BLENDING re-architected. The per-cell-quad floor + alpha-faded "feather"
  seam overlays never meshed (an alpha-faded texture is a translucent ghost, not a blend);
  user rejected it across grass-blocks, grass↔pavement, flowerbed↔grass, and the pond shore.
  New approach: **splatmap** — one flat ground surface (y=0) + a shader blending all 5 zone
  textures per-pixel from a control map generated off `ZoneGrid`. Two first-class features:
  **per-zone `blend` width (0 = razor-sharp "clear road")** and **faux-height plaza** via an
  edge-shadow (AO) band on the low side of a `tier` drop + optional albedo-luminance depth
  blend — geometry stays flat so the character is never swallowed. Elevation curbs removed.
  Full design in `2026-07-01-splatmap-ground-blending-design.md`.
- 2026-07-01 — ABILITY ICONS + PORTRAITS shipped for the full 10-character roster (§4.5),
  continuing the earlier "Avihay slice." 43 SDXL ability icons (single centered glowing emblem,
  character theme-colour, themed off each ability's description) + 9 character portraits, all
  auto-resolved by the `art/icons/abilities/<skill_id>.png` / `portraits/<char_id>.png`
  convention (no `.tres` edits). **Moved the generation pipeline in-repo** to `tools/icons/`
  (`gen_icon.py` + per-character prompt manifests) at the user's request — the game no longer
  depends on the external `/swarm` project; only the WSL venv + model weights stay outside git.
  Fixed a VRAM-exhaustion slowdown (SDXL cached activations filled the 16 GB GPU across a long
  batch → driver spilled to system RAM, ~400× slower): added per-image cache-clear + a
  `--skip-existing` resume flag, and switched to **one process per character** so each fully
  releases VRAM on exit. Committed on `feature/ability-icons-roster`.
- 2026-07-01 — Enemy navigation now ROUTES AROUND terrain instead of walking into it. Two
  changes: (1) the arena navmesh is BAKED with every obstacle footprint carved out (was a flat
  quad that only activated RVO) — `GardenScatter._activate_navigation` / `build_carved_navmesh`
  in `arena/floor/prop_scatter.gd` collects each `Obstacle3D` footprint and cuts a hole via a
  projected obstruction, baked with 1.0-unit agent clearance (cell_size 0.5); (2) enemies steer
  toward their `NavigationAgent3D` next path corner with throttled repathing (`REPATH_INTERVAL`
  0.3s) so a 50–200 swarm stays cheap, with a straight-line fallback so they never freeze when
  no path exists (`Enemy3D._path_toward` / `nav_desired_velocity`). RVO still layers on top for
  enemy-vs-enemy jostling. **Map-authoring note:** any new map's collidable props must be wrapped
  in `Obstacle3D` and have their footprints fed to the navmesh bake, or enemies will path straight
  through them. Suite 1129/1129.
- 2026-07-01 — CO-OP transformation kicked off. Decided to transform the game's systems toward
  Riot's *Swarm / Operation: Anima Squad* bullet-heaven while keeping our friends roster/art
  (IP-safe). Decomposed into 9 slices; designing **Slice #1 (Co-op Foundation)** first: 1–4
  player Steam P2P co-op, host-authoritative world / client-owned avatar, team XP & gold,
  synced level-up, downed/revival. **UI additions from this slice:** a networked **lobby /
  character-select** screen (reuses the existing `character_select` UI + a per-player ready
  flag) and **portrait ready-bubbles** during the synced level-up pause. Full HUD overhaul for
  Swarm (Augments/Passives/Weapons panels, scoreboard, boss bar) remains Slice #9. Design:
  `2026-07-01-coop-foundation-design.md`.
- 2026-07-01 — Task D1 (Co-op Foundation M2) shipped the networked lobby screen described
  above: `ui/lobby_3d.tscn`/`.gd` (Host/Join/fighter-grid-from-`CHARACTER_PATHS`/player
  list/Ready/Start/Solo) behind a new persistent `game/session_root.tscn` (`run/main_scene`),
  which swaps the lobby child for the arena via an authority/call_local RPC instead of
  `change_scene_to_file` (keeps the tree/RPCs alive across the transition). **This is plumbing
  only — no visual/theme pass yet**, tracked in §5 roadmap. Suite 1164/1164.
