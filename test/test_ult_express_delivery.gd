extends GutTest
## Express Delivery: line strikes damage enemies in the lane, leave others untouched.

class _Enemy extends Node3D:
	var hp := 100.0
	func _init() -> void:
		add_to_group("enemies")
	func take_damage(d: float) -> void:
		hp -= d

func test_enemy_on_line_takes_damage() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_express_delivery_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)

	var on_line := _Enemy.new()
	add_child_autofree(on_line)
	on_line.global_position = Vector3(5, 0, 0)   # 5 units along +X, well inside lane

	ult._strike_line(Vector3.ZERO, Vector3.RIGHT)

	assert_true(on_line.hp < 100.0, "enemy inside lane took damage")

func test_enemy_far_off_line_not_hit() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_express_delivery_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)

	var off_line := _Enemy.new()
	add_child_autofree(off_line)
	off_line.global_position = Vector3(5, 0, 10)  # 10 units sideways — outside 2-unit corridor

	ult._strike_line(Vector3.ZERO, Vector3.RIGHT)

	assert_eq(off_line.hp, 100.0, "enemy far off line was not hit")

func test_enemy_behind_origin_not_hit() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_express_delivery_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)

	var behind := _Enemy.new()
	add_child_autofree(behind)
	behind.global_position = Vector3(-5, 0, 0)  # behind origin when striking +X

	ult._strike_line(Vector3.ZERO, Vector3.RIGHT)

	assert_eq(behind.hp, 100.0, "enemy behind origin not hit")

func test_enemy_beyond_line_length_not_hit() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_express_delivery_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)

	var far_ahead := _Enemy.new()
	add_child_autofree(far_ahead)
	far_ahead.global_position = Vector3(20, 0, 0)  # 20 > LINE_LENGTH(14), out of reach

	ult._strike_line(Vector3.ZERO, Vector3.RIGHT)

	assert_eq(far_ahead.hp, 100.0, "enemy beyond lane length not hit")

func test_resource_wires_to_yoav() -> void:
	var cd: CharacterData = load("res://characters/yoav_3d.tres")
	assert_not_null(cd.ultimate, "Yoav has an ultimate")
	assert_not_null(cd.ultimate.weapon_scene, "ultimate has a weapon_scene")
