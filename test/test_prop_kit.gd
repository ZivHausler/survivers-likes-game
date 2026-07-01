extends GutTest
## Structural tests: all 5 primitive prop scenes load, instance as Node3D,
## and contain at least one MeshInstance3D. The lamp additionally requires
## an OmniLight3D child.

const CRATE_PATH   := "res://obstacles/prop_crate_3d.tscn"
const BARREL_PATH  := "res://obstacles/prop_barrel_3d.tscn"
const LAMP_PATH    := "res://obstacles/prop_lamp_3d.tscn"
const FENCE_PATH   := "res://obstacles/prop_fence_3d.tscn"
const FLOWERS_PATH := "res://obstacles/prop_flowers_3d.tscn"

func _count_of_type(node: Node, klass) -> int:
	var total := 0
	for child in node.get_children():
		if is_instance_of(child, klass):
			total += 1
		total += _count_of_type(child, klass)
	return total

# --- Crate ---

func test_crate_scene_loads() -> void:
	var scene: PackedScene = load(CRATE_PATH)
	assert_not_null(scene, "prop_crate_3d.tscn must load as PackedScene")

func test_crate_root_is_node3d() -> void:
	var scene: PackedScene = load(CRATE_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var root := scene.instantiate()
	assert_true(root is Node3D, "crate root must be Node3D, got %s" % root.get_class())
	root.free()

func test_crate_has_mesh_instances() -> void:
	var scene: PackedScene = load(CRATE_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var root := scene.instantiate()
	var count := _count_of_type(root, MeshInstance3D)
	assert_gt(count, 0, "prop_crate_3d must contain >= 1 MeshInstance3D, got %d" % count)
	root.free()

# --- Barrel ---

func test_barrel_scene_loads() -> void:
	var scene: PackedScene = load(BARREL_PATH)
	assert_not_null(scene, "prop_barrel_3d.tscn must load as PackedScene")

func test_barrel_root_is_node3d() -> void:
	var scene: PackedScene = load(BARREL_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var root := scene.instantiate()
	assert_true(root is Node3D, "barrel root must be Node3D, got %s" % root.get_class())
	root.free()

func test_barrel_has_mesh_instances() -> void:
	var scene: PackedScene = load(BARREL_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var root := scene.instantiate()
	var count := _count_of_type(root, MeshInstance3D)
	assert_gt(count, 0, "prop_barrel_3d must contain >= 1 MeshInstance3D, got %d" % count)
	root.free()

# --- Lamp ---

func test_lamp_scene_loads() -> void:
	var scene: PackedScene = load(LAMP_PATH)
	assert_not_null(scene, "prop_lamp_3d.tscn must load as PackedScene")

func test_lamp_root_is_node3d() -> void:
	var scene: PackedScene = load(LAMP_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var root := scene.instantiate()
	assert_true(root is Node3D, "lamp root must be Node3D, got %s" % root.get_class())
	root.free()

func test_lamp_has_mesh_instances() -> void:
	var scene: PackedScene = load(LAMP_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var root := scene.instantiate()
	var count := _count_of_type(root, MeshInstance3D)
	assert_gt(count, 0, "prop_lamp_3d must contain >= 1 MeshInstance3D, got %d" % count)
	root.free()

func test_lamp_has_omni_light() -> void:
	var scene: PackedScene = load(LAMP_PATH)
	assert_not_null(scene, "prop_lamp_3d.tscn must load")
	if scene == null:
		return
	var root := scene.instantiate()
	var count := _count_of_type(root, OmniLight3D)
	assert_gt(count, 0, "prop_lamp_3d must contain >= 1 OmniLight3D, got %d" % count)
	root.free()

# --- Fence ---

func test_fence_scene_loads() -> void:
	var scene: PackedScene = load(FENCE_PATH)
	assert_not_null(scene, "prop_fence_3d.tscn must load as PackedScene")

func test_fence_root_is_node3d() -> void:
	var scene: PackedScene = load(FENCE_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var root := scene.instantiate()
	assert_true(root is Node3D, "fence root must be Node3D, got %s" % root.get_class())
	root.free()

func test_fence_has_mesh_instances() -> void:
	var scene: PackedScene = load(FENCE_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var root := scene.instantiate()
	var count := _count_of_type(root, MeshInstance3D)
	assert_gt(count, 0, "prop_fence_3d must contain >= 1 MeshInstance3D, got %d" % count)
	root.free()

# --- Flowers ---

func test_flowers_scene_loads() -> void:
	var scene: PackedScene = load(FLOWERS_PATH)
	assert_not_null(scene, "prop_flowers_3d.tscn must load as PackedScene")

func test_flowers_root_is_node3d() -> void:
	var scene: PackedScene = load(FLOWERS_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var root := scene.instantiate()
	assert_true(root is Node3D, "flowers root must be Node3D, got %s" % root.get_class())
	root.free()

func test_flowers_has_mesh_instances() -> void:
	var scene: PackedScene = load(FLOWERS_PATH)
	assert_not_null(scene)
	if scene == null:
		return
	var root := scene.instantiate()
	var count := _count_of_type(root, MeshInstance3D)
	assert_gt(count, 0, "prop_flowers_3d must contain >= 1 MeshInstance3D, got %d" % count)
	root.free()
