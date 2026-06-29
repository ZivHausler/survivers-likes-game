# Ultimates (SPACE-activated) + All-Skills Cooldown HUD — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give every character a manually-activated (SPACE) ultimate on a long cooldown, and show a cooldown indicator on the HUD for ALL skills (auto weapons + the ultimate).

**Architecture:** A new `UltimateWeapon3D` base (extends `Weapon3D`, no auto-fire, manual `activate()` + own cooldown). `Player3D` holds the ult in a dedicated slot and activates it on the `ultimate` input (SPACE). `GameManager3D` grants the ult from `CharacterData.ultimate`, separate from the weapon pool — so ults are never offered or upgraded. The HUD reads the player's live weapons + ult each frame via `cooldown_fraction()` and renders one indicator per skill. This plan delivers the mechanism + HUD + one reference ultimate; the other 9 follow as a content batch (roadmap at the end).

**Tech Stack:** Godot 4.7, GDScript, GUT (headless).

## Global Constraints

- Engine **Godot 4.7 stable**. Headless boot stays green: `godot --headless --quit`.
- Full suite green after every task: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`.
- Single test: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/<file>.gd -gexit`. Run `--import` first when scripts/resources are added.
- GUT 9.7.0 **silently skips** a whole file using `assert_le`/`assert_ge` — use `assert_true(x <= y)`.
- Ultimates: **manual SPACE activation, NOT auto-fire, NEVER upgraded, NOT in the level-up pool** (spec §7/§7a). Input action id: `ultimate`, bound to **SPACE**.
- `cooldown_fraction()` convention: **0.0 = just fired, 1.0 = ready**.
- Team-effect ults (Buzzkill/Conference Call/Comic Relief) target the `players` group and no-op the team part in solo.
- Commit ONLY the files each task lists (never `git add -A`). Co-author trailer: `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>`.

---

### Task 1: `cooldown_fraction()` on Weapon3D + `ultimate` input action

**Files:**
- Modify: `core/weapon_3d.gd` (add static helper + method)
- Modify: `project.godot` (`[input]` section)
- Test: `test/test_weapon_cooldown_fraction.gd` (create)

**Interfaces:**
- Produces: `Weapon3D.cooldown_fraction() -> float`; static `Weapon3D.cooldown_fraction_of(time_left: float, wait_time: float) -> float` (pure, testable). Input action `&"ultimate"`.

- [ ] **Step 1: Write the failing test**

Create `test/test_weapon_cooldown_fraction.gd`:

```gdscript
extends GutTest
## Pure cooldown-fraction math: 0.0 just-fired … 1.0 ready.

func test_just_fired_is_zero() -> void:
	assert_eq(Weapon3D.cooldown_fraction_of(2.0, 2.0), 0.0)

func test_ready_is_one() -> void:
	assert_eq(Weapon3D.cooldown_fraction_of(0.0, 2.0), 1.0)

func test_halfway() -> void:
	assert_almost_eq(Weapon3D.cooldown_fraction_of(1.0, 2.0), 0.5, 0.0001)

func test_zero_wait_time_is_ready() -> void:
	# Degenerate timer (never set) reads as ready, not a divide-by-zero.
	assert_eq(Weapon3D.cooldown_fraction_of(0.0, 0.0), 1.0)

func test_clamped() -> void:
	assert_eq(Weapon3D.cooldown_fraction_of(5.0, 2.0), 0.0)  # time_left > wait → clamp 0
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_weapon_cooldown_fraction.gd -gexit`
Expected: FAIL — `Nonexistent function 'cooldown_fraction_of'`.

- [ ] **Step 3: Add the helper + method to `core/weapon_3d.gd`**

After `_refresh_cooldown()` (end of file), add:

```gdscript
## Pure cooldown fraction: 0.0 = just fired, 1.0 = ready. Static for testability.
static func cooldown_fraction_of(time_left: float, wait_time: float) -> float:
	if wait_time <= 0.0:
		return 1.0
	return clampf(1.0 - time_left / wait_time, 0.0, 1.0)

## Live cooldown fraction for the HUD (0.0 just fired … 1.0 ready).
func cooldown_fraction() -> float:
	if not _timer or _timer.is_stopped():
		return 1.0
	return cooldown_fraction_of(_timer.time_left, _timer.wait_time)
```

- [ ] **Step 4: Add the `ultimate` input action to `project.godot`**

