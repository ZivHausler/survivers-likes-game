# Boss HP Bars Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the big boss a top-center screen HP bar (name + fill + `cur / max`) and give mini-bosses a floating red HP bar above their heads; normal enemies stay bare.

**Architecture:** Bosses are tagged with a `BossKind` on the existing `Enemy3D`. The big boss drives a HUD bar through three new `GameEvents` signals; each mini-boss owns a code-built `HealthBar3D` (a billboarded `Node3D`) updated directly in `take_damage()`. The spawner tags each boss right after `setup()`.

**Tech Stack:** Godot 4.7, GDScript, GUT (headless unit tests).

## Global Constraints

- Godot 4.7 stable; GDScript with static typing as in the surrounding files.
- Tests run headless via GUT: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/<file>.gd -gexit`.
- Never mutate shared `.tres` resources.
- Boss display name for the big boss is exactly `"Undead Serpent"`.
- Normal enemies get no HP bar; big boss gets only the screen bar; mini-boss gets only the head bar.
- All gameplay stays on the XZ plane; visual-only nodes must never affect collision/contact.

## File Structure

- `autoload/game_events.gd` — modify: add 3 boss signals.
- `ui/health_bar_3d.gd` — create: `class_name HealthBar3D extends Node3D`, billboarded world-space bar.
- `enemies/enemy_3d.gd` — modify: `BossKind` enum, boss fields, `configure_boss()`, `take_damage()` hooks.
- `spawning/spawner_3d.gd` — modify: `configure_boss()` calls in `_spawn_boss` / `_spawn_big_boss`.
- `ui/hud.tscn` + `ui/hud.gd` — modify: top-center boss bar + signal handlers.
- `test/test_game_events.gd` — create.
- `test/test_health_bar_3d.gd` — create.
- `test/test_enemy_3d.gd` — modify: boss-tagging tests.
- `test/test_spawner_3d.gd` — modify: boss-spawn wiring tests.
- `test/test_hud.gd` — create: boss-bar signal handling.

---

### Task 1: GameEvents boss signals

**Files:**
- Modify: `autoload/game_events.gd`
- Test: `test/test_game_events.gd` (create)

**Interfaces:**
- Produces: signals `boss_spawned(boss_name: String, max_hp: float)`, `boss_hp_changed(current: float, max_hp: float)`, `boss_died()` on the `GameEvents` autoload.

- [ ] **Step 1: Write the failing test**

Create `test/test_game_events.gd`:

```gdscript
extends GutTest
## Verifies the global signal bus exposes the boss-HP signals.

func test_boss_spawned_signal_exists() -> void:
	assert_true(GameEvents.has_signal("boss_spawned"), "GameEvents must declare boss_spawned")

func test_boss_hp_changed_signal_exists() -> void:
	assert_true(GameEvents.has_signal("boss_hp_changed"), "GameEvents must declare boss_hp_changed")

func test_boss_died_signal_exists() -> void:
	assert_true(GameEvents.has_signal("boss_died"), "GameEvents must declare boss_died")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_game_events.gd -gexit`
Expected: FAIL (assertions false — signals not declared).

- [ ] **Step 3: Add the signals**

In `autoload/game_events.gd`, after the existing `signal skill_hit(...)` line, add:

```gdscript
## Big-boss lifecycle (drives the top-center HUD boss bar).
signal boss_spawned(boss_name: String, max_hp: float)
signal boss_hp_changed(current: float, max_hp: float)
signal boss_died()
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_game_events.gd -gexit`
Expected: PASS (3/3).

- [ ] **Step 5: Commit**

```bash
git add autoload/game_events.gd test/test_game_events.gd
git commit -m "feat(events): add boss_spawned/hp_changed/died signals"
```

---

### Task 2: HealthBar3D floating bar

**Files:**
- Create: `ui/health_bar_3d.gd`
- Test: `test/test_health_bar_3d.gd` (create)

**Interfaces:**
- Produces: `class_name HealthBar3D extends Node3D` with:
  - `static func compute_fill_scale(ratio: float) -> float` (returns `clampf(ratio, 0.0, 1.0)`)
  - `func set_ratio(r: float) -> void`
  - `const WIDTH := 1.0`, `const HEIGHT := 0.16`
  - members `_bg: MeshInstance3D`, `_fill_pivot: Node3D`, `_fill: MeshInstance3D`

- [ ] **Step 1: Write the failing test**

Create `test/test_health_bar_3d.gd`:

```gdscript
extends GutTest
## Unit tests for the world-space mini-boss HealthBar3D.

