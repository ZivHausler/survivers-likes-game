# See docs/notes/stylize-layer.md
extends Node
## Stylize autoload — applies the cel_rim ShaderMaterial to character/enemy models.
## Call apply_to() after all texture/tint setup so albedo textures are already present
## on surface override materials and can be copied into the shader's albedo param.
## Removable: callers guard with get_node_or_null("/root/Stylize") so absence is a no-op.

const _SHADER_PATH := "res://shaders/cel_rim.gdshader"

## Walk all MeshInstance3D descendants of `node`, build a ShaderMaterial using
## cel_rim.gdshader, set albedo_tint and rim_color, preserve any albedo texture
## from the surface's active StandardMaterial3D, and assign as material_override.
func apply_to(node: Node3D, tint: Color, rim: Color) -> void:
	_walk(node, tint, rim)

func _walk(node: Node, tint: Color, rim: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			var mat := ShaderMaterial.new()
			mat.shader = load(_SHADER_PATH)
			mat.set_shader_parameter("albedo_tint", tint)
			mat.set_shader_parameter("rim_color", rim)
			# Preserve albedo texture from the first surface that carries one.
			for i in mi.mesh.get_surface_count():
				var existing: Material = mi.get_active_material(i)
				if existing is BaseMaterial3D:
					var tex: Texture2D = (existing as BaseMaterial3D).albedo_texture
					if tex:
						mat.set_shader_parameter("albedo", tex)
						break
			mi.material_override = mat
	for child in node.get_children():
		_walk(child, tint, rim)
