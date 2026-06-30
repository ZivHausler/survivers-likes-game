# See docs/notes/stylize-layer.md
extends GutTest

func test_apply_to_sets_shader_material_override() -> void:
	var root := Node3D.new()
	add_child_autofree(root)
	var mi := MeshInstance3D.new()
	mi.mesh = BoxMesh.new()
	root.add_child(mi)

	Stylize.apply_to(root, Color.RED, Color.WHITE)

	assert_true(mi.material_override is ShaderMaterial,
			"material_override must be a ShaderMaterial")
	assert_eq(
			(mi.material_override as ShaderMaterial).shader.resource_path,
			"res://shaders/cel_rim.gdshader",
			"shader must be cel_rim.gdshader")
