# Friends Swarm — Visual Overhaul Design Spec

**Date:** 2026-06-28
**Engine:** Godot 4.7 (GDScript)
**Builds on:** the working v1 vertical slice (branch `feature/v1-vertical-slice`, 119 GUT tests green)

## 1. Goal

Replace the placeholder colored shapes with real art and game-feel: sprite-based
characters/enemies, a tiled background map, skill/hit VFX, and procedural "juice"
(screen shake, hit flashes, death pops, damage numbers, level-up/evolution
fanfare) — in one pass — to make the game look and feel like a polished
survivors game (reference: Temtem Swarm, LoL Swarm, Battlerite).

## 2. Guiding Principle

**The game logic is tested and working — visuals are a decoupled presentation
layer, not a rewrite.** We do not change the run loop, the upgrade/evolution
system, spawning, or collision rules. The 119 existing GUT tests MUST stay green.
Visuals attach in two ways only:
1. A **VFX/Juice layer** that listens to existing `GameEvents` signals and spawns
   effects (no logic coupling).
2. **Per-scene sprite swaps** that replace placeholder `ColorRect`/`Polygon2D`
   nodes with `Sprite2D`/`AnimatedSprite2D`, driven by the same existing nodes.

## 3. Scope

**In scope (one pass):**
- Sprite art for the 10 characters (animated), enemy variants, and mini-boss.
- Tiled background map + vignette.
- Skill/weapon VFX for both built characters (Ziv, Avihay) + their evolutions.
- XP-orb visual + collect sparkle.
- Procedural juice: screen shake, hit-flash, death pop, damage numbers,
  level-up flash, evolution fanfare, player-hurt feedback.
- HUD polish (styled HP/XP bars, clear level + EVOLVE banner).
- Asset acquisition + license tracking.

**Out of scope (later):**
- Implementing abilities for friends #3–#10 (this overhaul provides their
  *sprites* as selectable data, but their weapons stay v2 work).
- Audio/music/SFX.
- Custom/original art (we use CC0 + MIT sources).
- Standalone export build.

## 4. Asset Acquisition

**Sources (clean licensing only):**
- **Sprites + tiles:** Kenney CC0 packs (a top-down character pack for the
  friends, **Monster Builder** for enemies/boss, a top-down tileset for the
  ground). CC0 = no attribution required, commercial OK.
- **VFX:** `haowg/GODOT-VFX-LIBRARY` (MIT) — particle effects + shaders for
  action games (cloned from GitHub).
- Optional CC0 particle textures: `RPicster/Godot-particle-and-vfx-textures`.

**Acquisition policy:** try hard to auto-fetch (direct URLs, mirrors, `git clone`).
For any pack that is click-gated and cannot be scripted, STOP and give the user
the exact links + target filenames to download into `art/`, then continue.
**Never** substitute a different-licensed asset to avoid asking.

**Layout + licensing:**
- All art under `art/` (e.g. `art/characters/`, `art/enemies/`, `art/tiles/`,
  `art/vfx/`).
- `docs/notes/asset-licenses.md` records every asset's source URL + license +
  whether attribution is required, with a `CREDITS` section for any MIT/attribution
  assets surfaced in-game or in the repo README.

## 5. Sprite Integration (data-driven, logic untouched)

- **`CharacterData`** gains an optional `@export sprite_frames: SpriteFrames`
  (idle + walk). **Player** swaps its `ColorRect` for an `AnimatedSprite2D`,
  plays walk while moving / idle while still, and flips horizontally by movement
  direction. Falls back to the existing `color` tint if a sprite is absent
  (backward compatible — keeps tests green).
- **`EnemyData`** gains an optional `@export texture: Texture2D` (Monster Builder
  sprites are static). **Enemy** swaps its `ColorRect "Body"` for a `Sprite2D`;
  a small procedural wobble (sine squash/scale) makes static sprites feel alive.
  Mini-boss reuses the tank sprite at boss scale + tint.
- **XPGem** swaps its `ColorRect` for a small gem `Sprite2D` with a pulsing
  shader/tween glow.
- The 10 friends are mapped to best-fitting CC0 character sprites (documented in
  `asset-licenses.md` with the rationale per friend).

## 6. Background Map

- A `TileMapLayer` ground built from a Kenney top-down tileset, large enough for
  the arena, beneath all gameplay nodes (z-index/layer ordering below
  Player/Enemy/Pickups).
- A full-screen **vignette** (shader or textured `ColorRect` on a `CanvasLayer`
  below the HUD) for focus.
- Optional subtle parallax/scroll tied to the camera (kept cheap).

