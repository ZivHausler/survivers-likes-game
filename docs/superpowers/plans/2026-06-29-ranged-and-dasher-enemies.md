# Ranged & Dasher Enemy Archetypes Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add ranged (projectile) and dasher (gap-close) enemy archetypes via a reusable, data-driven attack-behavior system, so enemies threaten the player beyond melee contact.

**Architecture:** `EnemyData` gains an `attack_kind` enum + per-archetype params. `Enemy3D` keeps its existing melee chase+contact as the inline default; for `RANGED`/`DASHER` it instantiates a small `EnemyAttack` strategy object (`RangedAttack` / `DashAttack`) and delegates `desired_velocity()` (movement shaping) and `attack_tick()` (fire / lunge). Ranged enemies fire `EnemyProjectile3D` (Area3D) that damages the player's hurtbox and is blocked by terrain (cover); they hold fire without line-of-sight. New variants enter the spawn pool through `DifficultyTimeline` time-gates.

**Tech Stack:** Godot 4.7, GDScript, GUT 9.7.0, Godot physics raycast (`PhysicsRayQueryParameters3D`), CC0 models (Quaternius/Kenney).

## Global Constraints

- Godot **4.7**, Forward+, GDScript only.
- GUT 9.7.0 **silently skips** any test file using `assert_le`/`assert_ge` — always `assert_true(x <= y)`. Confirm the suite total RISES by the new tests (a flat total = a silently-skipped file).
- Gameplay is on the **XZ plane** (Y up); world scale **1 unit ≈ 16 px**.
- **Physics layers:** player body 1, **player Hurtbox `Area3D` layer 2**, bubble 3, enemy 4 (`collision_layer=8`), **obstacles/walls/water layer 5 (value 16)**. `EnemyProjectile3D` masks **layer 2 (player hurtbox) + layer 16 (terrain)** only — value **18**; it must NOT mask 8 (enemies) or 1 (ground).
- **Back-compat:** `EnemyData.is_ranged == true` maps to `attack_kind == RANGED`. The existing **melee chase + `CONTACT_RANGE` contact-damage path in `Enemy3D` must stay behavior-identical** (it is heavily tested) — melee is the inline default; behaviors are added only for RANGED/DASHER.
- Every new `.gd` first line is `# See docs/notes/<id>.md`; add the note + update `docs/notes/INDEX.md`.
- Decoupled visuals: gameplay/tests never depend on VFX (the `Juice3D`/`SkillVFX` rule).
- All sourced assets **CC0**, recorded in `docs/notes/asset-licenses.md`.
- Run focused: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/<file> -gexit`. Full: `-gdir=res://test`. Binary: `/opt/homebrew/bin/godot`.
- Commit per task; messages end with the repo's `Co-Authored-By: Claude Opus 4.8 (1M context) <noreply@anthropic.com>` trailer.

---

## File Structure

- `enemies/enemy_data.gd` — **Modify:** add `AttackKind` enum + `attack_kind` + ranged/dash params.
- `enemies/attacks/enemy_attack.gd` — **Create:** `EnemyAttack` base (RefCounted) interface.
- `enemies/attacks/ranged_attack.gd` — **Create:** `RangedAttack` (kite + LOS + fire).
- `enemies/attacks/dash_attack.gd` — **Create:** `DashAttack` (approach → windup → dash → cooldown).
- `enemies/enemy_projectile_3d.gd` + `enemies/enemy_projectile_3d.tscn` — **Create:** enemy projectile.
- `enemies/enemy_3d.gd` — **Modify:** instantiate `_attack` in `setup()`; delegate velocity + attack for non-melee.
- `enemies/spitter.tres` — **Modify:** `attack_kind = RANGED`.
- `enemies/archer.tres`, `enemies/magician.tres`, `enemies/dasher.tres` — **Create.**
- `art/enemies_3d/archer/`, `art/enemies_3d/magician/` — **Create:** CC0 models (+ `.import`).
- `spawning/spawner_3d.gd` — **Modify:** add archer/magician/dasher to `_variants`.
- `spawning/difficulty_timeline.gd` — **Modify:** gate the new variants by time.
- `test/test_enemy_attack_data.gd`, `test/test_enemy_projectile_3d.gd`, `test/test_ranged_attack.gd`, `test/test_dash_attack.gd`, `test/test_enemy_attack_wiring.gd`, `test/test_enemy_variant_gating.gd` — **Create.**
- `docs/notes/enemy-attacks.md`, `docs/notes/enemy-projectile-3d.md` — **Create** (+ INDEX).

Order: 1 data → 2 projectile → 3 base+wiring → 4 ranged → 5 dasher → 6 assets+variants → 7 spawn gating + full verify.

---

### Task 1: `EnemyData` attack fields

**Files:**
- Modify: `enemies/enemy_data.gd`
- Test: `test/test_enemy_attack_data.gd`

**Interfaces:**
- Produces: `EnemyData.AttackKind { MELEE = 0, RANGED = 1, DASHER = 2 }`; `attack_kind: int`;
  ranged params `attack_range, attack_cooldown, windup_time, projectile_speed, projectile_damage`;
  dash params `dash_trigger_range, dash_windup, dash_speed, dash_duration, dash_cooldown`.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_enemy_attack_data.gd
extends GutTest
## EnemyData gains attack archetype + per-archetype tunables (defaults + enum).

func test_default_is_melee() -> void:
	var d := EnemyData.new()
	assert_eq(d.attack_kind, EnemyData.AttackKind.MELEE, "default attack_kind is MELEE")

