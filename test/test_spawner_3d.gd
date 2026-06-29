# See docs/notes/spawner-3d.md
extends GutTest
## Unit tests for Spawner3D.
## Focuses on the pure static helpers (ring_position, data factories) which can be
## verified without instantiating enemies or a live scene tree.

# ── ring_position static helper ───────────────────────────────────────────────

func test_ring_position_angle_zero_gives_positive_x() -> void:
	var result := Spawner3D.ring_position(Vector3.ZERO, 0.0, 25.0)
	assert_almost_eq(result.x, 25.0, 0.001, "angle=0 → origin + (radius,0,0)")
	assert_almost_eq(result.y, 0.0,  0.001, "y must be 0 (XZ plane)")
	assert_almost_eq(result.z, 0.0,  0.001, "angle=0 → z = 0")

func test_ring_position_y_always_zero() -> void:
	for angle_deg in [0, 45, 90, 135, 180, 270]:
		var angle := deg_to_rad(float(angle_deg))
		var result := Spawner3D.ring_position(Vector3.ZERO, angle, 10.0)
		assert_almost_eq(result.y, 0.0, 0.001,
				"y must be 0 for angle %d°" % angle_deg)

func test_ring_position_distance_equals_radius() -> void:
	var origin := Vector3(5.0, 0.0, 3.0)
	var radius := 25.0
	for angle_deg in [0, 60, 120, 180, 240, 300]:
		var angle := deg_to_rad(float(angle_deg))
		var result := Spawner3D.ring_position(origin, angle, radius)
		var dist := result.distance_to(origin)
		assert_true(abs(dist - radius) < 0.001,
				"distance from origin must equal radius for angle %d°" % angle_deg)

func test_ring_position_respects_origin_offset() -> void:
	var origin := Vector3(3.0, 0.0, -2.0)
	var result := Spawner3D.ring_position(origin, 0.0, 10.0)
	assert_almost_eq(result.x, origin.x + 10.0, 0.001, "x offset from origin")
	assert_almost_eq(result.z, origin.z,         0.001, "z unchanged at angle 0")

# ── scale_enemy_data — move_speed rescaling ───────────────────────────────────

func test_normal_data_move_speed_scaled_to_3d() -> void:
	var swarmer := load("res://enemies/swarmer.tres") as EnemyData
	var scaled := Spawner3D.scale_enemy_data(swarmer, 1.0)
	var expected := swarmer.move_speed * (1.0 / 16.0)
	assert_almost_eq(scaled.move_speed, expected, 0.001,
			"move_speed must be divided by 16 in 3D world")

func test_normal_data_hp_multiplied() -> void:
	var swarmer := load("res://enemies/swarmer.tres") as EnemyData
	var scaled := Spawner3D.scale_enemy_data(swarmer, 2.0)
	var expected := int(swarmer.max_hp * 2.0)
	assert_eq(scaled.max_hp, expected, "max_hp should be multiplied by hp_mult")

# ── boss data factory ─────────────────────────────────────────────────────────

func test_boss_data_hp_is_boss_mult_times_hp_mult() -> void:
	var tank := load("res://enemies/tank.tres") as EnemyData
	var boss := Spawner3D.boss_enemy_data(tank, 1.0)
	var expected := int(tank.max_hp * Spawner3D.BOSS_HP_MULT * 1.0)
	assert_eq(boss.max_hp, expected,
			"boss max_hp = base_max_hp * BOSS_HP_MULT * hp_mult")

func test_boss_data_xp_value_is_boss_xp() -> void:
	var tank := load("res://enemies/tank.tres") as EnemyData
	var boss := Spawner3D.boss_enemy_data(tank, 1.0)
	assert_eq(boss.xp_value, Spawner3D.BOSS_XP_VALUE,
			"boss xp_value must equal BOSS_XP_VALUE (50)")

func test_boss_data_move_speed_scaled_to_3d() -> void:
	var tank := load("res://enemies/tank.tres") as EnemyData
	var original_speed := tank.move_speed
	var boss := Spawner3D.boss_enemy_data(tank, 1.0)
	assert_almost_eq(boss.move_speed, original_speed * (1.0 / 16.0), 0.001,
			"boss move_speed must also be divided by 16")

# ── big-boss data factory ─────────────────────────────────────────────────────

func test_big_boss_data_hp_is_big_boss_mult_times_hp_mult() -> void:
	var tank := load("res://enemies/tank.tres") as EnemyData
	var big := Spawner3D.big_boss_enemy_data(tank, 1.5)
	var expected := int(tank.max_hp * Spawner3D.BIG_BOSS_HP_MULT * 1.5)
	assert_eq(big.max_hp, expected,
			"big-boss max_hp = base_max_hp * BIG_BOSS_HP_MULT * hp_mult")

func test_big_boss_data_xp_value_is_big_boss_xp() -> void:
	var tank := load("res://enemies/tank.tres") as EnemyData
	var big := Spawner3D.big_boss_enemy_data(tank, 1.0)
	assert_eq(big.xp_value, Spawner3D.BIG_BOSS_XP_VALUE,
			"big-boss xp_value must equal BIG_BOSS_XP_VALUE (200)")

# ── shared .tres invariant (also closes a 2D coverage gap) ───────────────────

func test_shared_swarmer_tres_not_mutated_by_scale_enemy_data() -> void:
	var swarmer := load("res://enemies/swarmer.tres") as EnemyData
	var original_speed := swarmer.move_speed
	var original_hp    := swarmer.max_hp
	var _scaled := Spawner3D.scale_enemy_data(swarmer, 2.0)
	assert_almost_eq(swarmer.move_speed, original_speed, 0.001,
			"swarmer.tres move_speed must be unchanged after scale_enemy_data()")
	assert_almost_eq(swarmer.max_hp, original_hp, 0.001,
			"swarmer.tres max_hp must be unchanged after scale_enemy_data()")

func test_shared_tank_tres_not_mutated_by_boss_enemy_data() -> void:
	var tank := load("res://enemies/tank.tres") as EnemyData
	var original_speed := tank.move_speed
	var original_hp    := tank.max_hp
	var _boss := Spawner3D.boss_enemy_data(tank, 1.0)
	assert_almost_eq(tank.move_speed, original_speed, 0.001,
			"tank.tres move_speed must be unchanged after boss_enemy_data()")
	assert_almost_eq(tank.max_hp, original_hp, 0.001,
			"tank.tres max_hp must be unchanged after boss_enemy_data()")

func test_shared_tank_tres_not_mutated_by_big_boss_enemy_data() -> void:
	var tank := load("res://enemies/tank.tres") as EnemyData
	var original_speed := tank.move_speed
	var original_hp    := tank.max_hp
	var _big := Spawner3D.big_boss_enemy_data(tank, 1.0)
	assert_almost_eq(tank.move_speed, original_speed, 0.001,
			"tank.tres move_speed must be unchanged after big_boss_enemy_data()")
	assert_almost_eq(tank.max_hp, original_hp, 0.001,
			"tank.tres max_hp must be unchanged after big_boss_enemy_data()")
