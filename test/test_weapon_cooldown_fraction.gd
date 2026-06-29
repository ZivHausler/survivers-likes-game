extends GutTest
## Pure cooldown-fraction math: 0.0 just-fired … 1.0 ready.

func test_just_fired_is_zero() -> void:
	assert_eq(Weapon3D.cooldown_fraction_of(2.0, 2.0), 0.0)

func test_ready_is_one() -> void:
	assert_eq(Weapon3D.cooldown_fraction_of(0.0, 2.0), 1.0)

func test_halfway() -> void:
	assert_almost_eq(Weapon3D.cooldown_fraction_of(1.0, 2.0), 0.5, 0.0001)

func test_zero_wait_time_is_ready() -> void:
	# Degenerate timer (never set) reads as ready, not a divide-by-zero.
	assert_eq(Weapon3D.cooldown_fraction_of(0.0, 0.0), 1.0)

func test_clamped() -> void:
	assert_eq(Weapon3D.cooldown_fraction_of(5.0, 2.0), 0.0)  # time_left > wait → clamp 0
