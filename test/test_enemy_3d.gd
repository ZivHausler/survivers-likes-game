# See docs/notes/enemy-3d.md
extends GutTest
## Unit tests for Enemy3D — mirrors test_enemy.gd coverage against CharacterBody3D.
## Physics-process helpers are called directly (headless); move_and_slide() is a no-op
## without a live physics world, so we inspect velocity before it would be consumed.

## Stub target with a recordable take_damage method.
class StubTarget extends Node3D:
	var damage_log: Array = []
	func take_damage(amount: float) -> void:
		damage_log.append(amount)

var Enemy3DScene = null

func before_all() -> void:
	Enemy3DScene = load("res://enemies/enemy_3d.tscn")

func _make_data(max_hp: float = 20.0, xp: int = 3, is_ranged: bool = false) -> EnemyData:
	var d := EnemyData.new()
	d.id = &"test_enemy_3d"
	d.color = Color.RED
	d.max_hp = max_hp
	d.move_speed = 5.0
	d.contact_damage = 4.0
	d.xp_value = xp
	d.is_ranged = is_ranged
	d.radius = 0.5
	return d

func _make_enemy(max_hp: float = 20.0, xp: int = 3, is_ranged: bool = false) -> Enemy3D:
	assert_not_null(Enemy3DScene, "enemy_3d.tscn must exist")
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
	e.setup(_make_data(max_hp, xp, is_ranged), target)
	return e

# ── setup sets hp ────────────────────────────────────────────────────────────

func test_setup_sets_hp_to_max_hp() -> void:
	var e: Enemy3D = _make_enemy(30.0)
	assert_almost_eq(e.hp, 30.0, 0.001, "hp should equal data.max_hp after setup")

# ── steer_velocity static helper ──────────────────────────────────────────────

func test_steer_velocity_toward_positive_x() -> void:
	var v := Enemy3D.steer_velocity(Vector3.ZERO, Vector3(10.0, 0.0, 0.0), 5.0)
	assert_almost_eq(v.x, 5.0, 0.001, "x velocity should be speed")
	assert_almost_eq(v.y, 0.0, 0.001, "y must stay 0 (XZ plane)")
	assert_almost_eq(v.z, 0.0, 0.001, "z should be 0")

func test_steer_velocity_toward_positive_z() -> void:
	var v := Enemy3D.steer_velocity(Vector3.ZERO, Vector3(0.0, 0.0, 10.0), 5.0)
	assert_almost_eq(v.x, 0.0, 0.001, "x should be 0")
	assert_almost_eq(v.y, 0.0, 0.001, "y must stay 0")
	assert_almost_eq(v.z, 5.0, 0.001, "z velocity should be speed")

func test_steer_velocity_y_always_zero_even_with_height_difference() -> void:
	var v := Enemy3D.steer_velocity(Vector3(0.0, 0.0, 0.0), Vector3(0.0, 10.0, 5.0), 5.0)
	assert_almost_eq(v.y, 0.0, 0.001, "y must always be 0 regardless of height difference")

func test_steer_velocity_diagonal_is_normalized_times_speed() -> void:
	var v := Enemy3D.steer_velocity(Vector3.ZERO, Vector3(10.0, 0.0, 10.0), 5.0)
	var expected_component := 5.0 / sqrt(2.0)
	assert_almost_eq(v.x, expected_component, 0.01, "diagonal x normalized × speed")
	assert_almost_eq(v.z, expected_component, 0.01, "diagonal z normalized × speed")
	assert_almost_eq(v.y, 0.0, 0.001, "y must stay 0")

func test_steer_velocity_same_position_returns_zero() -> void:
	var v := Enemy3D.steer_velocity(Vector3(1.0, 0.0, 1.0), Vector3(1.0, 0.0, 1.0), 5.0)
	assert_eq(v, Vector3.ZERO, "zero distance → zero velocity")

func test_steer_velocity_zero_speed_returns_zero() -> void:
	var v := Enemy3D.steer_velocity(Vector3.ZERO, Vector3(5.0, 0.0, 0.0), 0.0)
	assert_eq(v, Vector3.ZERO, "zero speed → zero velocity")

# ── charm suppresses movement ─────────────────────────────────────────────────

func test_charm_stacks_by_max() -> void:
	var e: Enemy3D = _make_enemy()
	e.charm(2.0)
	e.charm(1.0)  # shorter, should not reduce timer
	assert_almost_eq(e._charm_timer, 2.0, 0.001, "charm stacks by taking the max")

func test_charm_keeps_velocity_zero_while_active() -> void:
	var e: Enemy3D = _make_enemy()
	e.charm(1.0)
	e.target.global_position = Vector3(5.0, 0.0, 0.0)
	e._physics_process(0.1)  # 0.9 s charm remaining
	assert_eq(e.velocity, Vector3.ZERO, "velocity must be zero while charmed")

func test_charm_expires_enemy_moves_toward_target() -> void:
	var e: Enemy3D = _make_enemy()
	e.charm(0.5)
	e.target.global_position = Vector3(10.0, 0.0, 0.0)
	# Tick past charm expiry — 0.6 s > 0.5 s charm
	e._physics_process(0.6)
	assert_true(e.velocity.x > 0.0, "enemy should move toward +X after charm expires")
	assert_almost_eq(e.velocity.y, 0.0, 0.001, "y velocity must stay 0 after charm")