In the `[input]` section, add (SPACE = physical keycode 32):

```
ultimate={
"deadzone": 0.5,
"events": [Object(InputEventKey,"resource_local_to_scene":false,"resource_name":"","device":-1,"window_id":0,"alt_pressed":false,"shift_pressed":false,"ctrl_pressed":false,"meta_pressed":false,"pressed":false,"keycode":0,"physical_keycode":32,"key_label":0,"unicode":0,"location":0,"echo":false,"script":null)
]
}
```

- [ ] **Step 5: Run tests + boot**

Run: `godot --headless --import && godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_weapon_cooldown_fraction.gd -gexit` → PASS (5).
Run: `godot --headless --quit` → zero errors; confirm `ProjectSettings` parses the new action (no input-map parse error).

- [ ] **Step 6: Commit**

```bash
git add core/weapon_3d.gd project.godot test/test_weapon_cooldown_fraction.gd
git commit -m "feat: Weapon3D.cooldown_fraction() + ultimate(SPACE) input action

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 2: `UltimateWeapon3D` base (manual activate + cooldown)

**Files:**
- Create: `core/ultimate_weapon_3d.gd`
- Test: `test/test_ultimate_weapon_3d.gd` (create)

**Interfaces:**
- Consumes: `Weapon3D` (Task 1).
- Produces: `UltimateWeapon3D extends Weapon3D` with `ult_cooldown: float`, `activate() -> bool`, `is_ready() -> bool`, `tick(delta)` (pure cooldown advance, public for tests), `cooldown_fraction()` override, and virtual `_do_ult()`. Does NOT auto-fire.

- [ ] **Step 1: Write the failing test**

Create `test/test_ultimate_weapon_3d.gd`:

```gdscript
extends GutTest
## Manual ultimate: activate() gates on cooldown; tick() advances it.

# Minimal concrete subclass that records activations without a scene.
class _ProbeUlt extends UltimateWeapon3D:
	var fired := 0
	func _do_ult() -> void:
		fired += 1

func _make() -> _ProbeUlt:
	var u := _ProbeUlt.new()
	u.ult_cooldown = 10.0
	return u

func test_starts_ready() -> void:
	var u := _make()
	assert_true(u.is_ready(), "ult starts ready")
	assert_eq(u.cooldown_fraction(), 1.0)

func test_activate_fires_and_starts_cooldown() -> void:
	var u := _make()
	assert_true(u.activate(), "activate succeeds when ready")
	assert_eq(u.fired, 1, "_do_ult ran once")
	assert_false(u.is_ready(), "on cooldown after activate")

func test_activate_blocked_while_on_cooldown() -> void:
	var u := _make()
	u.activate()
	assert_false(u.activate(), "second activate blocked")
	assert_eq(u.fired, 1, "no extra _do_ult while on cooldown")

func test_tick_recovers_then_ready() -> void:
	var u := _make()
	u.activate()
	u.tick(10.0)               # full cooldown elapses
	assert_true(u.is_ready(), "ready after cooldown elapses")
	assert_true(u.activate(), "can fire again")
	assert_eq(u.fired, 2)

func test_fraction_midway() -> void:
	var u := _make()
	u.activate()
	u.tick(5.0)                # half of 10s
	assert_almost_eq(u.cooldown_fraction(), 0.5, 0.0001)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_ultimate_weapon_3d.gd -gexit`
Expected: FAIL — `Could not find base class "UltimateWeapon3D"`.

- [ ] **Step 3: Create `core/ultimate_weapon_3d.gd`**

```gdscript
class_name UltimateWeapon3D extends Weapon3D
## Base for manually-activated ultimates. Unlike Weapon3D, it does NOT auto-fire:
## the Weapon3D auto-timer is never started. SPACE → Player3D.activate_ultimate()
## → activate(), which runs _do_ult() and starts a manual cooldown. Ultimates are
## never offered as level-up cards and never upgraded (fixed power).

## Big cooldown between activations (seconds). Subclasses set in _ready().
var ult_cooldown: float = 30.0
## Seconds left until ready; 0 = ready.
var _cd_remaining: float = 0.0
var _player_ref: Node3D = null

func setup(player: Node, p_stats: StatBlock) -> void:
	# Deliberately do NOT call super(): that would start the auto-fire timer.
	_player_ref = player as Node3D
	stats = p_stats
	if _timer:
		_timer.stop()

