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
	var root := _instantiate()
	var found := false
	for child in root.get_children():
		if child is Water3D:
			found = true
			break
	assert_true(found, "arena must contain at least one Water3D body")
	root.free()

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

## Counts nodes whose name contains "fir_tree" and "_LOD0" at any depth inside node.
## Pre-fix: 3 (all three gltf siblings). Post-fix: exactly 1 (single variant).
func _count_fir_lod0_in(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if "fir_tree" in child.name and "_LOD0" in child.name:
			total += 1
		total += _count_fir_lod0_in(child)
	return total

func test_tree_obstacle_has_single_fir_variant() -> void:
	var root: Node = autofree(_instantiate())
	add_child(root)
	await get_tree().process_frame
	var obstacles := root.get_node_or_null("Obstacles")
	assert_not_null(obstacles, "Obstacles container must exist")
	if obstacles == null:
		return
	# Even-indexed children are trees (ArenaScatter spawns tree when i%2==0).
	var checked := false
	for i in obstacles.get_child_count():
		if i % 2 != 0:
			continue
		var child := obstacles.get_child(i)
		if not (child is Obstacle3D):
			continue
		var lod_count := _count_fir_lod0_in(child)
		assert_eq(lod_count, 1,
			"tree Obstacle3D must contain exactly ONE fir_tree*_LOD0 variant, got %d" % lod_count)
		checked = true
		break  # one confirmed tree is sufficient to prove the fix
	assert_true(checked, "at least one tree Obstacle3D must have been inspected")
