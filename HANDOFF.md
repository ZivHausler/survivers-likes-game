# Friends Swarm — Session Handoff

> Last updated: 2026-06-29. Read this first to resume work.

## 🚧 3D PIVOT IN PROGRESS (plan: docs/superpowers/plans/2026-06-29-3d-pivot-and-feature-expansion.md)
The 2D→3D conversion + 8-item feature expansion is **underway** (subagent-driven, review-gated; ledger in `.superpowers/sdd/progress.md`). Decisions locked: tilted perspective `Camera3D` @ -55° on the XZ plane; players = Kenney Blocky Characters (CC0); enemies = user's MDA Downloads monster pack (FBX→glTF via FBX2glTF; ⚠️ license unconfirmed). Plan phases: 1 core 3D · A assets · 2 model integration · 3 four-skills + invuln + orb-colors · 4 per-skill synergy · 4.5 skill VFX · 5 all 10 friends · 6 integration.
**Done so far:** Track A assets (merged) · Task 1.1 world/camera/ground/`main_3d.tscn` (230/230). Main scene now boots into 3D. 2D scenes/tests left intact during transition.
**Next:** Task 1.2 Player→CharacterBody3D.

## What this is
A **Godot 4.7 (GDScript) 2D horde-survivor game** ("Vampire Survivors"–style): move-only control, auto-firing signature ability, enemies swarm, XP gems → level-up → pick 1-of-3 upgrades, with a synergy/evolution system (signature maxed + dedicated passive owned → golden EVOLVE). Each playable character is based on one of the owner's real friends.

- **Repo:** `~/friends-swarm` — **branch `feature/v1-vertical-slice`** (everything lives here; `main` is the empty initial commit, nothing merged yet).
- **Engine:** Godot 4.7 stable, installed at `/Applications/Godot.app`, symlinked as `godot` on PATH.
- **Run it:** `godot --path ~/friends-swarm` (opens a window). Headless boot check: `godot --headless --quit`.
- **Tests:** `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit` → currently **220/220 green**. GUT addon vendored under `addons/gut/`.

## Architecture (important)
- **Data-driven characters:** a friend = a `CharacterData` resource (`core/character_data.gd`) → weapon scene + base `StatBlock` + signature/passive/evolution `Upgrade` resources. Adding a character = mostly authoring data (see `docs/notes/how-to-add-a-character.md`).
- **Decoupled event bus:** systems talk through the `GameEvents` autoload (signals), never directly. `RunState` autoload carries the selected character + last-run score across scenes.
- **Pure logic is unit-tested; scenes/visuals are manual-playtest.** Pure `RefCounted` classes (`UpgradeSystem`, `DifficultyTimeline`, the XP curve in `player.gd`) have real GUT tests. Scene/physics/visual behavior is verified by the human running the game.
- **Visuals are a separate, decoupled layer** (`Juice` autoload + per-scene sprite swaps) that listens to `GameEvents` and dresses up the logic — so the logic tests stay green regardless of art.
- **Knowledge base (Zettelkasten):** `docs/notes/` — one atomic note per component, `INDEX.md` is the map, plus ADRs + runbooks. Every `.gd` file's first line is `# See docs/notes/<id>.md`. **Keep notes current as you change code.**
- **Specs & plans:** `docs/superpowers/specs/` and `docs/superpowers/plans/`. **Progress ledger:** `.superpowers/sdd/progress.md` (gitignored) tracks every task + commit range + review verdict.

