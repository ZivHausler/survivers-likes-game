extends GutTest
## Pure tests for the ground splatmap / AO generator.

const SplatField := preload("res://arena/floor/splat_field.gd")
const ZoneGrid := preload("res://arena/floor/zone_grid.gd")

# 6x6: a 2x2 stone_plaza block in the middle of grass, and a full column of
# stone_path on the right so we can test a sharp (blend=0) boundary.
const LEGEND := { ".": &"grass", "#": &"stone_plaza", "=": &"stone_path" }
func _grid() -> ZoneGrid:
	var rows := PackedStringArray([
		"....=.",
		"....=.",
		".##.=.",
		".##.=.",
		"....=.",
		"....=.",
	])
	return ZoneGrid.new(rows, LEGEND, 8.0)

const K := 8  # texels per cell

func test_interior_grass_is_pure_base() -> void:
	# Top-left cell (0,0) is grass surrounded by grass -> all channels ~0.
	var img := SplatField.build_splatmap(_grid(), { &"grass": 3.0, &"stone_plaza": 3.0, &"stone_path": 0.0 }, K)
	var c := img.get_pixel(K / 2, K / 2)  # center of cell (0,0)
	assert_lt(c.r + c.g + c.b + c.a, 0.05, "interior grass has ~zero channel weight (grass base)")

func test_interior_plaza_is_pure_plaza() -> void:
	# Plaza block is cells (1,2)-(2,3); sample the center of cell (1,2).
	var img := SplatField.build_splatmap(_grid(), { &"grass": 3.0, &"stone_plaza": 3.0, &"stone_path": 0.0 }, K)
	var c := img.get_pixel(1 * K + K / 2, 2 * K + K / 2)
	assert_gt(c.r, 0.95, "interior plaza texel is ~pure plaza (R channel)")

func test_soft_boundary_is_intermediate() -> void:
	# The seam between grass and the plaza block, with a soft plaza blend.
	var img := SplatField.build_splatmap(_grid(), { &"grass": 4.0, &"stone_plaza": 4.0, &"stone_path": 0.0 }, K)
	# Texel right at the top edge of the plaza block (cell row 2 starts at ty=2*K).
	var c := img.get_pixel(1 * K + K / 2, 2 * K)
	assert_between(c.r, 0.1, 0.9, "soft plaza/grass seam blends (intermediate R)")

func test_zero_blend_is_sharp() -> void:
	# stone_path column has blend 0 -> its grass boundary must be hard (no intermediate).
	var img := SplatField.build_splatmap(_grid(), { &"grass": 4.0, &"stone_plaza": 4.0, &"stone_path": 0.0 }, K)
	# Walk texels straddling the grass|stone_path seam (between cell x=3 grass and x=4 path).
	var seam_tx := 4 * K  # first texel of the path column
	var ty := 0 * K + K / 2
	for tx in range(seam_tx - 2, seam_tx + 2):
		var g := img.get_pixel(tx, ty).g
		assert_true(g < 0.05 or g > 0.95, "sharp seam texel is fully grass or fully path, got g=%f" % g)
