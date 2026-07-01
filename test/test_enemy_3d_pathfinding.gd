extends GutTest
## Verifies enemies route toward the player via the NavigationAgent3D's path (so they
## can go AROUND carved terrain) instead of steering blindly straight at the target,
## and that repathing is throttled so a large swarm doesn't re-path every frame.

var Scene: PackedScene = null

class StubTarget extends Node3D:
	pass

func before_all() -> void:
	Scene = load("res://enemies/enemy_3d.tscn")

func _make_enemy(target_pos: Vector3 = Vector3(10, 0, 0)) -> Enemy3D:
	var e: Enemy3D = add_child_autofree(Scene.instantiate())
	var d := EnemyData.new()
	d.max_hp = 30.0
	d.move_speed = 5.0
	d.contact_damage = 4.0
	var tgt: StubTarget = add_child_autofree(StubTarget.new())
	tgt.global_position = target_pos
	e.global_position = Vector3.ZERO
	e.setup(d, tgt)
	return e

# --- Pure steering helper ---------------------------------------------------

## Heads toward the navmesh corner when it is a meaningful step away.
func test_nav_desired_velocity_steers_toward_path_corner() -> void:
	# next path corner is off the straight line to the target: follow the corner.
	var v := Enemy3D.nav_desired_velocity(
		Vector3.ZERO, Vector3(0, 0, 5), Vector3(10, 0, 0), 5.0)
	assert_almost_eq(v.z, 5.0, 0.001, "must steer toward the path corner (+Z)")
	assert_almost_eq(v.x, 0.0, 0.001, "must NOT steer straight at the target (+X)")

## Falls back to a straight line at the target when the corner is ~the enemy's own
## position (navigation produced no usable path — headless / inactive map). No freeze.
func test_nav_desired_velocity_falls_back_when_corner_is_self() -> void:
	var v := Enemy3D.nav_desired_velocity(
		Vector3.ZERO, Vector3.ZERO, Vector3(10, 0, 0), 5.0)
	assert_almost_eq(v.x, 5.0, 0.001, "must fall back to a straight line at the target")
	assert_almost_eq(v.y, 0.0, 0.001, "velocity stays on the XZ plane")

# --- Path target wiring ------------------------------------------------------

## The enemy must publish its goal (the player) to the NavigationAgent3D so the
## server can compute a route around terrain.
func test_physics_process_sets_agent_target_toward_player() -> void:
	var e := _make_enemy(Vector3(10, 0, 0))
	var agent := e.get_node("NavigationAgent3D") as NavigationAgent3D
	e._physics_process(0.016)
	assert_almost_eq(agent.target_position.x, 10.0, 0.001,
		"agent.target_position must be set to the player position on the first frame")

## Repathing is throttled: within the repath interval the agent target is NOT
## rewritten every frame (keeps a 50-200 swarm cheap).
func test_repath_is_throttled_within_interval() -> void:
	var e := _make_enemy(Vector3(10, 0, 0))
	var agent := e.get_node("NavigationAgent3D") as NavigationAgent3D
	e._physics_process(0.016)                       # first frame → paths to (10,0,0)
	e.target.global_position = Vector3(0, 0, 10)     # player moved
	e._physics_process(0.016)                       # still within interval → no repath
	assert_almost_eq(agent.target_position.x, 10.0, 0.001,
		"target must stay at the old goal within the repath interval (throttled)")

## After the interval elapses the agent target is refreshed to the new goal.
func test_repath_refreshes_after_interval() -> void:
	var e := _make_enemy(Vector3(10, 0, 0))
	var agent := e.get_node("NavigationAgent3D") as NavigationAgent3D
	e._physics_process(0.016)
	e.target.global_position = Vector3(0, 0, 10)
	# Advance well past the repath interval.
	for _i in range(40):
		e._physics_process(0.016)
	assert_almost_eq(agent.target_position.z, 10.0, 0.001,
		"target must refresh to the new goal once the repath interval elapses")

## Regression: enemies must still actually move toward the player across frames
## even with no baked navmesh present (fallback path), never freezing.
func test_enemy_still_moves_with_no_navmesh_present() -> void:
	var e := _make_enemy(Vector3(10, 0, 0))
	var start_x := e.global_position.x
	for _i in range(15):
		await get_tree().physics_frame
	assert_true(e.global_position.x - start_x > 0.5,
		"enemy must move toward target across frames (moved %f)"
		% (e.global_position.x - start_x))
