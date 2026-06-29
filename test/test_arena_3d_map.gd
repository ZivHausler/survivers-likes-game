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