func test_enum_values() -> void:
	assert_eq(int(EnemyData.AttackKind.MELEE), 0)
	assert_eq(int(EnemyData.AttackKind.RANGED), 1)
	assert_eq(int(EnemyData.AttackKind.DASHER), 2)

func test_ranged_and_dash_param_defaults_present() -> void:
	var d := EnemyData.new()
	assert_true(d.attack_range > 0.0, "attack_range default > 0")
	assert_true(d.attack_cooldown > 0.0, "attack_cooldown default > 0")
	assert_true(d.projectile_speed > 0.0, "projectile_speed default > 0")
	assert_true(d.dash_speed > 0.0, "dash_speed default > 0")
	assert_true(d.dash_duration > 0.0, "dash_duration default > 0")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_attack_data.gd -gexit`
Expected: FAIL — `AttackKind`/fields don't exist.

- [ ] **Step 3: Add the fields** (append to `enemies/enemy_data.gd`, after `is_ranged`)

```gdscript
## Attack archetype. MELEE = chase + contact (default, legacy behavior).
## RANGED = kite + fire EnemyProjectile3D. DASHER = hold, telegraph, lunge.
enum AttackKind { MELEE = 0, RANGED = 1, DASHER = 2 }
@export var attack_kind: int = AttackKind.MELEE

# ── RANGED params (used when attack_kind == RANGED) ──────────────────────────
@export var attack_range: float = 12.0       ## world units; kite to this distance and fire
@export var attack_cooldown: float = 2.0      ## seconds between shots
@export var windup_time: float = 0.4          ## telegraph before a shot launches
@export var projectile_speed: float = 16.0    ## world units / s
@export var projectile_damage: float = 6.0

# ── DASHER params (used when attack_kind == DASHER) ──────────────────────────
@export var dash_trigger_range: float = 14.0  ## start a dash when within this
@export var dash_windup: float = 0.5          ## telegraph before the lunge
@export var dash_speed: float = 30.0          ## lunge speed (world units / s)
@export var dash_duration: float = 0.35       ## seconds the lunge lasts
@export var dash_cooldown: float = 2.5        ## seconds between dashes
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_attack_data.gd -gexit`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add enemies/enemy_data.gd test/test_enemy_attack_data.gd
git commit -m "feat(enemy): add attack_kind + ranged/dash params to EnemyData"
```

---

### Task 2: `EnemyProjectile3D`

**Files:**
- Create: `enemies/enemy_projectile_3d.gd`, `enemies/enemy_projectile_3d.tscn`
- Create: `docs/notes/enemy-projectile-3d.md` (+ INDEX line)
- Test: `test/test_enemy_projectile_3d.gd`

**Interfaces:**
- Produces: `class_name EnemyProjectile3D extends Area3D` with
  `func setup(direction: Vector3, speed: float, damage: float) -> void` and a pure
  `func _advance(dt: float) -> void` (moves `global_position` along the unit XZ direction).
  Damages a body/area in group `player` via `take_damage(damage)` then frees; frees on any
  layer-16 body; ignores enemies. Used by Task 4.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_enemy_projectile_3d.gd
extends GutTest
var Scene: PackedScene = null

class PlayerStub extends Area3D:
	var taken := 0.0
	func _init() -> void: add_to_group("player")
	func take_damage(a: float) -> void: taken += a

func before_all() -> void:
	Scene = load("res://enemies/enemy_projectile_3d.tscn")

func test_scene_loads_and_is_area() -> void:
	var p: EnemyProjectile3D = Scene.instantiate()
	assert_true(p is Area3D, "projectile is an Area3D")
	# mask must include player-hurtbox (2) and terrain (16), exclude enemies (8)
	assert_true((p.collision_mask & 2) == 2, "masks player hurtbox layer 2")
	assert_true((p.collision_mask & 16) == 16, "masks terrain layer 16")
	assert_true((p.collision_mask & 8) == 0, "must NOT mask enemy layer 8")
	p.free()

func test_advance_moves_along_direction() -> void:
	var p: EnemyProjectile3D = add_child_autofree(Scene.instantiate())
	p.setup(Vector3(1, 0, 0), 10.0, 5.0)
	p.global_position = Vector3.ZERO
	p._advance(0.5)
	assert_almost_eq(p.global_position.x, 5.0, 0.001, "moved speed*dt along +X")
	assert_almost_eq(p.global_position.y, 0.0, 0.001, "stays on travel plane (no Y drift)")

func test_hits_player_and_frees() -> void:
	var p: EnemyProjectile3D = add_child_autofree(Scene.instantiate())
	p.setup(Vector3(1, 0, 0), 10.0, 7.0)
	var stub := PlayerStub.new()
	add_child_autofree(stub)
	p._on_area_entered(stub)
	assert_almost_eq(stub.taken, 7.0, 0.001, "player takes projectile_damage on hurtbox hit")
	assert_true(p.is_queued_for_deletion(), "projectile frees after hitting the player")
```

- [ ] **Step 2: Run to verify it fails**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_projectile_3d.gd -gexit`
Expected: FAIL — scene/script missing.

- [ ] **Step 3: Create the script**

