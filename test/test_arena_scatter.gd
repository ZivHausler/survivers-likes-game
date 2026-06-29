extends GutTest
## Pure-logic tests for seeded obstacle placement.

const SEED := 12345
const COUNT := 40
const EXTENT := 90.0
const CLEAR := 12.0
const MIN_SEP := 6.0

func _positions() -> Array:
	return ArenaScatter.compute_positions(SEED, COUNT, EXTENT, CLEAR, MIN_SEP)

func test_deterministic_for_same_seed() -> void:
	var a := _positions()
	var b := ArenaScatter.compute_positions(SEED, COUNT, EXTENT, CLEAR, MIN_SEP)
	assert_eq(a.size(), b.size(), "same seed → same count")
	for i in a.size():
		assert_true(a[i].is_equal_approx(b[i]), "same seed → identical position %d" % i)

func test_count_is_capped() -> void:
	assert_true(_positions().size() <= COUNT, "never returns more than requested count")

func test_all_within_extent_and_on_xz() -> void:
	for p in _positions():
		assert_almost_eq(p.y, 0.0, 0.001, "positions live on the XZ plane")
		assert_true(abs(p.x) <= EXTENT, "x within extent")
		assert_true(abs(p.z) <= EXTENT, "z within extent")

func test_center_kept_clear() -> void:
	for p in _positions():
		assert_true(p.length() >= CLEAR, "no obstacle inside the spawn clear radius")

func test_min_separation_respected() -> void:
	var ps := _positions()
	for i in ps.size():
		for j in range(i + 1, ps.size()):
			assert_true(ps[i].distance_to(ps[j]) >= MIN_SEP - 0.001,
				"props must be at least min_separation apart")

func test_overdense_request_terminates_and_caps() -> void:
	# Impossible to fit 1000 props with this separation — must return fewer, not hang.
	var ps := ArenaScatter.compute_positions(SEED, 1000, 20.0, 5.0, 8.0)
	assert_true(ps.size() < 1000, "over-dense request places fewer than requested")
	assert_true(ps.size() > 0, "still places some")
