# See docs/notes/juice-3d.md
class_name DeathPop3D extends GPUParticles3D
## One-shot particle burst at an enemy death position in 3D. Auto-frees after playing.
## Usage: instantiate death_pop_3d.tscn, add to scene, call play_at(pos).

func play_at(pos: Vector3) -> void:
	global_position = pos
	emitting = true
	var timer: SceneTreeTimer = get_tree().create_timer(lifetime + 0.2)
	timer.timeout.connect(queue_free)
