extends GutTest
## Verifies enemies are wired for RVO avoidance and that velocity is still set
## synchronously in _physics_process (so existing velocity assertions hold).

var Scene: PackedScene = null

class StubTarget extends Node3D:
	pass

func before_all() -> void:
	Scene = load("res://enemies/enemy_3d.tscn")

func _make_enemy() -> Enemy3D:
	var e: Enemy3D = add_child_autofree(Scene.instantiate())
	var d := EnemyData.new()
	d.max_hp = 30.0
	d.move_speed = 5.0
	d.contact_damage = 4.0
	var tgt: StubTarget = add_child_autofree(StubTarget.new())
	tgt.global_position = Vector3(10, 0, 0)
	e.global_position = Vector3.ZERO
	e.setup(d, tgt)
	return e

func test_enemy_has_avoidance_agent() -> void:
	var e := _make_enemy()
	var agent := e.get_node_or_null("NavigationAgent3D")
	assert_not_null(agent, "enemy must have a NavigationAgent3D")
	assert_true((agent as NavigationAgent3D).avoidance_enabled, "avoidance must be enabled")

func test_velocity_set_synchronously_in_physics_process() -> void:
	var e := _make_enemy()
	e._physics_process(0.016)
	assert_true(e.velocity.x > 0.0,
		"velocity must be set synchronously toward target (+X), not deferred to callback")
	assert_almost_eq(e.velocity.y, 0.0, 0.001, "velocity stays on XZ plane")

func test_velocity_computed_callback_assigns_velocity() -> void:
	var e := _make_enemy()
	e._on_velocity_computed(Vector3(3.0, 0.0, 0.0))
	assert_almost_eq(e.velocity.x, 3.0, 0.001, "callback applies the safe velocity")