## 7. Skill / Weapon VFX

Map VFX-library effects per ability (and a bigger variant per evolution):
- **Ziv — Stunning Looks:** glowing beam (laser/energy effect) on each fire flash;
  sparkle ring on the charm field. **Absolutely Fabulous:** persistent rotating
  rainbow laser + denser sparkles.
- **Avihay — Chat Spam:** bubble projectile sprite + motion trail; small pop +
  particles on hit. **Reply-All Apocalypse:** denser homing bubbles + bigger pops.
- **Evolution unlock:** a screen-wide flash + burst keyed off
  `GameEvents.evolution_unlocked`.
- VFX are pooled/auto-freeing one-shot scenes; they never alter hit logic.

## 8. Procedural Juice (scripted, no assets)

A `Juice` system (autoload) connected to `GameEvents`, plus small reusable scenes:
- **Screen shake** (camera trauma) on player hit, enemy death bursts, boss spawn.
- **Hit-flash:** enemies/player flash white briefly on `take_damage` (a shader or
  `modulate` tween) — does not change HP logic.
- **Death pop:** on `enemy_killed`, a quick squash-scale + particle burst + fade
  at the death position.
- **Damage numbers:** floating, fading labels at hit positions.
- **Level-up flash** on `player_leveled_up`; **evolution fanfare** on
  `evolution_unlocked`; **XP collect** sparkle on `xp_collected`.

Because these are signal-driven, none of them require touching gameplay code.

## 9. HUD Polish

- Style the HP and XP `ProgressBar`s (visible fill colors via `StyleBox`), so the
  XP bar reads clearly (it currently looks empty/invisible at low values).
- Prominent level display + a transient **"EVOLVE!"** banner on evolution.
- Keep `process_mode` correct (HUD `ALWAYS`, level-up UI `WHEN_PAUSED`).

## 10. VFX / Juice Architecture

- **`Juice` autoload** subscribes to `GameEvents` and spawns pooled effect scenes;
  holds the active `Camera2D`/`Player` refs (found safely, deferred).
- Effect scenes (`death_pop.tscn`, `damage_number.tscn`, `hit_flash` helper,
  `evolution_flash.tscn`) each have one responsibility and auto-free.
- The layer is **removable**: disabling the autoload reverts to pure logic with no
  errors — proving decoupling.

## 11. Testing

- The full existing GUT logic suite MUST stay green (119+).
- Add **structural tests:** the Player/Enemy/XPGem scenes expose a sprite node;
  the VFX/effect scenes load without error; `Juice` connects to `GameEvents`
  without touching logic; `asset-licenses.md` exists and lists each bundled asset.
- `godot --headless --quit` loads `main.tscn` with zero errors.
- Visual feel (does it look good / animations read correctly) = the user's
  **manual playtest**, via an updated `docs/notes/how-to-playtest.md` visual
  checklist.

## 12. Knowledge Base

New/updated Zettel notes: `vfx-system`, `juice`, `sprite-integration`,
`asset-licenses`, plus updates to `player`, `enemy`, `xp-gem`, `weapon-ziv`,
`weapon-avihay`, `hud`, and `data-driven-characters`. Every new `.gd` file headers
its note; `INDEX.md` updated.

## 13. Build Approach

Same agent-wave method that delivered v1:
- **Wave A — Acquisition + foundation:** fetch assets (try hard; list gated ones
  for the user), establish `art/` + `asset-licenses.md`, add the sprite fields to
  `CharacterData`/`EnemyData`, set up the `Juice` autoload skeleton.
- **Wave B — Sprites:** Player/character animation, Enemy/boss sprites + wobble,
  XP-orb visual, background tilemap + vignette.
- **Wave C — VFX + juice:** screen shake, hit-flash, death pop, damage numbers,
  level-up/evolution fanfare, per-skill VFX.
- **Wave D — HUD polish + assembly + structural tests + final review + playtest
  checklist.**
Each task: fresh subagent, spec+quality review, fixes looped, logic suite kept
green; a final whole-branch review; then the user playtests.

## 14. Success Criteria

- Characters, enemies, the mini-boss, and XP orbs render as **sprites**, not
  colored squares; the player animates while moving.
- The arena has a **tiled background** instead of a blank one.
- Hitting/killing enemies produces visible **feedback** (flash, pop, damage
  numbers, shake); skills show **VFX**; evolving triggers a **fanfare**.
- The HP/XP bars are clearly readable.
- All bundled assets are listed in `asset-licenses.md` with correct licenses.
- The full logic suite stays green and `main.tscn` loads cleanly.
- The game is still fully playable (no logic regressions).
