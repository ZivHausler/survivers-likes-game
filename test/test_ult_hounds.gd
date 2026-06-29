extends GutTest
## UltHounds3D: activating spawns hound minions; resource wires to Barak.

class _Enemy extends Node3D:
	var hp  := 100.0
	var dead := false
	func _init() -> void:
		add_to_group("enemies")
	func take_damage(d: float) -> void:
		hp -= d
		if hp <= 0.0:
			dead = true

func test_activate_spawns_hounds() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_hounds_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)

	# Place a dummy enemy so hounds have a target.
	var enemy := _Enemy.new()
	add_child_autofree(enemy)
	enemy.global_position = Vector3(5.0, 0.0, 0.0)

	assert_true(ult.activate(), "activate() fires when ready")

	# Hounds register themselves in the "hounds" group.
	var hounds := get_tree().get_nodes_in_group("hounds")
	assert_eq(hounds.size(), 3, "three hound minions spawned")

func test_hound_hit_now_damages_enemy() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_hounds_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)

	var enemy := _Enemy.new()
	add_child_autofree(enemy)
	enemy.global_position = Vector3(1.0, 0.0, 0.0)

	assert_true(ult.activate(), "activate() fires")

	# Use the synchronous helper on the first hound.
	var hounds := get_tree().get_nodes_in_group("hounds")
	assert_true(hounds.size() > 0, "at least one hound spawned")
	var hound = hounds[0]
	hound.hit_now(enemy)
	assert_true(enemy.hp < 100.0, "hound dealt damage via hit_now()")

func test_resource_wires_to_barak() -> void:
	var cd: CharacterData = load("res://characters/barak_3d.tres")
	assert_not_null(cd.ultimate, "Barak has an ultimate")
	assert_not_null(cd.ultimate.weapon_scene, "ultimate has a weapon_scene")

func test_resource_fields() -> void:
	var res: SkillData = load("res://characters/ultimates/barak_hounds.tres")
	assert_eq(res.id, &"barak_hounds", "id correct")
	assert_eq(res.display_name, "Release the Hounds", "display_name correct")
	assert_eq(res.type, &"pack", "type is pack")
	assert_false(res.is_signature, "not signature")