```gdscript
# enemies/enemy_projectile_3d.gd
# See docs/notes/enemy-projectile-3d.md
class_name EnemyProjectile3D extends Area3D
## A travelling enemy attack. Moves along a fixed XZ direction, damages the player
## (group "player") on contact with their hurtbox, and is destroyed by terrain
## (layer 16) so trees/rocks/walls act as cover. Never hits other enemies (mask
## excludes layer 8). Despawns after MAX_LIFETIME so strays don't accumulate.

const MAX_LIFETIME := 6.0

var _direction: Vector3 = Vector3.ZERO
var _speed: float = 0.0
var _damage: float = 0.0
var _age: float = 0.0

func setup(direction: Vector3, speed: float, damage: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z)
	_direction = flat.normalized() if flat.length() > 0.001 else Vector3.FORWARD
	_speed = speed
	_damage = damage

func _ready() -> void:
	area_entered.connect(_on_area_entered)
	body_entered.connect(_on_body_entered)

func _physics_process(dt: float) -> void:
	_age += dt
	if _age >= MAX_LIFETIME:
		queue_free()
		return
	_advance(dt)

## Pure travel step (testable without signals).
func _advance(dt: float) -> void:
	global_position += _direction * _speed * dt

## Player hurtbox (Area3D, layer 2) → damage + despawn.
func _on_area_entered(area: Area3D) -> void:
	var owner_node := area.get_parent()
	if area.is_in_group("player") and area.has_method("take_damage"):
		area.take_damage(_damage)
		queue_free()
	elif owner_node and owner_node.is_in_group("player") and owner_node.has_method("take_damage"):
		owner_node.take_damage(_damage)
		queue_free()

## Terrain (StaticBody3D, layer 16) → despawn (cover). Player body also possible.
func _on_body_entered(body: Node3D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(_damage)
	queue_free()
```

- [ ] **Step 4: Create the scene** `enemies/enemy_projectile_3d.tscn`

```
[gd_scene load_steps=3 format=3 uid="uid://b0enmproj3d01"]

[ext_resource type="Script" path="res://enemies/enemy_projectile_3d.gd" id="1_proj"]

[sub_resource type="SphereShape3D" id="SphereShape3D_proj"]
radius = 0.4

[node name="EnemyProjectile3D" type="Area3D"]
collision_layer = 0
collision_mask = 18
monitoring = true
script = ExtResource("1_proj")

[node name="CollisionShape3D" type="CollisionShape3D" parent="."]
shape = SubResource("SphereShape3D_proj")

[node name="MeshInstance3D" type="MeshInstance3D" parent="."]
```

(`collision_mask = 18` = layer 2 + layer 16. A mesh is added so the projectile is visible; its
`mesh` is assigned/tinted at runtime or left to a later VFX pass — gameplay does not depend on it.)

- [ ] **Step 5: Docs note + INDEX**

Create `docs/notes/enemy-projectile-3d.md` (purpose, layers, cover behavior); add INDEX line.

- [ ] **Step 6: Run to verify it passes**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_projectile_3d.gd -gexit`
Expected: PASS (3 tests).

- [ ] **Step 7: Commit**

```bash
git add enemies/enemy_projectile_3d.gd enemies/enemy_projectile_3d.tscn test/test_enemy_projectile_3d.gd docs/notes/
git commit -m "feat(enemy): add EnemyProjectile3D (player-seeking, terrain-blocked)"
```

---

### Task 3: `EnemyAttack` base + `Enemy3D` delegation (melee unchanged)

**Files:**
- Create: `enemies/attacks/enemy_attack.gd`
- Modify: `enemies/enemy_3d.gd`
- Create: `docs/notes/enemy-attacks.md` (+ INDEX)
- Test: `test/test_enemy_attack_wiring.gd` (+ run existing enemy suites)

**Interfaces:**
- Produces: `class_name EnemyAttack extends RefCounted` with
  `func desired_velocity(enemy: Enemy3D, target: Node3D, dt: float) -> Vector3` and
  `func attack_tick(enemy: Enemy3D, target: Node3D, dt: float) -> void` (both no-ops in base);
  `Enemy3D._attack: EnemyAttack` (null for MELEE), set in `setup()` via `_make_attack()`.
- Consumes: `EnemyData.AttackKind` (Task 1).

- [ ] **Step 1: Create the base class** `enemies/attacks/enemy_attack.gd`

```gdscript
# See docs/notes/enemy-attacks.md
class_name EnemyAttack extends RefCounted
## Strategy object for non-melee enemy archetypes. Enemy3D delegates per-frame
## movement shaping (desired_velocity) and the attack action (attack_tick) to one
## of these. MELEE enemies use Enemy3D's inline default and have NO attack object.

## Returns this frame's desired XZ velocity (Y = 0). Base = stand still.
func desired_velocity(_enemy: Enemy3D, _target: Node3D, _dt: float) -> Vector3:
	return Vector3.ZERO

## Performs the archetype's attack for this frame (fire / lunge-hit). Base = nothing.
func attack_tick(_enemy: Enemy3D, _target: Node3D, _dt: float) -> void:
	pass
```

- [ ] **Step 2: Write the failing wiring test**

```gdscript
# test/test_enemy_attack_wiring.gd
extends GutTest
var Scene: PackedScene = null
class StubTarget extends Node3D:
	pass

func before_all() -> void:
	Scene = load("res://enemies/enemy_3d.tscn")

func _enemy_with(kind: int, is_ranged: bool = false) -> Enemy3D:
	var e: Enemy3D = add_child_autofree(Scene.instantiate())
	var d := EnemyData.new()
	d.max_hp = 10.0; d.move_speed = 5.0; d.contact_damage = 4.0
	d.attack_kind = kind; d.is_ranged = is_ranged
	var tgt: StubTarget = add_child_autofree(StubTarget.new())
	tgt.global_position = Vector3(10, 0, 0)
	e.setup(d, tgt)
	return e

func test_melee_has_no_attack_object() -> void:
	var e := _enemy_with(EnemyData.AttackKind.MELEE)
	assert_null(e._attack, "MELEE uses inline default — no strategy object")

