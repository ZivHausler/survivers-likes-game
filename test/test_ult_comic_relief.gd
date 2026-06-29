extends GutTest
## Comic Relief charms nearby enemies on activate; leaves far enemies alone.
## Also verifies natali_3d.tres is correctly wired to the ultimate.

class _Enemy extends Node3D:
	var charm_called := false
	var charmed_duration := 0.0
	func _init() -> void:
		add_to_group("enemies")
	func charm(duration: float) -> void:
		charm_called = true
		charmed_duration = duration

func test_activate_charms_near_enemy_not_far() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_comic_relief_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)
	var near := _Enemy.new()
	add_child_autofree(near)
	near.global_position = Vector3(3, 0, 0)
	var far := _Enemy.new()
	add_child_autofree(far)
	far.global_position = Vector3(999, 0, 0)
	assert_true(ult.activate(), "fires when ready")
	assert_true(near.charm_called, "nearby enemy was charmed")
	assert_false(far.charm_called, "far enemy was not charmed")

func test_charm_duration_is_correct() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_comic_relief_3d.gd").new()
	add_child_autofree(ult)
	ult.setup(self, StatBlock.new())
	var near := _Enemy.new()
	add_child_autofree(near)
	near.global_position = Vector3(1, 0, 0)
	ult.activate()
	assert_eq(near.charmed_duration, 2.5, "charm duration is 2.5 s")

func test_resource_wires_to_natali() -> void:
	var cd: CharacterData = load("res://characters/natali_3d.tres")
	assert_not_null(cd.ultimate, "Natali has an ultimate")
	assert_not_null(cd.ultimate.weapon_scene, "ultimate has a weapon_scene")
