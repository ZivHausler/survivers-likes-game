extends GutTest
## Bass Drop damages all enemies within radius on activate and shoves them outward.

class _Enemy extends Node3D:
	var hp := 100.0
	var dead := false
	func _init() -> void:
		add_to_group("enemies")
	func take_damage(d: float) -> void:
		hp -= d
		if hp <= 0:
			dead = true

func test_activate_damages_near_enemy_not_far() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_bass_drop_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)
	var near := _Enemy.new()
	add_child_autofree(near)
	near.global_position = Vector3(3.0, 0.0, 0.0)
	var far := _Enemy.new()
	add_child_autofree(far)
	far.global_position = Vector3(999.0, 0.0, 0.0)
	assert_true(ult.activate(), "fires when ready")
	assert_true(near.hp < 100.0, "nearby enemy took damage")
	assert_eq(far.hp, 100.0, "far enemy untouched")

func test_near_enemy_shoved_outward() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_bass_drop_3d.gd").new()
	add_child_autofree(ult)
	ult.setup(self, StatBlock.new())
	var enemy := _Enemy.new()
	add_child_autofree(enemy)
	enemy.global_position = Vector3(4.0, 0.0, 0.0)
	var start_x := enemy.global_position.x
	ult.activate()
	# Enemy should have been pushed further from the origin (positive X direction).
	assert_true(enemy.global_position.x > start_x, "enemy shoved outward on X")

func test_resource_wires_to_yuval() -> void:
	var cd: CharacterData = load("res://characters/yuval_3d.tres")
	assert_not_null(cd.ultimate, "Yuval has an ultimate")
	assert_not_null(cd.ultimate.weapon_scene, "ultimate has a weapon_scene")
