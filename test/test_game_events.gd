extends GutTest
## Verifies the global signal bus exposes the boss-HP signals.

func test_boss_spawned_signal_exists() -> void:
	assert_true(GameEvents.has_signal("boss_spawned"), "GameEvents must declare boss_spawned")

func test_boss_hp_changed_signal_exists() -> void:
	assert_true(GameEvents.has_signal("boss_hp_changed"), "GameEvents must declare boss_hp_changed")

func test_boss_died_signal_exists() -> void:
	assert_true(GameEvents.has_signal("boss_died"), "GameEvents must declare boss_died")

func test_boss_killed_3d_signal_exists() -> void:
	assert_true(GameEvents.has_signal("boss_killed_3d"), "GameEvents must declare boss_killed_3d")
