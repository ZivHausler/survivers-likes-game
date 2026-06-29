# See docs/notes/skill-vfx.md
class_name SkillCastFx3D extends GPUParticles3D
## One-shot particle flourish at the weapon cast position in 3D. Auto-frees after playing.
## Usage: instantiate skill_cast_fx_3d.tscn, add to scene, call play_at(pos, color).

func play_at(pos: Vector3, color: Color) -> void:
	global_position = pos
	# Duplicate the shared material so we can set a unique color per instance.
	var mat: ParticleProcessMaterial = process_material.duplicate()
	mat.color = color
	process_material = mat
	emitting = true
	var timer: SceneTreeTimer = get_tree().create_timer(lifetime + 0.2)
	timer.timeout.connect(queue_free)