func test_ranged_kind_gets_ranged_attack() -> void:
	var e := _enemy_with(EnemyData.AttackKind.RANGED)
	assert_true(e._attack is RangedAttack, "RANGED kind → RangedAttack")

func test_dasher_kind_gets_dash_attack() -> void:
	var e := _enemy_with(EnemyData.AttackKind.DASHER)
	assert_true(e._attack is DashAttack, "DASHER kind → DashAttack")

func test_is_ranged_backcompat_maps_to_ranged() -> void:
	var e := _enemy_with(EnemyData.AttackKind.MELEE, true)
	assert_true(e._attack is RangedAttack, "legacy is_ranged=true → RangedAttack")
```

(This test references `RangedAttack`/`DashAttack` created in Tasks 4–5. Run it at the END of
Task 5; for Task 3 alone, comment out the ranged/dasher/backcompat cases or expect them red
until those classes exist. The MELEE case must pass now.)

- [ ] **Step 3: Wire `Enemy3D`** — add the field + factory, delegate for non-melee only.

Add near the top vars:

```gdscript
## Non-melee attack strategy (RangedAttack / DashAttack); null for MELEE (inline default).
var _attack: EnemyAttack = null
```

In `setup()`, AFTER `hp = data.max_hp` (and the existing `_agent.max_speed` line), add:

```gdscript
	_attack = _make_attack(data)
```

Add the factory:

```gdscript
## Pick the attack strategy for this enemy's data. MELEE → null (inline default).
## Legacy is_ranged=true is treated as RANGED for back-compat.
func _make_attack(d: EnemyData) -> EnemyAttack:
	var kind: int = d.attack_kind
	if kind == EnemyData.AttackKind.MELEE and d.is_ranged:
		kind = EnemyData.AttackKind.RANGED
	match kind:
		EnemyData.AttackKind.RANGED:
			return RangedAttack.new()
		EnemyData.AttackKind.DASHER:
			return DashAttack.new()
		_:
			return null
```

In `_physics_process`, replace the velocity line and the contact block with delegation that
**leaves the melee path identical**. Replace lines (the `var desired := ...` through the
contact-damage block) with:

```gdscript
	var to_target := target.global_position - global_position
	to_target.y = 0.0  # Move only on XZ plane.
	var dist := to_target.length()
	if _attack:
		velocity = _attack.desired_velocity(self, target, dt)
	else:
		var desired := 0.0 if (data.is_ranged and dist < RANGED_STANDOFF) else data.move_speed
		velocity = steer_velocity(global_position, target.global_position, desired)
	_apply_movement(dt)
	var moving: bool = velocity.length_squared() > MOVE_THRESHOLD * MOVE_THRESHOLD
	if _model and moving:
		_model.rotation.y = face_angle(velocity)
		_play_anim("move")
	else:
		_play_anim("idle")
	_apply_bob(dt, velocity)
	if _attack:
		_attack.attack_tick(self, target, dt)
	else:
		# Melee contact damage with 0.5 s cooldown (unchanged).
		_contact_cd = max(0.0, _contact_cd - dt)
		if dist < CONTACT_RANGE and _contact_cd == 0.0 and is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(data.contact_damage)
			_contact_cd = 0.5
```

(The default-MELEE branch is byte-identical logic to before — `data.is_ranged` defaults false so
existing melee `.tres` are unaffected; only the new `_attack` path is added.)

- [ ] **Step 4: Run the MELEE wiring case + the FULL existing enemy regression**

Run (after creating the base class; before Tasks 4–5 keep only `test_melee_has_no_attack_object`):
`godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_attack_wiring.gd -gtest=res://test/test_enemy_3d.gd -gtest=res://test/test_enemy_3d_bugfix.gd -gtest=res://test/test_enemy_3d_avoidance.gd -gexit`
Expected: existing enemy tests **all still pass** (melee chase + contact + avoidance unchanged); MELEE wiring passes.

- [ ] **Step 5: Docs note + INDEX; commit**

Create `docs/notes/enemy-attacks.md` (strategy pattern, melee-inline rationale, the contract).

```bash
git add enemies/attacks/enemy_attack.gd enemies/enemy_3d.gd test/test_enemy_attack_wiring.gd docs/notes/
git commit -m "feat(enemy): attack-strategy delegation in Enemy3D (melee path unchanged)"
```

---

### Task 4: `RangedAttack` (kite + LOS + fire) + upgrade spitter

**Files:**
- Create: `enemies/attacks/ranged_attack.gd`
- Modify: `enemies/spitter.tres` (`attack_kind = 1`)
- Test: `test/test_ranged_attack.gd`

**Interfaces:**
- Consumes: `EnemyAttack` (Task 3), `EnemyProjectile3D` (Task 2), `EnemyData` ranged params (Task 1).
- Produces: `class_name RangedAttack extends EnemyAttack`. Kites to `attack_range`; fires when
  `_should_fire(dist, los_clear)` and a windup completes. Pure helper
  `static func kite_velocity(from: Vector3, to: Vector3, attack_range: float, speed: float) -> Vector3`.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_ranged_attack.gd
extends GutTest

func test_kite_advances_when_far() -> void:
	# enemy far beyond attack_range → move toward target
	var v := RangedAttack.kite_velocity(Vector3.ZERO, Vector3(30, 0, 0), 12.0, 5.0)
	assert_true(v.x > 0.0, "far enemy moves toward target (+X)")

func test_kite_backs_off_when_too_close() -> void:
	# enemy well inside attack_range → retreat (away from target)
	var v := RangedAttack.kite_velocity(Vector3(2, 0, 0), Vector3(0, 0, 0), 12.0, 5.0)
	assert_true(v.x > 0.0, "too-close enemy retreats away from target (+X, away from origin)")