## What's built so far
1. **v1 vertical slice:** core run loop, Player (move/HP/XP/level), 3 enemy variants + steering + contact damage, Spawner + difficulty timeline, XP gems + magnet, **Ziv** (charm beam) & **Avihay** (chat-spam bubbles) abilities with evolutions, full upgrade + synergy/evolution system, GameManager run flow, UpgradeUI, HUD, Game Over, character select, arena + main scenes.
2. **Visual overhaul (CC0 art, decoupled):** Kenney CC0 sprites (Tiny Dungeon characters, Monster Builder enemies, Tiny Town tiles) + MIT VFX lib; player + enemy sprites with procedural wobble, tiled camera-following background + vignette, screen shake / hit-flash / death pops / damage numbers / skill VFX / evolution + level-up fanfare, styled HP/XP bars + EVOLVE banner. Asset licenses tracked in `docs/notes/asset-licenses.md` (all CC0/MIT).
3. **Iteration 2 (gameplay + cards):**
   - XP scales with enemy strength; **mini-boss drops 50 XP**.
   - **Skill cap = 5** (guarded by tests).
   - **Steeper XP curve:** `xp_to_next(lvl) = 5 + lvl*3 + lvl*lvl*2`.
   - **Difficulty ramp:** enemy `hp_mult = 1 + t/120`, `enemy_scale = 1 + (t/600)*0.5`, **mini-boss every 180s**, **BIG BOSS at 10:00** (HP ×40×ramp, scale ×5, 200 XP, purple).
   - **Skill cards UI:** level-up picker is now 3 cards (name · placeholder icon · description · stat gain · "NEW"/"Lv X/max"; EVOLUTION golden). `Upgrade` gained `description`/`stat_text`/`icon`; all 11 upgrade `.tres` authored.
   - **Softlock fix:** maxing every upgrade no longer shows an empty picker / freezes — `UpgradeSystem.has_available_choices()` + a small +HP bonus on maxed level-ups.
   - **XP-collection fix (was critical):** the Player `CharacterBody2D` had **no body `CollisionShape2D`** (only a Hurtbox Area2D), so the gem's `body_entered` never fired — orbs magneted on but never collected. Added the body shape (layer 1, mask 0). Also tuned: player sprite 3×, enemies scaled to match, vignette softened, base `pickup_range` 48→80.

## OPEN DECISIONS / what's next
1. **🔴 3D PIVOT — UNRESOLVED (highest priority to decide).** The user said **"I want our game to be 3D."** This is a **major rebuild**: every scene/physics/render node (Player, Enemy, weapons, Spawner, XPGem, Juice/VFX, camera) becomes 3D (`CharacterBody3D`, `Area3D`, 3D physics, 3D models, `Camera3D`). **What carries over unchanged:** all pure logic (`UpgradeSystem`, `DifficultyTimeline`, XP curve, `GameEvents`, `RunState`, `CharacterData`/`Upgrade` data) and the UI overlay (HUD, cards). A brainstorming session was **started but interrupted** — resume by scoping: camera (top-down vs over-shoulder), player model source, and how much to rebuild first. The user has a **3D monster pack** at `~/Downloads/MDA_Hatchery_CP1` (`battle_monsters.zip` = 187 animated **FBX** models: dragonewt, mini-wyvern, undead serpent, plant monster, bug, fish, sloth, horns, needles, diatryma; **no license file bundled — confirm rights**). These are 3D models — directly usable in a 3D game, NOT in the current 2D game.
2. **8 remaining friend-characters** — user asked to add them. Only **Ziv** (#1) and **Avihay** (#4) are built. Still to do (designs sketched in `docs/superpowers/specs/2026-06-28-friends-swarm-design.md`): **Avinoam** (divine smite), **Matan** (irritation aura / enrage enemies), **Ido** (toxic trail DoT), **Yuval** (soundwave stun), **Natali** (laughter heal/support), **Barak** (dog summon + vanish), **Yinon** (rocket artillery), **Yoav** (Wolt-scooter strafe). Follow `docs/notes/how-to-add-a-character.md`. **Hold until the 2D-vs-3D decision is made** (abilities would be rebuilt in 3D).
3. **Visuals still crude** (repeated user complaint). CC0 Kenney "Tiny"/Monster-Builder are minimalist blobs. Options discussed: a richer cohesive 2D pack (**Ninja Adventure**, CC0, animated chars+monsters+tilesets+icons — git-cloneable from the creator's GitHub) OR the 3D pivot. Skill-card **icons are placeholder colored badges** pending this decision.

## Known minor gaps (non-blocking)
- T2 has no test asserting the shared enemy `.tres` is unmutated after spawn HP/scale scaling (the code *is* safe — it `duplicate()`s before mutating — but the invariant isn't test-guarded).
- Benign runtime warning: `player.tscn` references `player.gd` by a stale UID (Godot falls back to the text path; harmless — scrub by re-saving in the editor).
- `Upgrade.icon` field exists but `upgrade_ui.gd` always uses the placeholder badge (icons not wired until art arrives).

## How work is run here (process)
Subagent-driven, review-gated: each task = a fresh implementer subagent → a reviewer subagent (spec + quality) → fix loop → next, keeping the suite green. The orchestrator (main session) stays light and tracks `.superpowers/sdd/progress.md`. **The user runs the actual game for visual/feel verification** (headless can't see pixels — this is how the two collision bugs and the "ugly" feedback surfaced). When resuming: read this file, then `.superpowers/sdd/progress.md`, then `git log --oneline`, then `docs/notes/INDEX.md`.