func _process(delta: float) -> void:
	if _cd_remaining > 0.0:
		tick(delta)

## Advance the cooldown by dt. Public so tests drive it without the frame loop.
func tick(dt: float) -> void:
	_cd_remaining = max(0.0, _cd_remaining - dt)

func is_ready() -> bool:
	return _cd_remaining <= 0.0

## Fire the ultimate if ready. Returns true if it activated.
func activate() -> bool:
	if not is_ready():
		return false
	if is_inside_tree():
		GameEvents.skill_cast.emit(vfx_id, vfx_color, global_position)
	_do_ult()
	_cd_remaining = ult_cooldown
	return true

## Override per ultimate with the actual effect.
func _do_ult() -> void:
	pass

## HUD: 0.0 just fired … 1.0 ready.
func cooldown_fraction() -> float:
	if ult_cooldown <= 0.0:
		return 1.0
	return clampf(1.0 - _cd_remaining / ult_cooldown, 0.0, 1.0)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_ultimate_weapon_3d.gd -gexit` → PASS (5).

- [ ] **Step 5: Commit**

```bash
git add core/ultimate_weapon_3d.gd test/test_ultimate_weapon_3d.gd
git commit -m "feat: UltimateWeapon3D base — manual activate() + cooldown, no auto-fire

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 3: Player3D ult slot + SPACE routing + GameManager grants it

**Files:**
- Modify: `player/player_3d.gd` (ult slot + input + accessors)
- Modify: `game/game_manager_3d.gd` (`start()` grants the ult)
- Test: `test/test_player_ultimate.gd` (create)

**Interfaces:**
- Consumes: `UltimateWeapon3D` (Task 2), `CharacterData.ultimate` (foundation), input `&"ultimate"` (Task 1).
- Produces: `Player3D.grant_ultimate(scene: PackedScene)`, `Player3D.activate_ultimate() -> bool`, `Player3D.ultimate` (UltimateWeapon3D or null). `GameManager3D.start()` calls `grant_ultimate` when `char_data.ultimate` and its `weapon_scene` are set.

- [ ] **Step 1: Write the failing test**

Create `test/test_player_ultimate.gd`:

```gdscript
extends GutTest
## Player3D holds an ultimate in a dedicated slot and routes activation to it.

class _ProbeUlt extends UltimateWeapon3D:
	var fired := 0
	func _do_ult() -> void:
		fired += 1

func _player() -> Player3D:
	var p: Player3D = load("res://player/player_3d.tscn").instantiate()
	add_child_autofree(p)
	return p

func test_no_ult_by_default() -> void:
	var p := _player()
	assert_null(p.ultimate, "no ultimate until granted")
	assert_false(p.activate_ultimate(), "activate is a safe no-op with no ult")

func test_grant_and_activate() -> void:
	var p := _player()
	var scene := PackedScene.new()
	var probe := _ProbeUlt.new()
	probe.ult_cooldown = 5.0
	scene.pack(probe)
	p.grant_ultimate(scene)
	assert_not_null(p.ultimate, "ultimate granted")
	assert_true(p.activate_ultimate(), "activates when ready")
	assert_false(p.activate_ultimate(), "blocked on cooldown")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_player_ultimate.gd -gexit`
Expected: FAIL — `Nonexistent function 'grant_ultimate'`.

- [ ] **Step 3: Add the ult slot + input to `player/player_3d.gd`**

Add a field near the other weapon fields:

```gdscript
## Dedicated ultimate slot (manual, SPACE). Separate from the weapon pool.
var ultimate: UltimateWeapon3D = null
```

Add methods (place near `acquire_skill`):

```gdscript
## Instantiate and hold the character's ultimate. Manual mode (no auto-fire).
func grant_ultimate(scene: PackedScene) -> void:
	if scene == null:
		return
	var u := scene.instantiate()
	if not (u is UltimateWeapon3D):
		u.queue_free()
		return
	ultimate = u
	add_child(ultimate)               # add BEFORE setup (Weapon3D contract)
	ultimate.setup(self, stats)

## Fire the ultimate if present and ready. Returns true if it activated.
func activate_ultimate() -> bool:
	if ultimate == null:
		return false
	return ultimate.activate()
```

In `_physics_process` (or `_process`), add SPACE handling near the top (after the pause/early-out guards already present):