func test_kite_holds_in_band() -> void:
	# at roughly attack_range → ~hold (near-zero speed)
	var v := RangedAttack.kite_velocity(Vector3(12, 0, 0), Vector3(0, 0, 0), 12.0, 5.0)
	assert_true(v.length() <= 1.0, "enemy holds position within the standoff band")

func test_should_fire_requires_range_los_and_cooldown() -> void:
	var ra := RangedAttack.new()
	# in range + LOS clear + cooldown ready → can fire
	assert_true(ra._can_fire(10.0, true, 12.0), "fires when in range, LOS clear, cd ready")
	# out of range
	assert_false(ra._can_fire(40.0, true, 12.0), "no fire out of attack_range")
	# blocked LOS
	assert_false(ra._can_fire(10.0, false, 12.0), "no fire when LOS blocked (terrain cover)")

func test_cooldown_blocks_refire() -> void:
	var ra := RangedAttack.new()
	ra._cooldown_left = 1.0
	assert_false(ra._ready_to_fire(), "cooldown blocks immediate refire")
	ra._cooldown_left = 0.0
	assert_true(ra._ready_to_fire(), "fires once cooldown elapsed")
```

- [ ] **Step 2: Run to verify it fails**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_ranged_attack.gd -gexit`
Expected: FAIL — `RangedAttack` missing.

- [ ] **Step 3: Implement `RangedAttack`**

```gdscript
# See docs/notes/enemy-attacks.md
class_name RangedAttack extends EnemyAttack
## Kites to EnemyData.attack_range and fires EnemyProjectile3D at the player when it has
## line of sight (terrain on layer 16 blocks the ray → hold fire). Telegraphs each shot
## with a windup. Holds a hysteresis band around attack_range so it doesn't jitter.

const PROJECTILE := preload("res://enemies/enemy_projectile_3d.tscn")
const BAND := 2.0  ## +/- world units of "hold" tolerance around attack_range

var _cooldown_left: float = 0.0
var _windup_left: float = -1.0  ## >=0 means a shot is winding up

## Pure kite velocity: approach if beyond range+band, retreat if inside range-band, else hold.
static func kite_velocity(from: Vector3, to: Vector3, attack_range: float, speed: float) -> Vector3:
	var delta := to - from
	delta.y = 0.0
	var dist := delta.length()
	if dist < 0.001:
		return Vector3.ZERO
	var dir := delta.normalized()
	if dist > attack_range + BAND:
		return dir * speed            # approach
	if dist < attack_range - BAND:
		return -dir * speed           # retreat (kite)
	return Vector3.ZERO               # hold in band

func _ready_to_fire() -> bool:
	return _cooldown_left <= 0.0

## Pure firing gate: in range, line of sight clear, and off cooldown.
func _can_fire(dist: float, los_clear: bool, attack_range: float) -> bool:
	return dist <= attack_range and los_clear and _ready_to_fire()

func desired_velocity(enemy: Enemy3D, target: Node3D, _dt: float) -> Vector3:
	return kite_velocity(enemy.global_position, target.global_position,
			enemy.data.attack_range, enemy.data.move_speed)

func attack_tick(enemy: Enemy3D, target: Node3D, dt: float) -> void:
	_cooldown_left = max(0.0, _cooldown_left - dt)
	# Resolve an in-progress windup → launch.
	if _windup_left >= 0.0:
		_windup_left -= dt
		if _windup_left <= 0.0:
			_windup_left = -1.0
			_launch(enemy, target)
		return
	var to_t := target.global_position - enemy.global_position
	to_t.y = 0.0
	var dist := to_t.length()
	var los_clear := not _los_blocked(enemy, target)
	if _can_fire(dist, los_clear, enemy.data.attack_range):
		_windup_left = enemy.data.windup_time   # telegraph, then _launch
		GameEvents.skill_cast.emit(enemy.global_position, &"enemy_ranged_windup")

## Raycast enemy→player against terrain layer 16. True if a wall/obstacle blocks the shot.
func _los_blocked(enemy: Enemy3D, target: Node3D) -> bool:
	var world := enemy.get_world_3d()
	if world == null:
		return false
	var from := enemy.global_position + Vector3(0, 1, 0)
	var to := target.global_position + Vector3(0, 1, 0)
	var q := PhysicsRayQueryParameters3D.create(from, to, 16)  # mask = layer 16 (terrain)
	var hit := world.direct_space_state.intersect_ray(q)
	return not hit.is_empty()

func _launch(enemy: Enemy3D, target: Node3D) -> void:
	if not is_instance_valid(target):
		return
	var dir := target.global_position - enemy.global_position
	var proj: EnemyProjectile3D = PROJECTILE.instantiate()
	proj.setup(dir, enemy.data.projectile_speed, enemy.data.projectile_damage)
	var spawn_parent := enemy.get_parent()
	if spawn_parent == null:
		proj.free()
		return
	proj.global_position = enemy.global_position + Vector3(0, 1, 0)
	spawn_parent.add_child.call_deferred(proj)
	# Re-arm cooldown after the shot actually goes out.
	_cooldown_left = enemy.data.attack_cooldown
	GameEvents.skill_hit.emit(enemy.global_position, &"enemy_ranged_fire")
```

(If `GameEvents.skill_cast`/`skill_hit` signatures differ, match the existing emit signature used
by player weapons — check `core/weapon_3d.gd`; these emits are decoupled VFX only and never affect
gameplay/tests. If unsure, drop the two emit lines — they are optional polish.)

