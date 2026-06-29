# Friends Swarm — Session Handoff

> Last updated: 2026-06-29. Read this first to resume work.
> **Status:** Legacy 2D game **fully removed** this session and merged to **`main`** (fast-forward). `feature/v1-vertical-slice` == `main`. No git remote configured (local only).
> ⚠️ **`main` had diverged ahead** of the feature branch with an unmentioned **type-weapon-system foundation** (type tags on `SkillData`/`CharacterData`, `core/skill_pool.gd`, `SkillSystem` weapon-slot cap, GameManager type-gated run pool + ultimate; tests `test_run_assembly`, `test_skill_pool`, `test_type_system_fields`, `test_weapon_slot_cap`). The 2D removal was rebased on top of it.
> ⚠️ **Uncommitted WIP lives in the working tree** (NOT on any branch — the session-start "clean" snapshot was wrong): (a) **camera tuning** (`game_camera_3d.gd`/`main_3d.tscn`: pitch −55→−65°, distance 10→6.5; related to the `feature/orbit-camera` worktree); (b) an **enemy animation/art overhaul** (`enemy_3d.gd` clip-resolution via `_resolve_anim_clips()`/`resolve_clip()`, boss models serpent→**demon/dragon** in `spawner_3d.gd`, enemy art swaps in `archer/dasher/magician.tres` → ghost etc., new `art/enemies_3d/{demon,dragon_evolved,ghost,monkroose,wizard}/`, new `test_enemy_anim_clip_resolve.gd`). This WIP **is green and also fixes** the pre-existing `test_spawner_3d` bug below. **Commit it before it's lost.**

## What this is
A **Godot 4.7 (GDScript) 3D horde-survivor** ("Vampire Survivors"–style) with a **tilted top-down view**: move-only control, auto-firing skills, monsters swarm, XP orbs → level-up → pick 1-of-3 upgrade cards, with a per-skill synergy/evolution system. Each playable character is one of the owner's real friends. **The 2D→3D pivot + the full 8-item feature expansion are COMPLETE.**

