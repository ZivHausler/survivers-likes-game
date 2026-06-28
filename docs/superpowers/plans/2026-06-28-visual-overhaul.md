# Friends Swarm — Visual Overhaul Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace placeholder shapes with real CC0 sprites, a tiled background, skill/hit VFX, and procedural juice — without touching the tested game logic.

**Architecture:** Visuals attach two ways only: (1) a `Juice` autoload that listens to existing `GameEvents` signals and spawns pooled effect scenes, and (2) per-scene sprite swaps driven by existing nodes via new optional data fields. No gameplay rule changes; the 119 GUT logic tests stay green.

**Tech Stack:** Godot 4.7, GDScript, GUT. Assets: Kenney CC0 packs (direct kenney.nl zips) + `haowg/GODOT-VFX-LIBRARY` (MIT, git).

## Global Constraints

- Engine Godot 4.7; GDScript only. Run `godot --headless --import` before GUT.
- **Do NOT change gameplay logic** (run loop, upgrade/evolution system, spawning, collision masks, damage). The full existing GUT suite (≥119) MUST stay green after every task.
- All new `.gd` files start with `# See docs/notes/<note-id>.md`; every component gets/updates a Zettel note added to `docs/notes/INDEX.md` in the same commit.
- All bundled art lives under `art/`; the MIT VFX library under `addons/godot_vfx/` (keep its LICENSE). Every bundled asset is recorded in `docs/notes/asset-licenses.md` with source URL + license.
- New visual data fields are OPTIONAL `@export`s with safe fallbacks (missing sprite → existing color shape), so existing `.tres` and tests keep working.
- Only assets that are CC0 or MIT may be added. If an asset's license is unclear, do not bundle it.
- `godot --headless --quit` must load `main.tscn` with zero errors after every task.
- Commits: conventional messages ending with `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

## File Structure

```
res://
├── addons/godot_vfx/            # cloned MIT VFX library (vendored)
├── art/
│   ├── characters/  enemies/  tiles/  vfx/   # extracted Kenney CC0 packs
├── autoload/juice.gd            # "Juice" autoload: GameEvents → effects
├── vfx/
│   ├── death_pop.tscn/.gd       # one-shot squash + particle burst
│   ├── damage_number.tscn/.gd   # floating fading label
│   ├── evolution_flash.tscn/.gd # screen-wide flash on evolve
│   └── hit_flash.gd             # helper: flash a CanvasItem white
├── fx/screen_shake.gd           # camera trauma helper (attached to player camera)
├── game/arena.tscn              # + background TileMapLayer + vignette (modify)
├── ui/hud.tscn/.gd              # styled bars + EVOLVE banner (modify)
├── core/character_data.gd       # + sprite_frames (modify)
├── enemies/enemy_data.gd        # + texture (modify)
├── player/player.gd/.tscn       # ColorRect → AnimatedSprite2D (modify)
├── enemies/enemy.gd/.tscn       # ColorRect → Sprite2D + wobble (modify)
├── pickups/xp_gem.gd/.tscn      # ColorRect → gem Sprite2D + pulse (modify)
├── test/test_visual_*.gd        # structural tests
└── docs/notes/{vfx-system,juice,sprite-integration,asset-licenses}.md
```

---

## Agent Wave Strategy

Sequential tasks, fresh subagent each, spec+quality review between, logic suite kept green. Waves group by dependency:
- **Wave A (A1–A2):** acquire assets + add data fields + Juice autoload skeleton.
- **Wave B (B1–B3):** sprites — player, enemies/boss, XP orb + background.
- **Wave C (C1–C2):** juice (shake/flash/pop/numbers) + skill VFX.
- **Wave D (D1–D2):** HUD polish + assembly + structural-test sweep + final review.
Only Wave D edits `arena.tscn`/`hud.tscn` for final assembly beyond what B/C require; keep scene edits within the owning task.

---

## Task A1: Acquire assets + license note

**Files:** Create `addons/godot_vfx/` (clone), `art/**` (extracted), `docs/notes/asset-licenses.md`, `test/test_assets_present.gd`.

**Interfaces:** Produces on-disk assets other tasks reference by path, and `asset-licenses.md` listing each.

- [ ] **Step 1: Clone the MIT VFX library** — `git clone --depth 1 https://github.com/haowg/GODOT-VFX-LIBRARY addons/godot_vfx` then `rm -rf addons/godot_vfx/.git`. Keep `addons/godot_vfx/LICENSE`.
- [ ] **Step 2: Download Kenney CC0 packs.** For each pack, fetch the kenney.nl asset page, extract the direct `https://kenney.nl/media/pages/assets/.../<pack>.zip` URL, `curl -L -o` it, and `unzip` into `art/`:
  - Monster Builder Pack → `art/enemies/` (confirmed URL pattern: `https://kenney.nl/media/pages/assets/monster-builder-pack/663e4ef6de-1677495438/kenney_monster-builder-pack.zip`).
  - A top-down character pack (e.g. "Tiny Dungeon" or "Roguelike Characters") → `art/characters/`.
  - A top-down tileset (grass/terrain) → `art/tiles/`.
  If a page's direct zip URL cannot be extracted/downloaded, STOP and report the exact pack name + page URL for the user to download manually — do not substitute another asset.
- [ ] **Step 3: Verify downloads** — assert each zip extracted to PNG sprite files; `ls art/enemies art/characters art/tiles` shows images. Run `godot --headless --import` and confirm it imports the new textures without errors.
- [ ] **Step 4: Write `docs/notes/asset-licenses.md`** — a table: asset folder, source URL, license (Kenney = CC0; VFX lib = MIT), attribution-required (CC0 = no; MIT = yes → add a CREDITS line for the VFX lib). Add to `INDEX.md`.
- [ ] **Step 5: Structural test** `test/test_assets_present.gd` — asserts `art/enemies`, `art/characters`, `art/tiles` each contain ≥1 `.png`, `addons/godot_vfx/LICENSE` exists, and `res://docs/notes/asset-licenses.md` exists (read via FileAccess). Run headless GUT; expect pass.
- [ ] **Step 6: Commit** `feat: acquire CC0 sprites + MIT VFX library, license note`.

---

## Task A2: Visual data fields + Juice autoload skeleton

**Files:** Modify `core/character_data.gd`, `enemies/enemy_data.gd`; Create `autoload/juice.gd`, `test/test_juice_decoupled.gd`, `docs/notes/juice.md`, `docs/notes/sprite-integration.md`; Modify `project.godot` (autoload).

**Interfaces:**
- Produces `CharacterData.sprite_frames: SpriteFrames` (optional, default null) — consumed by Player (B1).
- Produces `EnemyData.texture: Texture2D` (optional, default null) — consumed by Enemy (B2).
- Produces autoload `Juice` (Node) that connects to `GameEvents` signals in `_ready` and exposes `register_camera(cam: Camera2D)` and `register_player(p: Node2D)`; spawns nothing yet (handlers are stubs). Effect-spawning added in Wave C.

- [ ] **Step 1: Add fields** — in `character_data.gd` add `@export var sprite_frames: SpriteFrames`; in `enemy_data.gd` add `@export var texture: Texture2D`. (Both optional; existing `.tres` unaffected.)
- [ ] **Step 2: Verify backward compat** — `godot --headless --import` clean; run full GUT suite, expect still ≥119 passing (fields are additive).
- [ ] **Step 3: Write `autoload/juice.gd`** — `extends Node`; in `_ready` connect to `GameEvents.enemy_killed/player_hp_changed/player_leveled_up/evolution_unlocked/xp_collected` with empty handler methods; add `register_camera`/`register_player` storing weak refs. First line `# See docs/notes/juice.md`.
- [ ] **Step 4: Register autoload** `Juice=*res://autoload/juice.gd` in `project.godot`.
- [ ] **Step 5: Decoupling test** `test/test_juice_decoupled.gd` — assert `Juice` is an autoload, that emitting each GameEvents signal with the Juice present does not error and does not change any game state (e.g. emit enemy_killed and assert no exception, no nodes spawned into a bare tree). Headless GUT; expect pass.
- [ ] **Step 6: Notes** `juice.md` (the autoload contract), `sprite-integration.md` (the data fields + fallback rule); add to INDEX.
- [ ] **Step 7: Commit** `feat: visual data fields + Juice autoload skeleton`.

---

## Task B1: Player character sprite + animation

**Files:** Modify `player/player.tscn`, `player/player.gd`, `characters/ziv.tres`, `characters/avihay.tres`; Create `test/test_player_visual.gd`; update `docs/notes/player.md`.

**Interfaces:** Consumes `CharacterData.sprite_frames`. Player shows an `AnimatedSprite2D` when `sprite_frames` is set, else keeps the `ColorRect` fallback.

- [ ] **Step 1: Add an `AnimatedSprite2D` child** ("Sprite") to `player.tscn` alongside the existing ColorRect.
- [ ] **Step 2: In `player.gd setup()`** — if `data.sprite_frames`: set `$Sprite.sprite_frames = data.sprite_frames`, hide the ColorRect, play "idle"; else hide `$Sprite`, keep ColorRect tinted. In `_physics_process`, when `$Sprite.visible`: play "walk" if moving else "idle", and set `$Sprite.flip_h` from `velocity.x` sign. Guard: only if `$Sprite.sprite_frames`.
- [ ] **Step 3: Build `SpriteFrames`** from chosen `art/characters/` sprites for Ziv and Avihay; assign to `ziv.tres`/`avihay.tres` `sprite_frames`. Pick two visually distinct characters; note the choice in `asset-licenses.md`.
- [ ] **Step 4: Structural test** `test/test_player_visual.gd` — instance `player.tscn`, assert it has an `AnimatedSprite2D` named "Sprite"; call `setup` with a CharacterData carrying a SpriteFrames and assert the sprite becomes visible and the ColorRect hidden; call with a data lacking sprite_frames and assert ColorRect fallback stays visible. Headless GUT.
- [ ] **Step 5: Full suite green + headless load clean.**
- [ ] **Step 6: Commit** `feat: animated player character sprites (Ziv, Avihay)`.

---

## Task B2: Enemy + boss sprites with procedural wobble

**Files:** Modify `enemies/enemy.tscn`, `enemies/enemy.gd`, `enemies/swarmer.tres`/`tank.tres`/`spitter.tres`, `spawning/spawner.gd` (boss visual only); Create `test/test_enemy_visual.gd`; update `docs/notes/enemy.md`.

**Interfaces:** Consumes `EnemyData.texture`. Enemy shows a `Sprite2D` when `data.texture` set, else the `ColorRect "Body"` fallback.

- [ ] **Step 1: Add a `Sprite2D` child** ("Sprite") to `enemy.tscn` next to the ColorRect "Body".
- [ ] **Step 2: In `enemy.gd setup()`** — if `data.texture`: `$Sprite.texture = data.texture`, modulate with `data.color` (optional tint), hide Body; else keep Body. Add procedural wobble: in `_physics_process`, set `$Sprite.scale` to a small sine squash based on a per-enemy phase (only if `$Sprite.visible`). Do NOT alter movement/damage/death logic.
- [ ] **Step 3: Assign Monster Builder textures** to swarmer/tank/spitter `.tres`. Boss: in `spawner.gd _spawn_boss`, after scaling, set the boss's sprite modulate/scale for a menacing look (visual only; keep the ×8 hp logic intact).
- [ ] **Step 4: Structural test** `test/test_enemy_visual.gd` — instance enemy, `setup` with EnemyData carrying a texture → `$Sprite` visible with that texture, Body hidden; without texture → Body fallback. Assert death-emit + take_damage still behave (reuse existing enemy contract). Headless GUT.
- [ ] **Step 5: Full suite green + headless load clean.**
- [ ] **Step 6: Commit** `feat: enemy + boss sprites with procedural wobble`.

---

## Task B3: XP orb visual + background map + vignette

**Files:** Modify `pickups/xp_gem.tscn`/`xp_gem.gd`, `game/arena.tscn`; Create `art`-based tileset resource, `test/test_arena_visual.gd`; update `docs/notes/xp-gem.md`, add `docs/notes/background.md`.

**Interfaces:** Arena gains a background layer beneath gameplay; XP gem gains a sprite + pulse. No collection-logic change.

- [ ] **Step 1: XP orb** — swap the gem `ColorRect` for a small gem `Sprite2D` (or keep ColorRect as fallback) and add a pulsing `Tween`/shader glow in `_ready`. Do not change `_collect`/magnet logic.
- [ ] **Step 2: Background** — add a `TileMapLayer` (or large textured `Sprite2D`/`Parallax2D`) built from `art/tiles/` as the FIRST child of `arena.tscn` (drawn under Player/Enemy/Pickups; set z-index/ordering). Add a full-screen vignette `ColorRect`+shader on a `CanvasLayer` with `layer` below the HUD.
- [ ] **Step 3: Structural test** `test/test_arena_visual.gd` — load `arena.tscn`, assert a background tile/sprite node exists and is ordered below the Player; assert the gem scene has a sprite node. Headless GUT.
- [ ] **Step 4: Full suite green + headless load clean.**
- [ ] **Step 5: Commit** `feat: XP orb visual + tiled background + vignette`.

---

## Task C1: Core juice — shake, hit-flash, death pop, damage numbers

**Files:** Create `fx/screen_shake.gd`, `vfx/death_pop.tscn`/`.gd`, `vfx/damage_number.tscn`/`.gd`, `vfx/hit_flash.gd`; Modify `autoload/juice.gd`, `player/player.tscn` (attach shake to camera), `enemies/enemy.gd` (call hit_flash on take_damage — VISUAL ONLY); Create `test/test_juice_effects.gd`; Create `docs/notes/vfx-system.md`.

**Interfaces:** `Juice` handlers now spawn effects: `_on_enemy_killed` → death_pop + damage number + small shake; `_on_player_hp_changed` (decrease) → player hit-flash + shake. `ScreenShake.add_trauma(amount)` on the player camera. `hit_flash(node, duration)` flashes a CanvasItem white via modulate tween.

- [ ] **Step 1: `fx/screen_shake.gd`** — trauma model (`trauma` decays each frame; camera offset = max_offset * trauma^2 with varied jitter). Pure-ish math: expose `add_trauma(a)` and a testable `_offset_for(trauma, seed)` returning a Vector2 magnitude. TDD: test that higher trauma → larger max offset and trauma decays to 0.
- [ ] **Step 2: `vfx/hit_flash.gd`** — static `flash(ci: CanvasItem, dur: float)` tweens `modulate` to white then back. TDD: after flash starts, modulate ≠ base; not a logic change.
- [ ] **Step 3: `vfx/damage_number.tscn`/`.gd`** — a `Label` that floats up and fades, frees on done. `setup(amount: int, pos: Vector2)`. TDD: setup sets text to the amount; after lifetime it queues_free.
- [ ] **Step 4: `vfx/death_pop.tscn`/`.gd`** — `CPUParticles2D` one-shot + a quick scale-pop, auto-frees. `play_at(pos)`.
- [ ] **Step 5: Wire into `Juice`** — `_on_enemy_killed(pos, xp)`: spawn death_pop + damage_number at pos and `add_trauma`. `_on_player_hp_changed`: on a decrease, flash the player + small trauma. Add enemy hit-flash: in `enemy.gd take_damage`, call `HitFlash.flash($Sprite or $Body, 0.08)` — VISUAL ONLY, after the existing hp math (must not change death/emit behavior; existing enemy tests must still pass).
- [ ] **Step 6: Tests** `test/test_juice_effects.gd` — damage number shows the amount and frees; shake trauma decays; hit_flash changes modulate; emitting enemy_killed via Juice spawns a death effect into a test tree without error. Confirm `enemy.gd` change didn't break `test_enemy.gd`.
- [ ] **Step 7: Full suite green + headless load clean.**
- [ ] **Step 8: Commit** `feat: core juice — screen shake, hit-flash, death pop, damage numbers`.

---

## Task C2: Skill VFX + level-up/evolution fanfare + XP sparkle

**Files:** Create `vfx/evolution_flash.tscn`/`.gd`; Modify `weapons/ziv_stunning_looks.gd`/`.tscn`, `weapons/avihay_chat_spam.gd`/`bubble.tscn`, `autoload/juice.gd`; Create `test/test_skill_vfx.gd`; update `docs/notes/weapon-ziv.md`, `weapon-avihay.md`, `vfx-system.md`.

**Interfaces:** Skills show VFX-library effects; `Juice._on_player_leveled_up` → level-up flash; `_on_evolution_unlocked` → full-screen `evolution_flash`; `_on_xp_collected` → small sparkle at the player.

- [ ] **Step 1: Ziv VFX** — replace/augment the beam visual with a glow effect from `addons/godot_vfx` (e.g. an energy/laser effect) shown during the fire window; charm field gets a sparkle particle. Evolved: persistent rotating glow. No hit-logic change.
- [ ] **Step 2: Avihay VFX** — bubble gets a particle trail + a pop (death_pop-style) on hit. Evolved: denser. No hit-logic change.
- [ ] **Step 3: `vfx/evolution_flash.tscn`** — a `CanvasLayer` white flash + radial burst that auto-frees; `Juice._on_evolution_unlocked` plays it. Level-up: a quick screen tint/flash. XP collect: a small sparkle at the player position.
- [ ] **Step 4: Tests** `test/test_skill_vfx.gd` — emitting evolution_unlocked via Juice spawns the flash and it frees; level-up handler runs without error; the weapon scenes still pass their existing tests (fire/level_up/evolve unchanged). Reconfirm `test_weapon_visuals.gd` guards still hold.
- [ ] **Step 5: Full suite green + headless load clean.**
- [ ] **Step 6: Commit** `feat: skill VFX + evolution/level-up fanfare + XP sparkle`.

---

## Task D1: HUD polish

**Files:** Modify `ui/hud.tscn`, `ui/hud.gd`; Create `test/test_hud_visual.gd`; update `docs/notes/hud.md`.

**Interfaces:** Styled HP/XP `ProgressBar`s with visible fills; transient "EVOLVE!" banner on `evolution_unlocked`; keep `process_mode = ALWAYS`.

- [ ] **Step 1: StyleBoxes** — give HPBar (red fill) and XPBar (cyan/gold fill) `StyleBoxFlat` fill + background so they read clearly; ensure XPBar is obviously visible even near-empty (distinct background).
- [ ] **Step 2: EVOLVE banner** — a Label that appears and fades on `GameEvents.evolution_unlocked`; larger level display.
- [ ] **Step 3: Test** `test/test_hud_visual.gd` — assert HPBar/XPBar have non-null `StyleBox` fills; assert HUD root `process_mode == PROCESS_MODE_ALWAYS` (regression guard kept); emitting evolution_unlocked shows the banner node. Headless GUT.
- [ ] **Step 4: Full suite green + headless load clean.**
- [ ] **Step 5: Commit** `feat: HUD polish — styled bars + EVOLVE banner`.

---

## Task D2: Assembly, structural sweep, playtest checklist

**Files:** Modify `game/arena.tscn` (register camera/player with Juice), `autoload/juice.gd` (camera registration wiring); update `docs/notes/how-to-playtest.md`, `INDEX.md`; Create `test/test_visual_smoke.gd`.

- [ ] **Step 1: Wire registration** — arena/GameManager (or Player `_ready`) calls `Juice.register_camera($Player/Camera2D)` and `Juice.register_player($Player)` so shake/sparkle target the right nodes (deferred, safe if absent).
- [ ] **Step 2: Visual smoke test** `test/test_visual_smoke.gd` — load `main.tscn` and `arena.tscn` headless and assert no error / required visual nodes present (background, player sprite, HUD bars styled, Juice autoload live).
- [ ] **Step 3: Update `how-to-playtest.md`** with a VISUAL checklist: sprites render (player animates, enemies wobble), background visible, hit-flash + death pop + damage numbers on kills, screen shake, skill VFX, EVOLVE fanfare + banner, readable HP/XP bars.
- [ ] **Step 4: Run the FULL suite** — `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`; expect all pass. Confirm `godot --headless --quit` loads `main.tscn` cleanly.
- [ ] **Step 5: Commit** `feat: wire Juice registration + visual smoke tests + playtest checklist`.

---

## Self-Review

**Spec coverage:** §4 acquisition → A1. §5 sprite integration (data fields + Player/Enemy/XPGem swaps) → A2,B1,B2,B3. §6 background → B3. §7 skill VFX → C2. §8 procedural juice → C1,C2. §9 HUD → D1. §10 VFX/Juice architecture → A2,C1,C2,D2. §11 testing (structural + suite green + headless) → every task + D2. §12 knowledge base → notes in each task. §13 build waves → wave strategy. §14 success criteria → B*/C*/D* deliverables. No gaps.

**Placeholder scan:** No TBD/TODO. Scene tasks specify node names + the data-driven fallback rule; testable logic (shake math, damage number, fields, decoupling) has explicit TDD steps. Exact sprite filenames are resolved at A1 (download) and referenced by the data-driven fields, not hardcoded in the plan.

**Type consistency:** `CharacterData.sprite_frames: SpriteFrames` and `EnemyData.texture: Texture2D` defined in A2, consumed in B1/B2. `Juice.register_camera/register_player` defined A2, used C1/D2. `HitFlash.flash(ci, dur)`, `ScreenShake.add_trauma(a)`, `DamageNumber.setup(amount, pos)`, `DeathPop.play_at(pos)` consistent between C1 definition and its consumers. The "logic untouched / suite green" constraint is repeated as an explicit verify step in every task.
