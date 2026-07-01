extends GutTest
## Visual / style regression tests for the fresh HUD.
## Asserts styled ProgressBars (HP + XP), the EVOLVE banner, and the new node tree.

func _hud() -> Node:
	return add_child_autofree(load("res://ui/hud.tscn").instantiate())

func test_hud_process_mode_is_always() -> void:
	assert_eq(_hud().process_mode, Node.PROCESS_MODE_ALWAYS,
		"HUD root process_mode must be PROCESS_MODE_ALWAYS")

func test_hp_bar_has_fill_stylebox() -> void:
	var hp_bar: ProgressBar = _hud().get_node("Command/HP")
	assert_true(hp_bar.has_theme_stylebox_override("fill"),
		"Command/HP must have a custom fill StyleBox (danger-orange) via theme_override_styles/fill")

func test_hp_bar_has_background_stylebox() -> void:
	var hp_bar: ProgressBar = _hud().get_node("Command/HP")
	assert_true(hp_bar.has_theme_stylebox_override("background"),
		"Command/HP must have a dark background StyleBox for contrast")

func test_xp_bar_has_fill_stylebox() -> void:
	var xp_bar: ProgressBar = _hud().get_node("Top/XP")
	assert_true(xp_bar.has_theme_stylebox_override("fill"),
		"Top/XP must have a custom fill StyleBox (cyan) via theme_override_styles/fill")

func test_xp_bar_has_background_stylebox() -> void:
	var xp_bar: ProgressBar = _hud().get_node("Top/XP")
	assert_true(xp_bar.has_theme_stylebox_override("background"),
		"Top/XP must have a dark background StyleBox so the bar is visible when near-empty")

func test_evolve_banner_starts_hidden() -> void:
	var banner: Label = _hud().get_node("Evolve")
	assert_false(banner.visible, "EVOLVE banner must start hidden")

func test_evolve_banner_shown_on_evolution_unlocked() -> void:
	var hud := _hud()
	var banner: Label = hud.get_node("Evolve")
	assert_false(banner.visible, "EVOLVE banner should start hidden")
	GameEvents.evolution_unlocked.emit(&"test_weapon")
	assert_true(banner.visible,
		"EVOLVE banner must be visible immediately after evolution_unlocked is emitted")

func test_top_strip_exists() -> void:
	assert_not_null(_hud().get_node_or_null("Top"),
		"Top must exist as the top status strip")

func test_command_bar_exists() -> void:
	assert_not_null(_hud().get_node_or_null("Command"),
		"Command must exist as the bottom command cluster")

func test_ultimate_slot_present() -> void:
	assert_not_null(_hud().get_node_or_null("Command/Ult"),
		"Command/Ult (ultimate radial) must exist inside Command")
