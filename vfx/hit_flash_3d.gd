# See docs/notes/juice-3d.md
class_name HitFlash3D extends Node
## Static utility — call HitFlash3D.flash() anywhere; no instance needed.
## Briefly overrides a MeshInstance3D's material with a white-emission flash,
## then restores the original material via a tween. No-ops safely if no mesh found.

## Flash the nearest MeshInstance3D under `target` white, then restore over `dur` seconds.
## `target` is Variant (not Node3D) so a freed object is caught by is_instance_valid().
static func flash(target: Variant, dur: float) -> void:
	if not is_instance_valid(target):
		return
	var node := target as Node
	if node == null:
		return
	var mesh_inst: MeshInstance3D = _find_mesh(node)
	if mesh_inst == null:
		return
	var original_mat: Material = mesh_inst.material_override
	var flash_mat := StandardMaterial3D.new()
	flash_mat.albedo_color = Color.WHITE
	flash_mat.emission_enabled = true
	flash_mat.emission = Color.WHITE
	flash_mat.emission_energy_multiplier = 2.0
	mesh_inst.material_override = flash_mat
	var tween: Tween = mesh_inst.create_tween()
	tween.tween_interval(dur)
	tween.tween_callback(func() -> void:
		if is_instance_valid(mesh_inst):
			mesh_inst.material_override = original_mat
	)

## Depth-first search for the first MeshInstance3D under (or equal to) `node`.
static func _find_mesh(node: Node) -> MeshInstance3D:
	if node == null:
		return null
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found: MeshInstance3D = _find_mesh(child)
		if found != null:
			return found
	return null
