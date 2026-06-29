# Friends Swarm — Session Handoff

> Last updated: 2026-06-29. Read this first to resume work.

## What this is
A **Godot 4.7 (GDScript) 3D horde-survivor** ("Vampire Survivors"–style) with a **tilted top-down view**: move-only control, auto-firing skills, monsters swarm, XP orbs → level-up → pick 1-of-3 upgrade cards, with a per-skill synergy/evolution system. Each playable character is one of the owner's real friends. **The 2D→3D pivot + the full 8-item feature expansion are COMPLETE.**

- **Repo:** `~/friends-swarm` — branch **`feature/v1-vertical-slice`**.
- **Run it:** `godot --path ~/friends-swarm` → boots to **character select (3D)** → pick 1 of 10 friends → 3D run. Headless boot: `godot --headless --quit`.
- **Tests:** `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit` → **916/916 green**. (⚠️ GUT 9.7.0 **silently skips** any test file using `assert_le`/`assert_ge` — always use `assert_true(x <= y)`; watch that the test count rises as expected.)

## Playtest round 1 — fixes applied (after first user run)
- **Camera was invisible (CRITICAL):** `GameCamera3D.target` never resolved from the `.tscn` `NodePath` → camera stuck at origin. Now set in code (`GameManager3D.start()` assigns `cam.target = player`); regression-tested.
- **Everything rendered white:** model GLBs ship untextured (albedo white, no texture bound). Fix: players now apply their Kenney skin atlas (`CharacterData.model_texture` = `texture-a…j`, applied in `Player3D`); monsters' embedded textures were corrupt (`image/unknown` MIME) so enemies are now **tinted by `EnemyData.color`** (swarmer green / spitter blue / tank dark-red / serpent boss).
- **Skills not visible:** orbiters/nova-telegraph/beam/bubbles + cast/hit VFX are now emissive-colored by `vfx_color`.
- **Enemies slid lifelessly:** added a procedural bob/lean while moving (guaranteed); a skeletal-walk retarget from the separate anim GLBs is attempted but **unconfirmed** (see below).
- **Ground:** arena ground is now brown earth + warm backdrop (was a white plane on blue-gray).
- Runtime-ordering bugs fixed: Avihay bubble + Nova telegraph were setting `global_position` before `add_child` (`!is_inside_tree()` errors, spawned at origin).
- ⚠️ **Process note:** a parallel merge of the three visual fixes silently dropped two branches + introduced a parse error (suite hit 97 failures); recovered by reset + clean re-merge by commit hash. Lesson: after multi-branch merges, run the full suite before declaring green; merge branches one at a time.

## The 8 delivered items
1. **3D conversion** — gameplay on the XZ plane; fixed perspective `Camera3D` at −55° tilt (height 14 / pullback 10), follows the player; `core/game_camera_3d.gd` (+ shake via `add_trauma`).
2. **Real models** — players = Kenney Blocky Characters (CC0), enemies = the user's MDA Downloads monster pack converted FBX→glTF. ⚠️ enemy anims are **static rest-pose** (mesh GLBs carry no embedded AnimationPlayer; clip retarget is a TODO). Model scale/orientation are **playtest-tunable** (`model_scale`/`model_y_offset` on each CharacterData/EnemyData).
3. **4 skills per character** — `Player3D.weapons` (multi-weapon); `SkillSystem` (`core/skill_system.gd`): a skill's **level 0 = unowned**, acquire at 0→1 via a card, level 1→5. Each character: 1 signature (owned at start) + 3 acquirable.
4. **All 10 friends** — Ziv, Avihay, Avinoam, Matan, Ido, Yuval, Natali, Barak, Yinon, Yoav. Each = `characters/<name>_3d.tres` with a 4-element `skills` array; selectable in `ui/character_select_3d` (data-driven over `CHARACTER_PATHS`).
5. **Per-skill synergy** — each skill has a matching passive + a synergy; the synergy enters the card pool (golden) once that skill is maxed (lvl 5) AND its passive ≥ 1. Folded into `SkillSystem`.
6. **2s post-levelup invulnerability** — `Player3D.set_invulnerable()`/`is_invulnerable()` (i-frame guard in `take_damage`, model blink); granted by `GameManager3D` when the level-up queue resolves and play resumes.
7. **Exp-orb colors** — `XPGem3D.tier_color(value)` (5 tiers blue→magenta); normal-enemy XP grows over the run (`Spawner3D.xp_time_mult`).
8. **Skill VFX** — decoupled `SkillVFX` autoload reacting to additive `GameEvents.skill_cast`/`skill_hit` (emitted uniformly by `Weapon3D._fire_internal` + archetypes/signatures); colored GPUParticles3D bursts. General juice (shake/hit-flash/damage-numbers/death-pops) via `Juice3D`.