- [ ] **Step 4: Upgrade the spitter** — in `enemies/spitter.tres`, add `attack_kind = 1` (RANGED).
  Set sensible ranged values (low damage starter): `attack_range = 12.0`, `attack_cooldown = 2.5`,
  `projectile_damage = 5.0`, `projectile_speed = 14.0`, `windup_time = 0.5`. (Add these as `.tres`
  properties on the EnemyData resource.)

- [ ] **Step 5: Run to verify it passes**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_ranged_attack.gd -gexit`
Expected: PASS (5 tests).

- [ ] **Step 6: Commit**

```bash
git add enemies/attacks/ranged_attack.gd enemies/spitter.tres test/test_ranged_attack.gd
git commit -m "feat(enemy): RangedAttack — kite, line-of-sight, fire projectile; spitter ranged"
```

---

### Task 5: `DashAttack` (approach → windup → dash → cooldown)

**Files:**
- Create: `enemies/attacks/dash_attack.gd`
- Test: `test/test_dash_attack.gd`

**Interfaces:**
- Consumes: `EnemyAttack` (Task 3), `EnemyData` dash params (Task 1).
- Produces: `class_name DashAttack extends EnemyAttack` with a phase enum
  `Phase { APPROACH, WINDUP, DASH, COOLDOWN }`, an exposed `_phase`, and a pure
  `static func dash_velocity(from: Vector3, locked_target: Vector3, speed: float) -> Vector3`.

- [ ] **Step 1: Write the failing test**

```gdscript
# test/test_dash_attack.gd
extends GutTest
class StubEnemy extends Node3D:
	var data: EnemyData
class StubTarget extends Node3D:
	pass

func _setup() -> Array:
	var e := StubEnemy.new()
	var d := EnemyData.new()
	d.move_speed = 5.0; d.dash_trigger_range = 14.0; d.dash_windup = 0.5
	d.dash_speed = 30.0; d.dash_duration = 0.35; d.dash_cooldown = 2.5; d.contact_damage = 6.0
	e.data = d
	var t := StubTarget.new()
	return [e, t, d]

func test_starts_in_approach() -> void:
	var da := DashAttack.new()
	assert_eq(da._phase, DashAttack.Phase.APPROACH, "begins approaching")

func test_enters_windup_when_in_trigger_range() -> void:
	var arr := _setup()
	var e: StubEnemy = arr[0]; var t: StubTarget = arr[1]
	e.global_position = Vector3.ZERO
	t.global_position = Vector3(10, 0, 0)  # within dash_trigger_range 14
	var da := DashAttack.new()
	da.attack_tick(e, t, 0.016)
	assert_eq(da._phase, DashAttack.Phase.WINDUP, "in range → windup")

func test_windup_then_dash_then_cooldown() -> void:
	var arr := _setup()
	var e: StubEnemy = arr[0]; var t: StubTarget = arr[1]
	e.global_position = Vector3.ZERO; t.global_position = Vector3(10, 0, 0)
	var da := DashAttack.new()
	da.attack_tick(e, t, 0.016)          # → WINDUP
	da.attack_tick(e, t, 1.0)            # windup (0.5) elapses → DASH
	assert_eq(da._phase, DashAttack.Phase.DASH, "after windup → dash")
	da.attack_tick(e, t, 1.0)            # dash (0.35) elapses → COOLDOWN
	assert_eq(da._phase, DashAttack.Phase.COOLDOWN, "after dash → cooldown")

func test_dash_velocity_points_at_locked_target() -> void:
	var v := DashAttack.dash_velocity(Vector3.ZERO, Vector3(0, 0, 8), 30.0)
	assert_almost_eq(v.z, 30.0, 0.001, "dash moves at dash_speed toward locked target (+Z)")
	assert_almost_eq(v.x, 0.0, 0.001)
```

- [ ] **Step 2: Run to verify it fails**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_dash_attack.gd -gexit`
Expected: FAIL — `DashAttack` missing.

- [ ] **Step 3: Implement `DashAttack`**

```gdscript
# See docs/notes/enemy-attacks.md
class_name DashAttack extends EnemyAttack
## Gap-closer. Approaches at move_speed until within dash_trigger_range, telegraphs
## (dash_windup), locks the player's position, then lunges at dash_speed for
## dash_duration (contact deals contact_damage), then waits dash_cooldown. desired_velocity
## reflects the phase so movement and attack stay in sync.

enum Phase { APPROACH, WINDUP, DASH, COOLDOWN }
var _phase: int = Phase.APPROACH
var _timer: float = 0.0
var _locked: Vector3 = Vector3.ZERO   ## player position captured at dash start
var _hit_this_dash: bool = false

## Pure: dash velocity from `from` toward the locked target at `speed` (Y flattened).
static func dash_velocity(from: Vector3, locked_target: Vector3, speed: float) -> Vector3:
	var d := locked_target - from
	d.y = 0.0
	if d.length() < 0.001:
		return Vector3.ZERO
	return d.normalized() * speed

func desired_velocity(enemy: Enemy3D, target: Node3D, _dt: float) -> Vector3:
	var d := enemy.data
	match _phase:
		Phase.APPROACH:
			var to := target.global_position - enemy.global_position
			to.y = 0.0
			return to.normalized() * d.move_speed if to.length() > 0.001 else Vector3.ZERO
		Phase.WINDUP, Phase.COOLDOWN:
			return Vector3.ZERO           # brace / recover (telegraph)
		Phase.DASH:
			return dash_velocity(enemy.global_position, _locked, d.dash_speed)
	return Vector3.ZERO

func attack_tick(enemy: Enemy3D, target: Node3D, dt: float) -> void:
	var d := enemy.data
	match _phase:
		Phase.APPROACH:
			var dist := (target.global_position - enemy.global_position).length()
			if dist <= d.dash_trigger_range:
				_phase = Phase.WINDUP
				_timer = d.dash_windup
				GameEvents.skill_cast.emit(enemy.global_position, &"enemy_dash_windup")
		Phase.WINDUP:
			_timer -= dt
			if _timer <= 0.0:
				_phase = Phase.DASH
				_timer = d.dash_duration
				_locked = target.global_position   # commit to a fixed lunge point
				_hit_this_dash = false
		Phase.DASH:
			_timer -= dt
			if not _hit_this_dash:
				var dist := (target.global_position - enemy.global_position).length()
				if dist < enemy.CONTACT_RANGE and target.has_method("take_damage"):
					target.take_damage(d.contact_damage)
					_hit_this_dash = true
			if _timer <= 0.0:
				_phase = Phase.COOLDOWN
				_timer = d.dash_cooldown
		Phase.COOLDOWN:
			_timer -= dt
			if _timer <= 0.0:
				_phase = Phase.APPROACH
```

