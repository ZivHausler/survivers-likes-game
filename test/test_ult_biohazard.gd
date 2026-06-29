extends GutTest
## Biohazard ultimate damages all enemies within radius on activate,
## leaves a poison field node, and is wired to Ido's CharacterData.

class _Enemy extends Node3D:
	var hp := 100.0
	var dead := false
	func _init() -> void:
		add_to_group("enemies")
	func take_damage(d: float) -> void:
		hp -= d
		if hp <= 0:
			dead = true

func test_activate_damages_enemies_in_radius() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_biohazard_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)                 # manual mode – no auto-fire timer
	var near := _Enemy.new(); add_child_autofree(near); near.global_position = Vector3(3, 0, 0)
	var far  := _Enemy.new(); add_child_autofree(far);  far.global_position  = Vector3(999, 0, 0)
	assert_true(ult.activate(), "fires when ready")
	assert_true(near.hp < 100.0, "nearby enemy took damage")
	assert_eq(far.hp, 100.0, "far enemy untouched")

func test_activate_spawns_poison_field() -> void:
	var ult: UltimateWeapon3D = load("res://weapons/ult_biohazard_3d.gd").new()
	add_child_autofree(ult)
	var stats := StatBlock.new()
	ult.setup(self, stats)
	ult.activate()
	# A poison field node should have been added to the current scene tree.
	# We wait one frame so add_child finishes.
	await get_tree().process_frame
	# Find any Node3D children of the root that are NOT our ult or test node –
	# the field is added to the scene root/current_scene directly.
	var root := get_tree().root
	var found_field := false
	for child in root.get_children():
		if child == ult or child == self:
			continue
		# The field is a plain Node3D with a Timer child.
		if child is Node3D and child.get_child_count() > 0:
			for sub in child.get_children():
				if sub is Timer:
					found_field = true
					break
		if found_field:
			break
	assert_true(found_field, "poison field node with Timer was spawned in scene")

func test_resource_wires_to_ido() -> void:
	var cd: CharacterData = load("res://characters/ido_3d.tres")
	assert_not_null(cd.ultimate, "Ido has an ultimate")
	assert_not_null(cd.ultimate.weapon_scene, "ultimate has a weapon_scene")
