extends GutTest
## Every new Garden prop scene must load and contain a visible mesh (no empty props).

const KEYS := [
	"garden_hero_tree_3d", "garden_bench_3d", "garden_planter_3d",
	"garden_trellis_3d", "garden_bollard_3d",
]

func _count_visible_meshes(node: Node) -> int:
	var n := 0
	for c in node.get_children():
		if c is MeshInstance3D and (c as MeshInstance3D).visible:
			n += 1
		n += _count_visible_meshes(c)
	return n

func test_all_garden_props_load_with_a_visible_mesh() -> void:
	for k in KEYS:
		var path := "res://obstacles/%s.tscn" % k
		assert_true(ResourceLoader.exists(path), "%s must exist" % path)
		var scene: PackedScene = load(path)
		assert_not_null(scene, "%s must load" % path)
		var inst := scene.instantiate()
		assert_true(inst is Node3D, "%s root must be Node3D" % k)
		assert_true(_count_visible_meshes(inst) >= 1, "%s must have >=1 visible MeshInstance3D" % k)
		inst.free()