- [ ] **Step 4: Run to verify it passes**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_dash_attack.gd -gexit`
Expected: PASS (4 tests).

- [ ] **Step 5: Run the full wiring test (now all classes exist)**

Uncomment the ranged/dasher/backcompat cases in `test/test_enemy_attack_wiring.gd` (Task 3),
then run:
`godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_attack_wiring.gd -gexit`
Expected: PASS (4 tests — melee null, ranged, dasher, is_ranged back-compat).

- [ ] **Step 6: Commit**

```bash
git add enemies/attacks/dash_attack.gd test/test_dash_attack.gd test/test_enemy_attack_wiring.gd
git commit -m "feat(enemy): DashAttack gap-closer (approach/windup/dash/cooldown)"
```

---

### Task 6: Source models + author archer/magician/dasher variants

**Files:**
- Create: `art/enemies_3d/archer/`, `art/enemies_3d/magician/` (CC0 models + `.import`)
- Create: `enemies/archer.tres`, `enemies/magician.tres`, `enemies/dasher.tres`
- Modify: `docs/notes/asset-licenses.md`
- Test: `test/test_enemy_attack_data.gd` (append variant-loads-correctly checks)

**Interfaces:**
- Consumes: `EnemyData` fields (Task 1).
- Produces: three loadable `EnemyData` `.tres` with correct `attack_kind` + model.

- [ ] **Step 1: Source CC0 models** (archer + magician). Try Quaternius RPG/fantasy character
  packs (CC0 glTF — e.g. a mage and a skeleton/archer) or Kenney. Download under
  `art/enemies_3d/archer/` and `.../magician/`, run `--headless --import`, and confirm each loads
  as a `PackedScene` (root Node3D), as in the trees task. **Fallback (pre-approved):** if no
  suitable CC0 humanoid is found, reuse an existing monster model (e.g. plant/bug) with a distinct
  `color` tint, and note it in `docs/notes/asset-licenses.md`. The `dasher` reuses the existing
  `swarmer` (bug) model with a distinct tint — no new asset needed.

- [ ] **Step 2: Author the `.tres`** (mirror `spitter.tres` structure; set fields):
  - `enemies/archer.tres`: `id=&"archer"`, `attack_kind=1` (RANGED), `max_hp≈16`, `move_speed≈70`,
    `attack_range≈14`, `attack_cooldown≈2.0`, `projectile_speed≈18`, `projectile_damage≈7`,
    `windup_time≈0.4`, `model_scene=` archer GLB.
  - `enemies/magician.tres`: `id=&"magician"`, `attack_kind=1`, `max_hp≈22`, `move_speed≈55`,
    `attack_range≈18`, `attack_cooldown≈3.0`, `projectile_speed≈12`, `projectile_damage≈12`,
    `windup_time≈0.6`, `model_scene=` magician GLB.
  - `enemies/dasher.tres`: `id=&"dasher"`, `attack_kind=2` (DASHER), `max_hp≈14`, `move_speed≈60`,
    `dash_trigger_range≈16`, `dash_windup≈0.5`, `dash_speed≈34`, `dash_duration≈0.35`,
    `dash_cooldown≈2.5`, `contact_damage≈10`, `model_scene=` existing swarmer GLB, distinct `color`.

- [ ] **Step 3: Append load tests** to `test/test_enemy_attack_data.gd`:

```gdscript
func test_variants_load_with_expected_kind() -> void:
	var archer := load("res://enemies/archer.tres") as EnemyData
	var mage := load("res://enemies/magician.tres") as EnemyData
	var dasher := load("res://enemies/dasher.tres") as EnemyData
	assert_eq(archer.attack_kind, EnemyData.AttackKind.RANGED, "archer is RANGED")
	assert_eq(mage.attack_kind, EnemyData.AttackKind.RANGED, "magician is RANGED")
	assert_eq(dasher.attack_kind, EnemyData.AttackKind.DASHER, "dasher is DASHER")
	assert_not_null(archer.model_scene, "archer has a model")
