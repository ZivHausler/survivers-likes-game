extends GutTest
## Verifies HUD sibling-discovery works for 3D nodes via duck typing (no hard casts).
## Headless-safe: no display required — uses plain Node stubs.

func test_hud_resolves_player_via_group() -> void:
	# Build a container that acts as a scene root with HUD + fake player sibling.
	var root := Node.new()
	add_child_autofree(root)

	var hud: Node = load("res://ui/hud.tscn").instantiate()
	root.add_child(hud)

	var fake_player := Node.new()
	fake_player.add_to_group("player")
	root.add_child(fake_player)

	# Call directly instead of waiting for call_deferred to fire.
	hud._find_siblings()

	assert_true(hud.get("_player") != null,
		"HUD must resolve _player via the 'player' group (covers both Player and Player3D)")

func test_hud_resolves_game_manager3d_by_name() -> void:
	var root := Node.new()
	add_child_autofree(root)

	var hud: Node = load("res://ui/hud.tscn").instantiate()
	root.add_child(hud)

	var fake_gm := Node.new()
	fake_gm.name = "GameManager3D"
	root.add_child(fake_gm)

	hud._find_siblings()

	assert_true(hud.get("_game_manager") != null,
		"HUD must resolve _game_manager for a sibling named 'GameManager3D'")

func test_hud_resolves_game_manager_via_has_method_get_elapsed() -> void:
	var root := Node.new()
	add_child_autofree(root)

	var hud: Node = load("res://ui/hud.tscn").instantiate()
	root.add_child(hud)

	# Use the real GameManager3D script so has_method("get_elapsed") returns true.
	# Name it something that won't match the hard-coded name checks.
	var gm_script := load("res://game/game_manager_3d.gd") as GDScript
	var fake_gm := Node.new()
	fake_gm.name = "SomeOtherManager"
	fake_gm.set_script(gm_script)
	root.add_child(fake_gm)

	hud._find_siblings()

	assert_true(hud.get("_game_manager") != null,
		"HUD must find any sibling with get_elapsed() when name doesn't match known names")
