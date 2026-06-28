# Friends Swarm — 3D Pivot & Feature Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement this plan task-by-task. All code is written by subagents (never the main/orchestrator session). Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the 2D horde-survivor into a tilted top-down **3D** game with real character models, 4 skills per character, all 10 friends, per-skill synergies, post-levelup invulnerability, and exp-tier–colored orbs.

**Architecture:** Keep the pure-logic + data + UI layers (UpgradeSystem, DifficultyTimeline, XP curve, GameEvents, RunState, CharacterData, Upgrade, HUD/cards) and rebuild only the scene/physics/render layer in 3D on the XZ ground plane with a fixed tilted perspective `Camera3D`. Gameplay logic stays unit-tested (GUT); 3D scenes/visuals get headless smoke tests + human playtest.

**Tech Stack:** Godot 4.7 (GDScript), GUT test addon, glTF 3D models (CC0 for players, converted FBX for enemies), GPUParticles3D / Label3D for VFX.

## Global Constraints

- Engine: Godot 4.7 stable. Headless boot must stay green: `godot --headless --quit`.
- Test suite must stay green after every task: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit` (currently 220/220).
- All work on branch `feature/v1-vertical-slice`. Atomic commits per task.
- Every `.gd` file's first line stays `# See docs/notes/<id>.md`; keep Zettelkasten notes + INDEX current.
- **All code authored by subagents.** Orchestrator only coordinates, reviews, updates `.superpowers/sdd/progress.md`, and updates `HANDOFF.md` after each agent/wave.
- Each task = implementer subagent → reviewer subagent (spec + quality) → fix loop. Parallel file-writing tasks use **git worktree isolation** to avoid conflicts.
- Human (user) runs the actual 3D game for visual/feel verification — headless cannot see pixels.

---

## Key Decisions (chosen from options, per user directive to pick the best-suited, not the easiest)

**DEC-1 — Camera / view.** Fixed-rotation **perspective `Camera3D`**, pitch ≈ **-55°** (looks down with a clear side tilt, not straight-down), height ≈ 14u, follows the player on X/Z only. Gameplay happens on the **XZ plane** (Y = up).
- Considered: (a) perspective @ ~55° tilt ✅ chosen — gives "above with a bit of side tilt" + subtle depth; (b) orthographic tilted — flatter, loses depth cue the user asked for; (c) over-shoulder/3rd-person — too much side, loses the top-down readability a horde-survivor needs.

**DEC-2 — Player ("friend") models.** **No humanoid models exist in Downloads** (only the monster pack + unrelated docs). Source a **CC0 rigged humanoid glTF pack** (Kenney "Mini Characters" / "Blocky Characters"; Quaternius "Ultimate Modular Characters" as backup) and differentiate the 10 friends by tint + accessory.
- Considered: (a) Kenney/Quaternius CC0 glTF ✅ chosen — native glTF import, CC0-safe, animations included, easy to make 10 distinct friends; (b) Mixamo rigged humanoids — great quality but per-model manual download + license friction; (c) primitive capsule + billboard face — fast but looks like a prototype, fails the "actual characters" goal.
- ⚠️ **Surfaced for approval:** this is the one place we deviate from "from the downloads folder" because the assets simply aren't there for players.

**DEC-3 — Enemy models.** Use the **Downloads MDA monster pack** (`~/Downloads/MDA_Hatchery_CP1`, ~187 animated **FBX**) per user request → convert **FBX→glTF** (Blender headless or FBX2glTF), extracting textures from the `.unitypackage`. **Fallback:** Quaternius "Ultimate Monsters" (CC0 glTF, animated) if conversion proves unreliable.
- ⚠️ **License caveat:** MDA Hatchery is a 2016 commercial Unity asset with no bundled license — fine for a local/personal prototype, but rights must be confirmed before any distribution. Documented in `docs/notes/asset-licenses.md`.

