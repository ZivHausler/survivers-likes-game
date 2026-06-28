extends GutTest
## Visual / style regression tests for HUD (Task D1: HUD polish).
## Asserts styled ProgressBars and the EVOLVE banner behaviour.

func test_hud_process_mode_is_always() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	assert_eq(hud.process_mode, Node.PROCESS_MODE_ALWAYS,
		"HUD root process_mode must be PROCESS_MODE_ALWAYS")

func test_hp_bar_has_fill_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var hp_bar: ProgressBar = hud.get_node("VBox/HPBar")
	assert_true(hp_bar.has_theme_stylebox_override("fill"),
		"HPBar must have a custom fill StyleBox (red) set via theme_override_styles/fill")

func test_xp_bar_has_fill_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var xp_bar: ProgressBar = hud.get_node("VBox/XPBar")
	assert_true(xp_bar.has_theme_stylebox_override("fill"),
		"XPBar must have a custom fill StyleBox (cyan) set via theme_override_styles/fill")

func test_hp_bar_has_background_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var hp_bar: ProgressBar = hud.get_node("VBox/HPBar")
	assert_true(hp_bar.has_theme_stylebox_override("background"),
		"HPBar must have a dark background StyleBox for contrast")

func test_xp_bar_has_background_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var xp_bar: ProgressBar = hud.get_node("VBox/XPBar")
	assert_true(xp_bar.has_theme_stylebox_override("background"),
		"XPBar must have a dark background StyleBox so bar is visible when near-empty")

func test_evolve_banner_starts_hidden() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var banner: Label = hud.get_node("EvolveBanner")
	assert_false(banner.visible, "EVOLVE banner must start hidden")

func test_evolve_banner_shown_on_evolution_unlocked() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var banner: Label = hud.get_node("EvolveBanner")
	assert_false(banner.visible, "EVOLVE banner should start hidden")
	GameEvents.evolution_unlocked.emit(&"test_weapon")
	assert_true(banner.visible,
		"EVOLVE banner must be visible immediately after evolution_unlocked is emitted")