```gdscript
	if Input.is_action_just_pressed("ultimate"):
		activate_ultimate()
```

- [ ] **Step 4: Grant the ult in `game/game_manager_3d.gd` `start()`**

After the player setup and skill-system construction (after the `if/elif` skill block), add — independent of which weapon path ran:

```gdscript
	# Ultimate: dedicated manual slot, granted separately from the weapon pool.
	if _player and char_data and char_data.ultimate and char_data.ultimate.weapon_scene:
		_player.grant_ultimate(char_data.ultimate.weapon_scene)
```

- [ ] **Step 5: Run tests + full suite + boot**

Run: `godot --headless --import && godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_player_ultimate.gd -gexit` → PASS (2).
Run full suite + `--headless --quit` → green + clean boot (no character sets `ultimate` yet, so grant is dormant).

- [ ] **Step 6: Commit**

```bash
git add player/player_3d.gd game/game_manager_3d.gd test/test_player_ultimate.gd
git commit -m "feat: Player3D ultimate slot + SPACE activation; GameManager grants it

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 4: HUD cooldown indicators for ALL skills

**Files:**
- Modify: `ui/hud.gd` (+ `ui/hud.tscn` if a container node is needed)
- Test: `test/test_cooldown_hud.gd` (create)

**Interfaces:**
- Consumes: `Weapon3D.cooldown_fraction()`, `Player3D.weapons` (dict skill_id→Weapon3D) + `Player3D.ultimate`.
- Produces: `Hud.collect_cooldowns(player) -> Array` — pure; one entry per active skill `{ "id": StringName, "fraction": float, "is_ultimate": bool }`, ultimate last. The visual layout consumes this each frame.

- [ ] **Step 1: Write the failing test**

Create `test/test_cooldown_hud.gd`:

```gdscript
extends GutTest
## HUD gathers one cooldown entry per active skill (weapons + ultimate, ult last).

class _StubWeapon extends Node3D:
	var _f := 1.0
	func cooldown_fraction() -> float: return _f

class _StubUlt extends Node3D:
	var _f := 1.0
	func cooldown_fraction() -> float: return _f

class _StubPlayer extends Node3D:
	var weapons := {}
	var ultimate = null

func test_empty_player_has_no_entries() -> void:
	var hud = load("res://ui/hud.gd").new()
	assert_eq(hud.collect_cooldowns(_StubPlayer.new()).size(), 0)

func test_weapons_then_ultimate_last() -> void:
	var hud = load("res://ui/hud.gd").new()
	var p := _StubPlayer.new()
	var w := _StubWeapon.new(); w._f = 0.25
	p.weapons = { &"pew_pew": w }
	var u := _StubUlt.new(); u._f = 0.5
	p.ultimate = u
	var got: Array = hud.collect_cooldowns(p)
	assert_eq(got.size(), 2, "one per weapon + ult")
	assert_eq(got[0]["id"], &"pew_pew")
	assert_almost_eq(got[0]["fraction"], 0.25, 0.0001)
	assert_false(got[0]["is_ultimate"])
	assert_true(got[1]["is_ultimate"], "ultimate is last")
	assert_almost_eq(got[1]["fraction"], 0.5, 0.0001)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_cooldown_hud.gd -gexit`
Expected: FAIL — `Nonexistent function 'collect_cooldowns'`.

- [ ] **Step 3: Add `collect_cooldowns` + rendering to `ui/hud.gd`**

Add the pure collector (duck-typed so tests use stubs):

```gdscript
## Gather one cooldown entry per active skill: weapons first, ultimate last.
## Each: { "id": StringName, "fraction": float, "is_ultimate": bool }.
func collect_cooldowns(player) -> Array:
	var out: Array = []
	if player == null:
		return out
	var weapons = player.get("weapons")
	if weapons is Dictionary:
		for id in weapons:
			var w = weapons[id]
			if w and w.has_method("cooldown_fraction"):
				out.append({ "id": id, "fraction": w.cooldown_fraction(), "is_ultimate": false })
	var ult = player.get("ultimate")
	if ult and ult.has_method("cooldown_fraction"):
		out.append({ "id": &"ultimate", "fraction": ult.cooldown_fraction(), "is_ultimate": true })
	return out
