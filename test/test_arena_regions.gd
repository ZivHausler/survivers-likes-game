extends GutTest
## Structural + runtime tests for the tiled Garden arena (FloorBuilder + GardenScatter).

var Scene: PackedScene = null

func before_all() -> void:
	Scene = load("res://arena/arena_3d.tscn")

func _build_arena() -> Node:
	var root: Node = autofree(Scene.instantiate())
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	return root

func test_scene_loads() -> void:
	assert_not_null(Scene, "arena_3d.tscn must load")

func test_floor_builder_and_scatter_nodes_exist() -> void:
	var root := Scene.instantiate()
	assert_not_null(root.get_node_or_null("FloorBuilder"), "arena needs a FloorBuilder node")
	assert_not_null(root.get_node_or_null("GardenScatter"), "arena needs a GardenScatter node")
	root.free()

func test_garden_floor_is_built() -> void:
	var root := await _build_arena()
	var floor := root.get_node_or_null("GardenFloor")
	assert_not_null(floor, "FloorBuilder must build GardenFloor")
	var ground := floor.get_node_or_null("Ground") as MeshInstance3D
	assert_not_null(ground, "splat Ground mesh is built")
	var mat := ground.mesh.surface_get_material(0)
	assert_true(mat is ShaderMaterial, "ground uses the splat ShaderMaterial")
	assert_not_null(mat.get_shader_parameter("splatmap"), "splatmap control texture is set")

func test_props_are_built_and_clustered() -> void:
	var root := await _build_arena()
	var props := root.get_node_or_null("Props")
	assert_not_null(props, "GardenScatter must build Props")
	var land := props.get_node("Landmarks").get_child_count()
	assert_true(land >= 1 and land <= 3, "1-3 landmarks, got %d" % land)

func test_spawn_disc_clear() -> void:
	var root := await _build_arena()
	var props := root.get_node("Props")
	for group in ["Landmarks", "MediumProps", "SmallDetails"]:
		for p in props.get_node(group).get_children():
			var n := p as Node3D
			assert_true(Vector2(n.position.x, n.position.z).length() >= 12.0,
				"prop '%s' inside spawn disc" % n.name)