func test_compute_fill_scale_clamps_high() -> void:
	assert_eq(HealthBar3D.compute_fill_scale(1.5), 1.0, "ratio above 1 clamps to 1.0")

func test_compute_fill_scale_clamps_low() -> void:
	assert_eq(HealthBar3D.compute_fill_scale(-0.3), 0.0, "negative ratio clamps to 0.0")

func test_compute_fill_scale_passthrough() -> void:
	assert_almost_eq(HealthBar3D.compute_fill_scale(0.5), 0.5, 0.001, "mid ratio passes through")

func test_set_ratio_updates_fill_pivot_scale() -> void:
	var bar: HealthBar3D = add_child_autofree(HealthBar3D.new())
	bar.set_ratio(0.25)
	assert_almost_eq(bar._fill_pivot.scale.x, 0.25, 0.001, "fill pivot x-scale tracks ratio")

func test_set_ratio_full_is_one() -> void:
	var bar: HealthBar3D = add_child_autofree(HealthBar3D.new())
	bar.set_ratio(1.0)
	assert_almost_eq(bar._fill_pivot.scale.x, 1.0, 0.001, "full HP → full-width fill")

func test_builds_background_and_fill_children() -> void:
	var bar: HealthBar3D = add_child_autofree(HealthBar3D.new())
	assert_not_null(bar._bg, "background quad must be built")
	assert_not_null(bar._fill, "fill quad must be built")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_health_bar_3d.gd -gexit`
Expected: FAIL (parse error — `HealthBar3D` does not exist).

- [ ] **Step 3: Write the implementation**

Create `ui/health_bar_3d.gd`:

```gdscript
class_name HealthBar3D extends Node3D
## A world-space health bar that floats above a mini-boss and faces the active
## camera. Built entirely in code (no .tscn). The fill quad is anchored at the bar's
## LEFT edge via a pivot node, so set_ratio() shrinks it from the right. Visual only —
## never touches collision, navigation, or contact damage.

const WIDTH := 1.0      ## Bar width in world units (at unit scale; see _process facing).
const HEIGHT := 0.16    ## Bar height in world units.
const FILL_EPSILON := 0.002  ## Fill quad sits slightly in front of the background quad.

const COLOR_BG := Color(0.07, 0.05, 0.05, 1.0)
const COLOR_FILL := Color(0.9, 0.12, 0.1, 1.0)

var _bg: MeshInstance3D = null
var _fill_pivot: Node3D = null
var _fill: MeshInstance3D = null

func _ready() -> void:
	_bg = _make_quad(WIDTH, HEIGHT, COLOR_BG, 0.0)
	add_child(_bg)
	# Pivot anchored at the bar's left edge; the fill quad is offset +WIDTH/2 so its
	# left edge coincides with the pivot. Scaling the pivot's x grows/shrinks the fill
	# from the left.
	_fill_pivot = Node3D.new()
	_fill_pivot.position = Vector3(-WIDTH * 0.5, 0.0, FILL_EPSILON)
	add_child(_fill_pivot)
	_fill = _make_quad(WIDTH, HEIGHT, COLOR_FILL, 0.0)
	_fill.position = Vector3(WIDTH * 0.5, 0.0, 0.0)
	_fill_pivot.add_child(_fill)
	set_ratio(1.0)

