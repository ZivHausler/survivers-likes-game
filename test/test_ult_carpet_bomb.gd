extends GutTest
## Carpet Bomb: synchronous _detonate_at damages nearby enemies; far enemies
## are untouched; yinon_3d.tres wires the ultimate correctly.

class _Enemy extends Node3D:
	var hp := 100.0
	func _init() -> void:
		add_to_group("enemies")
	func take_damage(d: float) -> void:
		hp -= d

func test_detonate_at_damages_near_enemy() -> void:
	var ult: UltCarpetBomb3D = load("res://weapons/ult_carpet_bomb_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)

	var near := _Enemy.new()
	add_child_autofree(near)
	near.global_position = Vector3(1.0, 0.0, 0.0)  # well within BLAST_RADIUS (3.0)

	ult._detonate_at(Vector3.ZERO)

	assert_true(near.hp < 100.0, "nearby enemy took damage from detonation")

func test_detonate_at_does_not_damage_far_enemy() -> void:
	var ult: UltCarpetBomb3D = load("res://weapons/ult_carpet_bomb_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)

	var far := _Enemy.new()
	add_child_autofree(far)
	far.global_position = Vector3(999.0, 0.0, 0.0)  # far outside BLAST_RADIUS

	ult._detonate_at(Vector3.ZERO)

	assert_eq(far.hp, 100.0, "far enemy untouched")

func test_resource_wires_to_yinon() -> void:
	var cd: CharacterData = load("res://characters/yinon_3d.tres")
	assert_not_null(cd.ultimate, "Yinon has an ultimate")
	assert_not_null(cd.ultimate.weapon_scene, "ultimate has a weapon_scene")

func test_resource_id_and_type() -> void:
	var skill: SkillData = load("res://characters/ultimates/yinon_carpet_bomb.tres")
	assert_eq(skill.id, &"yinon_carpet_bomb", "id matches")
	assert_eq(skill.type, &"bomber", "type is bomber")
	assert_eq(skill.display_name, "Carpet Bomb", "display_name matches")
	assert_false(skill.is_signature, "is_signature is false")
