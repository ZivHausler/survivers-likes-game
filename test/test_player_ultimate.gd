extends GutTest
## Player3D holds an ultimate in a dedicated slot and routes activation to it.

class _ProbeUlt extends UltimateWeapon3D:
	var fired := 0
	func _do_ult() -> void:
		fired += 1

func _player() -> Player3D:
	var p: Player3D = load("res://player/player_3d.tscn").instantiate()
	add_child_autofree(p)
	return p

func test_no_ult_by_default() -> void:
	var p := _player()
	assert_null(p.ultimate, "no ultimate until granted")
	assert_false(p.activate_ultimate(), "activate is a safe no-op with no ult")

func test_grant_and_activate() -> void:
	var p := _player()
	var scene := PackedScene.new()
	var probe := _ProbeUlt.new()
	probe.ult_cooldown = 5.0
	scene.pack(probe)
	p.grant_ultimate(scene)
	assert_not_null(p.ultimate, "ultimate granted")
	assert_true(p.activate_ultimate(), "activates when ready")
	assert_false(p.activate_ultimate(), "blocked on cooldown")
