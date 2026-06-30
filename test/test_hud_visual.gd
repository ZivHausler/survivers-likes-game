extends GutTest
## Visual / style regression tests for HUD (Command Bar remake).
## Asserts styled ProgressBars, the EVOLVE banner, and the new command-bar structure.

func test_hud_process_mode_is_always() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	assert_eq(hud.process_mode, Node.PROCESS_MODE_ALWAYS,
		"HUD root process_mode must be PROCESS_MODE_ALWAYS")

func test_hp_bar_has_fill_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var hp_bar: ProgressBar = hud.get_node("CommandBar/CBContent/HPZone/HPBarContainer/HPBar")
	assert_true(hp_bar.has_theme_stylebox_override("fill"),
		"HPBar must have a custom fill StyleBox (danger-orange) set via theme_override_styles/fill")

func test_xp_bar_has_fill_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var xp_bar: ProgressBar = hud.get_node("TopStrip/StripVBox/XPBar")
	assert_true(xp_bar.has_theme_stylebox_override("fill"),
		"XPBar must have a custom fill StyleBox (cyan) set via theme_override_styles/fill")

func test_hp_bar_has_background_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var hp_bar: ProgressBar = hud.get_node("CommandBar/CBContent/HPZone/HPBarContainer/HPBar")
	assert_true(hp_bar.has_theme_stylebox_override("background"),
		"HPBar must have a dark background StyleBox for contrast")

func test_xp_bar_has_background_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var xp_bar: ProgressBar = hud.get_node("TopStrip/StripVBox/XPBar")
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

func test_top_strip_exists() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	assert_not_null(hud.get_node_or_null("TopStrip"),
		"TopStrip must exist as the full-width top status strip")

func test_command_bar_exists() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	assert_not_null(hud.get_node_or_null("CommandBar"),
		"CommandBar must exist as the bottom command bar panel")

func test_ultimate_slot_present() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	assert_not_null(hud.get_node_or_null("CommandBar/CBContent/RightZone/UltSlot"),
		"UltSlot must exist inside CommandBar RightZone")
