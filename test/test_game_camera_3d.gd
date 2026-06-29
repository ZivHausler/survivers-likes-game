## Unit tests for GameCamera3D pure math helpers and zoom behaviour.
# See docs/notes/game-camera-3d.md
extends GutTest
## No scene tree required — tests call static functions directly on the class.
## Zoom input tests instantiate a camera node and call _unhandled_input directly.

# ── compute_position ──────────────────────────────────────────────────────────

func test_compute_position_x_tracks_target_x() -> void:
	var pos := GameCamera3D.compute_position(Vector3(7.0, 0.0, 3.0), 14.0, 10.0)
	assert_almost_eq(pos.x, 7.0, 0.001, "Camera X must equal target X")

func test_compute_position_x_tracks_negative_target_x() -> void:
	var pos := GameCamera3D.compute_position(Vector3(-12.5, 0.0, 0.0), 14.0, 10.0)
	assert_almost_eq(pos.x, -12.5, 0.001, "Camera X must track negative target X")

func test_compute_position_y_is_fixed_height_regardless_of_target_y() -> void:
	var pos := GameCamera3D.compute_position(Vector3(0.0, 99.0, 0.0), 14.0, 10.0)
	assert_almost_eq(pos.y, 14.0, 0.001, "Camera Y must equal height, ignoring target Y")

func test_compute_position_y_unchanged_when_target_y_varies() -> void:
	var pos_a := GameCamera3D.compute_position(Vector3(0.0, 0.0, 0.0), 14.0, 10.0)
	var pos_b := GameCamera3D.compute_position(Vector3(0.0, 50.0, 0.0), 14.0, 10.0)
	assert_almost_eq(pos_a.y, pos_b.y, 0.001, "Y must be identical regardless of target Y")

func test_compute_position_z_is_target_z_plus_distance() -> void:
	var pos := GameCamera3D.compute_position(Vector3(0.0, 0.0, 3.0), 14.0, 10.0)
	assert_almost_eq(pos.z, 13.0, 0.001, "Camera Z must be target.z + distance")

func test_compute_position_z_tracks_target_z_movement() -> void:
	var pos1 := GameCamera3D.compute_position(Vector3(0.0, 0.0, 0.0), 14.0, 10.0)
	var pos2 := GameCamera3D.compute_position(Vector3(0.0, 0.0, 5.0), 14.0, 10.0)
	assert_almost_eq(pos2.z - pos1.z, 5.0, 0.001, "Camera Z delta must match target Z delta")

func test_compute_position_default_params_match_spec() -> void:
	# With defaults: height=14, distance=10, target at origin → camera at (0, 14, 10)
	var pos := GameCamera3D.compute_position(Vector3.ZERO, 14.0, 10.0)
	assert_almost_eq(pos.x, 0.0, 0.001, "Default target origin: camera X = 0")
	assert_almost_eq(pos.y, 14.0, 0.001, "Default target origin: camera Y = height (14)")
	assert_almost_eq(pos.z, 10.0, 0.001, "Default target origin: camera Z = distance (10)")

# ── compute_pitch_basis ───────────────────────────────────────────────────────

func test_compute_pitch_basis_minus55_hardcoded_trig() -> void:
	# Independent numeric ground-truth for X-rotation by -55°.
	# cos(55°) ≈ 0.5736, sin(55°) ≈ 0.8192  (literals, not re-derived from the SUT)
	# Y-column of the rotation matrix: (0,  cos55°, -sin55°)
	# Z-column of the rotation matrix: (0,  sin55°,  cos55°)
	var basis := GameCamera3D.compute_pitch_basis(-55.0)
	assert_almost_eq(basis.y.x,  0.0,     0.001, "-55° pitch: y.x = 0 (no yaw/roll)")
	assert_almost_eq(basis.y.y,  0.5736,  0.001, "-55° pitch: y.y = cos(55°) ≈ 0.5736")
	assert_almost_eq(basis.y.z, -0.8192,  0.001, "-55° pitch: y.z = -sin(55°) ≈ -0.8192")
	assert_almost_eq(basis.z.x,  0.0,     0.001, "-55° pitch: z.x = 0 (no yaw/roll)")
	assert_almost_eq(basis.z.y,  0.8192,  0.001, "-55° pitch: z.y = sin(55°) ≈ 0.8192")
	assert_almost_eq(basis.z.z,  0.5736,  0.001, "-55° pitch: z.z = cos(55°) ≈ 0.5736")

