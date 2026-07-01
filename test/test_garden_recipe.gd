extends GutTest
## Validates the Garden recipe is well-formed and drives ZoneGrid correctly.

const ZoneGrid := preload("res://arena/floor/zone_grid.gd")

var RECIPE: Dictionary

func before_all() -> void:
	RECIPE = load("res://arena/maps/garden_map.gd").RECIPE

func test_has_required_keys() -> void:
	for k in ["cell_size", "rows", "legend", "priority", "zones", "pond", "decals", "prop_clusters"]:
		assert_true(RECIPE.has(k), "recipe must define '%s'" % k)

func test_rows_are_rectangular_and_sized() -> void:
	var rows: PackedStringArray = RECIPE["rows"]
	assert_true(rows.size() >= 16, "garden grid must be at least 16 rows")
	var w := rows[0].length()
	for r in rows:
		assert_eq(r.length(), w, "every row must be the same width (rectangular grid)")

func test_every_char_is_in_legend() -> void:
	var legend: Dictionary = RECIPE["legend"]
	for r in RECIPE["rows"]:
		for i in r.length():
			assert_true(legend.has(r.substr(i, 1)), "char '%s' must be in legend" % r.substr(i, 1))

func test_priority_covers_tiled_zones() -> void:
	# Every legend zone except pond/void must have a priority for seam resolution.
	var priority: Dictionary = RECIPE["priority"]
	for ch in RECIPE["legend"]:
		var z: StringName = RECIPE["legend"][ch]
		if z == &"pond" or z == &"void":
			continue
		assert_true(priority.has(z), "zone '%s' needs a priority" % z)

func test_zones_have_material_defs() -> void:
	var zones: Dictionary = RECIPE["zones"]
	for ch in RECIPE["legend"]:
		var z: StringName = RECIPE["legend"][ch]
		if z == &"void" or z == &"pond":
			continue  # pond is an inset (its own water/rim colors in recipe.pond), not a base tile
		assert_true(zones.has(z), "zone '%s' needs a material def" % z)
		assert_true(zones[z].has("color"), "zone '%s' needs a color" % z)

func test_grid_builds_and_has_a_hub() -> void:
	var g := ZoneGrid.new(RECIPE["rows"], RECIPE["legend"], RECIPE["cell_size"])
	var hub := 0
	for y in g.height:
		for x in g.width:
			if g.zone_at(x, y) == &"stone_plaza":
				hub += 1
	assert_true(hub >= 16, "recipe must contain a central stone_plaza hub (got %d cells)" % hub)