# ── contact damage ────────────────────────────────────────────────────────────

func test_contact_damage_called_when_in_range() -> void:
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var stub: StubTarget = add_child_autofree(StubTarget.new()) as StubTarget
	e.setup(_make_data(20.0, 3), stub)
	# Both at origin → dist = 0 < CONTACT_RANGE = 1.5
	e._physics_process(0.016)
	assert_eq(stub.damage_log.size(), 1, "take_damage should be called once")
	assert_almost_eq(stub.damage_log[0], 4.0, 0.001, "contact_damage value should match data")

func test_contact_damage_cooldown_prevents_immediate_repeat() -> void:
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var stub: StubTarget = add_child_autofree(StubTarget.new()) as StubTarget
	e.setup(_make_data(20.0, 3), stub)
	e._physics_process(0.016)  # first hit
	e._physics_process(0.016)  # cooldown not elapsed (0.5 s)
	assert_eq(stub.damage_log.size(), 1, "second tick within cooldown must not deal damage")

func test_contact_damage_fires_again_after_cooldown_elapses() -> void:
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var stub: StubTarget = add_child_autofree(StubTarget.new()) as StubTarget
	e.setup(_make_data(20.0, 3), stub)
	e._physics_process(0.016)   # first hit, _contact_cd = 0.5
	e._physics_process(0.5)     # advances cd to 0 exactly: max(0, 0.5 - 0.5) = 0 → second hit
	assert_eq(stub.damage_log.size(), 2, "second hit should fire after cooldown elapses")

# ── take_damage / death ───────────────────────────────────────────────────────

func test_take_damage_reduces_hp() -> void:
	var e: Enemy3D = _make_enemy(20.0)
	e.take_damage(7.0)
	assert_almost_eq(e.hp, 13.0, 0.001, "hp should be 13 after 7 damage on 20hp enemy")

func test_nonlethal_damage_does_not_emit_enemy_killed_3d() -> void:
	var e: Enemy3D = _make_enemy(20.0, 3)
	watch_signals(GameEvents)
	e.take_damage(10.0)
	assert_signal_not_emitted(GameEvents, "enemy_killed_3d")

func test_nonlethal_damage_does_not_free_node() -> void:
	var e: Enemy3D = _make_enemy(20.0)
	e.take_damage(5.0)
	assert_true(is_instance_valid(e), "enemy should still be alive after non-lethal damage")

func test_lethal_damage_emits_enemy_killed_3d() -> void:
	var e: Enemy3D = _make_enemy(20.0, 3)
	watch_signals(GameEvents)
	e.take_damage(20.0)
	assert_signal_emitted(GameEvents, "enemy_killed_3d")

func test_lethal_damage_emits_correct_xp_value() -> void:
	var e: Enemy3D = _make_enemy(20.0, 7)
	var expected_pos: Vector3 = e.global_position
	watch_signals(GameEvents)
	e.take_damage(25.0)
	assert_signal_emitted_with_parameters(GameEvents, "enemy_killed_3d", [expected_pos, 7])

func test_overkill_emits_enemy_killed_3d() -> void:
	var e: Enemy3D = _make_enemy(20.0, 3)
	watch_signals(GameEvents)
	e.take_damage(999.0)
	assert_signal_emitted(GameEvents, "enemy_killed_3d")

func test_lethal_damage_frees_node() -> void:
	var e: Enemy3D = _make_enemy(20.0)
	e.take_damage(20.0)
	await get_tree().process_frame
	assert_false(is_instance_valid(e), "enemy should be freed after lethal damage")

# ── null / freed-target guards ────────────────────────────────────────────────

func test_physics_process_before_setup_does_not_crash() -> void:
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	e._physics_process(0.016)
	assert_true(true, "no crash when _physics_process runs before setup()")

func test_physics_process_with_freed_target_does_not_crash() -> void:
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var doomed: Node3D = Node3D.new()
	add_child(doomed)
	e.setup(_make_data(20.0, 3), doomed)
	doomed.free()
	e._physics_process(0.016)
	assert_true(true, "no crash when _physics_process runs with a freed target")

# ── ranged stand-off ──────────────────────────────────────────────────────────

func test_ranged_standoff_gives_zero_speed_when_too_close() -> void:
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
	e.setup(_make_data(20.0, 3, true), target)
	# Place target 3 units away — within RANGED_STANDOFF (6.0)
	target.global_position = Vector3(3.0, 0.0, 0.0)
	e._physics_process(0.016)
	assert_eq(e.velocity, Vector3.ZERO, "ranged enemy within stand-off should not move")

func test_ranged_enemy_outside_standoff_moves_toward_target() -> void:
	var e: Enemy3D = add_child_autofree(Enemy3DScene.instantiate()) as Enemy3D
	var target: Node3D = add_child_autofree(Node3D.new()) as Node3D
	e.setup(_make_data(20.0, 3, true), target)
	# Place target 10 units away — beyond RANGED_STANDOFF (6.0)
	target.global_position = Vector3(10.0, 0.0, 0.0)
	e._physics_process(0.016)
	assert_true(e.velocity.x > 0.0, "ranged enemy beyond stand-off should move toward target")
