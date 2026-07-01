# LoL Swarm Visual Remake Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remake every asset class of friends-swarm (characters, enemies/bosses, environment, VFX, UI, pickups) into the neon cyber-anime **League of Legends: Swarm** visual identity, by adding an in-engine stylized render/VFX layer and regenerating geometry through the local artkit AI→3D pipeline.

**Architecture:** Three decoupled layers (per the [Visual Overhaul spec](../specs/2026-06-28-friends-swarm-visual-overhaul-design.md)). **Layer 1** (in-engine: shaders + bloom + palette + VFX) lands first and transforms the look on *current* geometry. **Layer 2** (artkit-generated cyber-anime characters, environment, enemies) swaps in via existing `CharacterData.model_scene`/`EnemyData.model_scene` points. **Layer 3** (UI/2D icons). A pilot character proves the whole chain before fan-out. Game logic is never touched; the GUT logic suite stays green; the render/VFX layer is removable.

**Tech Stack:** Godot 4.7 (GDScript), `.gdshader` spatial shaders, `WorldEnvironment` glow/post, GUT test addon, `addons/godot_vfx` (dormant shader library to mine). Asset production in the **separate** `C:\Users\avino\swarm\artkit\` repo: SDXL (`gen.py`, `gen_texture.py`), Hunyuan3D-2.1 (`gen_character.py`), Mixamo (manual web), Blender 5.1 (`finalize_character.py`, tools), all run via WSL.

## Global Constraints

- **Engine:** Godot 4.7 stable. Headless boot must stay green: `godot --headless --quit` loads `main_3d.tscn` with zero errors.
- **Logic suite green after every task:** `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit` (currently 220+/220+). No gameplay/logic file is edited by this plan.
- **Decoupling is mandatory:** visuals attach only via (a) `GameEvents`-driven render/VFX nodes, (b) `*Data.model_scene`/material swaps, (c) project-wide render settings. Disabling the render/VFX autoload(s) must revert to working plain logic with no errors.
- **Two repos:** every task states its repo. **GAME** = `C:\Users\avino\survivers-likes-game`. **ARTKIT** = `C:\Users\avino\swarm` (artkit toolkit + `swarm-art/` outputs).
- **Every `.gd` file's first line stays `# See docs/notes/<id>.md`;** keep Zettelkasten notes + `docs/notes/INDEX.md` current; update `HANDOFF.md` after each phase.
- **Atomic commits per task.** Commit only the files the task names.
- **Palette is law:** all colors derive from the role palette resource (Task 1.1); no new hardcoded gameplay colors. Palette role → value table is in Task 1.1, copied verbatim from north-star §8.
- **North star:** `docs/superpowers/specs/2026-06-30-lol-swarm-visual-identity-design.md` — the authoritative look/palette/per-layer rules. When a task says "per north-star §N", that section governs.
- **Asset-gen tasks are not unit-testable** (GPU + manual Mixamo + human eyes). Their verification = a 4-angle Blender render + headless import + a GUT *structural* assertion (file/animations present) + flagged for the human playtest. Visual quality is the user's call.
- **License tracking:** record every generated/sourced asset in `docs/notes/asset-licenses.md`.
- **Animation-clip naming contract (load-bearing):** the consumer code finds the glb's `AnimationPlayer` and plays clips **by exact name**. Characters (`player/player_3d.gd`) play **`idle`** and **`walk`** only; enemies (`enemies/enemy_3d.gd`) play **`idle`** and **`move`**. A missing clip silently no-ops (no crash, but no animation). So every generated character glb MUST export clips named exactly `idle` and `walk`; enemy glbs `idle` and `move`. Set these names in `finalize_character.py` via `--base-name`/`--extra name=...`. Extra clips (e.g. `run`) are harmless but unused.

---

## File Structure

**GAME repo (new):**
- `core/visual_palette.gd` — autoload; role→`Color` lookup (single source of truth).
- `shaders/cel_rim.gdshader` — spatial cel + rim-light + emissive-mask shader for characters/enemies.
- `shaders/dissolve_death.gdshader` — spatial dissolve for enemy deaths.
- `shaders/telegraph_ring.gdshader` — additive ground AoE telegraph decal.
- `vfx/stylize.gd` — autoload; applies cel_rim material override to tagged meshes on spawn (signal-driven, removable).
- `vfx/aoe_telegraph_3d.gd` / `.tscn` — telegraph decal effect for nova/orbit/ground skills.
- `ui/theme/swarm_hud_theme.tres` — dark sci-fi `Theme` + `StyleBox`es.
- `docs/notes/visual-palette.md`, `stylize-layer.md`, `aoe-telegraph.md`, `swarm-hud-theme.md` — Zettels.

