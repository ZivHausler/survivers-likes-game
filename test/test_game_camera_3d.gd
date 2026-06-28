# See docs/notes/game-camera-3d.md
extends GutTest
## Unit tests for GameCamera3D pure math helpers.
## No scene tree required — tests call static functions directly on the class.

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

func test_compute_pitch_basis_matches_from_euler() -> void:
	var basis := GameCamera3D.compute_pitch_basis(-55.0)
	var expected := Basis.from_euler(Vector3(deg_to_rad(-55.0), 0.0, 0.0))
	assert_almost_eq(basis.x.x, expected.x.x, 0.001, "Basis.x.x must match euler")
	assert_almost_eq(basis.y.y, expected.y.y, 0.001, "Basis.y.y must match euler")
	assert_almost_eq(basis.z.z, expected.z.z, 0.001, "Basis.z.z must match euler")

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
