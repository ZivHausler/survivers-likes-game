extends GutTest
## Tests for Juice visual effects — Wave C implementation.
## Covers: DamageNumber setup/lifetime, ScreenShake math/decay,
## HitFlash modulate, and Juice handler guards + effect spawning.

var _DamageNumberScene: PackedScene = null
var _DeathPopScene: PackedScene = null

func before_all() -> void:
	_DamageNumberScene = load("res://vfx/damage_number.tscn")
	_DeathPopScene = load("res://vfx/death_pop.tscn")

func after_each() -> void:
	# Reset Juice singleton state to avoid cross-test contamination
	Juice.register_player(null)
	Juice.register_camera(null)

# ── DamageNumber ─────────────────────────────────────────────────────────────

func test_damage_number_scenes_load() -> void:
	assert_not_null(_DamageNumberScene, "damage_number.tscn must load")

func test_damage_number_setup_sets_text() -> void:
	var dn: DamageNumber = add_child_autofree(_DamageNumberScene.instantiate())
	dn.setup(42, Vector2.ZERO)
	assert_eq(dn.text, "42", "setup() must set text to the amount")

func test_damage_number_setup_sets_position() -> void:
	var dn: DamageNumber = add_child_autofree(_DamageNumberScene.instantiate())
	dn.setup(10, Vector2(100.0, 200.0))
	assert_almost_eq(dn.global_position.x, 100.0, 0.5, "X position should match pos arg")

func test_damage_number_frees_after_lifetime() -> void:
	var dn: DamageNumber = add_child_autofree(_DamageNumberScene.instantiate())
	dn.setup(7, Vector2.ZERO)
	await get_tree().create_timer(DamageNumber.LIFETIME + 0.3).timeout
	assert_false(is_instance_valid(dn), "DamageNumber must queue_free after LIFETIME")

# ── ScreenShake (pure math, no camera needed) ────────────────────────────────

func test_screen_shake_zero_trauma_returns_zero_offset() -> void:
	var off: Vector2 = ScreenShake._offset_for(0.0, 1.0)
	assert_eq(off, Vector2.ZERO, "Zero trauma must produce zero offset")

func test_screen_shake_higher_trauma_larger_magnitude() -> void:
	var low: float = ScreenShake._offset_for(0.3, 1.0).length()
	var high: float = ScreenShake._offset_for(0.9, 1.0).length()
	assert_gt(high, low, "Higher trauma must produce larger offset magnitude")

func test_screen_shake_trauma_scales_quadratically() -> void:
	# At t=1.0 both use same angle, so magnitude ratio ~ trauma^2 ratio
	var m1: float = ScreenShake._offset_for(0.5, 1.0).length()
	var m2: float = ScreenShake._offset_for(1.0, 1.0).length()
	assert_almost_eq(m2 / m1, 4.0, 0.5, "Magnitude roughly quadruples when trauma doubles (^2)")

func test_screen_shake_add_trauma_clamps_to_one() -> void:
	var shake: ScreenShake = add_child_autofree(ScreenShake.new())
	shake.add_trauma(0.8)
	shake.add_trauma(0.8)  # would be 1.6 without clamp
	assert_almost_eq(shake.trauma, 1.0, 0.001, "Trauma must be clamped to 1.0")

func test_screen_shake_trauma_decays_each_frame() -> void:
	var shake: ScreenShake = add_child_autofree(ScreenShake.new())
	shake.add_trauma(1.0)
	shake._process(0.1)
	assert_lt(shake.trauma, 1.0, "Trauma must decay after _process(dt)")

func test_screen_shake_trauma_decays_to_zero() -> void:
	var shake: ScreenShake = add_child_autofree(ScreenShake.new())
	shake.add_trauma(0.3)
	shake._process(1.0)  # 1 second of decay > 0.3 / 2.5 = 0.12s needed
	assert_almost_eq(shake.trauma, 0.0, 0.001, "Trauma must reach 0 after enough time")

# ── HitFlash ──────────────────────────────────────────────────────────────────

func test_hit_flash_no_crash_on_invalid_node() -> void:
	var rect: ColorRect = ColorRect.new()
	rect.free()  # freed before flash
	HitFlash.flash(rect, 0.2)
	assert_true(true, "HitFlash.flash must not crash on an invalid CanvasItem")

func test_hit_flash_changes_modulate_from_original() -> void:
	var rect: ColorRect = add_child_autofree(ColorRect.new())
	rect.modulate = Color(0.4, 0.4, 0.4, 1.0)  # gray — not white
	HitFlash.flash(rect, 0.5)
	await get_tree().process_frame
	# One frame in, tween has nudged modulate toward white
	assert_ne(rect.modulate, Color(0.4, 0.4, 0.4, 1.0),
		"modulate must differ from original after flash starts")

# ── Juice handler guards ──────────────────────────────────────────────────────

func test_enemy_killed_no_player_no_crash_no_spawn() -> void:
	# No player registered — guard must prevent spawning and crashing
	var root: Node = get_tree().root
	var before: int = root.get_child_count()
	GameEvents.enemy_killed.emit(Vector2.ZERO, 5)
	await get_tree().process_frame
	assert_eq(root.get_child_count(), before, "No nodes added to root without player")

func test_player_hp_changed_decrease_no_player_no_crash() -> void:
	# Force a decrease path with no player — must not crash
	Juice._last_hp = 100.0
	GameEvents.player_hp_changed.emit(50.0, 100.0)
	await get_tree().process_frame
	assert_true(true, "hp_changed decrease must not crash without player/camera")

# ── Juice effect spawning with player registered ──────────────────────────────

func _effect_parent() -> Node:
	# Match Juice._safe_parent() logic: prefer current_scene, fall back to root
	var cs := get_tree().current_scene
	return cs if cs != null else get_tree().root

func test_enemy_killed_with_player_spawns_death_pop() -> void:
	var dummy: Node2D = add_child_autofree(Node2D.new())
	Juice.register_player(dummy)
	var parent: Node = _effect_parent()
	var before: int = parent.get_children().filter(func(c: Node) -> bool:
		return c is DeathPop).size()
	GameEvents.enemy_killed.emit(Vector2(50.0, 50.0), 3)
	await get_tree().process_frame
	var after: int = parent.get_children().filter(func(c: Node) -> bool:
		return c is DeathPop).size()
	assert_gt(after, before, "DeathPop must be spawned in scene when player is registered")

func test_enemy_killed_with_player_spawns_damage_number() -> void:
	var dummy: Node2D = add_child_autofree(Node2D.new())
	Juice.register_player(dummy)
	var parent: Node = _effect_parent()
	var before: int = parent.get_children().filter(func(c: Node) -> bool:
		return c is DamageNumber).size()
	GameEvents.enemy_killed.emit(Vector2(50.0, 50.0), 7)
	await get_tree().process_frame
	var after: int = parent.get_children().filter(func(c: Node) -> bool:
		return c is DamageNumber).size()
	assert_gt(after, before, "DamageNumber must be spawned in scene when player is registered")
