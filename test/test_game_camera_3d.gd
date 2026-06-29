## Unit tests for GameCamera3D pure math helpers and input behaviour.
# See docs/notes/game-camera-3d.md
extends GutTest
## No scene tree required for the math — tests call static functions directly.
## Input tests instantiate a camera node and call _unhandled_input directly.
## Orientation/centering is guaranteed by Node3D.look_at (engine primitive) given a
## correct position, so these tests cover the position geometry + the radius invariant.

# ── compute_position: orbit sphere (radius, pitch, yaw) ──────────────────────
# The camera sits on a sphere of `radius` around the target. Both pitch (elevation)
# and yaw (azimuth) move its position; look_at(target) then keeps the target centered.

func test_compute_position_sits_at_radius_from_target() -> void:
	# The defining invariant: distance from the target equals `radius` at any angle.
	for combo in [[-65.0, 0.0], [-45.0, 90.0], [-85.0, 200.0], [-25.0, -130.0]]:
		var pos := GameCamera3D.compute_position(Vector3.ZERO, 15.0, combo[0], combo[1])
		assert_almost_eq(pos.length(), 15.0, 0.001,
			"camera must sit at `radius` from target (pitch=%s, yaw=%s)" % [combo[0], combo[1]])

func test_compute_position_radius_invariant_offset_from_nonzero_target() -> void:
	var target := Vector3(5.0, 0.0, -3.0)
	var pos := GameCamera3D.compute_position(target, 12.0, -50.0, 70.0)
	assert_almost_eq((pos - target).length(), 12.0, 0.001, "radius is measured from the target, anywhere")

func test_compute_position_default_view_matches_approved_framing() -> void:
	# pitch -65°, yaw 0, radius 15.4 → ≈ (0, 13.95, 6.51): the -65° framing the owner approved.
	var pos := GameCamera3D.compute_position(Vector3.ZERO, 15.4, -65.0, 0.0)
	assert_almost_eq(pos.x, 0.0, 0.001, "yaw=0: no X offset")
	assert_almost_eq(pos.y, 13.95, 0.05, "height ≈ radius*sin(65°)")
	assert_almost_eq(pos.z, 6.51, 0.05, "pull-back ≈ radius*cos(65°)")

func test_compute_position_y_is_height_above_target() -> void:
	# Camera is always above the target (positive elevation), regardless of target Y.
	var pos := GameCamera3D.compute_position(Vector3(0.0, 9.0, 0.0), 15.0, -65.0, 0.0)
	assert_true(pos.y > 9.0, "camera must sit above the target")

func test_compute_position_translates_with_target() -> void:
	var a := GameCamera3D.compute_position(Vector3(5.0, 0.0, 3.0), 15.0, -65.0, 0.0)
	var b := GameCamera3D.compute_position(Vector3(7.0, 0.0, -1.0), 15.0, -65.0, 0.0)
	assert_almost_eq((b - a).x, 2.0, 0.001, "camera X tracks target X movement")
	assert_almost_eq((b - a).z, -4.0, 0.001, "camera Z tracks target Z movement")

func test_compute_position_yaw_sets_horizontal_heading() -> void:
	# The horizontal offset's azimuth equals yaw, so look_at swings the view around.
	var pos := GameCamera3D.compute_position(Vector3.ZERO, 15.0, -65.0, 90.0)
	assert_almost_eq(atan2(pos.x, pos.z), deg_to_rad(90.0), 0.001, "yaw sets the horizontal heading")

func test_compute_position_yaw_zero_is_pure_positive_z_offset() -> void:
	var pos := GameCamera3D.compute_position(Vector3.ZERO, 15.0, -65.0, 0.0)
	assert_almost_eq(pos.x, 0.0, 0.001, "yaw=0: X offset = 0")
	assert_true(pos.z > 0.0, "yaw=0: camera pulled back along +Z")

func test_compute_position_steeper_pitch_raises_and_pulls_in() -> void:
	var shallow := GameCamera3D.compute_position(Vector3.ZERO, 15.0, -40.0, 0.0)
	var steep := GameCamera3D.compute_position(Vector3.ZERO, 15.0, -80.0, 0.0)
	assert_true(steep.y > shallow.y, "steeper (more negative) pitch raises the camera (more top-down)")
	assert_true(steep.z < shallow.z, "steeper pitch reduces the horizontal pull-back")

func test_compute_position_zoom_scales_radius() -> void:
	var pos := GameCamera3D.compute_position(Vector3.ZERO, 15.0 * 2.0, -65.0, 0.0)
	assert_almost_eq(pos.length(), 30.0, 0.001, "zoom multiplies the orbit radius")