- **Repo:** `~/friends-swarm` — branch **`feature/v1-vertical-slice`** (== **`main`** after this session's merge).
- **Run it:** `godot --path ~/friends-swarm` → boots to **character select (3D)** → pick 1 of 10 friends → 3D run. Headless boot: `godot --headless --quit`.
- **Tests:** `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit` → **committed `main` tree: 889 green**; **working tree (incl. the uncommitted enemy/camera WIP): 914 green**. (Was 1049 before the 2D-test removal: −159 2D tests, +type-weapon tests from main.)
  - ⚠️ GUT 9.7.0 **silently skips** any test file using `assert_le`/`assert_ge` — always use `assert_true(x <= y)`; watch that the test count rises as expected.
  - ⚠️ **After switching branches, clear the class cache** before testing: `rm -f .godot/global_script_class_cache.cfg && godot --headless --import` (run import twice). Otherwise you get phantom "Parse Error: … not found in base …" for symbols that actually exist (stale cross-script class cache).
  - ⚠️ **Pre-existing bug on the committed tree:** `test/test_spawner_3d.gd` fails to load — it references `Spawner3D.SERPENT_SCENE_PATH`, but the boss model was renamed to `MINI_BOSS_SCENE_PATH`/`BIG_BOSS_SCENE_PATH` (demon/dragon). Its ~20 tests are silently excluded on `main`. **The uncommitted enemy WIP already fixes this** — committing that WIP restores the file (→ 914 green).

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

## Ranged & Dasher enemy archetypes (feature: ranged-and-dasher-enemies) — COMPLETE & merged

Three new enemy variants are now registered in the spawner and gated by difficulty time:

### New variants
| Variant   | Attack kind | `.tres`                  | Unlocks at |
|-----------|-------------|--------------------------|------------|
| `archer`  | RANGED      | `enemies/archer.tres`    | t ≥ 150 s  |
| `dasher`  | DASHER      | `enemies/dasher.tres`    | t ≥ 180 s  |
| `magician`| RANGED      | `enemies/magician.tres`  | t ≥ 240 s  |

### Attack-strategy system
`Enemy3D` delegates non-melee movement+attacks to an `EnemyAttack` strategy object (`enemies/attacks/`, created from `EnemyData.attack_kind` via `_make_attack()`). **MELEE is the inline default** — `_attack == null`, so Enemy3D's original chase + `CONTACT_RANGE` contact-damage runs byte-unchanged (there is no `MeleeAttack` class). Legacy `is_ranged == true` maps to RANGED.
- **RANGED** — `RangedAttack`: **approach to `attack_range`, then HOLD and keep firing** (per owner directive — NO kiting/retreat). Fires an `EnemyProjectile3D` only with line-of-sight (terrain on layer 16 blocks the ray = cover) and off cooldown, after a `windup_time` telegraph. `attack_range` is per-`.tres` (spitter 12, archer 14, magician 18); the legacy `RANGED_STANDOFF = 6.0` is no longer used for ranged movement.
- **DASHER** — `DashAttack`: approach → windup telegraph → dash to the *locked* target position → cooldown; telegraphs before any damage for fairness.
- **`EnemyProjectile3D`** (`enemies/enemy_projectile_3d.*`, Area3D, mask 18 = player hurtbox layer 2 + terrain layer 16): damages the player on hurtbox hit (i-frames respected), is destroyed by terrain (cover), ignores other enemies (not masking layer 8) and the ground (layer 1); lifetime cap. Spawned via `add_child` **then** position-set — the spawn-at-origin ordering bug (every arrow flying from map center) was caught in final review and fixed + regression-tested.

### Difficulty thresholds (full table)
| t (s) | Variants in pool                                     |
|-------|------------------------------------------------------|
| 0–59  | swarmer                                              |
| 60–119| swarmer, tank                                        |
| 120–149| swarmer, tank, spitter                              |
| 150–179| swarmer, tank, spitter, **archer**                 |
| 180–239| swarmer, tank, spitter, archer, **dasher**         |
| 240+  | swarmer, tank, spitter, archer, dasher, **magician**|

### Files
- `enemies/enemy_data.gd` — `AttackKind` enum (MELEE/RANGED/DASHER) + ranged params (`attack_range`, `attack_cooldown`, `windup_time`, `projectile_speed`, `projectile_damage`) + dash params (`dash_trigger_range`, `dash_windup`, `dash_speed`, `dash_duration`, `dash_cooldown`).
- `enemies/attacks/{enemy_attack,ranged_attack,dash_attack}.gd` — strategy base + the two behaviours.
- `enemies/enemy_projectile_3d.{gd,tscn}` — the enemy projectile.
- `enemies/enemy_3d.gd` — `_attack` field + `_make_attack()` + the `if _attack / else (inline melee)` delegation in `_physics_process`.
- `enemies/{spitter,archer,magician,dasher}.tres` — spitter upgraded to RANGED; three new variants (CC0 **placeholder** models — see open item).
- `spawning/spawner_3d.gd` — `ARCHER_PATH`/`MAGICIAN_PATH`/`DASHER_PATH` consts + three `_variants` entries in `setup()`.
- `spawning/difficulty_timeline.gd` — `ARCHER_THRESHOLD`/`DASHER_THRESHOLD`/`MAGICIAN_THRESHOLD` consts + three `variants.append` calls in `state_at()`.
- Tests: `test_enemy_attack_data`, `test_enemy_projectile_3d`, `test_enemy_attack_wiring`, `test_ranged_attack`, `test_dash_attack`, `test_enemy_variant_gating`. Docs: `docs/notes/enemy-attacks.md`, `docs/notes/enemy-projectile-3d.md`.

## Type-based weapon system — FOUNDATION (NEW this session, on `main`)

A **TemTem-style type-gated weapon pool** ported from *LoL Swarm* is designed, planned, and has its **foundation merged to `main`** (the data + wiring machinery only — no weapon content yet). It is **dormant**: nothing in-game changes until a character sets `types`/`ultimate`.

- **Design intent:** **10 "Natural" weapons** (every character can roll) + **10 type-gated weapons** (~50/50 split) + **10 exclusive per-friend ultimates** (big cooldown, offensive or defensive). Each friend has **1–2 types** and is offered `Natural ∪ their-type` weapons. Types: `charm/social/holy/pack/toxic/pest/joy/bomber/rush/sound` + `natural`. Friend→type→weapon→ultimate tables (incl. Matan's "Buzzkill" self-buff/team-debuff ult) live in the spec.
- **Spec:** `docs/superpowers/specs/2026-06-29-type-based-weapon-system-design.md`. **Plan:** `docs/superpowers/plans/2026-06-29-type-weapon-system-foundation.md`.
- **Foundation delivered — suite 1064/1064 on `main`:**
  - `SkillData.type: StringName` (default `&"natural"`); `CharacterData.types: Array[StringName]` + `CharacterData.ultimate: SkillData` (all additive/back-compat).
  - `core/skill_pool.gd` — `SkillPool.filter(pool, types)` (pure: `natural ∪ matching`), `all()` (empty registry — content plans populate it), `for_types()`.
  - `SkillSystem` **weapon-slot cap** (3rd ctor arg, default **6**; signature ultimate exempt; suppresses NEW non-signature weapons once at cap).
  - `GameManager3D.assemble_run_skills(ultimate, pool, types)` + a NEW first branch in `start()` (`[ultimate] + SkillPool.filter(SkillPool.all(), types)`) firing only when `ultimate != null AND types` non-empty; legacy per-character `skills` path kept as the `elif`.
  - Built via subagent-driven TDD in an isolated worktree; per-task + whole-branch (opus) reviewed; merged conflict-free (zero file overlap with the concurrent enemy work).
- **Authoring contract for the content plans** (foundation can't enforce these yet — from the final review):
  - every pool weapon `.tres`: `skill_upgrade.skill_id == SkillData.id` AND non-null `weapon_scene`;
  - every ultimate: `is_signature == true` AND non-null `weapon_scene` (else it isn't granted **and** wrongly counts against the cap);
  - migration: a character with only ONE of `{types, ultimate}` set silently falls to the legacy path — add a warn/assert.
- **Playtest spike — branch `demo/uwu-avihay`** (off `main`, not merged): built a **UwU Blaster ("Pew Pew")** Natural weapon — a fast **7-round burst on a 4 s cooldown**, aim locked once per burst, reuses `Bubble3D` — and temporarily set it as Avihay's signature to see the system run. **Avihay has since been reverted to Chat Spam** on that branch; the UwU Blaster files remain there (unwired) for reuse as the real Natural-pool weapon. `main` was never touched by the demo.
- **NEXT:** the content plans, in order — 10 Natural weapons → 10 type weapons → 10 ultimates (+ co-op `players`-group plumbing for the team-effect ults) → character `types`/`ultimate` wiring + migration → balance pass.

## ⚠️ Open / deferred (next session)
1. **2D code removed — DONE this session.** All legacy 2D scenes/scripts/tests/resources + their `.uid` sidecars were deleted (16 scripts, 13 scenes, 4 character resources, 15 test suites); the 2D `Juice` autoload was removed from `project.godot` (`Juice3D` stays); `test_skill_vfx.gd` Part A was migrated `Juice`→`Juice3D` to keep `EvolutionFlash` coverage. Verified: headless import + boot clean, no kept code references any 2D class/scene. Orphan 2D sprite atlases (referenced by the deleted `*_frames.tres`) were left in place — optional art cleanup later.
2. **Enemy skeletal animation UNCONFIRMED** — mesh GLBs lack embedded AnimationPlayers. A procedural bob/lean now keeps enemies visually alive while moving (works). A skeletal retarget (loading the separate `*_run/_walk.glb` clips onto each mesh's skeleton) is attempted in `Enemy3D` but **not verified to actually move bones** (needs the Godot editor / a real playtest to confirm track paths match). If bones don't move, finish the retarget in-editor. Players DO animate (idle/walk).
3. **Playtest tuning** — enemy `model_scale`/`model_y_offset` (converted FBX may import large/offset; bosses compound body-scale × model-scale), camera-shake magnitude, skill balance (e.g. Ido DoT cd 1.0 at high damage_mult), orb-color readability, VFX visibility/perf with many enemies.
4. **Accumulated Minor review notes** (non-blocking) are listed per-task in `.superpowers/sdd/progress.md` — triage before any release.
5. **Asset license** — the MDA monster pack is a 2016 commercial Unity asset with **no bundled license**: fine for a personal prototype, rights UNCONFIRMED before distribution (`docs/notes/asset-licenses.md`). Player models (Kenney) + VFX lib are CC0/MIT.
6. **Ranged & dasher enemies — DONE this session** (this resolves the earlier frozen-spitter bug). Spitter now fires; archer/magician/dasher added with difficulty gating (see the "Ranged & Dasher" section). Ranged enemies approach to their attack range then hold & fire (owner directive); the spawn-at-origin projectile bug was caught in final review and fixed. Suite green at **1049/1049**. **Two follow-ups:** (a) the new variants use **CC0 PLACEHOLDER models** — tinted Kenney character meshes (archer/magician) + the bug mesh (dasher); reliable headless download of bespoke rigged archer/magician art wasn't feasible — swap for dedicated art when available; the dasher's bug mesh is the same unconfirmed-license MDA asset as swarmer (item 5). (b) **Owner playtest pending** for feel/balance — projectile dodging, terrain-as-cover, dash timing, spawn cadence — since headless can't render or simulate RVO. Tuning lives in the `enemies/*.tres` (ranges/cooldowns/damage/windups). Deferred Minor cleanups (e.g. a now-dead `is_ranged` branch in `enemy_3d.gd`) are logged in `.superpowers/sdd/progress.md`.
7. **HP regen added (NEW this session)** — `StatBlock.hp_regen` (HP/sec, per-character; applied in `Player3D._physics_process`, no overheal / no reviving the dead). Values vary 0.4 (Yoav) → 2.0 (Natali) in each `characters/<name>_3d.tres`. Covered by tests in `test_player_3d.gd`.

When resuming: read this file, then `.superpowers/sdd/progress.md`, `git log --oneline`, `docs/notes/INDEX.md`.