```

- [ ] **Step 4: Run import + test**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_attack_data.gd -gexit`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add art/enemies_3d/archer art/enemies_3d/magician enemies/archer.tres enemies/magician.tres enemies/dasher.tres test/test_enemy_attack_data.gd docs/notes/asset-licenses.md
git commit -m "feat(enemy): add archer/magician (ranged) + dasher variants + CC0 models"
```

---

### Task 7: Spawn integration + difficulty gating + full verification

**Files:**
- Modify: `spawning/spawner_3d.gd` (add variants to `_variants`)
- Modify: `spawning/difficulty_timeline.gd` (`state_at` gating + thresholds)
- Modify: `HANDOFF.md`
- Test: `test/test_enemy_variant_gating.gd` (+ full suite)

**Interfaces:**
- Consumes: the three `.tres` (Task 6), `DifficultyTimeline.state_at` (existing).
- Produces: archer/magician/dasher appearing in `allowed_variants` at their thresholds.

- [ ] **Step 1: Write the failing gating test**

```gdscript
# test/test_enemy_variant_gating.gd
extends GutTest
func _allowed(t: float) -> Array:
	return DifficultyTimeline.new().state_at(t).allowed_variants

func test_archer_gated_at_150() -> void:
	assert_false(&"archer" in _allowed(149.0), "no archer before 150s")
	assert_true(&"archer" in _allowed(150.0), "archer from 150s")

func test_dasher_gated_at_180() -> void:
	assert_false(&"dasher" in _allowed(179.0), "no dasher before 180s")
	assert_true(&"dasher" in _allowed(180.0), "dasher from 180s")

func test_magician_gated_at_240() -> void:
	assert_false(&"magician" in _allowed(239.0), "no magician before 240s")
	assert_true(&"magician" in _allowed(240.0), "magician from 240s")

func test_early_game_still_just_swarmer() -> void:
	assert_eq(_allowed(10.0), [&"swarmer"], "early game unchanged")
```

- [ ] **Step 2: Run to verify it fails**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_variant_gating.gd -gexit`
Expected: FAIL — new variants not gated yet.

- [ ] **Step 3: Add thresholds + gating** — in `spawning/difficulty_timeline.gd`, add constants
  near the existing thresholds:

```gdscript
const ARCHER_THRESHOLD:   float = 150.0
const DASHER_THRESHOLD:   float = 180.0
const MAGICIAN_THRESHOLD: float = 240.0
```

In `state_at()`, after the existing `if t >= SPITTER_THRESHOLD: variants.append(&"spitter")`:

```gdscript
	if t >= ARCHER_THRESHOLD:
		variants.append(&"archer")
	if t >= DASHER_THRESHOLD:
		variants.append(&"dasher")
	if t >= MAGICIAN_THRESHOLD:
		variants.append(&"magician")
```

- [ ] **Step 4: Register variants in the spawner** — in `spawning/spawner_3d.gd`, add path consts
  and `_variants` entries:

```gdscript
const ARCHER_PATH   := "res://enemies/archer.tres"
const MAGICIAN_PATH := "res://enemies/magician.tres"
const DASHER_PATH   := "res://enemies/dasher.tres"
```

In `setup()` `_variants`:

```gdscript
		&"archer":   load(ARCHER_PATH)   as EnemyData,
		&"magician": load(MAGICIAN_PATH) as EnemyData,
		&"dasher":   load(DASHER_PATH)   as EnemyData,
```

- [ ] **Step 5: Run the gating test + FULL suite**

Run: `godot --headless --import && godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_variant_gating.gd -gexit`
Then: `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: gating PASS; full suite all green; total RISES by the new tests (no silent skips).

- [ ] **Step 6: Update HANDOFF + commit**

Update `HANDOFF.md` (new ranged/dasher archetypes; attack-strategy system; spawn thresholds).

```bash
git add spawning/spawner_3d.gd spawning/difficulty_timeline.gd test/test_enemy_variant_gating.gd HANDOFF.md
git commit -m "feat(enemy): spawn archer/magician/dasher with difficulty gating"
```

- [ ] **Step 7: Manual playtest (user-run — visuals/feel)**

Run `godot --path ~/friends-swarm`, play past 150s: confirm archers/magicians keep distance and
fire dodgeable projectiles, projectiles are blocked by trees/rocks/walls (cover works), dashers
telegraph then lunge, and melee enemies behave as before. Tune ranges/cooldowns/damage and the
spawn thresholds to taste.

---

## Self-Review

**Spec coverage:** attack_kind enum + params → Task 1. EnemyProjectile3D (player hurtbox + terrain-blocked, ignores enemies) → Task 2. Strategy delegation, melee unchanged, is_ranged back-compat → Task 3. RangedAttack kite + LOS/cover + telegraph + fire, spitter upgraded → Task 4. DashAttack approach/windup/dash/cooldown + telegraph → Task 5. New CC0 archer/magician models + dasher (reuse) + variants → Task 6. Spawn pool + difficulty gating → Task 7. Fairness telegraphs → Tasks 4–5 (windup before any damage). Testing across all tasks; full-suite gate in Task 7. Decoupled VFX via optional GameEvents emits (Tasks 4–5). All spec sections map to a task.

**Placeholder scan:** No "TBD"/"add error handling"/"write tests for the above". Asset sourcing (Task 6) is a real procedure with a pre-approved fallback. The GameEvents emit lines are explicitly marked optional with a verify-signature note (not a behavioral dependency).

**Type consistency:** `EnemyData.AttackKind.{MELEE,RANGED,DASHER}` used identically across Tasks 1/3/6/7. `EnemyAttack.desired_velocity(enemy, target, dt)` / `attack_tick(enemy, target, dt)` consistent in base (Task 3), `RangedAttack` (Task 4), `DashAttack` (Task 5). `Enemy3D._attack` + `_make_attack(data)` defined Task 3, exercised Tasks 3–5. `EnemyProjectile3D.setup(direction, speed, damage)` defined Task 2, called in `RangedAttack._launch` (Task 4). Variant keys `archer`/`magician`/`dasher` consistent Tasks 6–7. Projectile mask 18 (= 2+16) consistent with Global Constraints.