# ── clamp_pitch ──────────────────────────────────────────────────────────────

func test_clamp_pitch_below_min_returns_min() -> void:
	assert_almost_eq(GameCamera3D.clamp_pitch(-90.0), GameCamera3D.PITCH_MIN, 0.001,
		"pitch steeper than PITCH_MIN must clamp to PITCH_MIN")

func test_clamp_pitch_above_max_returns_max() -> void:
	assert_almost_eq(GameCamera3D.clamp_pitch(-10.0), GameCamera3D.PITCH_MAX, 0.001,
		"pitch flatter than PITCH_MAX must clamp to PITCH_MAX")

func test_clamp_pitch_in_range_unchanged() -> void:
	assert_almost_eq(GameCamera3D.clamp_pitch(-65.0), -65.0, 0.001,
		"pitch within [PITCH_MIN, PITCH_MAX] must pass through unchanged")

# ── clamp_zoom ────────────────────────────────────────────────────────────────

func test_clamp_zoom_below_min_returns_min() -> void:
	assert_almost_eq(GameCamera3D.clamp_zoom(0.0), GameCamera3D.ZOOM_MIN, 0.001, "zoom below ZOOM_MIN clamps to ZOOM_MIN")

func test_clamp_zoom_above_max_returns_max() -> void:
	assert_almost_eq(GameCamera3D.clamp_zoom(99.0), GameCamera3D.ZOOM_MAX, 0.001, "zoom above ZOOM_MAX clamps to ZOOM_MAX")

func test_clamp_zoom_in_range_unchanged() -> void:
	assert_almost_eq(GameCamera3D.clamp_zoom(1.0), 1.0, 0.001, "zoom in range passes through unchanged")

# ── zoom input handling ───────────────────────────────────────────────────────

func _make_button_event(button_index: int, pressed: bool) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	ev.pressed = pressed
	return ev

func _make_motion_event(relative: Vector2) -> InputEventMouseMotion:
	var ev := InputEventMouseMotion.new()
	ev.relative = relative
	return ev

func test_wheel_up_decreases_zoom_by_one_step() -> void:
	var cam := GameCamera3D.new()
	cam.zoom = 1.0
	cam._unhandled_input(_make_button_event(MOUSE_BUTTON_WHEEL_UP, true))
	assert_almost_eq(cam.zoom, GameCamera3D.clamp_zoom(1.0 - GameCamera3D.ZOOM_STEP), 0.001, "WHEEL_UP decreases zoom by ZOOM_STEP")
	cam.free()

func test_wheel_down_increases_zoom_by_one_step() -> void:
	var cam := GameCamera3D.new()
	cam.zoom = 1.0
	cam._unhandled_input(_make_button_event(MOUSE_BUTTON_WHEEL_DOWN, true))
	assert_almost_eq(cam.zoom, GameCamera3D.clamp_zoom(1.0 + GameCamera3D.ZOOM_STEP), 0.001, "WHEEL_DOWN increases zoom by ZOOM_STEP")
	cam.free()

func test_wheel_up_clamps_at_min() -> void:
	var cam := GameCamera3D.new()
	cam.zoom = GameCamera3D.ZOOM_MIN
	cam._unhandled_input(_make_button_event(MOUSE_BUTTON_WHEEL_UP, true))
	assert_almost_eq(cam.zoom, GameCamera3D.ZOOM_MIN, 0.001, "WHEEL_UP at ZOOM_MIN stays at ZOOM_MIN")
	cam.free()

func test_wheel_down_clamps_at_max() -> void:
	var cam := GameCamera3D.new()
	cam.zoom = GameCamera3D.ZOOM_MAX
	cam._unhandled_input(_make_button_event(MOUSE_BUTTON_WHEEL_DOWN, true))
	assert_almost_eq(cam.zoom, GameCamera3D.ZOOM_MAX, 0.001, "WHEEL_DOWN at ZOOM_MAX stays at ZOOM_MAX")
	cam.free()

# ── left-drag orbit/tilt + middle-click reset ────────────────────────────────

func test_left_drag_horizontal_changes_yaw() -> void:
	var cam := GameCamera3D.new()
	cam.yaw_degrees = 0.0
	cam._unhandled_input(_make_button_event(MOUSE_BUTTON_LEFT, true))
	cam._unhandled_input(_make_motion_event(Vector2(10.0, 0.0)))
	assert_almost_eq(cam.yaw_degrees, 10.0 * GameCamera3D.DRAG_SENSITIVITY, 0.001,
		"horizontal drag rotates yaw by relative.x * DRAG_SENSITIVITY")
	cam.free()

