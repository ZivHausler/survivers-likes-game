# See docs/notes/juice-3d.md
extends GutTest
## Unit tests for GameCamera3D trauma/shake pure static helpers.
## All tests call static functions directly — no live scene or Camera3D needed.

# ── decay_trauma ──────────────────────────────────────────────────────────────

func test_decay_trauma_reduces_trauma_below_initial() -> void:
	var result: float = GameCamera3D.decay_trauma(1.0, 0.1)
	assert_lt(result, 1.0, "decay_trauma must reduce trauma below 1.0 after dt=0.1")

func test_decay_trauma_positive_step_reduces_toward_zero() -> void:
	var result: float = GameCamera3D.decay_trauma(0.5, 0.1)
	assert_lt(result, 0.5, "decay_trauma must move trauma toward zero")
	assert_true(result >= 0.0, "decay_trauma must not go below 0")

func test_decay_trauma_clamps_at_zero_with_large_dt() -> void:
	var result: float = GameCamera3D.decay_trauma(0.1, 10.0)
	assert_almost_eq(result, 0.0, 0.001, "decay_trauma must clamp to 0.0 with large dt")

func test_decay_trauma_zero_input_stays_zero() -> void:
	var result: float = GameCamera3D.decay_trauma(0.0, 1.0)
	assert_almost_eq(result, 0.0, 0.001, "decay_trauma(0, dt) must return 0")

func test_decay_trauma_full_decay_at_one_second() -> void:
	# SHAKE_DECAY = 1.5, so trauma=1.0 → decay in 1.0/1.5 ≈ 0.67s.
	# After 1s full decay must be complete.
	var result: float = GameCamera3D.decay_trauma(1.0, 1.0)
	assert_almost_eq(result, 0.0, 0.001, "Full trauma=1.0 must decay to 0 within 1 second (decay rate 1.5/s)")

# ── shake_offset ──────────────────────────────────────────────────────────────

func test_shake_offset_zero_trauma_returns_vector3_zero() -> void:
	var off: Vector3 = GameCamera3D.shake_offset(0.0, 1.0)
	assert_eq(off, Vector3.ZERO, "shake_offset with trauma=0 must return Vector3.ZERO")

func test_shake_offset_negative_trauma_returns_vector3_zero() -> void:
	var off: Vector3 = GameCamera3D.shake_offset(-0.5, 1.0)
	assert_eq(off, Vector3.ZERO, "shake_offset with trauma<0 must return Vector3.ZERO")

func test_shake_offset_positive_trauma_returns_nonzero_vector() -> void:
	var off: Vector3 = GameCamera3D.shake_offset(0.5, 1.0)
	assert_true(off.length() > 0.0, "shake_offset with trauma=0.5 must return a non-zero vector")

func test_shake_offset_bounded_within_max_offset() -> void:
	# At trauma=1.0, max offset = 1.0^2 * SHAKE_MAX_OFFSET = 0.5.
	# The Y component has an additional 0.3 factor, Z has 0.5.
	# The maximum possible length: sqrt(0.5^2 + (0.5*0.3)^2 + (0.5*0.5)^2) ≈ 0.56
	var off: Vector3 = GameCamera3D.shake_offset(1.0, 1.0)
	assert_true(off.length() < 1.0, "shake_offset must stay bounded well below 1 world unit")

func test_shake_offset_scales_with_trauma_squared() -> void:
	# At same seed_t, higher trauma → larger magnitude (quadratic scaling).
	var low: float = GameCamera3D.shake_offset(0.3, 2.0).length()
	var high: float = GameCamera3D.shake_offset(0.9, 2.0).length()
	assert_true(high > low, "Higher trauma must produce larger shake_offset magnitude")
