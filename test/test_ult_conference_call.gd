extends GutTest
## Conference Call: shields self, damages/knocks-back enemies in radius,
## and spawns helper blips. Wired to avihay_3d.tres.

class _Enemy extends Node3D:
	var hp := 100.0
	var dead := false
	func _init() -> void:
		add_to_group("enemies")
	func take_damage(d: float) -> void:
		hp -= d
		if hp <= 0:
			dead = true

func test_activate_damages_near_not_far_enemy() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_conference_call_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)
	var near := _Enemy.new(); add_child_autofree(near); near.global_position = Vector3(3, 0, 0)
	var far  := _Enemy.new(); add_child_autofree(far);  far.global_position  = Vector3(999, 0, 0)
	assert_true(ult.activate(), "fires when ready")
	assert_true(near.hp < 100.0, "nearby enemy took damage")
	assert_eq(far.hp, 100.0, "far enemy untouched")

func test_activate_spawns_helpers() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_conference_call_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)
	ult.activate()
	# Wait one frame so helpers are fully added to the tree.
	await get_tree().process_frame
	# Helpers are added to scene root/current_scene as Node3D named "ConferenceHelper".
	var root := get_tree().root
	var helper_count := 0
	for child in root.get_children():
		if child is Node3D and child.name == "ConferenceHelper":
			helper_count += 1
	assert_true(helper_count > 0, "at least one ConferenceHelper node was spawned")

func test_resource_wires_to_avihay() -> void:
	var cd: CharacterData = load("res://characters/avihay_3d.tres")
	assert_not_null(cd.ultimate, "Avihay has an ultimate")
	assert_not_null(cd.ultimate.weapon_scene, "ultimate has a weapon_scene")
