extends GutTest
## Verifies the HUD's top-center big-boss bar reacts to GameEvents boss signals.

var HUDScene = null

func before_all() -> void:
	HUDScene = load("res://ui/hud.tscn")

func _make_hud() -> CanvasLayer:
	var hud: CanvasLayer = add_child_autofree(HUDScene.instantiate()) as CanvasLayer
	return hud

func test_boss_bar_hidden_by_default() -> void:
	var hud := _make_hud()
	var bar := hud.get_node("BossBar") as Control
	assert_not_null(bar, "BossBar node must exist")
	assert_false(bar.visible, "BossBar must be hidden until a boss spawns")

func test_boss_spawned_shows_bar_with_name_and_max() -> void:
	var hud := _make_hud()
	GameEvents.boss_spawned.emit("Undead Serpent", 2000.0)
	var bar := hud.get_node("BossBar") as Control
	var name_label := hud.get_node("BossBar/BossNameLabel") as Label
	var hp_bar := hud.get_node("BossBar/BossHPBar") as ProgressBar
	assert_true(bar.visible, "BossBar must show on boss_spawned")
	assert_eq(name_label.text, "Undead Serpent", "boss name displayed")
	assert_almost_eq(hp_bar.max_value, 2000.0, 0.001, "bar max set to boss max hp")
	assert_almost_eq(hp_bar.value, 2000.0, 0.001, "bar starts full")

func test_boss_hp_changed_updates_value_and_text() -> void:
	var hud := _make_hud()
	GameEvents.boss_spawned.emit("Undead Serpent", 2000.0)
	GameEvents.boss_hp_changed.emit(750.0, 2000.0)
	var hp_bar := hud.get_node("BossBar/BossHPBar") as ProgressBar
	var hp_text := hud.get_node("BossBar/BossHPBar/BossHPText") as Label
	assert_almost_eq(hp_bar.value, 750.0, 0.001, "bar value tracks current hp")
	assert_eq(hp_text.text, "750 / 2000", "numeric readout shows cur / max")

func test_boss_died_hides_bar() -> void:
	var hud := _make_hud()
	GameEvents.boss_spawned.emit("Undead Serpent", 2000.0)
	GameEvents.boss_died.emit()
	var bar := hud.get_node("BossBar") as Control
	assert_false(bar.visible, "BossBar hides on boss_died")
