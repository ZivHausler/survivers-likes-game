extends GutTest
## Structural tests: both sci-fi prop scenes load and instance as Node3D
## with at least one MeshInstance3D child.

const PYLON_PATH := "res://obstacles/sci_fi_pylon_3d.tscn"
const BARRIER_PATH := "res://obstacles/sci_fi_barrier_3d.tscn"

func _count_mesh_instances(node: Node) -> int:
	var total := 0
	for child in node.get_children():
		if child is MeshInstance3D:
			total += 1
		total += _count_mesh_instances(child)
	return total

func test_pylon_scene_loads() -> void:
	var scene: PackedScene = load(PYLON_PATH)
	assert_not_null(scene, "sci_fi_pylon_3d.tscn must load as PackedScene")

func test_pylon_root_is_node3d() -> void:
	var scene: PackedScene = load(PYLON_PATH)
	assert_not_null(scene)
	var root := scene.instantiate()
	assert_true(root is Node3D, "pylon root must be a Node3D, got %s" % root.get_class())
	root.free()

func test_pylon_has_mesh_instances() -> void:
	var scene: PackedScene = load(PYLON_PATH)
	assert_not_null(scene)
	var root := scene.instantiate()
	var count := _count_mesh_instances(root)
	assert_true(count >= 1,
		"sci_fi_pylon_3d must contain at least one MeshInstance3D, got %d" % count)
	root.free()

func test_barrier_scene_loads() -> void:
	var scene: PackedScene = load(BARRIER_PATH)
	assert_not_null(scene, "sci_fi_barrier_3d.tscn must load as PackedScene")

func test_barrier_root_is_node3d() -> void:
	var scene: PackedScene = load(BARRIER_PATH)
	assert_not_null(scene)
	var root := scene.instantiate()
	assert_true(root is Node3D, "barrier root must be a Node3D, got %s" % root.get_class())
	root.free()

func test_barrier_has_mesh_instances() -> void:
	var scene: PackedScene = load(BARRIER_PATH)
	assert_not_null(scene)
	var root := scene.instantiate()
	var count := _count_mesh_instances(root)
	assert_true(count >= 1,
		"sci_fi_barrier_3d must contain at least one MeshInstance3D, got %d" % count)
	root.free()