**GAME repo (modified):**
- `arena/arena_3d.tscn` — `WorldEnvironment` glow/post; lighting; ground material (Phase 1 + Phase 4).
- `enemies/enemy_3d.gd` — dissolve-death hook + cel_rim override (Phase 1/5).
- `pickups/xp_gem_3d.gd` — tier colors read from palette (Phase 1).
- `vfx/skill_vfx.gd`, `autoload/juice_3d.gd` — VFX colors from palette; telegraph dispatch (Phase 1).
- `ui/hud.tscn`, `ui/upgrade_ui.tscn`, `ui/health_bar_3d.gd` — apply theme (Phase 6).
- `characters/*_3d.tres`, `enemies/*.tres` — `model_scene`/tint swaps (Phases 2–5).

**ARTKIT repo (new/modified):**
- `artkit/STYLE-GUIDE-CYBERANIME.md`, `artkit/PROMPTS-CYBERANIME.md` — new prompt pack (Phase 0).
- `swarm-art/characters/<friend>/…`, `swarm-art/props/…`, `swarm-art/textures/…`, `swarm-art/enemies/…` — generated assets.

---

## Phase 0 — artkit cyber-anime prompt pack (ARTKIT repo)

Retarget the pipeline from cute-chibi to neon cyber-anime so every later gen produces the right style. (Decision VO-4.)

### Task 0.1: Cyber-anime STYLE BLOCK + roster prompt slots

**Files:**
- Create: `C:\Users\avino\swarm\artkit\PROMPTS-CYBERANIME.md`
- Create: `C:\Users\avino\swarm\artkit\STYLE-GUIDE-CYBERANIME.md`
- Modify: `C:\Users\avino\swarm\artkit\WORKFLOW.md` (link the new pack; mark cute pack deprecated)

**Interfaces:**
- Produces: a reusable `STYLE BLOCK` + `NEGATIVE` string pair, and a `{SUBJECT}` slot table (10 friends, 6 enemies, ~8 props) — consumed by every Phase 2–6 concept-image step.

- [ ] **Step 1: Author `PROMPTS-CYBERANIME.md`** with, verbatim, the north-star §17 reusable prompt as the STYLE BLOCK and the §17 negative prompt as NEGATIVE, plus a "Character T-pose constraints" reminder copied from `CHARACTER-GUIDE.md` Stage 0 (strict T-pose, empty hands, full body, plain grey bg). Add a `{SUBJECT}` table — one line per friend/enemy/prop (see Task 3.1 table for the 10 friends; enemies = "purple-blue insectoid carapace alien", etc.).
- [ ] **Step 2: Author `STYLE-GUIDE-CYBERANIME.md`** mirroring the existing `STYLE-GUIDE.md` structure but for the neon look: recommend an SD checkpoint suited to sci-fi/anime (not ToonYou), keep the LoRA-lock workflow, and note the trigger phrase `cyber-anime swarm style`.
- [ ] **Step 3: Deprecate the cute pack** — add a banner at the top of `PROMPTS.md` and `STYLE-GUIDE.md`: "> DEPRECATED for friends-swarm — use `*-CYBERANIME.md`. Kept for reference." Add a one-line pointer in `WORKFLOW.md`'s file map.
- [ ] **Step 4: Verify** — generate one throwaway concept to confirm the pack runs end-to-end:
```bash
wsl bash -lc '/root/sdgen/.venv/bin/python /root/sdgen/gen.py \
  --creature "cyber-anime hero, gold and white armor, angelic tech wings, T-pose, empty hands, full body, plain grey background" \
  --out "/mnt/c/Users/avino/swarm/swarm-art/raw/_styletest.png" --seed 12345'
```
Expected: a PNG at `swarm-art/raw/_styletest.png` reading as neon cyber-anime (not pastel chibi). Human eyeballs it.
- [ ] **Step 5: Commit** (ARTKIT repo)
```bash
git -C C:/Users/avino/swarm add artkit/PROMPTS-CYBERANIME.md artkit/STYLE-GUIDE-CYBERANIME.md artkit/PROMPTS.md artkit/STYLE-GUIDE.md artkit/WORKFLOW.md
git -C C:/Users/avino/swarm commit -m "docs(artkit): add cyber-anime prompt pack; deprecate cute pack"
```

---

## Phase 1 — In-engine stylized render & VFX layer (GAME repo)

The highest-ROI work. Everything here is additive + reversible and runs on *current* assets.

### Task 1.1: Palette autoload (single source of truth)

**Files:**
- Create: `core/visual_palette.gd`
- Create: `docs/notes/visual-palette.md`
- Modify: `project.godot` (register `VisualPalette` autoload)
- Test: `test/test_visual_palette.gd`

**Interfaces:**
- Produces: `VisualPalette.role(name: StringName) -> Color` and named consts. Roles (verbatim values from north-star §8, mapped to the existing in-code colors found in the survey):
  - `player_primary` cyan `Color(0.3,0.8,1.0)`, `player_secondary` gold `Color(1.0,0.8,0.2)`
  - `enemy_primary` purple `Color(0.6,0.3,1.0)`, `enemy_secondary` magenta `Color(1.0,0.2,0.6)`
  - `danger` `Color(1.0,0.35,0.1)`
  - `pickup_low` blue `Color(0.3,0.6,1.0)`, `pickup_mid` green `Color(0.3,1.0,0.4)`, `pickup_high` yellow `Color(1.0,0.9,0.2)`, `pickup_higher` orange `Color(1.0,0.55,0.1)`, `pickup_top` magenta `Color(1.0,0.2,0.6)`
  - `env_neutral` gray `Color(0.45,0.47,0.5)`

