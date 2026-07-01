extends GutTest
## Structural tests for the tiled floor builder. Runs headless (meshes, no display).

const FloorBuilder := preload("res://arena/floor/floor_builder.gd")
const ZoneGrid := preload("res://arena/floor/zone_grid.gd")

func _build() -> Node3D:
	var root := Node3D.new()
	add_child_autofree(root)
	var fb := FloorBuilder.new()
	fb.recipe_path = "res://arena/maps/garden_map.gd"
	fb.build_into(root)
	fb.free()
	return root

func _count_non_floor_cells() -> int:
	var recipe: Dictionary = load("res://arena/maps/garden_map.gd").RECIPE
	var g := ZoneGrid.new(recipe["rows"], recipe["legend"], recipe["cell_size"])
	var n := 0
	for y in g.height:
		for x in g.width:
			var z := g.zone_at(x, y)
			if z != &"void" and z != &"pond":
				n += 1
	return n

func test_garden_floor_root_and_containers() -> void:
	var root := _build()
	var floor := root.get_node_or_null("GardenFloor")
	assert_not_null(floor, "FloorBuilder must build a GardenFloor node")
	for c in ["BaseTiles", "TransitionTrims", "Decals", "Pond"]:
		assert_not_null(floor.get_node_or_null(c), "GardenFloor must contain %s" % c)

func test_one_base_tile_per_floor_cell() -> void:
	var root := _build()
	var tiles := root.get_node("GardenFloor/BaseTiles")
	assert_eq(tiles.get_child_count(), _count_non_floor_cells(),
		"one base tile per non-void, non-pond cell")

func test_base_tiles_have_surface_material() -> void:
	var root := _build()
	var tiles := root.get_node("GardenFloor/BaseTiles")
	var checked := 0
	for t in tiles.get_children():
		if t is MeshInstance3D:
			var mesh: Mesh = (t as MeshInstance3D).mesh
			assert_not_null(mesh, "tile has a mesh")
			assert_not_null(mesh.surface_get_material(0),
				"tile mesh surface 0 must have a material (avoids null-material render spam)")
			checked += 1
			if checked >= 5:
				break
	assert_true(checked > 0, "at least one base tile inspected")
