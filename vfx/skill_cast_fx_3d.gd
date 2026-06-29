# See docs/notes/skill-vfx.md
class_name SkillCastFx3D extends GPUParticles3D
## One-shot particle flourish at the weapon cast position in 3D. Auto-frees after playing.
## Usage: instantiate skill_cast_fx_3d.tscn, add to scene, call play_at(pos, color).

func play_at(pos: Vector3, color: Color) -> void:
	# Nudge up by 0.5 so particles burst at mid-body height rather than floor level.
	global_position = pos + Vector3(0.0, 0.5, 0.0)
	# Duplicate the shared process material so we can set a unique color per instance.
	var pmat: ParticleProcessMaterial = process_material.duplicate()
	pmat.color = color
	process_material = pmat
	# Apply a fresh emissive material so particles are visible against a dark arena.
	# vertex_color_use_as_albedo lets the process_material.color modulate albedo.
	var vmat := StandardMaterial3D.new()
	vmat.vertex_color_use_as_albedo = true
	vmat.albedo_color = color
	vmat.emission_enabled = true
	vmat.emission = color
	vmat.emission_energy_multiplier = 3.0
	material_override = vmat
	emitting = true
	var timer: SceneTreeTimer = get_tree().create_timer(lifetime + 0.2)
	timer.timeout.connect(queue_free)