- [ ] **Step 1: Write the failing test** — `test/test_visual_palette.gd`:
```gdscript
extends GutTest
func test_role_returns_known_color():
    assert_eq(VisualPalette.role(&"player_primary"), Color(0.3,0.8,1.0))
func test_unknown_role_returns_magenta_sentinel():
    assert_eq(VisualPalette.role(&"nope"), Color.MAGENTA)
```
- [ ] **Step 2: Run it, verify it fails** — `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_visual_palette.gd -gexit` → FAIL (VisualPalette unknown).
- [ ] **Step 3: Implement `core/visual_palette.gd`** (first line `# See docs/notes/visual-palette.md`): a `Node` with `const ROLES := { &"player_primary": Color(0.3,0.8,1.0), ... }` for every role above and `func role(name): return ROLES.get(name, Color.MAGENTA)`.
- [ ] **Step 4: Register autoload** in `project.godot` under `[autoload]`: `VisualPalette="*res://core/visual_palette.gd"`.
- [ ] **Step 5: Run test, verify pass.** Then `godot --headless --import` and `--headless --quit` clean.
- [ ] **Step 6: Write the Zettel** `docs/notes/visual-palette.md` (role table + "palette is law" rule); add to `INDEX.md`.
- [ ] **Step 7: Commit** `git add core/visual_palette.gd test/test_visual_palette.gd project.godot docs/notes/visual-palette.md docs/notes/INDEX.md && git commit -m "feat(visual): role palette autoload"`

### Task 1.2: Cel + rim + emissive spatial shader

**Files:**
- Create: `shaders/cel_rim.gdshader`
- Create: `docs/notes/stylize-layer.md`
- Test: `test/test_shaders_compile.gd`

**Interfaces:**
- Produces: a `shader_type spatial` shader with uniforms `albedo_tint:Color`, `rim_color:Color`, `rim_power:float=2.0`, `emissive_mask:sampler2D` (optional), `emissive_color:Color`, `emissive_energy:float`. Consumed by Task 1.3 and all model swaps.

- [ ] **Step 1: Write the failing test** — `test/test_shaders_compile.gd`:
```gdscript
extends GutTest
func test_cel_rim_loads():
    var s := load("res://shaders/cel_rim.gdshader")
    assert_not_null(s)
    var m := ShaderMaterial.new(); m.shader = s
    assert_eq(m.shader, s)
```
- [ ] **Step 2: Run it, verify it fails** (file missing).
- [ ] **Step 3: Implement `shaders/cel_rim.gdshader`** — spatial shader: 2–3 band cel ramp on `NdotL`, Fresnel rim using `rim_color`/`rim_power` added to `EMISSION`, `ALBEDO = albedo_tint.rgb * texture(...)` (sample `albedo` if a texture is bound, else flat), optional emissive mask → `EMISSION`. Keep it cheap (no loops). (Mine `addons/godot_vfx/` `outline_glow`/`enemy` shaders for reference if useful, but author a self-contained spatial shader.)
- [ ] **Step 4: Run test, verify pass.**
- [ ] **Step 5: Zettel** `docs/notes/stylize-layer.md` (shader uniforms + intent); INDEX.
- [ ] **Step 6: Commit.**

### Task 1.3: Stylize autoload — apply cel_rim to characters/enemies

**Files:**
- Create: `vfx/stylize.gd`
- Modify: `project.godot` (autoload `Stylize`)
- Modify: `docs/notes/stylize-layer.md`
- Test: `test/test_stylize_layer.gd`

