# Ultimates Phase 2 — the 9 remaining ults + 3-zone HUD

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Give the other 9 friends their exclusive SPACE ultimate (each with a signature visual), and reorganize the in-run HUD into three zones: passives left, ultimate as a radial circle center-bottom, weapons right.

**Architecture:** Each ult is an `UltimateWeapon3D` subclass following the proven `UltJudgmentDay3D` reference (`weapons/ult_judgment_day_3d.gd`): set `ult_cooldown` + `vfx_*` in `_ready()` then `super()`, override `_do_ult()` with the effect + a self-contained visual, ship a scene + a `characters/ultimates/<friend>_<ult>.tres` SkillData (no upgrade fields), and set `ultimate` on the friend's `CharacterData`. The HUD splits its single cooldown row into three anchored zones and adds a radial ultimate indicator + passive icons.

**Tech Stack:** Godot 4.7, GDScript, GUT (headless).

## Global Constraints

- Engine Godot 4.7. Headless boot stays green: `godot --headless --quit`. Full suite green after every task: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit` (currently 923/923 on this branch).
- Single test: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/<file>.gd -gexit`. Run `--import` first when files are added.
- GUT 9.7.0 silently skips files using `assert_le`/`assert_ge` — use `assert_true(x <= y)`.
- **Ultimates: manual SPACE only, never auto-fire, never in the weapon pool, never upgraded.** Reference: `weapons/ult_judgment_day_3d.gd` + base `core/ultimate_weapon_3d.gd`.
- Ult resource `.tres`: `SkillData` with `id`, `display_name`, `weapon_scene`, `type` (owner's primary type), `is_signature = false`, `description`, and NO `skill_upgrade`/`passive_upgrade`/`synergy_upgrade`.
- Wiring a friend: add one `ext_resource` for the ult `.tres` + `ultimate = ExtResource(...)` on the `[resource]`; leave `skills`, `types`, stats UNCHANGED.
- **Team-effect ults** (Avihay/Matan/Natali): apply self + enemy effects directly; apply the TEAM portion only to other members of the `players` group — in solo that set is empty, so the team portion no-ops (self effects still apply). Per spec §10.
- Each ult `_do_ult()` spawns a self-contained visual (own mesh/material/tween, auto-frees) like Judgment Day's `_strike_bolt`. Keep visuals at that fidelity — clear, cheap, no shared resources.
- Commit ONLY each task's listed files (never `git add -A`). Co-author trailer: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 1: 3-zone HUD (passives left · ultimate center-bottom radial · weapons right)

**Files:**
- Modify: `player/player_3d.gd` (track acquired passives)
- Modify: `ui/hud.gd` (three zones + radial ult + passives)
- Create: `ui/radial_cooldown.gd` (a small reusable radial indicator Control)
- Test: `test/test_hud_zones.gd` (create)

**Interfaces:**
- Produces: `Player3D.passives: Dictionary` (skill_id → level int); `HUD.collect_passives(player) -> Array` (entries `{ "id": StringName, "level": int }`); `RadialCooldown.set_fraction(f: float)` drawing an arc (0 empty … 1 full ring). `HUD.collect_cooldowns` (existing) reused; weapons → right zone, the `is_ultimate` entry → center radial.

- [ ] **Step 1: Write the failing test**

Create `test/test_hud_zones.gd`:

```gdscript
extends GutTest
## HUD splits skills into zones: weapons (right) vs ultimate (center) from
## collect_cooldowns; passives (left) from collect_passives.

class _StubWeapon extends Node3D:
	func cooldown_fraction() -> float: return 0.3
class _StubUlt extends Node3D:
	func cooldown_fraction() -> float: return 0.7
class _StubPlayer extends Node3D:
	var weapons := {}
	var ultimate = null
	var passives := {}

func test_collect_passives_lists_levels() -> void:
	var hud = load("res://ui/hud.gd").new()
	var p := _StubPlayer.new()
	p.passives = { &"pew_pew": 2, &"trigger_finger": 1 }
	var got: Array = hud.collect_passives(p)
	assert_eq(got.size(), 2)
	# entries carry id + level
	var ids := []
	for e in got: ids.append(e["id"])
	assert_true(ids.has(&"pew_pew"))

func test_collect_passives_empty_when_none() -> void:
	var hud = load("res://ui/hud.gd").new()
	assert_eq(hud.collect_passives(_StubPlayer.new()).size(), 0)

func test_radial_fraction_clamped() -> void:
	var r = load("res://ui/radial_cooldown.gd").new()
	r.set_fraction(1.5)
	assert_almost_eq(r.fraction, 1.0, 0.0001)
	r.set_fraction(-0.2)
	assert_almost_eq(r.fraction, 0.0, 0.0001)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_hud_zones.gd -gexit` → FAIL (`collect_passives`/`radial_cooldown.gd` missing).

- [ ] **Step 3: Track passives on `Player3D`**

In `player/player_3d.gd` add a field near `weapons`:

```gdscript
## Acquired passive upgrades: skill_id → level (count of times applied). For the HUD.
var passives: Dictionary = {}
```

In `apply_skill_passive(skill_id, value)` (existing), record it (add at the top of the method body):

```gdscript
	passives[skill_id] = int(passives.get(skill_id, 0)) + 1
```

- [ ] **Step 4: Create `ui/radial_cooldown.gd`**

```gdscript
class_name RadialCooldown extends Control
## A circular cooldown ring: draws a filled ring arc for `fraction` (0..1)
## plus a label. Used center-bottom for the ultimate. 1.0 = full/ready.

var fraction: float = 1.0
var label: String = "ULT"
var ready_color := Color(1.0, 0.85, 0.2)
var cooling_color := Color(0.5, 0.5, 0.55)

func set_fraction(f: float) -> void:
	fraction = clampf(f, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 4.0
	# Background ring.
	draw_arc(c, radius, 0.0, TAU, 48, Color(0,0,0,0.5), 6.0, true)
	# Filled portion (clockwise from top).
	var col := ready_color if fraction >= 1.0 else cooling_color
	var end := -PI/2 + TAU * fraction
	draw_arc(c, radius, -PI/2, end, 48, col, 6.0, true)
	# Center fill when ready.
	if fraction >= 1.0:
		draw_circle(c, radius - 6.0, Color(ready_color.r, ready_color.g, ready_color.b, 0.25))
```

- [ ] **Step 5: Rework the HUD zones in `ui/hud.gd`**

Replace the single bottom-left `_cooldowns_box` setup with three anchored containers built in `_ready()`:
- **Right** — an `HBoxContainer` anchored `PRESET_BOTTOM_RIGHT` for WEAPON cooldown bars (the existing cyan bar style; one per `collect_cooldowns` entry where `is_ultimate == false`).
- **Center** — a `RadialCooldown` (≈64×64) centered horizontally, anchored to bottom-center, fed the `is_ultimate` entry's `fraction` each frame (hidden if the player has no ultimate).
- **Left** — an `HBoxContainer` anchored `PRESET_BOTTOM_LEFT` for PASSIVE indicators (one small panel/label per `collect_passives` entry, showing a level pip; no cooldown).

Add the pure collector:

```gdscript
## Acquired passives for the left HUD zone. Pure (stub-friendly).
func collect_passives(player) -> Array:
	var out: Array = []
	if player == null or not is_instance_valid(player):
		return out
	var p = player.get("passives")
	if p is Dictionary:
		for id in p:
			out.append({ "id": id, "level": int(p[id]) })
	return out
```

In `_process`, drive all three zones from the located `_player`: weapons → right bars, ult entry → `RadialCooldown.set_fraction(...)`, passives → left indicators. Keep the per-frame rebuild cheap (only rebuild a zone when its entry count changes; update fraction/label every frame). Visual styling (sizes, colors, fonts) is playtest-tunable — the test only covers `collect_passives` + `RadialCooldown.set_fraction` clamping.

- [ ] **Step 6: Run tests + full suite + boot**

`godot --headless --import && godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_hud_zones.gd -gexit` → PASS (3).
Full suite + `--headless --quit` → green + clean boot.

- [ ] **Step 7: Commit**

```bash
git add player/player_3d.gd ui/hud.gd ui/radial_cooldown.gd test/test_hud_zones.gd
git commit -m "feat(hud): 3-zone layout — passives left, ultimate radial center, weapons right

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Ultimate task template (Tasks 2–10)

Each ultimate task creates four files + wires one character + one test, modeled on `weapons/ult_judgment_day_3d.gd`. Per task:

1. `weapons/ult_<key>_3d.gd` — `class_name Ult<Camel>3D extends UltimateWeapon3D`; `_ready()` sets `ult_cooldown`, `vfx_id`, `vfx_color`, then `super()`; `_do_ult()` performs the effect from the table + spawns a self-contained signature visual (own mesh/material/tween, auto-free) at the relevant positions.
2. `weapons/ult_<key>_3d.tscn` — a `Node3D` with the script (copy Judgment Day's scene shape).
3. `characters/ultimates/<friend>_<key>.tres` — SkillData (see Global Constraints; type = the friend's primary type), no upgrade fields.
4. Wire `characters/<friend>_3d.tres` — add the `ext_resource` + `ultimate = ExtResource(...)`, leaving `skills`/`types` unchanged.
5. `test/test_ult_<key>.gd` — `activate()` applies the effect to a nearby stub enemy (damage/charm) and NOT to a far one; and the friend's `ultimate` + `weapon_scene` load. Use the Judgment Day test as the template. For non-damage ults (buff/summon), assert the observable effect (e.g. a spawned child appears, or `charm()` was called).

Each task ends: run the new test + full suite + `--headless --quit`, commit only that task's files.

### The 9 ultimates

| # | Friend | Ult (key) | type | CD | `_do_ult` behavior | Signature visual |
|---|---|---|---|---|---|---|
| 2 | Ziv | Main Character Moment (`main_character`) | charm | 30 | charm every enemy within `radius`≈12 for ~3 s (`enemy.charm(3.0)`); no damage | expanding pink/magenta ring + floating hearts |
| 3 | Avihay | Conference Call (`conference_call`) | social | 35 | self: `player.set_invulnerable(3.0)`; enemies in `radius`: damage + shove outward; spawn 2 temporary "helper" nodes that chase+ping enemies for ~6 s; team shield applies to other `players` (no-op solo) | blue summon ring + helper blips |
| 4 | Barak | Release the Hounds (`hounds`) | pack | 30 | spawn N≈3 hound minions (reuse the `weapons/barak_loyal_hounds_3d` pattern) that chase nearest enemies and deal contact damage for ~8 s then despawn | hound meshes + spawn puff |
| 5 | Ido | Biohazard (`biohazard`) | toxic | 28 | damage enemies in `radius`; leave a lingering poison field that re-damages enemies inside it each ~0.5 s for ~5 s | green expanding toxic cloud that lingers + fades |
| 6 | Matan | Buzzkill (`buzzkill`) | pest | 30 | self: temporary buff for ~6 s — `stats.damage_mult`, `move_speed`, `fire_rate_mult` up (store originals, revert on a timer; `refresh_cooldown` on weapons via player if needed); other `players`: slow + reduce stats (no-op solo) | red/orange buff aura pulsing on Matan |
| 7 | Natali | Comic Relief (`comic_relief`) | joy | 30 | stun/charm enemies in `radius` (`enemy.charm(2.5)`); heal self (`player` HP up, clamped to max); heal other `players` (no-op solo) | yellow laughter burst + "ha ha" pop |
| 8 | Yinon | Carpet Bomb (`carpet_bomb`) | bomber | 35 | over ~2 s, spawn a sequence of ~8 explosions at spread positions around the player (each an AoE damage pop) using `await get_tree().create_timer(...)` between blasts | staggered orange explosion spheres |
| 9 | Yoav | Express Delivery (`express_delivery`) | rush | 30 | perform ~3 plow-through line strikes: pick a direction, damage all enemies along a line segment from the player, repeat with a short delay; (optionally nudge the player along) | fast white dash streaks along each line |
| 10 | Yuval | Bass Drop (`bass_drop`) | sound | 30 | one massive shockwave: damage all enemies in a large `radius`≈16 and shove them outward from the player | huge expanding concentric sound ring |

Notes for implementers:
- `enemy.charm(duration)` and `enemy.take_damage(amount)` exist on `Enemy3D`. There is no knockback API — "shove outward" = directly offset the enemy's `global_position` away from the origin by a few units (guard `is_instance_valid`), or skip the push and keep damage+visual if it risks fighting navigation; keep it simple and safe.
- Buff/timed effects (Matan) can ride the ult's own `_process`/a `SceneTreeTimer`; revert exactly once. Don't leak buffs across activations.
- Summons (Barak/Avihay helpers) should auto-despawn (`queue_free` on a timer) and never crash if the player/enemies are gone.
- Team portions query `get_tree().get_nodes_in_group("players")` and skip `self`'s player; in solo this is empty → no-op.

---

### Task 11: Phase-2 whole-branch review

- [ ] Dispatch the final reviewer over the Phase-2 commit range: verify all 10 friends now have a working SPACE ultimate (Avinoam from Phase 1 + these 9), each visible and damaging/affecting enemies; no ult auto-fires or enters the weapon pool; the 3-zone HUD reads correctly (passives left, radial ult center, weapons right) and degrades when a character has no ult; team-effect ults no-op safely in solo; full suite green; clean boot. Fix Critical/Important findings, then this plan is done.

## Self-Review

- **Spec coverage:** §7 all 10 ults → Avinoam (Phase 1) + Tasks 2–10; §7a manual/non-upgradeable preserved (template reuses `UltimateWeapon3D`, no pool wiring); §10 team-effect `players` plumbing → Tasks 3/6/7 + Global Constraints; all-skills HUD → reorganized in Task 1 (passives left, ult center radial, weapons right). ✓
- **Placeholder scan:** Ult `_do_ult` bodies are specified by behavior + the Judgment Day reference rather than full code per ult — acceptable for a templated content batch with a proven reference; HUD visual styling is playtest chrome with the tested contract (`collect_passives`, `set_fraction`) fully specified.
- **Type consistency:** every ult extends `UltimateWeapon3D` (manual `activate`/`_do_ult` from Phase 1); resources use the no-upgrade `SkillData` shape; `passives`/`collect_passives`/`RadialCooldown.set_fraction` consistent across Task 1 and its test.
