extends GutTest
## Unit tests for Enemy take_damage and death logic.
## Contact-damage path (physics overlap with player) requires interactive playtest.

var EnemyScene = null

func before_all() -> void:
	EnemyScene = load("res://enemies/enemy.tscn")

func _make_data(max_hp: float = 20.0, xp: int = 3) -> EnemyData:
	var d := EnemyData.new()
	d.id = &"test_enemy"
	d.color = Color.WHITE
	d.max_hp = max_hp
	d.move_speed = 80.0
	d.contact_damage = 5.0
	d.xp_value = xp
	d.is_ranged = false
	d.radius = 8.0
	return d

func _make_enemy(max_hp: float = 20.0, xp: int = 3) -> Enemy:
	assert_not_null(EnemyScene, "enemy.tscn must exist")
	var e: Enemy = add_child_autofree(EnemyScene.instantiate()) as Enemy
	# setup with a dummy target node
	var dummy: Node2D = add_child_autofree(Node2D.new()) as Node2D
	e.setup(_make_data(max_hp, xp), dummy)
	return e

# ── take_damage reduces hp ───────────────────────────────────────────────────

func test_take_damage_reduces_hp() -> void:
	var e: Enemy = _make_enemy(20.0)
	e.take_damage(5.0)
	assert_almost_eq(e.hp, 15.0, 0.001, "hp should be 15 after 5 damage on 20hp enemy")

func test_nonlethal_damage_does_not_emit_enemy_killed() -> void:
	var e: Enemy = _make_enemy(20.0, 3)
	watch_signals(GameEvents)
	e.take_damage(10.0)  # non-lethal: hp 20 -> 10
	assert_signal_not_emitted(GameEvents, "enemy_killed")

func test_nonlethal_damage_does_not_free_node() -> void:
	var e: Enemy = _make_enemy(20.0)
	e.take_damage(5.0)
	assert_true(is_instance_valid(e), "enemy should still be alive after non-lethal damage")

# ── lethal damage ────────────────────────────────────────────────────────────

func test_lethal_damage_emits_enemy_killed_with_xp() -> void:
	var e: Enemy = _make_enemy(20.0, 3)
	watch_signals(GameEvents)
	e.take_damage(20.0)  # exactly lethal
	assert_signal_emitted(GameEvents, "enemy_killed")

func test_lethal_damage_emits_correct_xp_value() -> void:
	var e: Enemy = _make_enemy(20.0, 7)
	var expected_pos: Vector2 = e.global_position
	watch_signals(GameEvents)
	e.take_damage(25.0)  # overkill
	assert_signal_emitted_with_parameters(GameEvents, "enemy_killed", [expected_pos, 7])

func test_overkill_emits_enemy_killed() -> void:
	var e: Enemy = _make_enemy(20.0, 3)
	watch_signals(GameEvents)
	e.take_damage(999.0)
	assert_signal_emitted(GameEvents, "enemy_killed")

func test_lethal_damage_frees_node() -> void:
	var e: Enemy = _make_enemy(20.0)
	e.take_damage(20.0)
	# queue_free schedules removal; after process the node is freed
	await get_tree().process_frame
	assert_false(is_instance_valid(e), "enemy should be freed after lethal damage")

# ── null guard: no crash before setup ───────────────────────────────────────

func test_physics_process_before_setup_does_not_crash() -> void:
	var e: Enemy = add_child_autofree(EnemyScene.instantiate()) as Enemy
	# do NOT call setup — data is null; _physics_process should return early
	# If this doesn't crash, the guard works
	e._physics_process(0.016)
	assert_true(true, "no crash when _physics_process runs before setup()")
