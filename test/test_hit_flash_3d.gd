# See docs/notes/juice-3d.md
extends GutTest
## Tests for HitFlash3D static utility.
## Verifies: no-op safety on nodes without meshes; flash doesn't crash; material restored.

# ── Guard: freed node ─────────────────────────────────────────────────────────

func test_flash_no_crash_on_freed_node() -> void:
	var node := Node3D.new()
	node.free()
	HitFlash3D.flash(node, 0.1)
	assert_true(true, "HitFlash3D.flash must not crash on a freed node")

# ── Guard: node without a MeshInstance3D ─────────────────────────────────────

func test_flash_no_crash_on_plain_node3d_no_mesh() -> void:
	var node: Node3D = add_child_autofree(Node3D.new())
	HitFlash3D.flash(node, 0.1)
	assert_true(true, "HitFlash3D.flash must not crash on a Node3D with no mesh child")

func test_flash_no_crash_on_null() -> void:
	HitFlash3D.flash(null, 0.1)
	assert_true(true, "HitFlash3D.flash(null) must not crash")

# ── Flash on a direct MeshInstance3D ─────────────────────────────────────────

func test_flash_on_mesh_instance_does_not_crash() -> void:
	var mesh_inst: MeshInstance3D = add_child_autofree(MeshInstance3D.new())
	mesh_inst.mesh = SphereMesh.new()
	HitFlash3D.flash(mesh_inst, 0.3)
	assert_true(true, "HitFlash3D.flash must not crash on a MeshInstance3D")

func test_flash_overrides_material_during_flash() -> void:
	var mesh_inst: MeshInstance3D = add_child_autofree(MeshInstance3D.new())
	mesh_inst.mesh = SphereMesh.new()
	var orig := StandardMaterial3D.new()
	orig.albedo_color = Color(0.4, 0.4, 0.4, 1.0)
	mesh_inst.material_override = orig
	HitFlash3D.flash(mesh_inst, 0.5)
	# Immediately after call, the flash material should be set (override replaced)
	assert_ne(mesh_inst.material_override, orig, "Material override must change during flash")

func test_flash_restores_material_after_duration() -> void:
	var mesh_inst: MeshInstance3D = add_child_autofree(MeshInstance3D.new())
	mesh_inst.mesh = SphereMesh.new()
	var orig := StandardMaterial3D.new()
	orig.albedo_color = Color(0.4, 0.4, 0.4, 1.0)
	mesh_inst.material_override = orig
	HitFlash3D.flash(mesh_inst, 0.1)
	await get_tree().create_timer(0.25).timeout
	assert_eq(mesh_inst.material_override, orig, "Material override must be restored after flash duration")

# ── Flash on a parent node with a MeshInstance3D child ───────────────────────

func test_flash_on_parent_finds_mesh_child_no_crash() -> void:
	var parent: Node3D = add_child_autofree(Node3D.new())
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	parent.add_child(mesh_inst)
	HitFlash3D.flash(parent, 0.1)
	assert_true(true, "HitFlash3D.flash must find MeshInstance3D under parent and not crash")

func test_flash_on_parent_overrides_child_material() -> void:
	var parent: Node3D = add_child_autofree(Node3D.new())
	var mesh_inst := MeshInstance3D.new()
	mesh_inst.mesh = BoxMesh.new()
	var orig := StandardMaterial3D.new()
	orig.albedo_color = Color(0.2, 0.5, 0.8, 1.0)
	mesh_inst.material_override = orig
	parent.add_child(mesh_inst)
	HitFlash3D.flash(parent, 0.5)
	assert_ne(mesh_inst.material_override, orig, "Child mesh material override must change during flash")