```

Then render it: in `_process`, fetch the player (existing HUD already locates the player via the `player` group / duck-typing — reuse that), call `collect_cooldowns(player)`, and update a `HBoxContainer` of indicator nodes — one `TextureRect`/`Panel` per entry with a radial or bar overlay whose `value`/`material` reflects `fraction` (ult tinted distinctly, READY when fraction ≥ 1.0). Add the container to `ui/hud.tscn` if not present. (Visual layout is playtest-tunable; the test covers the data contract only.)

- [ ] **Step 4: Run tests + full suite + boot**

Run: `godot --headless --import && godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_cooldown_hud.gd -gexit` → PASS (2).
Run full suite + `--headless --quit` → green + clean boot.

- [ ] **Step 5: Commit**

```bash
git add ui/hud.gd ui/hud.tscn test/test_cooldown_hud.gd
git commit -m "feat: HUD cooldown indicators for all skills (weapons + ultimate)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

### Task 5: Reference ultimate — Avinoam "Judgment Day" (end-to-end)

Proves the whole chain: a real ult, wired to a character, fired by SPACE, shown on the HUD.

**Files:**
- Create: `weapons/ult_judgment_day_3d.gd` + `weapons/ult_judgment_day_3d.tscn`
- Create: `characters/ultimates/avinoam_judgment_day.tres` (SkillData; upgrade fields left null — ults are never offered/upgraded)
- Modify: `characters/avinoam_3d.tres` (set `ultimate`)
- Test: `test/test_ult_judgment_day.gd` (create)

**Interfaces:**
- Consumes: `UltimateWeapon3D` (Task 2). Mechanic: on activate, deal heavy AoE damage to all enemies within `radius` (holy strike), with a telegraph; `O` (offensive). Cooldown ~25s.

- [ ] **Step 1: Write the failing test**

Create `test/test_ult_judgment_day.gd`:

```gdscript
extends GutTest
## Judgment Day damages all enemies within radius on activate.

class _Enemy extends Node3D:
	var hp := 100.0
	var dead := false
	func _init() -> void:
		add_to_group("enemies")
	func take_damage(d: float) -> void:
		hp -= d
		if hp <= 0: dead = true

func test_activate_damages_enemies_in_radius() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_judgment_day_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)                 # manual mode
	var near := _Enemy.new(); add_child_autofree(near); near.global_position = Vector3(2, 0, 0)
	var far := _Enemy.new();  add_child_autofree(far);  far.global_position = Vector3(999, 0, 0)
	assert_true(ult.activate(), "fires when ready")
	assert_true(near.hp < 100.0, "nearby enemy took damage")
	assert_eq(far.hp, 100.0, "far enemy untouched")

func test_resource_wires_to_avinoam() -> void:
	var cd: CharacterData = load("res://characters/avinoam_3d.tres")
	assert_not_null(cd.ultimate, "Avinoam has an ultimate")
	assert_not_null(cd.ultimate.weapon_scene, "ultimate has a weapon_scene")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_ult_judgment_day.gd -gexit`
Expected: FAIL — script/resource missing.

- [ ] **Step 3: Create the ultimate weapon `weapons/ult_judgment_day_3d.gd`**

```gdscript
class_name UltJudgmentDay3D extends UltimateWeapon3D
## Avinoam's ultimate "Judgment Day": a holy strike that hits every enemy within
## `radius` for heavy damage. Offensive. (Stun/telegraph polish is playtest-tunable.)

var radius: float = 12.0
var damage: float = 120.0

func _ready() -> void:
	ult_cooldown = 25.0
	vfx_id = &"judgment_day"
	vfx_color = Color(1.0, 0.95, 0.5)   # holy gold
	super()

func _do_ult() -> void:
	if not is_inside_tree():
		return
	var origin := _player_ref.global_position if is_instance_valid(_player_ref) else global_position
	var dmg := damage * (stats.damage_mult if stats else 1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var e3d := e as Node3D
		if e3d and origin.distance_to(e3d.global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg)
				GameEvents.skill_hit.emit(vfx_id, vfx_color, e3d.global_position)
```

- [ ] **Step 4: Create the scene `weapons/ult_judgment_day_3d.tscn`**

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://weapons/ult_judgment_day_3d.gd" id="1_jd"]

[node name="UltJudgmentDay3D" type="Node3D"]
script = ExtResource("1_jd")
```

- [ ] **Step 5: Create the ult resource `characters/ultimates/avinoam_judgment_day.tres`**

```
[gd_resource type="Resource" script_class="SkillData" load_steps=3 format=3]

