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

func test_arena_contains_water() -> void:
	# Water is now a procedural mesh built by MapBuilder (deferred at _ready).
	var root: Node = autofree(_instantiate())
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	var gg := root.get_node_or_null("GeneratedGround")
	assert_not_null(gg, "GeneratedGround must be built")
	var found := false
	if gg != null:
		for child in gg.get_children():
			if child.name.begins_with("Water"):
				found = true
				break
	assert_true(found, "MapBuilder must build at least one water body mesh")

func test_scatter_spawns_obstacles_at_runtime() -> void:
	var root: Node = autofree(_instantiate())
	add_child(root)   # entering the tree runs the spawner's _ready
	await get_tree().process_frame
	var obstacles := root.get_node_or_null("Obstacles")
	assert_not_null(obstacles, "arena must have an Obstacles container")
	var count := 0
	for child in obstacles.get_children():
		if child is Obstacle3D:
			count += 1
	assert_true(count > 0, "scatter must spawn at least one Obstacle3D at runtime")

## Count MeshInstance3D nodes at any depth inside node (skipping invisible placeholders).
func _count_visible_mesh_instances_in(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if child is MeshInstance3D and (child as MeshInstance3D).visible:
			total += 1
		total += _count_visible_mesh_instances_in(child)
	return total

func test_pylon_obstacle_has_mesh_instances() -> void:
	var root: Node = autofree(_instantiate())
	add_child(root)
	await get_tree().process_frame
	var obstacles := root.get_node_or_null("Obstacles")
	assert_not_null(obstacles, "Obstacles container must exist")
	if obstacles == null:
		return
	# All obstacle props are wrapped models; confirm any even-indexed one has a visible mesh.
	var checked := false
	for i in obstacles.get_child_count():
		if i % 2 != 0:
			continue
		var child := obstacles.get_child(i)
		if not (child is Obstacle3D):
			continue
		var mesh_count := _count_visible_mesh_instances_in(child)
		assert_true(mesh_count >= 1,
			"Obstacle3D at index %d must contain at least one visible MeshInstance3D, got %d" % [i, mesh_count])
		checked = true
		break  # one confirmed obstacle is sufficient
	assert_true(checked, "at least one even-indexed Obstacle3D must have been inspected")
