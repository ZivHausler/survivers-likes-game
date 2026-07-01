extends GutTest
## Structural tests for the Final City prop expansion (13 props).
## Each scene: loads as PackedScene, roots as Node3D, has >= 1 MeshInstance3D.
## prop_brazier_3d + prop_fountain_3d additionally require >= 1 OmniLight3D.

# --- paths ---
const ROCK_PATH       := "res://obstacles/prop_rock_3d.tscn"
const TREE_PATH       := "res://obstacles/prop_tree_3d.tscn"
const BUSH_PATH       := "res://obstacles/prop_bush_3d.tscn"
const GRASS_PATH      := "res://obstacles/prop_tall_grass_3d.tscn"
const MUSHROOM_PATH   := "res://obstacles/prop_mushroom_3d.tscn"
const CONE_PATH       := "res://obstacles/prop_cone_3d.tscn"
const DUMPSTER_PATH   := "res://obstacles/prop_dumpster_3d.tscn"
const HOLO_PATH       := "res://obstacles/prop_holo_sign_3d.tscn"
const GENERATOR_PATH  := "res://obstacles/prop_generator_3d.tscn"
const BARRIER_PATH    := "res://obstacles/prop_concrete_barrier_3d.tscn"
const PILLAR_PATH     := "res://obstacles/prop_pillar_3d.tscn"
const BRAZIER_PATH    := "res://obstacles/prop_brazier_3d.tscn"
const FOUNTAIN_PATH   := "res://obstacles/prop_fountain_3d.tscn"

# --- helpers ---
func _count_of_type(node: Node, klass) -> int:
	var total := 0
	for child in node.get_children():
		if is_instance_of(child, klass):
			total += 1
		total += _count_of_type(child, klass)
	return total

func _assert_prop(path: String, label: String) -> Node:
	var scene: PackedScene = load(path)
	assert_not_null(scene, "%s must load as PackedScene" % label)
	if scene == null:
		return null
	var root := scene.instantiate()
	assert_true(root is Node3D, "%s root must be Node3D, got %s" % [label, root.get_class()])
	var meshes := _count_of_type(root, MeshInstance3D)
	assert_gt(meshes, 0, "%s must have >= 1 MeshInstance3D, got %d" % [label, meshes])
	return root

# --- Rock ---
func test_rock_loads_and_has_mesh() -> void:
	var root := _assert_prop(ROCK_PATH, "prop_rock_3d")
	if root == null: return
	root.free()

# --- Tree ---
func test_tree_loads_and_has_mesh() -> void:
	var root := _assert_prop(TREE_PATH, "prop_tree_3d")
	if root == null: return
	root.free()

# --- Bush ---
func test_bush_loads_and_has_mesh() -> void:
	var root := _assert_prop(BUSH_PATH, "prop_bush_3d")
	if root == null: return
	root.free()

# --- Tall Grass ---
func test_tall_grass_loads_and_has_mesh() -> void:
	var root := _assert_prop(GRASS_PATH, "prop_tall_grass_3d")
	if root == null: return
	root.free()

# --- Mushroom ---
func test_mushroom_loads_and_has_mesh() -> void:
	var root := _assert_prop(MUSHROOM_PATH, "prop_mushroom_3d")
	if root == null: return
	root.free()

# --- Cone ---
func test_cone_loads_and_has_mesh() -> void:
	var root := _assert_prop(CONE_PATH, "prop_cone_3d")
	if root == null: return
	root.free()

# --- Dumpster ---
func test_dumpster_loads_and_has_mesh() -> void:
	var root := _assert_prop(DUMPSTER_PATH, "prop_dumpster_3d")
	if root == null: return
	root.free()

# --- Holo Sign ---
func test_holo_sign_loads_and_has_mesh() -> void:
	var root := _assert_prop(HOLO_PATH, "prop_holo_sign_3d")
	if root == null: return
	root.free()

# --- Generator ---
func test_generator_loads_and_has_mesh() -> void:
	var root := _assert_prop(GENERATOR_PATH, "prop_generator_3d")
	if root == null: return
	root.free()

# --- Concrete Barrier ---
func test_concrete_barrier_loads_and_has_mesh() -> void:
	var root := _assert_prop(BARRIER_PATH, "prop_concrete_barrier_3d")
	if root == null: return
	root.free()

# --- Pillar ---
func test_pillar_loads_and_has_mesh() -> void:
	var root := _assert_prop(PILLAR_PATH, "prop_pillar_3d")
	if root == null: return
	root.free()

# --- Brazier (also requires OmniLight3D) ---
func test_brazier_loads_and_has_mesh() -> void:
	var root := _assert_prop(BRAZIER_PATH, "prop_brazier_3d")
	if root == null: return
	root.free()

func test_brazier_has_omni_light() -> void:
	var scene: PackedScene = load(BRAZIER_PATH)
	assert_not_null(scene, "prop_brazier_3d.tscn must load")
	if scene == null: return
	var root := scene.instantiate()
	var lights := _count_of_type(root, OmniLight3D)
	assert_gt(lights, 0, "prop_brazier_3d must have >= 1 OmniLight3D, got %d" % lights)
	root.free()

# --- Fountain (also requires OmniLight3D) ---
func test_fountain_loads_and_has_mesh() -> void:
	var root := _assert_prop(FOUNTAIN_PATH, "prop_fountain_3d")
	if root == null: return
	root.free()

func test_fountain_has_omni_light() -> void:
	var scene: PackedScene = load(FOUNTAIN_PATH)
	assert_not_null(scene, "prop_fountain_3d.tscn must load")
	if scene == null: return
	var root := scene.instantiate()
	var lights := _count_of_type(root, OmniLight3D)
	assert_gt(lights, 0, "prop_fountain_3d must have >= 1 OmniLight3D, got %d" % lights)
	root.free()
