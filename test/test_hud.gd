extends GutTest
## Verifies the HUD's boss bar reacts to GameEvents boss signals (new HUD tree).

var HUDScene = null

func before_all() -> void:
	HUDScene = load("res://ui/hud.tscn")

func _make_hud() -> CanvasLayer:
	return add_child_autofree(HUDScene.instantiate()) as CanvasLayer

func test_boss_bar_hidden_by_default() -> void:
	var bar := _make_hud().get_node("Boss") as Control
	assert_not_null(bar, "Boss node must exist")
	assert_false(bar.visible, "Boss panel must be hidden until a boss spawns")

func test_boss_spawned_shows_bar_with_name_and_max() -> void:
	var hud := _make_hud()
	GameEvents.boss_spawned.emit("Undead Serpent", 2000.0)
	var bar := hud.get_node("Boss") as Control
	var name_label := hud.get_node("Boss/BossName") as Label
	var hp_bar := hud.get_node("Boss/BossHP") as ProgressBar
	assert_true(bar.visible, "Boss panel must show on boss_spawned")
	assert_eq(name_label.text, "Undead Serpent", "boss name displayed")
	assert_almost_eq(hp_bar.max_value, 2000.0, 0.001, "bar max set to boss max hp")
	assert_almost_eq(hp_bar.value, 2000.0, 0.001, "bar starts full")

func test_boss_hp_changed_updates_value_and_text() -> void:
	var hud := _make_hud()
	GameEvents.boss_spawned.emit("Undead Serpent", 2000.0)
	GameEvents.boss_hp_changed.emit(750.0, 2000.0)
	var hp_bar := hud.get_node("Boss/BossHP") as ProgressBar
	var hp_text := hud.get_node("Boss/BossHP/BossHPText") as Label
	assert_almost_eq(hp_bar.value, 750.0, 0.001, "bar value tracks current hp")
	assert_eq(hp_text.text, "750 / 2000", "numeric readout shows cur / max")

func test_boss_died_hides_bar() -> void:
	var hud := _make_hud()
	GameEvents.boss_spawned.emit("Undead Serpent", 2000.0)
	GameEvents.boss_died.emit()
	var bar := hud.get_node("Boss") as Control
	assert_false(bar.visible, "Boss panel hides on boss_died")