func test_compute_pitch_basis_zero_is_identity() -> void:
	var basis := GameCamera3D.compute_pitch_basis(0.0)
	assert_almost_eq(basis.x.x, 1.0, 0.001, "Zero pitch: x.x = 1")
	assert_almost_eq(basis.y.y, 1.0, 0.001, "Zero pitch: y.y = 1")
	assert_almost_eq(basis.z.z, 1.0, 0.001, "Zero pitch: z.z = 1")
	assert_almost_eq(basis.x.y, 0.0, 0.001, "Zero pitch: x.y = 0")
	assert_almost_eq(basis.x.z, 0.0, 0.001, "Zero pitch: x.z = 0")

func test_compute_pitch_basis_no_yaw_or_roll() -> void:
	# A pure X-rotation must not change x-axis direction
	var basis := GameCamera3D.compute_pitch_basis(-55.0)
	assert_almost_eq(basis.x.x, 1.0, 0.001, "Pure pitch: right vector X unchanged")
	assert_almost_eq(basis.x.y, 0.0, 0.001, "Pure pitch: right vector Y = 0")
	assert_almost_eq(basis.x.z, 0.0, 0.001, "Pure pitch: right vector Z = 0")

# ── clamp_zoom ────────────────────────────────────────────────────────────────

func test_clamp_zoom_below_min_returns_min() -> void:
	var result := GameCamera3D.clamp_zoom(0.0)
	assert_almost_eq(result, GameCamera3D.ZOOM_MIN, 0.001, "zoom below ZOOM_MIN must clamp to ZOOM_MIN (0.45)")

func test_clamp_zoom_above_max_returns_max() -> void:
	var result := GameCamera3D.clamp_zoom(99.0)
	assert_almost_eq(result, GameCamera3D.ZOOM_MAX, 0.001, "zoom above ZOOM_MAX must clamp to ZOOM_MAX (2.2)")

func test_clamp_zoom_in_range_unchanged() -> void:
	var result := GameCamera3D.clamp_zoom(1.0)
	assert_almost_eq(result, 1.0, 0.001, "zoom in [ZOOM_MIN, ZOOM_MAX] must pass through unchanged")

func test_clamp_zoom_at_min_boundary_unchanged() -> void:
	var result := GameCamera3D.clamp_zoom(GameCamera3D.ZOOM_MIN)
	assert_almost_eq(result, GameCamera3D.ZOOM_MIN, 0.001, "zoom exactly at ZOOM_MIN must be unchanged")

func test_clamp_zoom_at_max_boundary_unchanged() -> void:
	var result := GameCamera3D.clamp_zoom(GameCamera3D.ZOOM_MAX)
	assert_almost_eq(result, GameCamera3D.ZOOM_MAX, 0.001, "zoom exactly at ZOOM_MAX must be unchanged")

# ── zoom input handling ───────────────────────────────────────────────────────

func _make_wheel_event(button_index: int) -> InputEventMouseButton:
	var ev := InputEventMouseButton.new()
	ev.button_index = button_index
	ev.pressed = true
	return ev

func test_wheel_up_decreases_zoom_by_one_step() -> void:
	var cam := GameCamera3D.new()
	cam.zoom = 1.0
	var ev := _make_wheel_event(MOUSE_BUTTON_WHEEL_UP)
	cam._unhandled_input(ev)
	var expected := GameCamera3D.clamp_zoom(1.0 - GameCamera3D.ZOOM_STEP)
	assert_almost_eq(cam.zoom, expected, 0.001, "WHEEL_UP must decrease zoom by ZOOM_STEP")
	cam.free()

func test_wheel_down_increases_zoom_by_one_step() -> void:
	var cam := GameCamera3D.new()
	cam.zoom = 1.0
	var ev := _make_wheel_event(MOUSE_BUTTON_WHEEL_DOWN)
	cam._unhandled_input(ev)
	var expected := GameCamera3D.clamp_zoom(1.0 + GameCamera3D.ZOOM_STEP)
	assert_almost_eq(cam.zoom, expected, 0.001, "WHEEL_DOWN must increase zoom by ZOOM_STEP")
	cam.free()

