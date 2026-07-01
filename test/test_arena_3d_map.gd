extends GutTest
## Structural tests for the realistic arena map (ground material + sky + props root).

var Scene: PackedScene = null

func before_all() -> void:
	Scene = load("res://arena/arena_3d.tscn")

func _instantiate() -> Node:
	return Scene.instantiate()

func test_scene_loads() -> void:
	assert_not_null(Scene, "arena_3d.tscn must load")

func test_ground_has_albedo_texture() -> void:
	var root := _instantiate()
	var mesh: MeshInstance3D = root.get_node("Ground/GroundMesh")
	var mat: StandardMaterial3D = mesh.get_surface_override_material(0)
	assert_not_null(mat, "ground must have a material")
	assert_not_null(mat.albedo_texture, "ground material must use a PBR albedo texture")
	root.free()

func test_environment_uses_sky_background() -> void:
	var root := _instantiate()
	var we: WorldEnvironment = root.get_node("WorldEnvironment")
	# Environment.BG_SKY == 2
	assert_eq(we.environment.background_mode, 2,
		"WorldEnvironment must use Sky background, not solid color")
	root.free()

const OBSTACLE_BIT := 16

func test_has_four_border_walls_on_obstacle_layer() -> void:
	var root := _instantiate()
	var borders := root.get_node_or_null("Borders")
	assert_not_null(borders, "arena must have a Borders node")
	var walls := 0
	for child in borders.get_children():
		if child is StaticBody3D and ((child as StaticBody3D).collision_layer & OBSTACLE_BIT) == OBSTACLE_BIT:
			walls += 1
	assert_eq(walls, 4, "must have 4 border walls on the Obstacles layer")
	root.free()

func test_floor_tiles_built_at_runtime() -> void:
	var root: Node = autofree(_instantiate())
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	var floor := root.get_node_or_null("GardenFloor")
	assert_not_null(floor, "GardenFloor must be built at runtime")
	assert_not_null(floor.get_node_or_null("Ground"), "splat Ground mesh built")
