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

## Counts all cells the ground mesh covers: every non-void cell, INCLUDING pond cells.
## (Pond cells are included in the ground so the vertex-alpha water disc reveals the
## splatmapped grass underneath at the shoreline.)
func _count_ground_cells() -> int:
	var recipe: Dictionary = load("res://arena/maps/garden_map.gd").RECIPE
	var g := ZoneGrid.new(recipe["rows"], recipe["legend"], recipe["cell_size"])
	var n := 0
	for y in g.height:
		for x in g.width:
			if g.zone_at(x, y) != &"void":
				n += 1
	return n

func test_garden_floor_root_and_containers() -> void:
	var root := _build()
	var floor := root.get_node_or_null("GardenFloor")
	assert_not_null(floor, "FloorBuilder must build a GardenFloor node")
	# Splatmap rewrite: one merged Ground mesh + Decals + Pond + Centerpiece (no per-tile nodes).
	for c in ["Ground", "Decals", "Pond", "Centerpiece"]:
		assert_not_null(floor.get_node_or_null(c), "GardenFloor must contain %s" % c)

func test_ground_is_single_mesh_instance() -> void:
	var root := _build()
	var ground := root.get_node("GardenFloor/Ground")
	assert_true(ground is MeshInstance3D, "Ground must be a MeshInstance3D")
	var mi := ground as MeshInstance3D
	assert_not_null(mi.mesh, "Ground MeshInstance3D must have a mesh")
	assert_true(mi.mesh.get_surface_count() > 0, "Ground mesh must have at least one surface")

func test_ground_has_splat_shader_material() -> void:
	var root := _build()
	var ground := root.get_node("GardenFloor/Ground") as MeshInstance3D
	var mat := ground.mesh.surface_get_material(0)
	assert_not_null(mat, "Ground mesh surface 0 must have a material")
	assert_true(mat is ShaderMaterial,
		"Ground must use a ShaderMaterial (splatmap shader, not a StandardMaterial3D)")

func test_ground_covers_all_floor_cells() -> void:
	# The merged quad mesh must cover every non-void cell (including pond cells, which are
	# covered by the ground so the shoreline vertex-alpha fade reveals grass beneath).
	# vertex count = cells * 6 (two tris per quad, no index buffer).
	var root := _build()
	var ground := root.get_node("GardenFloor/Ground") as MeshInstance3D
	var arrays := ground.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var expected_verts := _count_ground_cells() * 6
	assert_eq(verts.size(), expected_verts,
		"ground mesh vertex count must equal non-void cells * 6 (two tris each)")

func test_ground_blends_zones_via_splatmap() -> void:
	# ShaderMaterial must carry a splatmap and an ao_map texture parameter.
	var root := _build()
	var ground := root.get_node("GardenFloor/Ground") as MeshInstance3D
	var mat := ground.mesh.surface_get_material(0) as ShaderMaterial
	assert_not_null(mat.get_shader_parameter("splatmap"),
		"ShaderMaterial must have a splatmap parameter for zone blending")
	assert_not_null(mat.get_shader_parameter("ao_map"),
		"ShaderMaterial must have an ao_map parameter for edge darkening")

func test_authored_decals_placed() -> void:
	var root := _build()
	var decals := root.get_node("GardenFloor/Decals")
	var recipe: Dictionary = load("res://arena/maps/garden_map.gd").RECIPE
	assert_eq(decals.get_child_count(), (recipe["decals"] as Array).size(),
		"one Decal node per authored decal entry")

func test_pond_surface_and_rim_built() -> void:
	var root := _build()
	var pond := root.get_node("GardenFloor/Pond")
	# Splatmap rewrite: the shoreline rim is now baked into the water mesh as vertex-alpha fade
	# (no separate rim node). One PondWater MeshInstance3D suffices.
	assert_true(pond.get_child_count() >= 1, "pond must have a water surface MeshInstance3D")
