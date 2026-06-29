# Avinoam Bunny Mega-Blast — Vertical Slice Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Re-skin Avinoam's signature (`holy_smite` slot) into LoL Swarm's **Bunny Mega-Blast** — random-target delayed orbital strikes with a gold telegraph and a descending pillar of light — proving the full re-skin pipeline (new mechanic archetype + Channel 1/2 VFX + registry routing + skill wiring) end-to-end.

**Architecture:** Add a new reusable `OrbitalStrikeWeapon3D` archetype (delayed random-target AoE strikes), built like the existing `NovaWeapon3D`/`OrbitWeapon3D` archetypes with pure static helpers for unit testing. Re-point `AvinoamHolySmite3D` from `NovaWeapon3D` to the new archetype. Reuse the existing `avinoam_holy_smite` → descending-pillar hit-FX registry entry for the strike impact; add a new color-driven ground telegraph FX for the wind-up.

**Tech Stack:** Godot 4 / GDScript, GUT test framework (`addons/gut`), `godot_vfx` addon for shaders/particles.

## Global Constraints

- **Branch base:** `feature/holy-smite-vfx`. The bespoke-VFX registry (`_HIT_REGISTRY` in `autoload/skill_vfx.gd`), the `avinoam_holy_smite` → `HolySmiteHitFx3D` (descending pillar) entry, and `Juice3D.add_shake()` all exist there and NOT on `main`. Create a working branch off `feature/holy-smite-vfx`.
- **GDScript style:** tabs for indentation; fully typed vars/params/returns; `class_name` + `## docstring` header on every script; one responsibility per file.
- **VFX instancing rule:** every effect instance creates FRESH `StandardMaterial3D`/`ShaderMaterial`/`ParticleProcessMaterial` — never mutate a shared resource (see `NovaWeapon3D._spawn_telegraph`).
- **Color parameterization:** all VFX colors derive from the passed `color` argument (transient) or an exported `vfx_color` (persistent). Never hardcode a character's hue inside a shared effect scene.
- **Fidelity bar:** effects must read as AAA LoL-Swarm juice — additive/emissive bloom (`emission_energy_multiplier` ≥ 3), expanding ring shockwave on impact, screen shake scaled to weight. Placeholder-grade visuals do not pass review.
- **Pure-helper rule:** selection/geometry logic lives in `static` functions with no scene/physics dependency so it is unit-testable, mirroring `NovaWeapon3D.affected_enemies` and `OrbitWeapon3D.orbiter_offsets`.
- **Test command:** `godot --headless -s addons/gut/gut_cmdln.gd -gdir=res://test -gprefix=test_ -gsuffix=.gd -gtest=res://test/<file>.gd -gexit` (adapt to the project's GUT runner; see `docs/notes/how-to-playtest.md`).

---

### Task 1: `OrbitalStrikeWeapon3D` archetype — mechanics + pure helpers

**Files:**
- Create: `weapons/orbital_strike_weapon_3d.gd`
- Create: `weapons/orbital_strike_weapon_3d.tscn`
- Test: `test/test_orbital_strike_weapon_3d.gd`

**Interfaces:**
- Consumes: `Weapon3D` (base), `StatBlock` (`damage_mult`, `fire_rate_mult`), `GameEvents.skill_hit`.
- Produces:
  - `class OrbitalStrikeWeapon3D extends Weapon3D`
  - vars: `strike_count:int`, `target_range:float`, `strike_radius:float`, `strike_delay:float`, `damage:float`
  - `static candidates_in_range(enemies:Array, origin:Vector3, range:float) -> Array`
  - `static pick_targets(candidates:Array, count:int) -> Array`
  - `static enemies_in_blast(enemies:Array, center:Vector3, radius:float) -> Array`
  - `_strike(point:Vector3) -> void` (deals AoE damage at a point + emits `skill_hit`)
  - overrides `fire()`, `level_up()`, `evolve()`, `apply_passive(value)`

- [ ] **Step 1: Write the failing test**

Create `test/test_orbital_strike_weapon_3d.gd`:

```gdscript
extends GutTest
## Unit tests for OrbitalStrikeWeapon3D archetype (pure helpers + mechanics).
## No physics required — selection/blast logic are pure static Array filters.

class StubEnemy extends Node3D:
	var damage_received: float = 0.0
	func _init() -> void:
		add_to_group("enemies")
	func take_damage(amount: float) -> void:
		damage_received += amount

func _make_stats(dmg: float = 1.0, rate: float = 1.0) -> StatBlock:
	var s := StatBlock.new()
	s.damage_mult = dmg
	s.fire_rate_mult = rate
	return s

func _make_weapon() -> OrbitalStrikeWeapon3D:
	var w: OrbitalStrikeWeapon3D = add_child_autofree(OrbitalStrikeWeapon3D.new())
	var player := add_child_autofree(Node3D.new()) as Node3D
	w.setup(player, _make_stats())
	return w

func _enemy_at(x: float, z: float, y: float = 0.0) -> StubEnemy:
	var e := StubEnemy.new()
	add_child_autofree(e)
	e.global_position = Vector3(x, y, z)
	return e

# ── candidates_in_range ──
func test_candidates_includes_within_range() -> void:
	var near := _enemy_at(2.0, 0.0)
	var result := OrbitalStrikeWeapon3D.candidates_in_range([near], Vector3.ZERO, 5.0)
	assert_true(result.has(near), "enemy at dist 2 must be within range 5")

func test_candidates_excludes_beyond_range() -> void:
	var far := _enemy_at(10.0, 0.0)
	var result := OrbitalStrikeWeapon3D.candidates_in_range([far], Vector3.ZERO, 5.0)
	assert_false(result.has(far), "enemy at dist 10 must be outside range 5")

func test_candidates_ignores_y() -> void:
	var e := _enemy_at(2.0, 0.0, 100.0)
	var result := OrbitalStrikeWeapon3D.candidates_in_range([e], Vector3.ZERO, 5.0)
	assert_true(result.has(e), "Y must be ignored in range check")

# ── pick_targets ──
func test_pick_targets_caps_at_count() -> void:
	var pool := [_enemy_at(1, 0), _enemy_at(2, 0), _enemy_at(3, 0)]
	var picked := OrbitalStrikeWeapon3D.pick_targets(pool, 2)
	assert_eq(picked.size(), 2, "must return exactly count when enough candidates")

func test_pick_targets_returns_all_when_fewer() -> void:
	var pool := [_enemy_at(1, 0)]
	var picked := OrbitalStrikeWeapon3D.pick_targets(pool, 3)
	assert_eq(picked.size(), 1, "must return all when fewer than count")

func test_pick_targets_zero_count_empty() -> void:
	var pool := [_enemy_at(1, 0)]
	assert_eq(OrbitalStrikeWeapon3D.pick_targets(pool, 0).size(), 0)

# ── enemies_in_blast ──
func test_blast_hits_inside_radius() -> void:
	var inside := _enemy_at(1.0, 0.0)
	var result := OrbitalStrikeWeapon3D.enemies_in_blast([inside], Vector3.ZERO, 2.5)
	assert_true(result.has(inside), "enemy 1 unit from center must be in 2.5 blast")

func test_blast_excludes_outside_radius() -> void:
	var outside := _enemy_at(5.0, 0.0)
	var result := OrbitalStrikeWeapon3D.enemies_in_blast([outside], Vector3.ZERO, 2.5)
	assert_false(result.has(outside), "enemy 5 units away must be outside 2.5 blast")

# ── _strike applies damage ──
func test_strike_damages_enemies_in_blast() -> void:
	var w := _make_weapon()
	w.strike_radius = 3.0
	w.damage = 40.0
	var hit := _enemy_at(1.0, 0.0)
	var miss := _enemy_at(20.0, 0.0)
	w._strike(Vector3.ZERO)
	assert_almost_eq(hit.damage_received, 40.0, 0.001, "in-blast enemy takes full damage")
	assert_almost_eq(miss.damage_received, 0.0, 0.001, "out-of-blast enemy takes none")

func test_strike_scales_with_damage_mult() -> void:
	var w: OrbitalStrikeWeapon3D = add_child_autofree(OrbitalStrikeWeapon3D.new())
	var player := add_child_autofree(Node3D.new()) as Node3D
	w.setup(player, _make_stats(2.0))
	w.strike_radius = 3.0
	w.damage = 40.0
	var hit := _enemy_at(1.0, 0.0)
	w._strike(Vector3.ZERO)
	assert_almost_eq(hit.damage_received, 80.0, 0.001, "damage must scale by damage_mult")

# ── level_up / evolve / apply_passive ──
func test_level_up_increases_damage_by_12() -> void:
	var w := _make_weapon()
	var before := w.damage
	w.level_up()
	assert_almost_eq(w.damage - before, 12.0, 0.001, "level_up adds 12 damage")

func test_level_up_adds_target_every_other_level() -> void:
	var w := _make_weapon()  # level 1, strike_count 2
	w.level_up()  # -> level 2, +1 target
	assert_eq(w.strike_count, 3, "even level adds a target")
	w.level_up()  # -> level 3, no target
	assert_eq(w.strike_count, 3, "odd level adds no target")

func test_evolve_sets_flag_and_boosts() -> void:
	var w := _make_weapon()
	var radius_before := w.strike_radius
	w.evolve()
	assert_true(w.evolved, "evolve sets evolved=true")
	assert_gt(w.strike_radius, radius_before, "evolve enlarges strike_radius")

func test_apply_passive_increases_strike_radius() -> void:
	var w := _make_weapon()
	var before := w.strike_radius
	w.apply_passive(0.5)
	assert_almost_eq(w.strike_radius, before + 0.5, 0.001, "passive adds to strike_radius")

# ── defaults / scene ──
func test_default_base_cooldown() -> void:
	var w := _make_weapon()
	assert_almost_eq(w.base_cooldown, 5.0, 0.001, "archetype base_cooldown default 5.0")

func test_scene_loads_as_weapon3d() -> void:
	var scene := load("res://weapons/orbital_strike_weapon_3d.tscn")
	assert_not_null(scene, "orbital_strike_weapon_3d.tscn must load")
	var w = add_child_autofree(scene.instantiate())
	assert_true(w is Weapon3D, "must be a Weapon3D")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_orbital_strike_weapon_3d.gd -gexit`
Expected: FAIL — `OrbitalStrikeWeapon3D` is not a known class / scene does not load.

- [ ] **Step 3: Write the archetype script**

Create `weapons/orbital_strike_weapon_3d.gd`:

```gdscript
# See docs/superpowers/specs/2026-06-29-lol-swarm-weapon-reskin-design.md
class_name OrbitalStrikeWeapon3D extends Weapon3D
## Reusable archetype: random-target delayed orbital strike (LoL Swarm
## "Bunny Mega-Blast"). On each fire() the weapon picks up to `strike_count`
## enemies within `target_range`, shows a ground telegraph at each for
## `strike_delay` seconds, then detonates an AoE blast of `strike_radius`
## dealing `damage` to every enemy caught in it (emitting skill_hit per blast).
##
## Selection / blast geometry live in pure static helpers for unit testing.
## 1 unit ≈ 16 px; gameplay on the XZ plane (Y up).

## Ground telegraph shown at each target before the strike lands.
const _TelegraphScene: PackedScene = preload("res://vfx/orbital_strike_telegraph_fx_3d.tscn")

## Max simultaneous strikes per fire().
var strike_count: int = 2
## World-unit range within which targets are eligible.
var target_range: float = 9.0
## AoE radius of each strike's blast.
var strike_radius: float = 2.5
## Seconds the telegraph shows before the blast lands.
var strike_delay: float = 0.5
## Damage per blast (multiplied by stats.damage_mult).
var damage: float = 40.0

func _init() -> void:
	base_cooldown = 5.0
	vfx_id = &"orbital_strike"
	vfx_color = Color(1.0, 0.4, 0.8)  # default magenta; subclasses override

func _ready() -> void:
	super()

## Timer-driven fire: pick random targets in range, telegraph each, strike after delay.
func fire() -> void:
	if not stats:
		return
	var all_enemies: Array = get_tree().get_nodes_in_group("enemies")
	var candidates: Array = candidates_in_range(all_enemies, global_position, target_range)
	candidates.shuffle()
	var targets: Array = pick_targets(candidates, strike_count)
	for enemy in targets:
		var point: Vector3 = (enemy as Node3D).global_position
		_telegraph_at(point)
		_schedule_strike(point)

## Level up: +12 damage every level, +1 target on even levels (2→4 across L1-5).
func level_up() -> void:
	super()
	damage += 12.0
	if level % 2 == 0:
		strike_count += 1

## Evolve (synergy): +2 targets, larger blasts.
func evolve() -> void:
	super()
	strike_count += 2
	strike_radius *= 1.3

## Passive bonus: increases blast radius.
func apply_passive(value: float) -> void:
	strike_radius += value

# ── Pure / testable helpers ──

## Enemies within `range` XZ units of `origin` (Y ignored). Pure.
static func candidates_in_range(enemies: Array, origin: Vector3, range: float) -> Array:
	var result: Array = []
	for enemy in enemies:
		var pos: Vector3 = (enemy as Node3D).global_position
		var dx: float = pos.x - origin.x
		var dz: float = pos.z - origin.z
		if sqrt(dx * dx + dz * dz) <= range:
			result.append(enemy)
	return result

## First `count` entries of `candidates` (caller shuffles for randomness). Pure.
static func pick_targets(candidates: Array, count: int) -> Array:
	if count <= 0:
		return []
	var result: Array = []
	for i in range(min(count, candidates.size())):
		result.append(candidates[i])
	return result

## Enemies within `radius` XZ units of `center` (Y ignored). Pure.
static func enemies_in_blast(enemies: Array, center: Vector3, radius: float) -> Array:
	var result: Array = []
	for enemy in enemies:
		var pos: Vector3 = (enemy as Node3D).global_position
		var dx: float = pos.x - center.x
		var dz: float = pos.z - center.z
		if sqrt(dx * dx + dz * dz) <= radius:
			result.append(enemy)
	return result

# ── Private ──

## Spawn the contracting ground telegraph at a target point.
func _telegraph_at(point: Vector3) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var fx: Node = _TelegraphScene.instantiate()
	parent.add_child(fx)
	fx.play_at(point, vfx_color, strike_delay, strike_radius)

## Arm a one-shot timer to detonate the strike after the telegraph delay.
func _schedule_strike(point: Vector3) -> void:
	if not is_inside_tree():
		return
	var timer: SceneTreeTimer = get_tree().create_timer(strike_delay)
	timer.timeout.connect(_strike.bind(point))

## Detonate one strike: AoE damage at `point` + bespoke pillar hit FX via registry.
func _strike(point: Vector3) -> void:
	if not stats:
		return
	var all_enemies: Array = get_tree().get_nodes_in_group("enemies")
	var dmg: float = damage * stats.damage_mult
	for enemy in enemies_in_blast(all_enemies, point, strike_radius):
		if enemy.has_method("take_damage"):
			enemy.take_damage(dmg)
	if is_inside_tree():
		GameEvents.skill_hit.emit(vfx_id, vfx_color, point)
```

- [ ] **Step 4: Create the archetype scene**

Create `weapons/orbital_strike_weapon_3d.tscn` (mirror `nova_weapon_3d.tscn` structure):

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://weapons/orbital_strike_weapon_3d.gd" id="1_orbital"]

[node name="OrbitalStrikeWeapon3D" type="Node3D"]
script = ExtResource("1_orbital")
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_orbital_strike_weapon_3d.gd -gexit`
Expected: PASS — all tests green. (The scene-load test requires Task 2's telegraph scene to exist for the `preload` to resolve; if it fails on the `preload`, do Task 2 first, then re-run.)

> NOTE: `_TelegraphScene` preloads `orbital_strike_telegraph_fx_3d.tscn` (Task 2). GDScript resolves `const ... preload` at parse time, so the archetype script will not load until that scene exists. Implement Task 2 before running Step 5, or temporarily stub the file. The two tasks are committed together.

- [ ] **Step 6: Commit (after Task 2 scene exists)**

```bash
git add weapons/orbital_strike_weapon_3d.gd weapons/orbital_strike_weapon_3d.tscn test/test_orbital_strike_weapon_3d.gd
git commit -m "feat(weapons): OrbitalStrikeWeapon3D archetype (Bunny Mega-Blast behavior)"
```

---

### Task 2: Orbital-strike ground telegraph FX

**Files:**
- Create: `vfx/orbital_strike_telegraph_fx_3d.gd`
- Create: `vfx/orbital_strike_telegraph_fx_3d.tscn`
- Test: `test/test_orbital_strike_telegraph_fx_3d.gd`

**Interfaces:**
- Consumes: nothing (self-contained Node3D effect).
- Produces: `class OrbitalStrikeTelegraphFx3D extends Node3D` with `play_at(pos:Vector3, color:Color, duration:float, radius:float) -> void`. Used by `OrbitalStrikeWeapon3D._telegraph_at`.

- [ ] **Step 1: Write the failing test**

Create `test/test_orbital_strike_telegraph_fx_3d.gd`:

```gdscript
extends GutTest
## Structural tests for the orbital-strike ground telegraph FX.
## Visual quality is validated by playtest, not unit tests — here we verify the
## scene loads, positions on the XZ plane, and auto-frees after its duration.

const GOLD := Color(1.0, 0.84, 0.0, 1.0)
const _Scene := preload("res://vfx/orbital_strike_telegraph_fx_3d.tscn")

func test_scene_loads() -> void:
	assert_not_null(load("res://vfx/orbital_strike_telegraph_fx_3d.tscn"),
		"telegraph scene must load")

func test_play_at_positions_on_xz() -> void:
	var fx: OrbitalStrikeTelegraphFx3D = _Scene.instantiate()
	add_child_autofree(fx)
	fx.play_at(Vector3(3.0, 0.0, -4.0), GOLD, 0.5, 2.5)
	assert_almost_eq(fx.global_position.x, 3.0, 0.001, "telegraph x must match target")
	assert_almost_eq(fx.global_position.z, -4.0, 0.001, "telegraph z must match target")

func test_play_at_spawns_a_mesh() -> void:
	var fx: OrbitalStrikeTelegraphFx3D = _Scene.instantiate()
	add_child_autofree(fx)
	fx.play_at(Vector3.ZERO, GOLD, 0.5, 2.5)
	var has_mesh := false
	for c in fx.get_children():
		if c is MeshInstance3D:
			has_mesh = true
	assert_true(has_mesh, "telegraph must create a MeshInstance3D decal")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_orbital_strike_telegraph_fx_3d.gd -gexit`
Expected: FAIL — `OrbitalStrikeTelegraphFx3D` unknown / scene missing.

- [ ] **Step 3: Write the FX script**

Create `vfx/orbital_strike_telegraph_fx_3d.gd`:

```gdscript
# See docs/superpowers/specs/2026-06-29-lol-swarm-weapon-reskin-design.md
class_name OrbitalStrikeTelegraphFx3D extends Node3D
## Ground telegraph for OrbitalStrikeWeapon3D: a bright additive disc marking
## where an incoming strike will land, contracting over `duration` to signal
## impact, then auto-frees. Fully color-driven (no hardcoded hue).
## Usage: instantiate, add to scene, call play_at(pos, color, duration, radius).

func play_at(pos: Vector3, color: Color, duration: float, radius: float) -> void:
	# Sit just above the ground so the decal does not z-fight the floor.
	global_position = pos + Vector3(0.0, 0.05, 0.0)

	var mi := MeshInstance3D.new()
	var plane := PlaneMesh.new()  # PlaneMesh lies on the XZ plane (normal +Y)
	plane.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = plane

	# Fresh additive emissive material per instance — never share resources.
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.albedo_color = Color(color.r, color.g, color.b, 0.8)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 4.0
	mi.material_override = mat
	add_child(mi)

	# Contract toward the center + fade as the strike approaches, then free.
	mi.scale = Vector3.ONE
	var t := create_tween()
	t.set_parallel(true)
	t.tween_property(mi, "scale", Vector3(0.4, 1.0, 0.4), duration)
	t.tween_property(mat, "albedo_color:a", 0.2, duration)
	t.chain().tween_callback(queue_free)
```

- [ ] **Step 4: Create the FX scene**

Create `vfx/orbital_strike_telegraph_fx_3d.tscn`:

```
[gd_scene load_steps=2 format=3]

[ext_resource type="Script" path="res://vfx/orbital_strike_telegraph_fx_3d.gd" id="1_tele"]

[node name="OrbitalStrikeTelegraphFx3D" type="Node3D"]
script = ExtResource("1_tele")
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_orbital_strike_telegraph_fx_3d.gd -gexit`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add vfx/orbital_strike_telegraph_fx_3d.gd vfx/orbital_strike_telegraph_fx_3d.tscn test/test_orbital_strike_telegraph_fx_3d.gd
git commit -m "feat(vfx): orbital-strike ground telegraph (color-driven)"
```

(Then return to Task 1 Step 5/6: the archetype's `preload` now resolves — run the Task 1 test and commit Task 1.)

---

### Task 3: Re-skin `AvinoamHolySmite3D` → Bunny Mega-Blast + fix existing tests

**Files:**
- Modify: `weapons/avinoam_holy_smite_3d.gd` (entire file — change base class + params)
- Test: `test/test_holy_smite_vfx.gd` (verify still green), `test/test_avinoam_character.gd` (fix archetype expectations)

**Interfaces:**
- Consumes: `OrbitalStrikeWeapon3D` (Task 1), the existing `&"avinoam_holy_smite"` → `HolySmiteHitFx3D` registry entry in `autoload/skill_vfx.gd` (descending pillar), `Juice3D.add_shake`.
- Produces: `class AvinoamHolySmite3D extends OrbitalStrikeWeapon3D` keeping `vfx_id = &"avinoam_holy_smite"` and gold `vfx_color`.

- [ ] **Step 1: Write the failing test**

Add to `test/test_holy_smite_vfx.gd` (append these tests):

```gdscript
# ── Bunny Mega-Blast re-skin ──
func test_holy_smite_is_orbital_strike() -> void:
	var w: AvinoamHolySmite3D = add_child_autofree(AvinoamHolySmite3D.new())
	assert_true(w is OrbitalStrikeWeapon3D,
		"Holy Smite must now be an OrbitalStrikeWeapon3D (Bunny Mega-Blast)")

func test_holy_smite_strike_defaults() -> void:
	var w: AvinoamHolySmite3D = add_child_autofree(AvinoamHolySmite3D.new())
	assert_eq(w.strike_count, 2, "starts with 2 strikes")
	assert_almost_eq(w.strike_radius, 3.0, 0.001, "blast radius starts at 3.0")
	assert_almost_eq(w.base_cooldown, 5.0, 0.001, "base cooldown 5.0")

func test_holy_smite_keeps_gold_vfx() -> void:
	var w: AvinoamHolySmite3D = add_child_autofree(AvinoamHolySmite3D.new())
	assert_eq(w.vfx_id, &"avinoam_holy_smite", "keeps the pillar registry vfx_id")
	assert_eq(w.vfx_color, Color(1.0, 0.84, 0.0), "keeps Avinoam gold")
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_holy_smite_vfx.gd -gexit`
Expected: FAIL — `test_holy_smite_is_orbital_strike` fails (still a `NovaWeapon3D`); `strike_count`/`strike_radius` don't exist.

- [ ] **Step 3: Re-skin the weapon**

Replace the entire contents of `weapons/avinoam_holy_smite_3d.gd`:

```gdscript
# See docs/notes/char-avinoam.md
class_name AvinoamHolySmite3D extends OrbitalStrikeWeapon3D
## Avinoam signature — re-skinned to LoL Swarm "Bunny Mega-Blast": calls down
## random orbital strikes that telegraph on the ground then slam each target
## with a descending pillar of gold light (see avinoam_holy_smite registry FX).

func _ready() -> void:
	strike_count  = 2
	target_range  = 9.0
	strike_radius = 3.0
	strike_delay  = 0.5
	damage        = 40.0
	base_cooldown = 5.0
	vfx_id    = &"avinoam_holy_smite"      # keeps the descending-pillar hit FX
	vfx_color = Color(1.0, 0.84, 0.0)      # Avinoam gold
	super()
```

- [ ] **Step 4: Run the holy-smite test to verify it passes**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_holy_smite_vfx.gd -gexit`
Expected: PASS — including the original `test_holy_smite_emits_avinoam_vfx_id` / `_color` tests (unchanged) and the new re-skin tests.

- [ ] **Step 5: Fix the Avinoam character test for the new archetype**

Run the character test to surface stale assumptions:
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_avinoam_character.gd -gexit`

If any assertion expects `AvinoamHolySmite3D` to be a `NovaWeapon3D`, to have a `.radius` of `6.0`, or to deal damage to all enemies in `radius` on `fire()`, update it to the orbital-strike contract: it is an `OrbitalStrikeWeapon3D`; damage is applied by `_strike(point)` to enemies within `strike_radius` of the struck point (not to all enemies in a player-centered radius). Replace any `fire()`-deals-damage assertion with a `_strike(point)` assertion modeled on `test_strike_damages_enemies_in_blast` from Task 1. Re-run until green.

> If `test_avinoam_character.gd` does not reference the Holy Smite archetype/radius at all, this step is a no-op confirmation.

- [ ] **Step 6: Run the full weapon + Avinoam test suite**

Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_orbital_strike_weapon_3d.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_holy_smite_vfx.gd -gexit`
Run: `godot --headless -s addons/gut/gut_cmdln.gd -gtest=res://test/test_avinoam_character.gd -gexit`
Expected: all PASS.

- [ ] **Step 7: Commit**

```bash
git add weapons/avinoam_holy_smite_3d.gd test/test_holy_smite_vfx.gd test/test_avinoam_character.gd
git commit -m "feat(avinoam): re-skin Holy Smite to Bunny Mega-Blast orbital strikes"
```

---

### Task 4: In-game verification (manual playtest)

**Files:** none (verification only).

**Interfaces:** Consumes the full slice (archetype + telegraph + reskin + existing pillar FX).

- [ ] **Step 1: Launch the game and select Avinoam**

Use the project's run path (see `docs/notes/how-to-playtest.md`; the `/run` skill can launch it). Start a run as Avinoam.

- [ ] **Step 2: Observe the signature firing**

Confirm, against the fidelity bar:
- Every ~5s, 2 gold ground telegraph discs appear on random nearby enemies and contract over ~0.5s.
- A descending gold pillar of light then slams each telegraphed point with a ground impact ring + rising sparks (existing `HolySmiteHitFx3D`), and a screen-shake jolt fires.
- Enemies within ~3 units of each struck point take damage; enemies elsewhere do not.
- Leveling the skill adds targets (on even levels) and damage.

- [ ] **Step 3: Record the result**

If it meets the bar, note completion. If telegraph/strike timing, colors, blast radius, or shake weight feel off, tune the exported values in `weapons/avinoam_holy_smite_3d.gd` (`strike_delay`, `strike_radius`, `vfx_color`) and the FX constants, then re-verify. VFX aesthetics are tuned here by observation, not by unit tests.

- [ ] **Step 4: Commit any tuning**

```bash
git add -A
git commit -m "tune(avinoam): bunny mega-blast strike timing/feel"
```

---

## Self-Review

**1. Spec coverage (this slice):**
- New mechanical archetype (random-target delayed orbital strike) → Task 1 ✓
- Channel 2 persistent-ish telegraph (color-driven) → Task 2 ✓
- Channel 1 transient strike FX via registry routing → reuses existing `avinoam_holy_smite` → pillar entry; wired in Task 3 ✓
- Color parameterization (gold via `vfx_color`, telegraph via `color` arg) → Tasks 2–3 ✓
- Skill wiring into Avinoam's signature slot → Task 3 ✓
- Fidelity bar / screen shake → existing pillar FX (`Juice3D.add_shake`) + Task 4 verification ✓
- Out of this slice (tracked as follow-up plans): Lioness's Lament, Radiant Field, Vortex Glove, Annihilator (rest of Avinoam); the other 9 characters; the `AuraWeapon3D`/`ProjectileWeapon3D`/`SpiralEmitterWeapon3D` archetypes.

**2. Placeholder scan:** No TBD/TODO; all steps carry full code or exact commands. (The single `TODO(sound)` lives in the pre-existing `HolySmiteHitFx3D`, not introduced here.)

**3. Type consistency:** `strike_count:int`, `strike_radius:float`, `target_range:float`, `strike_delay:float`, `damage:float`, and helper signatures (`candidates_in_range`, `pick_targets`, `enemies_in_blast`, `_strike`) are used identically across Tasks 1 and 3. `play_at(pos, color, duration, radius)` matches between the telegraph FX (Task 2) and the archetype caller (Task 1). `vfx_id`/`vfx_color` match the existing registry entry asserted in `test_holy_smite_vfx.gd`.