[ext_resource type="Script" uid="uid://d24b36hfii0n" path="res://core/skill_data.gd" id="1_skilldata"]
[ext_resource type="PackedScene" path="res://weapons/ult_judgment_day_3d.tscn" id="2_weapon"]

[resource]
script = ExtResource("1_skilldata")
id = &"avinoam_judgment_day"
display_name = "Judgment Day"
weapon_scene = ExtResource("2_weapon")
is_signature = false
type = &"holy"
description = "Avinoam's ultimate. A holy strike smites all nearby enemies."
```

(skill_upgrade/passive_upgrade/synergy_upgrade are intentionally omitted/null — ultimates are never offered or upgraded.)

- [ ] **Step 6: Wire Avinoam's `ultimate` in `characters/avinoam_3d.tres`**

Add an `ext_resource` for the ult and set the `ultimate` property on the `[resource]`. Add this line to the ext_resource block (use the next free id number for the file):

```
[ext_resource type="Resource" path="res://characters/ultimates/avinoam_judgment_day.tres" id="ult_jd"]
```

And in the `[resource]` body add:

```
ultimate = ExtResource("ult_jd")
```

(Leave `types` empty — that keeps Avinoam on the existing weapon path; only the ult is added.)

- [ ] **Step 7: Run tests + full suite + boot**

Run: `godot --headless --import && godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_ult_judgment_day.gd -gexit` → PASS (2).
Run full suite + `--headless --quit` → green + clean boot.

- [ ] **Step 8: Commit**

```bash
git add weapons/ult_judgment_day_3d.gd weapons/ult_judgment_day_3d.tscn characters/ultimates/avinoam_judgment_day.tres characters/avinoam_3d.tres test/test_ult_judgment_day.gd
git commit -m "feat: Avinoam ultimate 'Judgment Day' (reference ult, SPACE-activated)

Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>"
```

---

## Self-Review

- **Spec coverage:** §7a manual activation → Tasks 1–3; SPACE input → Task 1; non-upgradeable/separate slot → Task 3 (granted outside the pool) + Task 5 resource (null upgrades); all-skills cooldown HUD → Tasks 1+4; reference ult → Task 5. The other 9 ults + co-op `players` plumbing → roadmap (Phase 2). ✓
- **Placeholder scan:** HUD visual layout (Task 4 Step 3) is described, not coded, because it's playtest-tuned chrome; the tested contract (`collect_cooldowns`) is fully specified. No TODO/TBD in logic.
- **Type consistency:** `cooldown_fraction()` (0=fired,1=ready) consistent across Weapon3D, UltimateWeapon3D, and the HUD test. `activate()/is_ready()/tick()` consistent Tasks 2→3→5. `grant_ultimate`/`activate_ultimate`/`ultimate` consistent Tasks 3→4(test stub)→5.

## Phase 2 — the remaining 9 ultimates (roadmap, own plan)

Each = an `UltimateWeapon3D` subclass + scene + `characters/ultimates/<friend>_<ult>.tres` + wire onto the friend + a test, following Task 5's template. Cooldowns tunable.

| Friend | Ultimate | O/D | Mechanic | Build basis |
|---|---|---|---|---|
| Ziv | Main Character Moment | D | halt + charm all nearby for a few s | radius scan + enemy `charm()` (exists) |
| Avihay | Conference Call | D | self/team shield + knockback ring, summon temp helpers | custom + `players` group |
| Barak | Release the Hounds | O | summon a pack that chases & grinds | custom multi-summon |
| Ido | Biohazard | O | expanding poison nova + lingering DoT cloud | radius damage + ground hazard |
| Matan | Buzzkill | O | self-buff (dmg/speed/fire-rate) N s; teammates slowed/weakened | timed stat-mod + `players` group |
| Natali | Comic Relief | D | AoE stun/disarm + team heal | radius stun + `players` heal |
| Yinon | Carpet Bomb | O | screen-wide barrage over a few s | sequenced AoE strikes |
| Yoav | Express Delivery | O | repeated plow-through dashes in lines | mobility + line hits |
| Yuval | Bass Drop | O | massive shockwave, damage + knockback | radius damage + knockback |

**Co-op note:** the team-effect ults (Conference Call, Buzzkill, Comic Relief) query the `players` group; in solo the team portion no-ops (self-effects still apply), per spec §10.