func test_wheel_up_clamps_at_min() -> void:
	var cam := GameCamera3D.new()
	cam.zoom = GameCamera3D.ZOOM_MIN
	var ev := _make_wheel_event(MOUSE_BUTTON_WHEEL_UP)
	cam._unhandled_input(ev)
	assert_almost_eq(cam.zoom, GameCamera3D.ZOOM_MIN, 0.001, "WHEEL_UP at ZOOM_MIN must not go below ZOOM_MIN")
	cam.free()

func test_wheel_down_clamps_at_max() -> void:
	var cam := GameCamera3D.new()
	cam.zoom = GameCamera3D.ZOOM_MAX
	var ev := _make_wheel_event(MOUSE_BUTTON_WHEEL_DOWN)
	cam._unhandled_input(ev)
	assert_almost_eq(cam.zoom, GameCamera3D.ZOOM_MAX, 0.001, "WHEEL_DOWN at ZOOM_MAX must not exceed ZOOM_MAX")
	cam.free()

# ── zoom scales compute_position ─────────────────────────────────────────────

func test_zoom_in_produces_closer_camera_y() -> void:
	# zoom < 1 means height * zoom < height → camera is closer (lower Y)
	var zoom_in: float = 0.5
	var pos_zoomed := GameCamera3D.compute_position(Vector3.ZERO, 14.0 * zoom_in, 10.0 * zoom_in)
	var pos_default := GameCamera3D.compute_position(Vector3.ZERO, 14.0, 10.0)
	assert_true(pos_zoomed.y < pos_default.y, "Zoom in (zoom<1) must reduce camera height (Y)")

func test_zoom_out_produces_farther_camera_y() -> void:
	# zoom > 1 means height * zoom > height → camera is farther (higher Y)
	var zoom_out: float = 1.5
	var pos_zoomed := GameCamera3D.compute_position(Vector3.ZERO, 14.0 * zoom_out, 10.0 * zoom_out)
	var pos_default := GameCamera3D.compute_position(Vector3.ZERO, 14.0, 10.0)
	assert_true(pos_zoomed.y > pos_default.y, "Zoom out (zoom>1) must increase camera height (Y)")

func test_zoom_in_produces_closer_camera_z() -> void:
	# zoom < 1 means distance * zoom < distance → camera Z offset is smaller
	var zoom_in: float = 0.5
	var pos_zoomed := GameCamera3D.compute_position(Vector3.ZERO, 14.0 * zoom_in, 10.0 * zoom_in)
	var pos_default := GameCamera3D.compute_position(Vector3.ZERO, 14.0, 10.0)
	assert_true(pos_zoomed.z < pos_default.z, "Zoom in (zoom<1) must reduce camera Z offset")

func test_zoom_out_produces_farther_camera_z() -> void:
	# zoom > 1 means distance * zoom > distance → camera Z offset is larger
	var zoom_out: float = 1.5
	var pos_zoomed := GameCamera3D.compute_position(Vector3.ZERO, 14.0 * zoom_out, 10.0 * zoom_out)
	var pos_default := GameCamera3D.compute_position(Vector3.ZERO, 14.0, 10.0)
	assert_true(pos_zoomed.z > pos_default.z, "Zoom out (zoom>1) must increase camera Z offset")

func test_zoom_scales_height_proportionally() -> void:
	# At zoom=0.5, height should be exactly 14 * 0.5 = 7.0
	var zoom: float = 0.5
	var pos := GameCamera3D.compute_position(Vector3.ZERO, 14.0 * zoom, 10.0 * zoom)
	assert_almost_eq(pos.y, 7.0, 0.001, "zoom=0.5 must halve the effective height (14→7)")

func test_zoom_scales_distance_proportionally() -> void:
	# At zoom=2.0, Z offset should be exactly 10 * 2.0 = 20.0
	var zoom: float = 2.0
	var pos := GameCamera3D.compute_position(Vector3.ZERO, 14.0 * zoom, 10.0 * zoom)
	assert_almost_eq(pos.z, 20.0, 0.001, "zoom=2.0 must double the effective distance (10→20)")
