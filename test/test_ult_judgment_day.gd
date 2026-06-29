extends GutTest
## Judgment Day damages all enemies within radius on activate.

class _Enemy extends Node3D:
	var hp := 100.0
	var dead := false
	func _init() -> void:
		add_to_group("enemies")
	func take_damage(d: float) -> void:
		hp -= d
		if hp <= 0: dead = true

func test_activate_damages_enemies_in_radius() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_judgment_day_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)                 # manual mode
	var near := _Enemy.new(); add_child_autofree(near); near.global_position = Vector3(2, 0, 0)
	var far := _Enemy.new();  add_child_autofree(far);  far.global_position = Vector3(999, 0, 0)
	assert_true(ult.activate(), "fires when ready")
	assert_true(near.hp < 100.0, "nearby enemy took damage")
	assert_eq(far.hp, 100.0, "far enemy untouched")

func test_resource_wires_to_avinoam() -> void:
	var cd: CharacterData = load("res://characters/avinoam_3d.tres")
	assert_not_null(cd.ultimate, "Avinoam has an ultimate")
	assert_not_null(cd.ultimate.weapon_scene, "ultimate has a weapon_scene")