**DEC-4 — Multi-skill architecture.** `Player.weapons: Array[Weapon]`; `CharacterData.skills: Array[SkillDef]` (1 signature owned at start + 3 acquirable). `Upgrade` gains a `skill_id` to target a specific skill. Level-up pool offers: acquire-a-new-skill cards, level-an-owned-skill, matching passives, synergies, and generic stats.
- Considered: (a) array-of-weapons ✅ chosen — matches Vampire-Survivors multi-weapon, clean routing; (b) single weapon with "modes" — hacky, doesn't scale to 4 distinct skills; (c) full component/ability-slot ECS — overkill for this scope.

**DEC-5 — Per-skill synergy.** Generalize the current single evolution rule: **each of the 4 skills has a matching passive**; when a skill is **maxed (lvl 5)** AND its matching passive is **≥ lvl 1**, that skill's **synergy** upgrade enters the card pool on the next level-up (golden card).

---

## Phases & Ordering (with parallelism)

```
Phase 1  3D Core Conversion ───────────┐ (runs concurrently with Track A)
Track A  Asset Pipeline ───────────────┘
                 │
Phase 2  Model Integration  (needs Phase 1 + Track A)
                 │
Phase 3  Multi-skill framework + [‖ Item 6 invuln] + [‖ Item 7 orb colors]
                 │
Phase 4  Per-skill synergy system
                 │
Phase 4.5  Skill VFX & visuals framework (NEW — Item 8)
                 │
Phase 5  All 10 characters (fan-out, worktree-isolated; each skill ships with its VFX)
                 │
Phase 6  Integration + verification + handoff
```

---

## Phase 1 — 3D Core Conversion (Item 1) — foundational

Rebuilds scene/physics/render in 3D. Pure logic (`UpgradeSystem`, `DifficultyTimeline`, XP curve, `GameEvents`, `RunState`, `CharacterData`, `Upgrade`) is reused unchanged; its GUT tests must stay green throughout.

### Task 1.1 — World, camera, ground, main scene skeleton
- **Files:** Create `game/main_3d.tscn`, `arena/arena_3d.tscn`, `core/game_camera_3d.gd`; modify `project.godot` (main scene), `autoload` wiring.
- **Deliverable:** Bootable 3D scene — tilted perspective `Camera3D` (DEC-1), `DirectionalLight3D` + `WorldEnvironment`, ground plane, camera follows a placeholder body on XZ.
- **Test:** headless boot (`--headless --quit`) + GUT smoke test asserting camera pitch/follow math.

