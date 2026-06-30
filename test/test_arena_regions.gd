extends GutTest
## Structural and runtime tests for the Final City arena biome-region layout.
## Verifies ground region planes, plaza centerpiece, obstacle count, and spawn
## disc clearance — all in headless mode using the real arena scene.

var Scene: PackedScene = null

func before_all() -> void:
	Scene = load("res://arena/arena_3d.tscn")

func _instantiate() -> Node:
	return Scene.instantiate()

# --- Procedural ground (built by MapBuilder, deferred at _ready) ---

## Instantiate, enter the tree, and wait for the deferred MapBuilder + scatter builds.
func _build_arena() -> Node:
	var root: Node = autofree(_instantiate())
	add_child(root)
	await get_tree().process_frame
	await get_tree().process_frame
	return root

## Collect direct children of GeneratedGround whose name starts with `prefix`.
func _ground_children(root: Node, prefix: String) -> Array:
	var out: Array = []
	var gg := root.get_node_or_null("GeneratedGround")
	if gg == null:
		return out
	for child in gg.get_children():
		if child.name.begins_with(prefix):
			out.append(child)
	return out

func test_scene_loads() -> void:
	assert_not_null(Scene, "arena_3d.tscn must load")

func test_ground_builder_node_exists() -> void:
	var root := _instantiate()
	assert_not_null(root.get_node_or_null("GroundBuilder"),
			"arena must have a GroundBuilder (MapBuilder) node")
	root.free()

func test_generated_ground_is_built() -> void:
	var root := await _build_arena()
	var gg := root.get_node_or_null("GeneratedGround")
	assert_not_null(gg, "MapBuilder must build a GeneratedGround node")
	if gg != null:
		assert_true(gg.get_child_count() > 0, "GeneratedGround must contain ground meshes")

func test_paths_and_medallion_exist() -> void:
	var root := await _build_arena()
	assert_true(_ground_children(root, "Path").size() >= 1,
			"MapBuilder must build at least one winding path ribbon")
	assert_true(_ground_children(root, "FeatureRing").size() >= 1,
			"MapBuilder must build the central plaza medallion rings")
	assert_true(_ground_children(root, "FeatureDisc").size() >= 1,
			"MapBuilder must build the plaza medallion discs")

func test_biome_meshes_exist() -> void:
	var root := await _build_arena()
	assert_true(_ground_children(root, "Biome").size() >= 4,
			"MapBuilder must build several organic biome districts")

func test_biome_meshes_have_albedo_textures() -> void:
	var root := await _build_arena()
	var biomes := _ground_children(root, "Biome")
	assert_true(biomes.size() >= 1, "at least one biome mesh must exist to inspect")
	for mi in biomes:
		var mat := (mi as MeshInstance3D).material_override as StandardMaterial3D
		assert_not_null(mat, "%s must have a StandardMaterial3D override" % mi.name)
		if mat != null:
			assert_not_null(mat.albedo_texture,
					"%s material must have an albedo texture" % mi.name)

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
	# 9 plaza (fountain + 8 pillars) + district/grove clusters ~= 60 total.
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
