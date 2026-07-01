extends GutTest
## Pure tests for deterministic per-cell tile-variant selection.

const TileVariants := preload("res://arena/floor/tile_variants.gd")

func test_single_variant_is_zero() -> void:
	assert_eq(TileVariants.variant_for(3, 7, 1), 0, "count 1 → always variant 0")
	assert_eq(TileVariants.variant_for(0, 0, 0), 0, "count 0 → 0 (guard, no div-by-zero)")

func test_in_range() -> void:
	for x in range(-20, 20):
		for y in range(-20, 20):
			var v := TileVariants.variant_for(x, y, 3)
			assert_true(v >= 0 and v < 3, "variant in [0,3) for (%d,%d) got %d" % [x, y, v])

func test_deterministic() -> void:
	assert_eq(TileVariants.variant_for(5, 9, 4), TileVariants.variant_for(5, 9, 4),
		"same cell+count → same variant")

func test_varies_across_cells() -> void:
	# Not all equal — the hash must spread values across a small neighbourhood.
	var seen := {}
	for x in 6:
		for y in 6:
			seen[TileVariants.variant_for(x, y, 3)] = true
	assert_true(seen.size() >= 2, "variants must differ across cells (got %d distinct)" % seen.size())