### Task 1.2 — Player → `CharacterBody3D`
- **Files:** `player/player.tscn`/`player.gd` (rebuild as 3D), `player/hurtbox` Area3D.
- **Reuse:** HP/XP/level/`xp_to_next` logic and signals unchanged; only movement (XZ via `velocity`/`move_and_slide`) and collision become 3D. Re-add body `CollisionShape3D` (the 2D bug's analog) so gem pickup works.
- **Test:** existing player logic GUT tests pass; new smoke test for 3D movement + pickup collision layers.

### Task 1.3 — Enemy → `CharacterBody3D` (3 variants) [parallelizable with 1.2 via worktree]
- **Files:** `enemies/enemy.tscn`/`enemy.gd`, `enemies/{swarmer,spitter,tank}.tres` (EnemyData → 3D mesh/model ref), contact-damage Area3D.
- **Reuse:** steering/contact-damage/HP-scale logic; preserve `duplicate()` safety. Replace ColorRect/Sprite2D with a `MeshInstance3D`/model slot.
- **Test:** enemy logic GUT tests pass; smoke test for steering toward player on XZ.

### Task 1.4 — Weapons, Spawner, XP gems → 3D
- **Files:** `weapons/ziv_stunning_looks.*`, `weapons/avihay_chat_spam.*`, `weapons/projectile_3d.*`, `spawning/spawner.*`, `pickups/xp_gem.*`.
- **Deliverable:** Ziv beam/charm + Avihay bubbles fire in 3D (Area3D/RayCast3D); spawner places enemies on XZ ring around player; XP gems are 3D with magnet + `body_entered` collection.
- **Test:** spawner + gem-magnet GUT/smoke tests; weapon fire-timer tests preserved.

### Task 1.5 — Juice/VFX + UI → 3D
- **Files:** `autoload/juice.gd`, `vfx/*`, `fx/*`, `ui/hud.tscn`, `ui/upgrade_ui.tscn`.
- **Deliverable:** screen shake (camera), hit-flash (material), damage numbers (billboard `Label3D`), death pops + level-up/evolution fanfare (`GPUParticles3D`). HUD/cards stay on `CanvasLayer` (largely unchanged).
- **Test:** Juice signal-wiring GUT tests; headless boot stays green.

## Track A — Asset Pipeline (runs concurrently with Phase 1; no code-file conflicts)

### Task A.1 — Player character models (DEC-2)
- Download CC0 humanoid glTF pack (Kenney first; Quaternius backup) into `art/characters_3d/`; import; verify rigs + idle/walk animations load in Godot. Record license in `docs/notes/asset-licenses.md`.

### Task A.2 — Enemy models from Downloads (DEC-3)
- Extract `~/Downloads/MDA_Hatchery_CP1`; convert chosen monster FBX→glTF (Blender headless / FBX2glTF; verify a tool is available, else fallback to Quaternius CC0 monsters); extract textures from `.unitypackage`; import into `art/enemies_3d/`; verify animations. Record license caveat.

## Phase 2 — Model Integration (Item 2) — needs Phase 1 + Track A

### Task 2.1 — Player uses real friend models
- Wire per-`CharacterData` model + tint/accessory into `player.tscn`; hook idle/walk/run animations to movement state; scale/orient for the tilted camera.

### Task 2.2 — Enemies use real monster models
- Map each `EnemyData` variant to a converted monster model; hook idle/move/death animations; replace remaining placeholder meshes; tune scale vs player on the tilted camera.

## Phase 3 — Multi-skill framework (Item 3) + parallel small features

### Task 3.1 — Multi-weapon refactor (DEC-4)
- **Files:** `player/player.gd` (`weapons: Array[Weapon]`), `core/character_data.gd` (`skills: Array`), `upgrades/upgrade.gd` (`skill_id`), `upgrades/upgrade_system.gd`, `game/game_manager.gd` (routing + acquire-skill cards).
- **Deliverable:** start with the signature skill owned; the other 3 acquirable via cards; leveling targets a specific owned skill. **TDD with full GUT coverage** (this is pure logic — first-class tests).

### Task 3.2 — Ziv's + Avihay's 3 extra skills each (6 new 3D weapons)
- Author 3 new weapon scenes per existing character following `docs/notes/how-to-add-a-character.md` (3D), plus their skill upgrade `.tres`.

### Task 3.6 — Post-levelup invulnerability (Item 6) [‖ parallel with 3.2/3.7]
- **Files:** `player/player.gd` (`set_invulnerable(2.0)` + i-frame state in hurtbox), `game/game_manager.gd` (trigger on card chosen), `autoload/juice.gd` (blink VFX).
- **Deliverable:** 2.0s of no-damage after choosing an upgrade card, with a visible blink. **GUT test** for the i-frame window.

### Task 3.7 — Exp-tier orb colors (Item 7) [‖ parallel]
- **Files:** `pickups/xp_gem.*`, value→tier mapping helper, spawn wiring.
- **Deliverable:** gem color/emission set by XP value bucket; buckets scale with enemy strength and elapsed run time (weakest enemies = lowest tier early; higher tiers appear as the run progresses). **GUT test** for value→color bucketing + time scaling.

## Phase 4 — Per-skill synergy system (Item 5)

### Task 4.1 — Generalize evolution → per-skill synergy (DEC-5)
- **Files:** `upgrades/upgrade_system.gd` (offer synergy when `skill.level == 5 && matching_passive.level >= 1`), `upgrades/upgrade.gd`, `ui/upgrade_ui.gd` (golden synergy card), `docs/notes/evolution-rule.md`.
- **Deliverable:** each skill has a matching passive + a synergy that enters the pool on the next level-up once the max+passive condition holds. **Full GUT coverage** of the gating logic; apply to Ziv/Avihay as the reference implementation.

## Phase 4.5 — Skill VFX & visuals framework (Item 8 — NEW)

Make every skill *look* and *feel* distinct. Built as a **decoupled VFX layer** (same pattern as the existing `Juice` autoload): skills emit `GameEvents` signals (cast/hit/evolve), and VFX scenes react — so the gameplay/logic tests stay green regardless of visuals.

### Task 4.5.1 — Skill VFX framework + library integration
- **Files:** `vfx/skill_vfx.gd` (registry mapping `skill_id` → cast/hit/evolve effect scenes), `autoload/juice.gd` (skill-cast/skill-hit hooks), `core/weapon.gd` (emit cast/hit signals via `GameEvents`), `addons/` (vendor relevant CC0/MIT effects from GODOT-VFX-LIBRARY + gdquest godot-visual-effects, 3D-compatible: muzzle flashes, beams, impacts, AoE rings, trails, status auras).
- **Deliverable:** a reusable, data-driven way to attach muzzle/cast VFX, projectile trails, impact bursts, AoE telegraphs, and status-effect auras (charm, poison, stun, burn) to any skill — plus a distinct **synergy/evolution** visual upgrade. Record effect-asset licenses in `docs/notes/asset-licenses.md`.
- **Reference implementation:** wire full VFX for **Ziv's 4 skills + Avihay's 4 skills** (cast + hit + evolved variant each), proving the framework before fan-out.
- **Test:** GUT tests assert skills emit the cast/hit signals and the registry resolves an effect per `skill_id`; headless boot stays green. Visual quality verified by user playtest.

### Task 4.5.2 — Skill juice pass
- Per-skill screen-shake/hit-stop weight, damage-number styling per element, sound hooks (if audio assets present), and EVOLVE-tier glow. Tuning task; small, follows 4.5.1.

> **Note for Phase 5:** each character-authoring task now **also** ships its 4 skills' VFX using the 4.5.1 framework — VFX is part of "a skill is done," not a separate later pass.

## Phase 5 — All 10 characters (Item 4) — fan-out

### Task 5.x (one task per remaining friend; parallel, worktree-isolated)
- Friends: **Avinoam, Matan, Ido, Yuval, Natali, Barak, Yinon, Yoav** (designs in `docs/superpowers/specs/2026-06-28-friends-swarm-design.md`).
- Each character authors: 4 skill weapon scenes (3D) + 4 matching passives + 4 synergies + `CharacterData` `.tres` + model wiring + Zettelkasten notes. Reviewer per character. Run as parallel waves (e.g. 2–4 characters concurrently) in isolated worktrees, merged sequentially with the suite kept green.

## Phase 6 — Integration & verification

### Task 6.1 — Full integration + verification
- Run full GUT suite (target: green, expanded well beyond 220), headless boot check, `docs/notes/INDEX.md` + ADRs refreshed, `.superpowers/sdd/progress.md` finalized, `HANDOFF.md` rewritten for the 3D state.
- **Hand off to user** for manual 3D playtest (camera feel, model scale/orientation, skill feel, synergy flow, orb colors, invuln window) — the only verification headless can't do.

---

## Documentation cadence
After **every** agent/wave completes, the orchestrator updates `HANDOFF.md` (and `progress.md`) with what changed, before moving on — per user directive.

## Self-review coverage map
- Item 1 → Phase 1 (all tasks). Item 2 → Track A + Phase 2. Item 3 → Phase 3 (3.1, 3.2).
- Item 4 → Phase 5. Item 5 → Phase 4. Item 6 → Task 3.6. Item 7 → Task 3.7.
- Item 8 (skill effects & visuals — NEW) → Phase 4.5 (framework + Ziv/Avihay) + Phase 5 (per-character skills ship with VFX).
- All 8 items mapped to at least one task. ✅