func test_left_drag_vertical_changes_pitch() -> void:
	var cam := GameCamera3D.new()
	cam.pitch_degrees = -65.0
	cam._unhandled_input(_make_button_event(MOUSE_BUTTON_LEFT, true))
	cam._unhandled_input(_make_motion_event(Vector2(0.0, 5.0)))
	assert_almost_eq(cam.pitch_degrees, GameCamera3D.clamp_pitch(-65.0 + 5.0 * GameCamera3D.DRAG_SENSITIVITY), 0.001,
		"vertical drag tilts pitch by relative.y * DRAG_SENSITIVITY (clamped)")
	cam.free()

func test_left_drag_pitch_clamped_to_min() -> void:
	var cam := GameCamera3D.new()
	cam.pitch_degrees = -84.0
	cam._unhandled_input(_make_button_event(MOUSE_BUTTON_LEFT, true))
	cam._unhandled_input(_make_motion_event(Vector2(0.0, -100.0)))
	assert_almost_eq(cam.pitch_degrees, GameCamera3D.PITCH_MIN, 0.001, "a large vertical drag cannot push pitch past PITCH_MIN")
	cam.free()

func test_motion_without_left_button_does_not_change_view() -> void:
	var cam := GameCamera3D.new()
	cam.yaw_degrees = 0.0
	cam.pitch_degrees = -65.0
	cam._unhandled_input(_make_motion_event(Vector2(50.0, 50.0)))
	assert_almost_eq(cam.yaw_degrees, 0.0, 0.001, "no orbit without an active left-drag")
	assert_almost_eq(cam.pitch_degrees, -65.0, 0.001, "no tilt without an active left-drag")
	cam.free()

func test_left_release_stops_dragging() -> void:
	var cam := GameCamera3D.new()
	cam.yaw_degrees = 0.0
	cam._unhandled_input(_make_button_event(MOUSE_BUTTON_LEFT, true))
	cam._unhandled_input(_make_button_event(MOUSE_BUTTON_LEFT, false))
	cam._unhandled_input(_make_motion_event(Vector2(50.0, 0.0)))
	assert_almost_eq(cam.yaw_degrees, 0.0, 0.001, "releasing the left button stops orbiting")
	cam.free()

func test_middle_click_resets_view() -> void:
	var cam := GameCamera3D.new()
	cam.yaw_degrees = 123.0
	cam.pitch_degrees = -40.0
	cam._unhandled_input(_make_button_event(MOUSE_BUTTON_MIDDLE, true))
	assert_almost_eq(cam.pitch_degrees, GameCamera3D.DEFAULT_PITCH, 0.001, "middle-click resets pitch to default")
	assert_almost_eq(cam.yaw_degrees, GameCamera3D.DEFAULT_YAW, 0.001, "middle-click resets yaw to default")
	cam.free()

func test_reset_view_restores_defaults() -> void:
	var cam := GameCamera3D.new()
	cam.yaw_degrees = 99.0
	cam.pitch_degrees = -30.0
	cam.reset_view()
	assert_almost_eq(cam.pitch_degrees, GameCamera3D.DEFAULT_PITCH, 0.001, "reset_view restores default pitch")
	assert_almost_eq(cam.yaw_degrees, GameCamera3D.DEFAULT_YAW, 0.001, "reset_view restores default yaw")
	cam.free()

func test_yaw_radians_converts_degrees() -> void:
	var cam := GameCamera3D.new()
	cam.yaw_degrees = 90.0
	assert_almost_eq(cam.yaw_radians(), PI / 2.0, 0.001, "yaw_radians() converts yaw_degrees to radians")
	cam.free()

# ── screen shake (pure helpers) ──────────────────────────────────────────────

func test_shake_offset_zero_trauma_is_zero() -> void:
	assert_eq(GameCamera3D.shake_offset(0.0, 1.23), Vector3.ZERO, "trauma=0 → no shake offset")

func test_decay_trauma_reduces_toward_zero() -> void:
	assert_almost_eq(GameCamera3D.decay_trauma(1.0, 0.1), 1.0 - GameCamera3D.SHAKE_DECAY * 0.1, 0.001, "trauma decays at SHAKE_DECAY")

func test_decay_trauma_clamps_at_zero() -> void:
	assert_almost_eq(GameCamera3D.decay_trauma(0.05, 1.0), 0.0, 0.001, "trauma never goes below 0")
