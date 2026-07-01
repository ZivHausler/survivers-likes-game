# See docs/notes/aoe-telegraph.md
class_name AoeTelegraph3D extends MeshInstance3D
## Flat additive ring telegraph drawn on the XZ ground plane.
## Usage: instantiate aoe_telegraph_3d.tscn, add to scene, call play_at(pos, radius, color).
## The ring expands from center outward over its lifetime then auto-frees.

const _SHADER:    Shader = preload("res://shaders/telegraph_ring.gdshader")
const _LIFETIME  := 0.8   # total duration in seconds
const _RING_WIDTH := 0.06  # normalized ring half-width (shader uniform)
const _Y_LIFT     := 0.02  # lift above ground to prevent z-fighting

func play_at(pos: Vector3, radius: float, color: Color) -> void:
	# Position: match XZ, lift Y slightly to prevent z-fighting with terrain.
	global_position = Vector3(pos.x, pos.y + _Y_LIFT, pos.z)
	# Scale the mesh so 1 UV unit == radius world-units on XZ.
	scale = Vector3(radius * 2.0, 1.0, radius * 2.0)

	# Create a fresh ShaderMaterial so each instance animates independently.
	var mat := ShaderMaterial.new()
	mat.shader = _SHADER
	material_override = mat
	mat.set_shader_parameter("ring_color", Color(color.r, color.g, color.b, 1.0))
	mat.set_shader_parameter("radius", 0.02)
	mat.set_shader_parameter("width", _RING_WIDTH)

	var tween: Tween = create_tween()
	# Phase 1 (70 %): expand ring from center to outer edge.
	tween.tween_property(mat, "shader_parameter/radius", 0.92, _LIFETIME * 0.7)
	# Phase 2 (30 %): fade out alpha to 0.
	var fade := Color(color.r, color.g, color.b, 0.0)
	tween.tween_property(mat, "shader_parameter/ring_color", fade, _LIFETIME * 0.3)

	get_tree().create_timer(_LIFETIME + 0.1).timeout.connect(queue_free)
