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

## FIX 1 — first-frame warmup fallback: enemy must move (velocity non-zero/desired)
## on the very first _physics_process frame before any velocity_computed callback fires.
## In headless tests the NavigationServer never emits velocity_computed, so
## _avoidance_active stays false and the warmup fallback runs.
func test_first_frame_enemy_moves_before_avoidance_callback() -> void:
	var e := _make_enemy()
	assert_false(e._avoidance_active,
		"_avoidance_active must start false (no callback yet)")
	e._physics_process(0.016)
	assert_true(e.velocity.x > 0.0,
		"velocity must be non-zero/desired on first frame (warmup fallback)")
	assert_false(e._avoidance_active,
		"_avoidance_active stays false — no nav callback in headless")

## FIX 2 — stale-velocity guard: _on_velocity_computed must be a no-op when
## data is null (enemy constructed but setup() never called).
func test_velocity_computed_noop_when_data_null() -> void:
	var e: Enemy3D = add_child_autofree(Scene.instantiate())
	# data is null — setup() never called
	assert_null(e.data, "data must be null without setup()")
	# Calling the callback should not crash and must not change velocity
	e._on_velocity_computed(Vector3(5.0, 0.0, 0.0))
	assert_almost_eq(e.velocity.x, 0.0, 0.001,
		"velocity must remain zero when data is null (no-op guard)")

## FIX 3 — max_speed coupling: setup() must raise _agent.max_speed to
## data.move_speed when the enemy's speed exceeds the tscn default (12.0).
func test_setup_raises_agent_max_speed_to_move_speed() -> void:
	var e: Enemy3D = add_child_autofree(Scene.instantiate())
	var d := EnemyData.new()
	d.max_hp = 30.0
	d.move_speed = 20.0   # exceeds NavigationAgent3D tscn default of 12.0
	d.contact_damage = 4.0
	var tgt: StubTarget = add_child_autofree(StubTarget.new())
	tgt.global_position = Vector3(10, 0, 0)
	e.setup(d, tgt)
	var agent := e.get_node_or_null("NavigationAgent3D") as NavigationAgent3D
	assert_not_null(agent, "NavigationAgent3D must exist")
	assert_almost_eq(agent.max_speed, 20.0, 0.001,
		"max_speed must be raised to data.move_speed when it exceeds the default")

## FREEZE REGRESSION — RVO returns a zero safe_velocity when its nav map is not
## simulating avoidance (no active NavigationRegion, and always in headless). The
## callback must NOT then zero out a real desired velocity, or enemies freeze.
func test_velocity_computed_falls_back_to_desired_when_safe_zero() -> void:
	var e := _make_enemy()
	e.velocity = Vector3(5.0, 0.0, 0.0)   # desired velocity, as _physics_process sets it
	e._on_velocity_computed(Vector3.ZERO) # RVO yields nothing
	assert_almost_eq(e.velocity.x, 5.0, 0.001,
		"a ~zero safe velocity must NOT overwrite a real desired velocity (no freeze)")

## A meaningful (non-zero) safe velocity from RVO is still adopted (avoidance steers).
func test_velocity_computed_uses_nonzero_safe() -> void:
	var e := _make_enemy()
	e.velocity = Vector3(5.0, 0.0, 0.0)
	e._on_velocity_computed(Vector3(0.0, 0.0, 4.0))
	assert_almost_eq(e.velocity.z, 4.0, 0.001, "a real safe velocity is adopted")
	assert_almost_eq(e.velocity.x, 0.0, 0.001, "avoided velocity replaces desired")

## END-TO-END FREEZE GUARD — an in-tree enemy must actually CHANGE POSITION toward
## its target over several physics frames. This is the test that catches the
## "spawns but never moves" regression (headless RVO never emits a non-zero
## velocity, so movement relies on the desired-velocity fallback).
func test_enemy_actually_moves_over_physics_frames() -> void:
	var e := _make_enemy()  # at origin, target at (10,0,0), move_speed 5
	var start_x := e.global_position.x
	for _i in range(15):
		await get_tree().physics_frame
	assert_true(e.global_position.x - start_x > 0.5,
		"enemy must move toward target across frames, not freeze (moved %f)"
		% (e.global_position.x - start_x))
