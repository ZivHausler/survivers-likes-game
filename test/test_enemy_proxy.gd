extends GutTest
## Task E1 (M3): client-side proxy mode + snapshot state on Enemy3D.
## Covers snapshot_state() tagging, configure_proxy() disabling collision/AI, and the
## from→to interpolation that a proxy uses in place of host-side simulation.

var Scene: PackedScene = null

func before_all() -> void:
	Scene = load("res://enemies/enemy_3d.tscn")

func _make_proxy(pos: Vector3 = Vector3.ZERO) -> Enemy3D:
	var e: Enemy3D = add_child_autofree(Scene.instantiate())
	e.global_position = pos
	e.configure_proxy()
	return e

# ── snapshot_state() ──────────────────────────────────────────────────────────

func test_snapshot_state_normal_is_zero() -> void:
	var e: Enemy3D = add_child_autofree(Scene.instantiate())
	assert_eq(e.snapshot_state(), 0, "normal enemy snapshot_state must be 0")

func test_snapshot_state_mini_boss_is_two() -> void:
	var e: Enemy3D = add_child_autofree(Scene.instantiate())
	e.boss_kind = Enemy3D.BossKind.MINI
	assert_eq(e.snapshot_state(), 2, "mini-boss snapshot_state must be 2")

func test_snapshot_state_big_boss_is_two() -> void:
	var e: Enemy3D = add_child_autofree(Scene.instantiate())
	e.boss_kind = Enemy3D.BossKind.BIG
	assert_eq(e.snapshot_state(), 2, "big-boss snapshot_state must be 2")

# ── configure_proxy() disables the host-side simulation ──────────────────────

func test_configure_proxy_disables_collision() -> void:
	var e := _make_proxy()
	assert_eq(e.get_collision_layer(), 0, "proxy must disable its collision layer")
	assert_eq(e.get_collision_mask(), 0, "proxy must disable its collision mask")

func test_proxy_physics_does_not_steer_and_interpolates() -> void:
	# A proxy has no data/target. Stepping physics must NOT crash (no AI/nav/contact) and
	# must move it toward the interp target instead — proving the AI branch is skipped.
	var e := _make_proxy(Vector3.ZERO)
	e.set_interp_target(Vector3(10, 0, 0), 0.0)
	var before := e.global_position.x
	e._physics_process(0.05)
	assert_true(e.global_position.x > before,
			"proxy _physics_process must interpolate toward the target, not steer via AI")

func test_proxy_interp_monotonic_approach() -> void:
	var e := _make_proxy(Vector3.ZERO)
	var target := Vector3(10, 0, 0)
	e.set_interp_target(target, 0.0)
	var last := -1.0
	for i in range(5):
		e._physics_process(0.02)
		var d := e.global_position.distance_to(target)
		if last >= 0.0:
			assert_true(d <= last + 0.0001, "distance to target must never increase")
		last = d
	assert_almost_eq(e.global_position.x, 10.0, 0.01,
			"proxy must reach the target after a full NET_INTERVAL of stepping")

# ── pure interpolation helper ─────────────────────────────────────────────────

func test_interp_step_one_full_interval_reaches_target() -> void:
	var res := Enemy3D.interp_step(Vector3.ZERO, Vector3(10, 0, 0), 0.0, 0.05)
	assert_almost_eq((res[0] as Vector3).x, 10.0, 0.001, "one full step reaches the target")
	assert_almost_eq(float(res[1]), 1.0, 0.001, "interp param clamps to 1.0")

func test_interp_step_clamps_param_at_one() -> void:
	var res := Enemy3D.interp_step(Vector3.ZERO, Vector3(10, 0, 0), 0.9, 1.0)
	assert_almost_eq(float(res[1]), 1.0, 0.001, "param must clamp to 1.0, never overshoot")
