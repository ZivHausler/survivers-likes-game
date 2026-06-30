extends GutTest
## Phase 6.1 — Dark sci-fi HUD theme.
## Verifies the theme asset exists and is wired into the HUD and upgrade-card scenes.
##
## NOTE: hud.tscn and upgrade_ui.tscn both root to CanvasLayer (not Control),
## so the theme is applied to their first Control child:
##   hud.tscn       → VBox (VBoxContainer)
##   upgrade_ui.tscn → Panel (PanelContainer)

func test_theme_resource_is_theme() -> void:
	var theme = load("res://ui/theme/swarm_hud_theme.tres")
	assert_not_null(theme, "swarm_hud_theme.tres must exist")
	assert_true(theme is Theme, "loaded resource must be a Theme")

func test_hud_vbox_theme_is_set() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var vbox: Control = hud.get_node("VBox") as Control
	assert_not_null(vbox, "VBox must exist in hud.tscn")
	assert_not_null(vbox.theme, "VBox.theme must not be null (theme applied in hud.tscn)")

func test_upgrade_ui_panel_theme_is_set() -> void:
	var ui: Node = add_child_autofree(load("res://upgrades/upgrade_ui.tscn").instantiate())
	var panel: Control = ui.get_node("Panel") as Control
	assert_not_null(panel, "Panel must exist in upgrade_ui.tscn")
	assert_not_null(panel.theme, "Panel.theme must not be null (theme applied in upgrade_ui.tscn)")