## Realistic arena map (feature: realistic-arena-map)
`arena/arena_3d.tscn` is now a proper environment instead of a bare plane:
- **PBR grass ground + HDRI sky** — `StandardMaterial3D` (albedo/normal/roughness, Poly Haven *aerial_grass_rock*, CC0) on the 200×200 plane; `WorldEnvironment` Sky background from an HDRI panorama (Poly Haven *kloofendal_43d_clear_puresky*, CC0).
- **Border walls** — 4 `StaticBody3D` walls on the Obstacles layer (16) enclosing the arena so the player can't leave.
- **Water** — `Water3D` ponds: decorative translucent surface that also blocks movement (layer 16 + `NavigationObstacle3D`).
- **Collidable tree/rock props via seeded scatter** — an `ObstacleSpawner` (`arena/arena_scatter.gd`) runs at `_ready`, calls the deterministic static `ArenaScatter.compute_positions(...)`, and spawns real CC0 nature gltf models (`art/models/nature/fir_tree_01`, `boulder_01`) as `Obstacle3D` props under an `Obstacles` node. Props use `Obstacle3D.set_model()` (adds the multi-mesh gltf as a child visual + sizes a `CylinderShape3D`/nav footprint) and sit on layer 16; the container is attached via `add_child.call_deferred` (parent is busy during scene entry). Asset-load failure falls back to a `BoxMesh` (`configure()`) with a warning — never crashes.
- **Tunable scatter params** (exported on `ObstacleSpawner`): `obstacle_count=35`, `rng_seed=1`, `extent=88.0`, `clear_radius=14.0`, `min_separation=7.0`, per-prop `tree_/rock_footprint_radius`+`_height`, `model_scale=1.0`.
- **Enemy RVO avoidance** — `Enemy3D` carries a `NavigationAgent3D`/avoidance so the swarm flows around walls, water, and props instead of bunching. Skills never mask layer 16, so projectiles pass over props unchanged.
- Docs: `docs/notes/arena-map.md` (full detail), `docs/notes/asset-licenses.md` (CC0 sources). **Visuals (prop scale/placement, sky sun angle) are playtest-tunable** via the exported params above.

## Architecture (3D)
- **Data-driven characters:** a friend = `CharacterData` (`core/character_data.gd`) → world-scale `StatBlock` + model + `skills: Array[SkillData]`. A `SkillData` (`core/skill_data.gd`) = weapon scene + 3 upgrades (SKILL/PASSIVE/SYNERGY) + is_signature.
- **Skills:** `Weapon3D` base (`core/weapon_3d.gd`, Timer-driven auto-fire). Bespoke signatures: Ziv beam+charm, Avihay bubbles. Two reusable archetypes: `OrbitWeapon3D` (orbiting hitboxes) and `NovaWeapon3D` (XZ AoE pulse, optional charm/heal/DoT via subclass overrides — e.g. Ido DoT, Natali heal). The 8 new friends' skills are themed archetype subclasses.
- **Run flow:** `GameManager3D` builds a `SkillSystem` from the chosen `CharacterData`, acquires the signature, spawns enemies (`Spawner3D`), routes kill→XP gem, drives the level-up card flow (queue + softlock guard) via the reused `UpgradeUI` (system-agnostic, SYNERGY golden), HUD, and game-over.
- **Decoupled visuals:** `Juice3D` (game juice) + `SkillVFX` (skill cast/hit) autoloads react to `GameEvents` — logic/tests stay green regardless of visuals. World scale: **1 unit ≈ 16 px**.
- **Physics layers:** player body layer 1, player hurtbox layer 2, bubble layer 3 (mask), enemies layer 4 (collision_layer=8), XP gem mask=1 (player only).
- **Knowledge base:** `docs/notes/` (one note per component, `INDEX.md` is the map). Every `.gd`'s first line is `# See docs/notes/<id>.md`. Plan: `docs/superpowers/plans/2026-06-29-3d-pivot-and-feature-expansion.md`. Progress ledger: `.superpowers/sdd/progress.md` (gitignored).

## How work was run (process)
Subagent-driven, review-gated: each task = implementer subagent → reviewer subagent (spec + quality) → fix loop, suite kept green, atomic commits. Phase 5 (8 characters) + several features fanned out across parallel git-worktree agents, merged sequentially. **The user runs the actual game for visual/feel verification** (headless can't see pixels).

## ⚠️ Open / deferred (next session)
1. **2D code still present** — the old 2D scenes/scripts/tests were kept intact as a fallback during the pivot (Option B). A **cleanup task to delete 2D** (`game/main.tscn`, 2D player/enemy/weapons/spawner/gem, `game/game_manager.gd`, `ui/character_select.tscn`, 2D-only tests, `autoload/Juice` 2D) is **deferred until the user confirms the 3D build in a playtest**. `project.godot` main scene is already `character_select_3d`.
2. **Enemy skeletal animation UNCONFIRMED** — mesh GLBs lack embedded AnimationPlayers. A procedural bob/lean now keeps enemies visually alive while moving (works). A skeletal retarget (loading the separate `*_run/_walk.glb` clips onto each mesh's skeleton) is attempted in `Enemy3D` but **not verified to actually move bones** (needs the Godot editor / a real playtest to confirm track paths match). If bones don't move, finish the retarget in-editor. Players DO animate (idle/walk).
3. **Playtest tuning** — enemy `model_scale`/`model_y_offset` (converted FBX may import large/offset; bosses compound body-scale × model-scale), camera-shake magnitude, skill balance (e.g. Ido DoT cd 1.0 at high damage_mult), orb-color readability, VFX visibility/perf with many enemies.
4. **Accumulated Minor review notes** (non-blocking) are listed per-task in `.superpowers/sdd/progress.md` — triage before any release.
5. **Asset license** — the MDA monster pack is a 2016 commercial Unity asset with **no bundled license**: fine for a personal prototype, rights UNCONFIRMED before distribution (`docs/notes/asset-licenses.md`). Player models (Kenney) + VFX lib are CC0/MIT.

When resuming: read this file, then `.superpowers/sdd/progress.md`, `git log --oneline`, `docs/notes/INDEX.md`.
