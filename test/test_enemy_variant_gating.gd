# test/test_enemy_variant_gating.gd
extends GutTest
func _allowed(t: float) -> Array:
	return DifficultyTimeline.new().state_at(t).allowed_variants

func test_archer_gated_at_150() -> void:
	assert_false(&"archer" in _allowed(149.0), "no archer before 150s")
	assert_true(&"archer" in _allowed(150.0), "archer from 150s")

func test_dasher_gated_at_180() -> void:
	assert_false(&"dasher" in _allowed(179.0), "no dasher before 180s")
	assert_true(&"dasher" in _allowed(180.0), "dasher from 180s")

func test_magician_gated_at_240() -> void:
	assert_false(&"magician" in _allowed(239.0), "no magician before 240s")
	assert_true(&"magician" in _allowed(240.0), "magician from 240s")

func test_early_game_still_just_swarmer() -> void:
	assert_eq(_allowed(10.0), [&"swarmer"], "early game unchanged")