## Build an unshaded, double-sided, depth-test-disabled quad of the given size/color.
func _make_quad(w: float, h: float, color: Color, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	mi.mesh = quad
	mi.position = Vector3(0.0, 0.0, z)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.albedo_color = color
	mi.material_override = mat
	return mi

## Set the fill fraction in [0, 1]; clamps out-of-range input.
func set_ratio(r: float) -> void:
	if _fill_pivot == null:
		return
	var s := compute_fill_scale(r)
	_fill_pivot.scale.x = s

## Pure helper: clamp a ratio into [0, 1]. Unit-testable without a scene tree.
static func compute_fill_scale(ratio: float) -> float:
	return clampf(ratio, 0.0, 1.0)

## Billboard: orient the bar to the active camera each frame so it reads as a flat
## rectangle from the angled follow-cam. Uses the camera basis (unit scale) so the bar
## renders at a consistent on-screen size regardless of the boss's body scale. No-ops
## headlessly when there is no active camera.
func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	global_transform = Transform3D(cam.global_transform.basis, global_position)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_health_bar_3d.gd -gexit`
Expected: PASS (6/6).

- [ ] **Step 5: Commit**

```bash
git add ui/health_bar_3d.gd test/test_health_bar_3d.gd
git commit -m "feat(ui): add billboarded world-space HealthBar3D"
```

---

### Task 3: Enemy3D boss identity + HP-feedback hooks

**Files:**
- Modify: `enemies/enemy_3d.gd` (add fields near the var block ~line 26-39; add `configure_boss`; extend `take_damage` ~line 143-154)
- Test: `test/test_enemy_3d.gd` (append)

**Interfaces:**
- Consumes: `GameEvents.boss_spawned/boss_hp_changed/boss_died` (Task 1); `HealthBar3D` + `HealthBar3D.set_ratio` (Task 2).
- Produces on `Enemy3D`:
  - `enum BossKind { NONE, MINI, BIG }`
  - `var boss_kind: int` (default `BossKind.NONE`), `var boss_name: String`, `var _health_bar: HealthBar3D`
  - `const MINI_BOSS_BAR_OFFSET_Y := 2.5`
  - `func configure_boss(kind: int, p_name: String = "") -> void`

- [ ] **Step 1: Write the failing tests**

Append to `test/test_enemy_3d.gd` (the `_make_enemy` / `_make_data` / `StubTarget` helpers already exist):

```gdscript
# ── boss tagging + HP feedback ────────────────────────────────────────────────

func test_default_enemy_boss_kind_is_none() -> void:
	var e: Enemy3D = _make_enemy()
	assert_eq(e.boss_kind, Enemy3D.BossKind.NONE, "normal enemy defaults to BossKind.NONE")

func test_normal_enemy_has_no_health_bar_child() -> void:
	var e: Enemy3D = _make_enemy()
	assert_null(e._health_bar, "normal enemy must not own a HealthBar3D")

func test_configure_big_boss_emits_boss_spawned_with_max_hp() -> void:
	var e: Enemy3D = _make_enemy(500.0)
	watch_signals(GameEvents)
	e.configure_boss(Enemy3D.BossKind.BIG, "Undead Serpent")
	assert_eq(e.boss_kind, Enemy3D.BossKind.BIG, "boss_kind set to BIG")
	assert_signal_emitted_with_parameters(GameEvents, "boss_spawned", ["Undead Serpent", 500.0])

func test_big_boss_nonlethal_damage_emits_boss_hp_changed() -> void:
	var e: Enemy3D = _make_enemy(500.0)
	e.configure_boss(Enemy3D.BossKind.BIG, "Undead Serpent")
	watch_signals(GameEvents)
	e.take_damage(120.0)  # 500 → 380, non-lethal
	assert_signal_emitted_with_parameters(GameEvents, "boss_hp_changed", [380.0, 500.0])

func test_big_boss_lethal_damage_emits_boss_died() -> void:
	var e: Enemy3D = _make_enemy(100.0)
	e.configure_boss(Enemy3D.BossKind.BIG, "Undead Serpent")
	watch_signals(GameEvents)
	e.take_damage(100.0)  # lethal
	assert_signal_emitted(GameEvents, "boss_died")

func test_configure_mini_boss_creates_health_bar_at_full() -> void:
	var e: Enemy3D = _make_enemy(200.0)
	e.configure_boss(Enemy3D.BossKind.MINI)
	assert_eq(e.boss_kind, Enemy3D.BossKind.MINI, "boss_kind set to MINI")
	assert_not_null(e._health_bar, "mini-boss must own a HealthBar3D child")
	assert_almost_eq(e._health_bar._fill_pivot.scale.x, 1.0, 0.001, "bar starts full")

func test_mini_boss_nonlethal_damage_updates_bar_ratio() -> void:
	var e: Enemy3D = _make_enemy(200.0)
	e.configure_boss(Enemy3D.BossKind.MINI)
	e.take_damage(50.0)  # 200 → 150 → ratio 0.75
	assert_almost_eq(e._health_bar._fill_pivot.scale.x, 0.75, 0.001, "bar fill tracks hp/max")

func test_normal_enemy_damage_emits_no_boss_signals() -> void:
	var e: Enemy3D = _make_enemy(50.0)
	watch_signals(GameEvents)
	e.take_damage(10.0)
	assert_signal_not_emitted(GameEvents, "boss_hp_changed")
	assert_signal_not_emitted(GameEvents, "boss_died")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_3d.gd -gexit`
Expected: FAIL (parse error — `Enemy3D.BossKind` / `configure_boss` / `_health_bar` undefined).

- [ ] **Step 3: Add fields and the enum**

In `enemies/enemy_3d.gd`, in the variable block (after `var _bob_phase: float = 0.0` ~line 39), add:

```gdscript

## Boss classification — set by Spawner3D via configure_boss() after setup().
enum BossKind { NONE, MINI, BIG }
var boss_kind: int = BossKind.NONE
var boss_name: String = ""
## Floating world-space HP bar for mini-bosses only (null otherwise).
var _health_bar: HealthBar3D = null
## Local-space Y offset of the mini-boss head bar (scales with the boss body).
const MINI_BOSS_BAR_OFFSET_Y := 2.5
```

- [ ] **Step 4: Add `configure_boss()`**

In `enemies/enemy_3d.gd`, immediately after `setup()` ends (before `charm()` ~line 88), add:

```gdscript
## Tag this enemy as a boss. Called by Spawner3D AFTER setup() (so `data` is set).
## BIG  → announce to the HUD via GameEvents.boss_spawned (no head bar).
## MINI → attach a HealthBar3D above the head, starting full.
func configure_boss(kind: int, p_name: String = "") -> void:
	boss_kind = kind
	boss_name = p_name
	if kind == BossKind.BIG:
		GameEvents.boss_spawned.emit(p_name, data.max_hp)
	elif kind == BossKind.MINI:
		_health_bar = HealthBar3D.new()
		add_child(_health_bar)
		_health_bar.position = Vector3(0.0, MINI_BOSS_BAR_OFFSET_Y, 0.0)
		_health_bar.set_ratio(1.0)
```

- [ ] **Step 5: Extend `take_damage()`**

In `enemies/enemy_3d.gd`, replace the body of `take_damage()` (~line 143-154) with:

```gdscript
func take_damage(amount: float) -> void:
	if data == null:
		return
	hp -= amount
	if hp <= 0.0:
		# Big boss announces death so the HUD bar hides before the node is freed.
		if boss_kind == BossKind.BIG:
			GameEvents.boss_died.emit()
		# Death visuals handled by Juice3D / HitFlash3D + the death pop particle;
		# _play_anim("die") would never render because queue_free() follows immediately.
		GameEvents.enemy_killed_3d.emit(global_position, data.xp_value)
		queue_free()
		return
	# Non-lethal hit: drive boss HP feedback, then flash.
	if boss_kind == BossKind.BIG:
		GameEvents.boss_hp_changed.emit(hp, data.max_hp)
	elif boss_kind == BossKind.MINI and is_instance_valid(_health_bar):
		_health_bar.set_ratio(hp / data.max_hp)
	# Non-lethal hit: flash the enemy mesh white for 0.08 s.
	HitFlash3D.flash(self, 0.08)
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_enemy_3d.gd -gexit`
Expected: PASS (all enemy tests, including the 8 new boss tests).

- [ ] **Step 7: Commit**

```bash
git add enemies/enemy_3d.gd test/test_enemy_3d.gd
git commit -m "feat(enemy): boss tagging + HP-bar feedback in take_damage"
```

---

### Task 4: Spawner tags bosses

**Files:**
- Modify: `spawning/spawner_3d.gd` (`_spawn_boss` ~line 179-199, `_spawn_big_boss` ~line 202-221)
- Test: `test/test_spawner_3d.gd` (append)

**Interfaces:**
- Consumes: `Enemy3D.configure_boss` + `Enemy3D.BossKind` (Task 3).
- Produces: spawned mini-boss has `boss_kind == MINI` + a `HealthBar3D` child; spawned big boss has `boss_kind == BIG` and emits `boss_spawned`.

- [ ] **Step 1: Write the failing tests**

Append to `test/test_spawner_3d.gd`:

```gdscript
# ── boss spawn wiring (configure_boss tagging) ────────────────────────────────

## Build a Spawner3D under a non-root container (so _instance_enemy's parent assert
## passes and spawned enemies land in the container), wired to a dummy target.
func _make_active_spawner() -> Spawner3D:
	var container: Node3D = add_child_autofree(Node3D.new())
	var spawner := Spawner3D.new()
	container.add_child(spawner)
	var target: Node3D = add_child_autofree(Node3D.new())
	spawner.setup(target)
	return spawner

func _first_enemy_in(spawner: Spawner3D) -> Enemy3D:
	for child in spawner.get_parent().get_children():
		if child is Enemy3D:
			return child as Enemy3D
	return null

func test_spawn_boss_tags_enemy_as_mini() -> void:
	var spawner := _make_active_spawner()
	spawner._spawn_boss(1.0)
	var boss := _first_enemy_in(spawner)
	assert_not_null(boss, "a mini-boss enemy must be spawned")
	assert_eq(boss.boss_kind, Enemy3D.BossKind.MINI, "mini-boss tagged MINI")
	assert_not_null(boss._health_bar, "mini-boss must carry a HealthBar3D")

func test_spawn_big_boss_tags_enemy_as_big_and_emits() -> void:
	var spawner := _make_active_spawner()
	watch_signals(GameEvents)
	spawner._spawn_big_boss(1.0)
	var boss := _first_enemy_in(spawner)
	assert_not_null(boss, "a big-boss enemy must be spawned")
	assert_eq(boss.boss_kind, Enemy3D.BossKind.BIG, "big-boss tagged BIG")
	assert_signal_emitted(GameEvents, "boss_spawned")
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_spawner_3d.gd -gexit`
Expected: FAIL (`boss_kind` stays NONE / `_health_bar` null — `configure_boss` not yet called).

- [ ] **Step 3: Wire the mini-boss**

In `spawning/spawner_3d.gd` `_spawn_boss()`, inside the `if boss != null:` block, after the `apply_model_tint(...)` call, add:

```gdscript
		boss.configure_boss(Enemy3D.BossKind.MINI)
```

- [ ] **Step 4: Wire the big boss**

In `spawning/spawner_3d.gd` `_spawn_big_boss()`, inside the `if boss != null:` block, after the `apply_model_tint(...)` call, add:

```gdscript
		boss.configure_boss(Enemy3D.BossKind.BIG, "Undead Serpent")
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_spawner_3d.gd -gexit`
Expected: PASS (all spawner tests, including the 2 new ones).

- [ ] **Step 6: Commit**

```bash
git add spawning/spawner_3d.gd test/test_spawner_3d.gd
git commit -m "feat(spawner): tag mini/big bosses via configure_boss"
```

---

### Task 5: HUD big-boss screen bar

**Files:**
- Modify: `ui/hud.tscn` (add `BossBar` subtree; reuse existing HP `StyleBoxFlat` sub-resources)
- Modify: `ui/hud.gd` (`@onready` refs + signal handlers)
- Test: `test/test_hud.gd` (create)

**Interfaces:**
- Consumes: `GameEvents.boss_spawned/boss_hp_changed/boss_died` (Task 1).
- Produces: HUD node `BossBar` (hidden by default) with children `BossNameLabel`, `BossHPBar`, `BossHPBar/BossHPText`; handlers `_on_boss_spawned`, `_on_boss_hp_changed`, `_on_boss_died`.

- [ ] **Step 1: Write the failing test**

Create `test/test_hud.gd`:

```gdscript
extends GutTest
## Verifies the HUD's top-center big-boss bar reacts to GameEvents boss signals.

var HUDScene = null

func before_all() -> void:
	HUDScene = load("res://ui/hud.tscn")

func _make_hud() -> CanvasLayer:
	var hud: CanvasLayer = add_child_autofree(HUDScene.instantiate()) as CanvasLayer
	return hud

func test_boss_bar_hidden_by_default() -> void:
	var hud := _make_hud()
	var bar := hud.get_node("BossBar") as Control
	assert_not_null(bar, "BossBar node must exist")
	assert_false(bar.visible, "BossBar must be hidden until a boss spawns")

func test_boss_spawned_shows_bar_with_name_and_max() -> void:
	var hud := _make_hud()
	GameEvents.boss_spawned.emit("Undead Serpent", 2000.0)
	var bar := hud.get_node("BossBar") as Control
	var name_label := hud.get_node("BossBar/BossNameLabel") as Label
	var hp_bar := hud.get_node("BossBar/BossHPBar") as ProgressBar
	assert_true(bar.visible, "BossBar must show on boss_spawned")
	assert_eq(name_label.text, "Undead Serpent", "boss name displayed")
	assert_almost_eq(hp_bar.max_value, 2000.0, 0.001, "bar max set to boss max hp")
	assert_almost_eq(hp_bar.value, 2000.0, 0.001, "bar starts full")

func test_boss_hp_changed_updates_value_and_text() -> void:
	var hud := _make_hud()
	GameEvents.boss_spawned.emit("Undead Serpent", 2000.0)
	GameEvents.boss_hp_changed.emit(750.0, 2000.0)
	var hp_bar := hud.get_node("BossBar/BossHPBar") as ProgressBar
	var hp_text := hud.get_node("BossBar/BossHPBar/BossHPText") as Label
	assert_almost_eq(hp_bar.value, 750.0, 0.001, "bar value tracks current hp")
	assert_eq(hp_text.text, "750 / 2000", "numeric readout shows cur / max")

func test_boss_died_hides_bar() -> void:
	var hud := _make_hud()
	GameEvents.boss_spawned.emit("Undead Serpent", 2000.0)
	GameEvents.boss_died.emit()
	var bar := hud.get_node("BossBar") as Control
	assert_false(bar.visible, "BossBar hides on boss_died")
```

- [ ] **Step 2: Run test to verify it fails**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_hud.gd -gexit`
Expected: FAIL (`BossBar` node not found).

- [ ] **Step 3: Add the BossBar subtree to `ui/hud.tscn`**

In `ui/hud.tscn`, append these nodes after the `EvolveBanner` node block (the existing `StyleBoxFlat_hpbg` / `StyleBoxFlat_hpfill` sub-resources are reused for the boss bar):

```
[node name="BossBar" type="VBoxContainer" parent="."]
visible = false
anchor_left = 0.5
anchor_right = 0.5
offset_left = -320.0
offset_top = 10.0
offset_right = 320.0
offset_bottom = 64.0
grow_horizontal = 2
theme_override_constants/separation = 2
alignment = 1

[node name="BossNameLabel" type="Label" parent="BossBar"]
text = "Boss"
horizontal_alignment = 1
theme_override_font_sizes/font_size = 20

[node name="BossHPBar" type="ProgressBar" parent="BossBar"]
custom_minimum_size = Vector2(640, 26)
max_value = 100.0
value = 100.0
show_percentage = false
theme_override_styles/background = SubResource("StyleBoxFlat_hpbg")
theme_override_styles/fill = SubResource("StyleBoxFlat_hpfill")

[node name="BossHPText" type="Label" parent="BossBar/BossHPBar"]
anchor_right = 1.0
anchor_bottom = 1.0
mouse_filter = 2
text = "0 / 0"
horizontal_alignment = 1
vertical_alignment = 1
```

- [ ] **Step 4: Add refs + handlers to `ui/hud.gd`**

In `ui/hud.gd`, add `@onready` refs after the existing `_evolve_banner` ref (~line 12):

```gdscript
@onready var _boss_bar:     Control     = $BossBar
@onready var _boss_name:    Label       = $BossBar/BossNameLabel
@onready var _boss_hp_bar:  ProgressBar = $BossBar/BossHPBar
@onready var _boss_hp_text: Label       = $BossBar/BossHPBar/BossHPText
```

In `_ready()`, after the existing `GameEvents.evolution_unlocked.connect(...)` line, add:

```gdscript
	GameEvents.boss_spawned.connect(_on_boss_spawned)
	GameEvents.boss_hp_changed.connect(_on_boss_hp_changed)
	GameEvents.boss_died.connect(_on_boss_died)
```

At the end of the file, add the handlers:

```gdscript
func _on_boss_spawned(boss_name: String, max_hp: float) -> void:
	_boss_name.text = boss_name
	_boss_hp_bar.max_value = max_hp
	_boss_hp_bar.value = max_hp
	_boss_hp_text.text = "%d / %d" % [int(max_hp), int(max_hp)]
	_boss_bar.visible = true

func _on_boss_hp_changed(current: float, max_hp: float) -> void:
	_boss_hp_bar.max_value = max_hp
	_boss_hp_bar.value = current
	_boss_hp_text.text = "%d / %d" % [int(max(current, 0.0)), int(max_hp)]

func _on_boss_died() -> void:
	_boss_bar.visible = false
```

- [ ] **Step 5: Run test to verify it passes**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gtest=res://test/test_hud.gd -gexit`
Expected: PASS (4/4).

- [ ] **Step 6: Run the full suite (no regressions)**

Run: `godot --headless -d -s addons/gut/gut_cmdln.gd -gdir=res://test -gexit`
Expected: All tests pass.

- [ ] **Step 7: Commit**

```bash
git add ui/hud.tscn ui/hud.gd test/test_hud.gd
git commit -m "feat(hud): top-center big-boss HP bar (name + cur/max)"
```

---

## Self-Review

**Spec coverage:**
- Big-boss screen bar (name + bar + cur/max) → Task 1 (signals) + Task 5 (HUD). ✓
- Mini-boss floating head bar, always visible → Task 2 (HealthBar3D) + Task 3 (configure_boss MINI) + Task 4 (spawner). ✓
- Normal enemies no bar → Task 3 tests `test_normal_enemy_has_no_health_bar_child` + `test_normal_enemy_damage_emits_no_boss_signals`. ✓
- Boss identity marker + take_damage hooks → Task 3. ✓
- Spawner wiring → Task 4. ✓
- Data flow / edge cases (death hides bar; clamp; guard valid; no collision impact) → Task 2 (`no_depth_test`, clamp, visual-only Node3D) + Task 3 (boss_died before queue_free, `is_instance_valid` guard). ✓
- Testing plan → tasks include all four listed test files. ✓

**Placeholder scan:** No TBD/TODO/"handle edge cases"; every code step shows full code. ✓

**Type consistency:** `configure_boss(kind: int, p_name: String)`, `BossKind { NONE, MINI, BIG }`, `set_ratio`, `compute_fill_scale`, `_fill_pivot`, `_health_bar`, `_boss_bar/_boss_name/_boss_hp_bar/_boss_hp_text`, signal names `boss_spawned/boss_hp_changed/boss_died` — all consistent across tasks. ✓
