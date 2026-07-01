extends GutTest
## Dark sci-fi HUD theme (fresh HUD tree).
## Verifies the theme asset exists and is wired into the HUD and upgrade-card scenes.
##
## NOTE: hud.tscn and upgrade_ui.tscn both root to CanvasLayer (not Control),
## so the theme is applied to their first Control child:
##   hud.tscn        → Top   (first Control child)
##   upgrade_ui.tscn → Panel (PanelContainer)

func test_theme_resource_is_theme() -> void:
	var theme = load("res://ui/theme/swarm_hud_theme.tres")
	assert_not_null(theme, "swarm_hud_theme.tres must exist")
	assert_true(theme is Theme, "loaded resource must be a Theme")

func test_hud_top_theme_is_set() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var top: Control = hud.get_node("Top") as Control
	assert_not_null(top, "Top must exist in hud.tscn")
	assert_not_null(top.theme, "Top.theme must not be null (theme applied in hud.tscn)")

func test_upgrade_ui_panel_theme_is_set() -> void:
	var ui: Node = add_child_autofree(load("res://upgrades/upgrade_ui.tscn").instantiate())
	var panel: Control = ui.get_node("Panel") as Control
	assert_not_null(panel, "Panel must exist in upgrade_ui.tscn")
	assert_not_null(panel.theme, "Panel.theme must not be null (theme applied in upgrade_ui.tscn)")

func test_boss_panel_is_themed_panel_container() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var boss: Control = hud.get_node("Boss") as Control
	assert_not_null(boss, "Boss node must exist")
	assert_true(boss is PanelContainer,
		"Boss must be a PanelContainer for the dark-panel background")
	assert_not_null(boss.theme,
		"Boss.theme must not be null (themed in hud.tscn for dark sci-fi consistency)")

func test_evolve_banner_has_gold_font_color() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var banner: Label = hud.get_node("Evolve") as Label
	assert_not_null(banner, "Evolve must exist")
	assert_true(banner.has_theme_color_override("font_color"),
		"Evolve must have a font_color override (gold neon callout)")
	var gold := Color(1.0, 0.8, 0.2, 1.0)
	# get_theme_color returns the effective value (override wins over theme lookup)
	assert_eq(banner.get_theme_color("font_color"), gold,
		"Evolve font_color must be palette player_secondary gold")

func test_evolve_banner_has_cyan_outline() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var banner: Label = hud.get_node("Evolve") as Label
	assert_true(banner.has_theme_constant_override("outline_size"),
		"Evolve must have an outline_size override for the neon glow effect")
	# get_theme_constant returns the effective value (override wins)
	assert_true(banner.get_theme_constant("outline_size") > 0,
		"Evolve outline_size must be positive")

func test_upgrade_card_hover_changes_stylebox() -> void:
	var ui: Node = add_child_autofree(load("res://upgrades/upgrade_ui.tscn").instantiate())
	var card0: Control = ui.get_node("Panel/PanelVBox/CardRow/Card0") as Control
	assert_not_null(card0, "Card0 must exist")
	# Capture the normal stylebox (set in _ready)
	assert_true(card0.has_theme_stylebox_override("panel"),
		"Card0 must have a panel override after _ready (normal state)")
	# get_theme_stylebox returns the effective stylebox (override wins)
	var style_before: StyleBox = card0.get_theme_stylebox("panel")
	# Simulate hover
	(ui as UpgradeUI)._on_card_hover(0, true)
	var style_after: StyleBox = card0.get_theme_stylebox("panel")
	assert_not_null(style_after, "Card0 must still have a panel override after hover")
	assert_true(style_after != style_before,
		"Card0 panel stylebox must change on hover (different StyleBox object)")
