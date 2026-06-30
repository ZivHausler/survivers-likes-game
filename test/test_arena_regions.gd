extends GutTest
## Structural and runtime tests for the Final City arena biome-region layout.
## Verifies ground region planes, plaza centerpiece, obstacle count, and spawn
## disc clearance — all in headless mode using the real arena scene.

var Scene: PackedScene = null

func before_all() -> void:
	Scene = load("res://arena/arena_3d.tscn")

func _instantiate() -> Node:
	return Scene.instantiate()

# --- Static scene structure (no _ready needed) ---

func test_scene_loads() -> void:
	assert_not_null(Scene, "arena_3d.tscn must load")

func test_ground_regions_node_exists() -> void:
	var root := _instantiate()
	var regions := root.get_node_or_null("Ground/GroundRegions")
	assert_not_null(regions, "Ground/GroundRegions node must exist")
	root.free()

func test_plaza_and_roads_exist() -> void:
	var root := _instantiate()
	var regions := root.get_node_or_null("Ground/GroundRegions")
	assert_not_null(regions, "GroundRegions must exist")
	if regions == null:
		root.free()
		return
	for expected in ["PlazaCenter", "RoadNS", "RoadEW"]:
		assert_not_null(regions.get_node_or_null(expected),
				"GroundRegions must contain '%s'" % expected)
	root.free()

func test_quadrant_planes_exist() -> void:
	var root := _instantiate()
	var regions := root.get_node_or_null("Ground/GroundRegions")
	assert_not_null(regions, "GroundRegions must exist")
	if regions == null:
		root.free()
		return
	for expected in ["QuadrantNE", "QuadrantSW", "QuadrantSE"]:
		assert_not_null(regions.get_node_or_null(expected),
				"GroundRegions must contain quadrant plane '%s'" % expected)
	root.free()

func test_region_planes_have_albedo_textures() -> void:
	var root := _instantiate()
	var regions := root.get_node_or_null("Ground/GroundRegions")
	assert_not_null(regions, "GroundRegions must exist")
	if regions == null:
		root.free()
		return
	for node_name in ["PlazaCenter", "RoadNS", "RoadEW", "QuadrantNE", "QuadrantSW", "QuadrantSE"]:
		var mesh_node := regions.get_node_or_null(node_name) as MeshInstance3D
		assert_not_null(mesh_node, "%s must be a MeshInstance3D" % node_name)
		if mesh_node == null:
			continue
		var mat := mesh_node.get_surface_override_material(0) as StandardMaterial3D
		assert_not_null(mat, "%s must have a StandardMaterial3D" % node_name)
		if mat == null:
			continue
		assert_not_null(mat.albedo_texture,
				"%s material must have an albedo texture" % node_name)
	root.free()

# --- Runtime tests (require _ready / process frame) ---

func test_fountain_centerpiece_in_obstacles() -> void:
	var root: Node = autofree(_instantiate())
	add_child(root)
	await get_tree().process_frame
	var obstacles := root.get_node_or_null("Obstacles")
	assert_not_null(obstacles, "Obstacles container must exist")
	if obstacles == null:
		return
	var fountain := obstacles.get_node_or_null("Fountain")
	assert_not_null(fountain, "Obstacles must contain a node named 'Fountain' (plaza centerpiece)")

func test_obstacles_has_many_props() -> void:
	var root: Node = autofree(_instantiate())
	add_child(root)
	await get_tree().process_frame
	var obstacles := root.get_node_or_null("Obstacles")
	assert_not_null(obstacles, "Obstacles container must exist")
	if obstacles == null:
		return
	var count := 0
	for child in obstacles.get_children():
		if child is Obstacle3D:
			count += 1
	# 7 plaza (fountain+pillars) + 6 NW + 10 NE + 7 SW + 11 SE = 41 total.
	# Allow for rejection-sampling shortfall; require at least 20.
	assert_true(count >= 20,
			"Obstacles must have at least 20 Obstacle3D props across all regions, got %d" % count)

func test_spawn_disc_clear() -> void:
	var root: Node = autofree(_instantiate())
	add_child(root)
	await get_tree().process_frame
	var obstacles := root.get_node_or_null("Obstacles")
	assert_not_null(obstacles, "Obstacles container must exist")
	if obstacles == null:
		return
	for child in obstacles.get_children():
		if not (child is Obstacle3D):
			continue
		var dist := Vector2(child.position.x, child.position.z).length()
		assert_true(dist > 10.0,
				"Obstacle '%s' at (%.1f, %.1f) is within the 10-unit spawn disc"
				% [child.name, child.position.x, child.position.z])
