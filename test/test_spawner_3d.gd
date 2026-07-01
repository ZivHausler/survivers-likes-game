# See docs/notes/spawner-3d.md
extends GutTest
## Unit tests for Spawner3D.
## Focuses on the pure static helpers (ring_position, data factories) which can be
## verified without instantiating enemies or a live scene tree.
## Phase 2 additions: boss model_scene assignment, texture-preserving apply_model_tint.

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

func test_big_boss_data_move_speed_scaled_to_3d() -> void:
	var tank := load("res://enemies/tank.tres") as EnemyData
	var original_speed := tank.move_speed
	var big := Spawner3D.big_boss_enemy_data(tank, 1.0)
	assert_almost_eq(big.move_speed, original_speed * (1.0 / 16.0), 0.001,
			"big-boss move_speed must be divided by 16 in 3D world")

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

# ── boss model_scene — demon (mini) / dragon (big) assignment ─────────────────

func test_boss_enemy_data_is_a_duplicate_not_the_original() -> void:
	var tank := load("res://enemies/tank.tres") as EnemyData
	var boss := Spawner3D.boss_enemy_data(tank, 1.0)
	assert_true(boss != tank, "boss_enemy_data must return a new duplicate, not the source .tres")

func test_shared_swarmer_tres_model_scene_not_null() -> void:
	# Verify that swarmer.tres now carries a real model_scene (Phase 2 requirement).
	var swarmer := load("res://enemies/swarmer.tres") as EnemyData
	assert_not_null(swarmer.model_scene, "swarmer.tres must have model_scene set (bug_mesh.glb)")

func test_shared_spitter_tres_model_scene_not_null() -> void:
	var spitter := load("res://enemies/spitter.tres") as EnemyData
	assert_not_null(spitter.model_scene, "spitter.tres must have model_scene set (plant_mesh.glb)")

func test_shared_tank_tres_model_scene_not_null() -> void:
	var tank := load("res://enemies/tank.tres") as EnemyData
	assert_not_null(tank.model_scene, "tank.tres must have model_scene set (diatryma_mesh.glb)")

func test_shared_tank_tres_not_mutated_after_model_assignment() -> void:
	# Even if boss_enemy_data duplicates, the shared tank.tres model_scene must be untouched.
	var tank := load("res://enemies/tank.tres") as EnemyData
	var original_model := tank.model_scene
	var boss := Spawner3D.boss_enemy_data(tank, 1.0)
	# Manually assign the mini-boss demon model (as _spawn_boss does):
	boss.model_scene = load(Spawner3D.MINI_BOSS_SCENE_PATH) as PackedScene
	assert_eq(tank.model_scene, original_model,
			"Assigning model_scene to the duplicated boss must not mutate the shared tank.tres")

# ── apply_model_tint — texture-preserving tint ────────────────────────────────

func test_apply_model_tint_duplicates_material_not_replaces() -> void:
	# Create a MeshInstance3D with an existing material; tint should duplicate, not blank.
	var mi := MeshInstance3D.new()
	mi.mesh = SphereMesh.new()
	var original_mat := StandardMaterial3D.new()
	original_mat.albedo_color = Color.GREEN
	mi.set_surface_override_material(0, original_mat)
	add_child_autofree(mi)

	var tint := Color(1.0, 0.15, 0.1, 1.0)
	Spawner3D.apply_model_tint(mi, tint)

	var result_mat := mi.get_surface_override_material(0)
	assert_not_null(result_mat, "tinted surface must have an override material")
	assert_true(result_mat != original_mat, "material must be a duplicate, not the same instance")
	var bm := result_mat as BaseMaterial3D
	assert_not_null(bm, "result material must be a BaseMaterial3D")
	assert_eq(bm.albedo_color, tint, "duplicated material albedo_color must equal the tint")

func test_apply_model_tint_no_existing_material_creates_standard() -> void:
	# Surface with no material: should get a new StandardMaterial3D with the tint.
	var mi := MeshInstance3D.new()
	mi.mesh = SphereMesh.new()
	# Do NOT set any surface material — leave it null.
	add_child_autofree(mi)

	var tint := Color(0.5, 0.0, 1.0, 1.0)
	Spawner3D.apply_model_tint(mi, tint)

	var result_mat := mi.get_surface_override_material(0)
	assert_not_null(result_mat, "fallback must create a material when no existing one")
	var bm := result_mat as BaseMaterial3D
	assert_not_null(bm, "fallback must produce a BaseMaterial3D")
	assert_eq(bm.albedo_color, tint, "fallback material albedo_color must equal the tint")

func test_apply_model_tint_recurses_into_children() -> void:
	# Parent node with a MeshInstance3D child — tint should reach it recursively.
	var parent := Node3D.new()
	add_child_autofree(parent)
	var mi := MeshInstance3D.new()
	mi.mesh = SphereMesh.new()
	parent.add_child(mi)

	Spawner3D.apply_model_tint(parent, Color.RED)

	var result_mat := mi.get_surface_override_material(0)
	assert_not_null(result_mat, "apply_model_tint must reach MeshInstance3D children")
	var bm := result_mat as BaseMaterial3D
	assert_not_null(bm, "child material must be BaseMaterial3D")
	assert_eq(bm.albedo_color, Color.RED, "child surface albedo must equal the tint")

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

# ── net_id assignment (Task E1) ───────────────────────────────────────────────

func test_net_id_increments_monotonically_per_spawn() -> void:
	var spawner := _make_active_spawner()
	var data := load("res://enemies/swarmer.tres") as EnemyData
	var e1 := spawner._instance_enemy(Spawner3D.scale_enemy_data(data, 1.0), 1.0)
	var e2 := spawner._instance_enemy(Spawner3D.scale_enemy_data(data, 1.0), 1.0)
	var e3 := spawner._instance_enemy(Spawner3D.scale_enemy_data(data, 1.0), 1.0)
	assert_not_null(e1, "first enemy spawned")
	assert_not_null(e2, "second enemy spawned")
	assert_not_null(e3, "third enemy spawned")
	assert_eq(e2.net_id, e1.net_id + 1, "net_id must increment by 1 per spawn")
	assert_eq(e3.net_id, e2.net_id + 1, "net_id must increment monotonically")
	assert_true(e1.net_id != e2.net_id and e2.net_id != e3.net_id,
			"net_ids must be unique across spawns")