**Interfaces:**
- Consumes: `shaders/cel_rim.gdshader`, `VisualPalette`.
- Produces: `Stylize.apply_to(node: Node3D, tint: Color, rim: Color) -> void` (walks `MeshInstance3D` children, sets a `ShaderMaterial` using cel_rim as `material_override`, preserving each surface's albedo texture into the shader). Player/enemy `_ready` call it; **guarded** so absence of the autoload is a no-op (decoupling).

- [ ] **Step 1: Write the failing test** — instance a `MeshInstance3D` with a `BoxMesh` under a `Node3D`, call `Stylize.apply_to(root, Color.RED, Color.WHITE)`, assert the mesh's `material_override is ShaderMaterial` and its shader path == `res://shaders/cel_rim.gdshader`.
- [ ] **Step 2: Run it, verify it fails.**
- [ ] **Step 3: Implement `vfx/stylize.gd`** (autoload Node; first line note header). `apply_to` recurses, copies any existing `albedo_texture` from a `StandardMaterial3D`/GLB surface into the shader's `albedo` param, sets `albedo_tint`/`rim_color`.
- [ ] **Step 4: Register autoload; run test, verify pass.**
- [ ] **Step 5: Wire callers (guarded).** In `player/player_3d.gd` and `enemies/enemy_3d.gd`, after the model loads, add: `if Engine.has_singleton("Stylize") or get_node_or_null("/root/Stylize"): Stylize.apply_to($Model, tint, VisualPalette.role(&"enemy_secondary"))`. For player use `model_tint`; for enemy use `data.color`. **Run the full GUT logic suite — must stay green.**
- [ ] **Step 6: Disable-check.** Comment out the `Stylize` autoload line, `--headless --quit` → no errors (proves removable). Re-enable.
- [ ] **Step 7: Commit.**

### Task 1.4: WorldEnvironment glow/bloom + lighting pass

**Files:**
- Modify: `arena/arena_3d.tscn` (the `WorldEnvironment` + `DirectionalLight3D`)
- Test: `test/test_arena_environment.gd`

**Interfaces:**
- Produces: an `Environment` resource on the arena with `glow_enabled=true`, bloom tuned so emissive (energy>1) blooms; raised ambient; soft shadows. Consumed visually by all later phases.

- [ ] **Step 1: Write the failing structural test** — load `arena/arena_3d.tscn`, find the `WorldEnvironment`, assert `environment.glow_enabled == true` and `environment.ambient_light_energy >= 0.3`.
- [ ] **Step 2: Run it, verify it fails.**
- [ ] **Step 3: Edit `arena_3d.tscn`'s Environment:** `glow_enabled=true`, `glow_intensity≈0.8`, `glow_bloom≈0.2`, `glow_hdr_threshold≈1.0`, `tonemap_mode=2` (Filmic), `ambient_light_source` from sky, `ambient_light_energy≈0.4`; set `DirectionalLight3D` `shadow_enabled=true`, soft, energy ≈1.0 (bright, low-contrast per north-star §7).
- [ ] **Step 4: Run test, verify pass;** `--headless --quit` clean.
- [ ] **Step 5: Commit.** Flag for human playtest (bloom is eyeball-tuned).

### Task 1.5: Dissolve-death shader + enemy death hook

**Files:**
- Create: `shaders/dissolve_death.gdshader`
- Modify: `enemies/enemy_3d.gd` (death visual), `autoload/juice_3d.gd` (or wherever `enemy_killed_3d` is handled)
- Test: `test/test_dissolve_death.gd`

**Interfaces:**
- Consumes: `enemy_killed_3d` signal (already emitted).
- Produces: on death, the enemy's mesh swaps `material_override` to a dissolve `ShaderMaterial` (uniform `progress:float 0→1`, `edge_color` = `VisualPalette.role(&"enemy_secondary")`) tweened over ~0.4s before free. **Logic unchanged** — only the visual delay/effect.

- [ ] **Step 1: Write the failing test** — assert `shaders/dissolve_death.gdshader` loads and a `ShaderMaterial` accepts `progress` + `edge_color` params.
- [ ] **Step 2: Run it, verify it fails.**
- [ ] **Step 3: Implement `shaders/dissolve_death.gdshader`** — spatial, `noise`-driven `ALPHA` clip by `progress`, emissive `edge_color` band at the dissolve edge. `render_mode` with alpha scissor.
- [ ] **Step 4: Wire the death visual** in `enemy_3d.gd`: keep the existing kill/scoring logic; on death, hide collision, apply dissolve material, `create_tween()` `progress` 0→1 over 0.4s, then `queue_free()`. Ensure this does not delay damage/score signals (those fire as today).
- [ ] **Step 5: Run test + full GUT suite, verify green;** `--headless --quit` clean.
- [ ] **Step 6: Commit.**

### Task 1.6: AoE telegraph decal

**Files:**
- Create: `shaders/telegraph_ring.gdshader`, `vfx/aoe_telegraph_3d.gd`, `vfx/aoe_telegraph_3d.tscn`
- Create: `docs/notes/aoe-telegraph.md`
- Modify: `vfx/skill_vfx.gd` (dispatch a telegraph on cast for ground/nova skills)
- Test: `test/test_aoe_telegraph.gd`

**Interfaces:**
- Consumes: `skill_cast` signal (vfx_id, pos, color, radius).
- Produces: `AoeTelegraph3D.play_at(pos: Vector3, radius: float, color: Color) -> void` — a flat additive ring decal on the ground that expands/pulses then auto-frees. Boss telegraphs use a stronger variant (brighter, `danger` color).

- [ ] **Step 1: Write the failing test** — instance `vfx/aoe_telegraph_3d.tscn`, call `play_at(Vector3.ZERO, 6.0, Color.CYAN)`, assert it's inside the tree and auto-frees within its lifetime (process a few frames).
- [ ] **Step 2: Run it, verify it fails.**
- [ ] **Step 3: Implement** the shader (radial additive ring, `radius`/`width`/`color` uniforms, soft edge) + scene (a `MeshInstance3D` quad/torus laid flat, `billboard` off, transparent additive) + script honoring the `play_at(pos,radius,color)` contract used by `skill_vfx.gd`.
- [ ] **Step 4: Dispatch from `skill_vfx.gd`** for nova/ground skills on `skill_cast` (color from `VisualPalette` by owner). Keep existing cast/hit FX.
- [ ] **Step 5: Run test + GUT suite green;** `--headless --quit` clean.
- [ ] **Step 6: Zettel + INDEX; Commit.**

### Task 1.7: Palette-drive existing VFX + XP gems

**Files:**
- Modify: `pickups/xp_gem_3d.gd`, `vfx/skill_vfx.gd`, `autoload/juice_3d.gd`
- Test: `test/test_xp_gem_palette.gd`

**Interfaces:**
- Consumes: `VisualPalette`.
- Produces: gem tier colors + skill VFX archetype colors all sourced from `VisualPalette` (no hardcoded RGB). Behavior/tiers unchanged.

- [ ] **Step 1: Write the failing test** — set up an `XPGem3D` with a low value, assert its emissive color == `VisualPalette.role(&"pickup_low")`.
- [ ] **Step 2: Run it, verify it fails** (gem currently hardcodes the color).
- [ ] **Step 3: Replace hardcoded colors** in `xp_gem_3d.gd` tier mapping, `skill_vfx.gd` archetype colors (orbit→`player_secondary`, nova→`player_primary`), and `juice_3d.gd` death-pop/damage-number tints with `VisualPalette.role(...)`. Keep the same buckets/behavior.
- [ ] **Step 4: Run test + GUT suite green.**
- [ ] **Step 5: Commit.**

### Task 1.8: Phase 1 checkpoint — headless + handoff

- [ ] **Step 1:** Run `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit` → all green.
- [ ] **Step 2:** `godot --headless --quit` → zero errors.
- [ ] **Step 3:** Update `HANDOFF.md` (Phase 1 render layer complete; what's reversible; how to disable). Commit.
- [ ] **Step 4: HUMAN PLAYTEST** — confirm the current game now reads neon (rim/emissive + bloom, dissolve deaths, telegraphs, palette role-separation) on existing Kenney/Quaternius models. This is the proof Layer 1 carries the identity.

---

## Phase 2 — Pilot character vertical slice (gate) — Decision VO-2

Prove the **full chain** on one character: regenerated cyber-anime model + weapon prop + recolored Primordian enemies + one sci-fi arena zone, on top of Phase 1. **Pilot = Avinoam** (gold/white radiant — max contrast against purple enemies; already the weapon-reskin deep-spec target). Fully mechanically implemented already, so visuals are the only variable.

### Task 2.1: Generate Avinoam cyber-anime model + weapon prop (ARTKIT repo)

**Files:**
- Create: `swarm-art/characters/avinoam/reference_tpose.png`, `…/avinoam_textured.glb`, `…/avinoam_rigged.glb`
- Create: `swarm-art/props/avinoam_weapon.glb`

**Interfaces:**
- Produces: `avinoam_rigged.glb` (idle/walk/run animations, `mixamorig:` skeleton) + a weapon prop glb. Consumed by Task 2.2.

- [ ] **Step 1: Concept images** — using `PROMPTS-CYBERANIME.md`, generate a strict T-pose, empty-hands Avinoam (gold/white cyber-paladin, angelic tech wings/halo motif) and an isolated weapon prop (radiant scepter/blaster). Save per `CHARACTER-GUIDE.md` Stage 0 paths.
- [ ] **Step 2: Generate + texture** both via `gen_character.py` (char `--target-faces 30000`, prop `--target-faces 20000`) — `CHARACTER-GUIDE.md` Stage 1 commands.
- [ ] **Step 3: Preview** — `blender -b -P artkit/tools/render_glb.py -- <glb> <outdir>`; human approves the look (regen if back is smeary, etc.).
- [ ] **Step 4: Rig on Mixamo** (Stage 2): export FBX, upload, place markers, grab Rifle Idle/Walk/Run (In-Place), download FBXs.
- [ ] **Step 5: Finalize** (Stage 3) `finalize_character.py` → `avinoam_rigged.glb` + reattached PBR. **Name the clips exactly `idle` and `walk`** (consumer contract): `--base "Rifle Idle.fbx" --base-name idle --extra "walk=Walk With Rifle.fbx"` (a `run` extra is fine but unused by the player).
- [ ] **Step 6: Verify** — `render_glb.py` on the rigged glb; confirm animations via JSON. Record license in `docs/notes/asset-licenses.md` (both repos as appropriate).
- [ ] **Step 7: Commit** (ARTKIT) the prompts + final glbs (sidecars git-ignored).

### Task 2.2: Integrate Avinoam model into the game (GAME repo)

**Files:**
- Copy into: `art/characters_3d/avinoam/avinoam_rigged.glb`, `art/props/avinoam_weapon.glb`
- Modify: `characters/avinoam_3d.tres` (`model_scene` → new glb; `model_scale`/`model_tint` tuned)
- Test: `test/test_avinoam_model.gd`

**Interfaces:**
- Consumes: `avinoam_rigged.glb`. Produces: Avinoam plays as the cyber-anime model with idle/walk/run + hand-attached weapon, cel_rim + bloom applied (Phase 1).

- [ ] **Step 1: Write the failing structural test** — load the rigged glb, assert an `AnimationPlayer` exists with `idle`, `walk`, `run` clips.
- [ ] **Step 2: Run it, verify it fails** (file not yet copied).
- [ ] **Step 3: Copy glbs** into `art/`; `godot --headless --import`.
- [ ] **Step 4: Point `characters/avinoam_3d.tres`** `model_scene` at the new glb; set `model_scale` (Kenney native ≈1.8m as the size reference) and tint. Add a `BoneAttachment3D` (bone `mixamorig:RightHand`) child carrying `avinoam_weapon.glb` in the player scene's model path per `CHARACTER-GUIDE.md` Stage 4A (scale ≈0.6, orient muzzle-forward).
- [ ] **Step 5: Run test + GUT suite green;** `--headless --quit` clean.
- [ ] **Step 6: Commit.**

### Task 2.3: Recolor enemies to the Primordian palette (GAME repo, Phase-5A preview on the pilot)

**Files:**
- Modify: `enemies/*.tres` (tint to purple/blue), rely on Task 1.3 cel_rim + Task 1.5 dissolve
- Test: covered by existing enemy tests staying green

- [ ] **Step 1:** Set each `EnemyData` `color` to a Primordian value from `VisualPalette` (swarmer/spitter/etc. → `enemy_primary`/`enemy_secondary` variants). The cel_rim override + dissolve already apply.
- [ ] **Step 2:** Run GUT suite green; `--headless --quit` clean.
- [ ] **Step 3:** Commit.

### Task 2.4: One sci-fi arena zone (GAME repo)

**Files:**
- Create (ARTKIT→GAME): `art/textures/asphalt_albedo.png`, `art/textures/scifi_pavement_albedo.png`
- Modify: `arena/arena_3d.tscn` (ground material → sci-fi textures, neutral/muted per north-star §8)
- Test: `test/test_arena_ground_material.gd`

- [ ] **Step 1: Generate tiling ground textures** (ARTKIT) via `gen_texture.py` — "dark sci-fi asphalt with faint cyan seams", "clean sci-fi pavement panels"; verify seamless 3×3 montage (`WORKFLOW.md` Stage T). Copy into `art/textures/`.
- [ ] **Step 2: Write the failing test** — assert the arena ground `MeshInstance3D` material's albedo texture path is the new asphalt (not grass).
- [ ] **Step 3: Run it, verify it fails.**
- [ ] **Step 4: Swap the ground material** in `arena_3d.tscn` to the sci-fi textures; keep UV scale/collision/borders unchanged.
- [ ] **Step 5: Run test + GUT green;** `--headless --quit` clean. Commit.

### Task 2.5: Pilot gate — playtest go/no-go

- [ ] **Step 1:** Full suite green + headless boot clean + `HANDOFF.md` updated.
- [ ] **Step 2: HUMAN PLAYTEST of the vertical slice** — Avinoam cyber-anime hero (gold, weapon in hand, animating) vs recolored purple Primordians on a sci-fi floor, with bloom/telegraphs/dissolve. **Decision gate:** approve the look + the per-character effort (~30 min gen + integration) before fan-out. Record the verdict + any tuning notes in `HANDOFF.md`.

---

## Phase 3 — Character fan-out (9 remaining friends)

Repeat the **proven** Task 2.1 + 2.2 pattern per friend. Each friend is one task pair (generate in ARTKIT → integrate in GAME) using the per-friend concept below. Run 2–4 in parallel via git-worktree isolation (per the 3D-pivot method); merge sequentially with the suite green.

**Per-friend concept table** (fills `{SUBJECT}` in the cyber-anime STYLE BLOCK; tint = palette accent):

| Friend | Skill identity | Cyber-anime motif | Accent |
|---|---|---|---|
| Avihay | Chat Spam | netrunner / messenger, headset + holo-screens | electric blue |
| Barak | Pack Tactics | beast-handler, wolf-ear visor, tech collar | amber/orange |
| Ido | Corrosion | hazmat cyber-alchemist, toxic vents | toxic green |
| Matan | Annoyance Orbit | gadgeteer, drone-pods, antennae | magenta |
| Natali | Laughter (heal) | medic-idol, cyan cross, soft armor | pink/cyan |
| Yinon | Airstrike | aviator, jet-pack, targeting visor | military orange |
| Yoav | Express Run | courier speedster, aero-fins | cyan/yellow |
| Yuval | Bass Drop | DJ, speaker-rig, bass cannon | purple/cyan |
| Ziv | Stunning Looks | idol, glam armor, charm aura | pink/magenta |

### Task 3.x (one per friend above): Generate + integrate `<friend>`

**Files:** (mirror Tasks 2.1/2.2 with the friend's name)
- ARTKIT: `swarm-art/characters/<friend>/<friend>_rigged.glb` + `swarm-art/props/<friend>_weapon.glb`
- GAME: `art/characters_3d/<friend>/<friend>_rigged.glb`, `art/props/<friend>_weapon.glb`, modify `characters/<friend>_3d.tres`
- GAME test: `test/test_<friend>_model.gd`

**Interfaces:** Produces a rigged cyber-anime `.glb` (idle/walk/run) wired via `model_scene`; consumed by the player scene like the pilot.

- [ ] **Step 1:** Generate concept (T-pose, empty hands) + prop from the table row, via `PROMPTS-CYBERANIME.md`.
- [ ] **Step 2:** `gen_character.py` char (30k) + prop (20k); `render_glb.py` preview; human approve.
- [ ] **Step 3:** Mixamo rig (Rifle Idle/Walk/Run, In-Place) → download FBXs.
- [ ] **Step 4:** `finalize_character.py` → `<friend>_rigged.glb`; **name clips exactly `idle` and `walk`** (`--base-name idle --extra "walk=..."`); verify clips; license note.
- [ ] **Step 5:** Copy into GAME `art/`; `--headless --import`.
- [ ] **Step 6:** Write structural test (idle/walk/run clips present); point `characters/<friend>_3d.tres` `model_scene` at the glb; set tint to the accent; attach the weapon prop to `mixamorig:RightHand`.
- [ ] **Step 7:** Run test + full GUT suite green; `--headless --quit` clean. Commit (atomic per friend).

- [ ] **Phase 3 checkpoint:** all 10 friends render as cyber-anime heroes; suite green; `HANDOFF.md` updated; HUMAN PLAYTEST spot-check.

---

## Phase 4 — Environment: Final City (GAME + ARTKIT)

### Task 4.1: Full Final City ground texture set (ARTKIT→GAME)

**Files:** `art/textures/` (asphalt, sci-fi pavement, neon-accent zone, dark metal, optional park-green) — generated via `gen_texture.py`; verify seamless.
- [ ] Generate each (muted/neutral per north-star §8 so VFX stay loud); 3×3 seam check; copy to `art/textures/`; record licenses; commit.

### Task 4.2: Sci-fi props (ARTKIT→GAME)

**Files:** `art/models/scifi/<prop>.glb` × ~6 (barrier, circular structure, machinery, sign/pylon) via `gen_prop.py`/`gen_character.py` on isolated concepts; Blender cleanup; origin at base.
- [ ] Generate, preview (`render_glb.py`), copy in, `--headless --import`; license notes; commit.

### Task 4.3: Rebuild the arena as a combat board (GAME)

**Files:** Modify `arena/arena_3d.tscn`, `arena/arena_scatter.gd`; Test `test/test_arena_scatter.gd` (existing) stays green.

**Interfaces:** Consumes the new textures/props. Produces readable combat-board zones (wide lanes, plazas, obstacle silhouettes) replacing grass/trees/water with sci-fi equivalents. Navigation/collision/`NavigationObstacle3D` behavior preserved.

- [ ] **Step 1:** Write/extend a structural test asserting the scatter places the new sci-fi prop scenes (not boulder/tree).
- [ ] **Step 2:** Run it, verify it fails.
- [ ] **Step 3:** Point `arena_scatter.gd` prop pool at the sci-fi `.glb`s; set the ground to multi-zone sci-fi materials; keep collision radii/nav obstacles.
- [ ] **Step 4:** Run test + GUT green; `--headless --quit` clean. Commit. Flag for playtest (readability under VFX).

---

## Phase 5 — Enemies, phased (Decision VO-3)

### Task 5.1: Recolor + dissolve all enemies to Primordian palette (GAME)

Already previewed on the pilot (Task 2.3); finalize across the whole roster.
- [ ] **Step 1:** Set every `enemies/*.tres` `color` to a `VisualPalette` Primordian value (small swarm = `enemy_primary`; ranged/elite variants = `enemy_secondary`); confirm cel_rim + dissolve apply uniformly.
- [ ] **Step 2:** GUT green; `--headless --quit` clean; commit.

### Task 5.2: Generate alien meshes for bosses + key archetypes (ARTKIT→GAME)

Bosses + 2–3 highest-visibility enemies get bespoke alien Primordian meshes (static mesh + procedural wobble/shader motion — **no Mixamo**, per the hard edge).

**Files:** ARTKIT `swarm-art/enemies/<name>.glb`; GAME `art/enemies_3d/<name>/<name>.glb`, modify the matching `enemies/*.tres` `model_scene`; Test `test/test_<name>_enemy_model.gd`.

- [ ] **Step 1:** Generate alien concepts (insectoid/angular, purple-blue carapace, pointed limbs) via the cyber-anime pack; `gen_character.py` (no rig needed — static).
- [ ] **Step 2:** Preview; copy in; `--headless --import`.
- [ ] **Step 3:** Write structural test: the new glb loads as a mesh; the `EnemyData` `model_scene` resolves.
- [ ] **Step 4:** Wire `model_scene`; confirm the existing procedural wobble (squash/scale) + cel_rim + dissolve give it life without skeletal animation.
- [ ] **Step 5:** GUT green; `--headless --quit` clean; commit per enemy. Bosses get the stronger telegraph variant (Task 1.6) + larger scale (existing 3×/5× node scaling).

---

## Phase 6 — UI / 2D art (GAME + ARTKIT)

### Task 6.1: Dark sci-fi HUD theme (GAME)

**Files:** Create `ui/theme/swarm_hud_theme.tres`; create `docs/notes/swarm-hud-theme.md`; modify `ui/hud.tscn`, `ui/upgrade_ui.tscn`, `ui/health_bar_3d.gd`; Test `test/test_hud_theme.gd`.

**Interfaces:** Produces a `Theme` (dark panels, bright icons, readable HP/XP `StyleBox` fills) applied to HUD + upgrade cards + the billboard health bars; uses `VisualPalette` for bar fills (HP `danger`/green, XP `player_primary`).

- [ ] **Step 1:** Write the failing test — load `swarm_hud_theme.tres`, assert it's a `Theme` and that `hud.tscn`'s root `theme` is set.
- [ ] **Step 2:** Run it, verify it fails.
- [ ] **Step 3:** Author the theme (dark `StyleBoxFlat` panels, bright icon modulate, colored bar fills from palette); assign to `hud.tscn`/`upgrade_ui.tscn`; update `health_bar_3d.gd` fill/background colors to palette roles.
- [ ] **Step 4:** Run test + GUT green; `--headless --quit` clean.
- [ ] **Step 5:** Zettel + INDEX; commit. Flag for playtest (readability over busy combat).

### Task 6.2: Ability / upgrade-card / passive icons (ARTKIT→GAME)

**Files:** ARTKIT SDXL 2D (`gen.py` + `artkit process`) → GAME `art/icons/<id>.png`; modify upgrade/skill `.tres` icon refs as applicable; Test: structural (icons load).

- [ ] **Step 1:** Generate painterly cyber-anime icons per skill/passive/ultimate using the cyber-anime style (plain bg → `artkit process` cutout).
- [ ] **Step 2:** Copy into `art/icons/`; `--headless --import`; wire icon refs; structural test that referenced icons load.
- [ ] **Step 3:** GUT green; `--headless --quit` clean; license notes; commit.

---

## Phase 7 — Integration, licensing, handoff

### Task 7.1: Full integration sweep

- [ ] **Step 1:** Run full GUT suite (green), `--headless --import`, `--headless --quit` (zero errors).
- [ ] **Step 2:** Verify the **decoupling invariant**: disable `Stylize` + the VFX autoloads → game still boots/plays on plain logic with no errors; re-enable.
- [ ] **Step 3:** Confirm `docs/notes/asset-licenses.md` lists every generated/sourced asset; `INDEX.md` + ADRs + Zettels current for all new `.gd`/shaders.
- [ ] **Step 4:** Rewrite `HANDOFF.md` for the remade visual state. Commit.

### Task 7.2: Final human playtest checklist

- [ ] **Step 1:** Update `docs/notes/how-to-playtest.md` with a north-star-derived visual checklist: readability under swarm density; palette role-separation (purple enemies vs cyan/gold player vs muted ground); boss telegraphs override noise; no VFX hiding the player/ground; dark HUD legible over combat; dissolve deaths read.
- [ ] **Step 2: HUMAN PLAYTEST** against the checklist; log results + any follow-up tuning in `HANDOFF.md`.

---

## Self-Review

**Spec coverage (vs Visual Overhaul spec):**
- §5.1 render layer → Phase 1 (palette 1.1, cel/rim 1.2–1.3, bloom 1.4, dissolve 1.5, telegraph 1.6, VFX/gems 1.7). ✅
- §5.2 assets: characters → Phase 2 + 3; environment → Phase 4; enemies (phased) → Task 2.3 + Phase 5. ✅
- §5.3 UI/2D → Phase 6. ✅
- VO-1 3-layer → phase structure. VO-2 pilot-first → Phase 2 gate. VO-3 enemies phased → 5.1 then 5.2. VO-4 artkit pack → Phase 0. VO-5 fixed camera → unchanged (no task needed; noted). VO-6 decoupling/removable → Tasks 1.3 step 6, 7.1 step 2. ✅
- §8 testing (logic green, headless, licenses, playtest) → Global Constraints + per-task steps + 7.1/7.2. ✅
- §9 success criteria → covered by Phase 2 gate + Phase 7. ✅
- Cross-repo (§7) → every task tagged GAME/ARTKIT; Phase 0/2.1/3.x/4/5.2/6.2 in ARTKIT. ✅

**Placeholder scan:** asset-gen tasks intentionally use verification-by-render/import/structural-test + human playtest rather than code TDD (GPU + manual Mixamo + pixels can't be unit-tested — stated in Global Constraints). Per-friend fan-out (Phase 3) is one fully-specified task pair applied over an explicit data table, not "similar to Task N." No TBD/TODO left.

**Type/name consistency:** `VisualPalette.role(name)` and role names are defined in Task 1.1 and reused verbatim throughout; `Stylize.apply_to(node,tint,rim)` defined in 1.3 and called in 1.3/2.2/3.x; `play_at(pos,radius,color)`/`AoeTelegraph3D` defined in 1.6 and dispatched there; shader paths consistent. ✅
