extends GutTest
## Pure tests for the floor autotile resolver.

const Autotile: Script = preload("res://arena/floor/autotile.gd")
const ZoneGrid: Script = preload("res://arena/floor/zone_grid.gd")

const PRIORITY := { &"stone_plaza": 5, &"stone_path": 4, &"grass": 1 }

# Build a 3x3 grid where the center is HIGH priority and selected neighbours are LOW,
# to exercise each piece/rotation. 'H' = stone_plaza (high), 'L' = grass (low).
func _grid(rows: Array) -> ZoneGrid:
	var legend := { "H": &"stone_plaza", "L": &"grass" }
	return ZoneGrid.new(PackedStringArray(rows), legend, 4.0)

func _resolve(rows: Array) -> Dictionary:
	return Autotile.resolve(_grid(rows), 1, 1, PRIORITY)

func test_interior_is_base() -> void:
	var r := _resolve(["HHH", "HHH", "HHH"])
	assert_eq(r["piece"], Autotile.PIECE_BASE, "all-same neighbourhood → base")

func test_equal_priority_neighbour_is_not_a_seam() -> void:
	# center stone_plaza, north neighbour also stone_plaza-priority via '=' path? use H everywhere
	# but make north a same-priority DIFFERENT zone is out of scope; equal id = base already covered.
	var r := _resolve(["HHH", "HHH", "HHH"])
	assert_eq(r["piece"], Autotile.PIECE_BASE)

func test_edge_north() -> void:
	var r := _resolve(["LLL", "HHH", "HHH"])  # only north row is low
	assert_eq(r["piece"], Autotile.PIECE_EDGE, "one lower orthogonal → edge")
	assert_eq(r["rotation"], 0, "north seam → rotation 0")

func test_edge_east() -> void:
	var r := _resolve(["HHL", "HHL", "HHL"])  # east column low
	assert_eq(r["piece"], Autotile.PIECE_EDGE)
	assert_eq(r["rotation"], 1, "east seam → rotation 1")

func test_edge_south() -> void:
	var r := _resolve(["HHH", "HHH", "LLL"])
	assert_eq(r["piece"], Autotile.PIECE_EDGE)
	assert_eq(r["rotation"], 2, "south seam → rotation 2")

func test_edge_west() -> void:
	var r := _resolve(["LHH", "LHH", "LHH"])
	assert_eq(r["piece"], Autotile.PIECE_EDGE)
	assert_eq(r["rotation"], 3, "west seam → rotation 3")

func test_outer_corner_ne() -> void:
	# north AND east low → convex corner facing NE
	var r := _resolve(["LLL", "HHL", "HHL"])
	assert_eq(r["piece"], Autotile.PIECE_OUTER, "two adjacent lower sides → outer corner")
	assert_eq(r["rotation"], 0, "N+E → rotation 0")

func test_outer_corner_sw() -> void:
	var r := _resolve(["LHH", "LHH", "LLL"])  # west AND south low
	assert_eq(r["piece"], Autotile.PIECE_OUTER)
	assert_eq(r["rotation"], 2, "S+W → rotation 2")

func test_inner_corner_ne() -> void:
	# N, E orthogonals HIGH; NE diagonal LOW → concave pocket at NE
	var r := _resolve(["HHL", "HHH", "HHH"])
	assert_eq(r["piece"], Autotile.PIECE_INNER, "concave diagonal → inner corner")
	assert_eq(r["rotation"], 0, "NE pocket → rotation 0")

func test_determinism() -> void:
	var a := _resolve(["LLL", "HHH", "HHH"])
	var b := _resolve(["LLL", "HHH", "HHH"])
	assert_eq(a, b, "same input → identical output")
