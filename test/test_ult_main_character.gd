extends GutTest
## Main Character Moment charms nearby enemies but not far ones on activate.

class _Enemy extends Node3D:
	var charmed_duration := 0.0
	var charm_called := false
	func _init() -> void:
		add_to_group("enemies")
	func charm(duration: float) -> void:
		charm_called = true
		charmed_duration = duration

func test_activate_charms_near_enemy_not_far() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_main_character_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)
	var near := _Enemy.new()
	add_child_autofree(near)
	near.global_position = Vector3(2, 0, 0)
	var far := _Enemy.new()
	add_child_autofree(far)
	far.global_position = Vector3(999, 0, 0)
	assert_true(ult.activate(), "fires when ready")
	assert_true(near.charm_called, "nearby enemy was charmed")
	assert_false(far.charm_called, "far enemy not charmed")

func test_resource_wires_to_ziv() -> void:
	var cd: CharacterData = load("res://characters/ziv_3d.tres")
	assert_not_null(cd.ultimate, "Ziv has an ultimate")
	assert_not_null(cd.ultimate.weapon_scene, "ultimate has a weapon_scene")
