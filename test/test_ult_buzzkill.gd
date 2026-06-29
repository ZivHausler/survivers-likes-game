extends GutTest
## Unit tests for Matan's "Buzzkill" ultimate.
## Tests: buff raises stats, revert restores exact originals, resource wires correctly.

func test_apply_buff_raises_damage_mult() -> void:
	var ult: UltBuzzkill3D = load("res://weapons/ult_buzzkill_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	stats.damage_mult = 1.0
	stats.move_speed = 5.0
	stats.fire_rate_mult = 1.0
	ult.setup(null, stats)
	# Manually point _player_ref to null so _apply_buff uses stats directly.
	# We override stats on the ult and verify via the same stat object.
	ult._apply_buff()
	assert_true(stats.damage_mult > 1.0, "damage_mult should be increased after buff")

func test_apply_buff_raises_move_speed() -> void:
	var ult: UltBuzzkill3D = load("res://weapons/ult_buzzkill_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	stats.damage_mult = 1.0
	stats.move_speed = 5.0
	stats.fire_rate_mult = 1.0
	ult.setup(null, stats)
	ult._apply_buff()
	assert_true(stats.move_speed > 5.0, "move_speed should be increased after buff")

func test_apply_buff_raises_fire_rate_mult() -> void:
	var ult: UltBuzzkill3D = load("res://weapons/ult_buzzkill_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	stats.damage_mult = 1.0
	stats.move_speed = 5.0
	stats.fire_rate_mult = 1.0
	ult.setup(null, stats)
	ult._apply_buff()
	assert_true(stats.fire_rate_mult > 1.0, "fire_rate_mult should be increased after buff")

func test_revert_buff_restores_damage_mult_exactly() -> void:
	var ult: UltBuzzkill3D = load("res://weapons/ult_buzzkill_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	stats.damage_mult = 1.0
	stats.move_speed = 5.0
	stats.fire_rate_mult = 1.0
	ult.setup(null, stats)
	ult._apply_buff()
	ult._revert_buff()
	assert_eq(stats.damage_mult, 1.0, "damage_mult should be exactly restored after revert")

func test_revert_buff_restores_move_speed_exactly() -> void:
	var ult: UltBuzzkill3D = load("res://weapons/ult_buzzkill_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	stats.damage_mult = 1.0
	stats.move_speed = 5.0
	stats.fire_rate_mult = 1.0
	ult.setup(null, stats)
	ult._apply_buff()
	ult._revert_buff()
	assert_eq(stats.move_speed, 5.0, "move_speed should be exactly restored after revert")

func test_revert_buff_restores_fire_rate_mult_exactly() -> void:
	var ult: UltBuzzkill3D = load("res://weapons/ult_buzzkill_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	stats.damage_mult = 1.0
	stats.move_speed = 5.0
	stats.fire_rate_mult = 1.0
	ult.setup(null, stats)
	ult._apply_buff()
	ult._revert_buff()
	assert_eq(stats.fire_rate_mult, 1.0, "fire_rate_mult should be exactly restored after revert")

func test_double_apply_does_not_stack() -> void:
	var ult: UltBuzzkill3D = load("res://weapons/ult_buzzkill_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	stats.damage_mult = 1.0
	stats.move_speed = 5.0
	stats.fire_rate_mult = 1.0
	ult.setup(null, stats)
	ult._apply_buff()
	var after_first := stats.damage_mult
	ult._apply_buff()
	assert_eq(stats.damage_mult, after_first, "second _apply_buff should be a no-op while buff is active")

func test_revert_without_apply_is_safe() -> void:
	var ult: UltBuzzkill3D = load("res://weapons/ult_buzzkill_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	stats.damage_mult = 1.0
	ult.setup(null, stats)
	# Should not crash or change stats.
	ult._revert_buff()
	assert_eq(stats.damage_mult, 1.0, "revert without prior apply should not change stats")

func test_resource_wires_to_matan() -> void:
	var cd: CharacterData = load("res://characters/matan_3d.tres")
	assert_not_null(cd.ultimate, "Matan should have an ultimate")
	assert_not_null(cd.ultimate.weapon_scene, "Buzzkill ultimate should have a weapon_scene")

func test_resource_id_and_type() -> void:
	var skill: SkillData = load("res://characters/ultimates/matan_buzzkill.tres")
	assert_eq(skill.id, &"matan_buzzkill", "resource id should be matan_buzzkill")
	assert_eq(skill.type, &"pest", "resource type should be pest")
