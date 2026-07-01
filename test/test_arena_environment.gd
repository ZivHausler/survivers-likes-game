# See docs/notes/arena-3d.md
extends GutTest
## Structural tests for arena WorldEnvironment glow/bloom + lighting (Task 1.4).

var Scene: PackedScene = null

func before_all() -> void:
	Scene = load("res://arena/arena_3d.tscn")

func test_environment_glow_and_ambient() -> void:
	var root := Scene.instantiate()
	var we: WorldEnvironment = root.get_node("WorldEnvironment")
	assert_true(we.environment.glow_enabled,
		"WorldEnvironment must have glow enabled")
	# Ambient kept low on purpose so the directional key + shadows + SSAO create form
	# (high ambient washes everything flat). Still positive so the scene isn't black.
	assert_true(we.environment.ambient_light_energy >= 0.1,
		"ambient_light_energy must be > 0, got %f" % we.environment.ambient_light_energy)
	assert_true(we.environment.ssao_enabled, "SSAO must be enabled for grounded form")
	root.free()
