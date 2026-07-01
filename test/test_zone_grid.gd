extends GutTest
## Pure tests for the ASCII zone-map parser.

const _ZoneGrid := preload("res://arena/floor/zone_grid.gd")
const LEGEND := { ".": &"grass", "#": &"stone_plaza", "=": &"stone_path" }

func _grid():
	var rows := PackedStringArray([
		"...",
		".#=",
		"...",
	])
	return _ZoneGrid.new(rows, LEGEND, 4.0)

func test_dimensions() -> void:
	var g = _grid()
	assert_eq(g.width, 3, "width = longest row length")
	assert_eq(g.height, 3, "height = row count")
	assert_almost_eq(g.cell_size, 4.0, 0.001, "cell size stored")

func test_zone_lookup_by_legend() -> void:
	var g = _grid()
	assert_eq(g.zone_at(0, 0), &"grass", "'.' → grass")
	assert_eq(g.zone_at(1, 1), &"stone_plaza", "'#' → stone_plaza")
	assert_eq(g.zone_at(2, 1), &"stone_path", "'=' → stone_path")

func test_out_of_bounds_is_void() -> void:
	var g = _grid()
	assert_eq(g.zone_at(-1, 0), &"void", "negative → void")
	assert_eq(g.zone_at(3, 0), &"void", "past width → void")
	assert_eq(g.zone_at(0, 3), &"void", "past height → void")
	assert_false(g.in_bounds(3, 0), "in_bounds false past edge")
	assert_true(g.in_bounds(2, 2), "in_bounds true inside")

func test_unknown_char_is_void() -> void:
	var g := _ZoneGrid.new(PackedStringArray(["?"]), LEGEND, 4.0)
	assert_eq(g.zone_at(0, 0), &"void", "char not in legend → void")

func test_short_rows_padded_with_void() -> void:
	var g := _ZoneGrid.new(PackedStringArray(["##", "#"]), LEGEND, 4.0)
	assert_eq(g.width, 2, "width is longest row")
	assert_eq(g.zone_at(1, 1), &"void", "missing cell in short row → void")

func test_cell_center_world_is_centered_on_origin() -> void:
	# 3x3 grid, cell 4 → centers span [-4,0,4]; middle cell at origin.
	var g = _grid()
	var mid := g.cell_center_world(1, 1)
	assert_almost_eq(mid.x, 0.0, 0.001, "middle cell centered on x")
	assert_almost_eq(mid.z, 0.0, 0.001, "middle cell centered on z")
	assert_almost_eq(mid.y, 0.0, 0.001, "tiles live on y=0 plane")
	var corner := g.cell_center_world(0, 0)
	assert_almost_eq(corner.x, -4.0, 0.001, "cell 0 is one cell left of center")
	assert_almost_eq(corner.z, -4.0, 0.001, "cell 0 is one cell up of center")
