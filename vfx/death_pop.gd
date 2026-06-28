# See docs/notes/vfx-system.md
class_name DeathPop extends CPUParticles2D
## One-shot particle burst at an enemy death position. Auto-frees after playing.
## Usage: instantiate death_pop.tscn, add to scene, call play_at(pos).

func play_at(pos: Vector2) -> void:
	global_position = pos
	emitting = true
	# Auto-free after particles finish (particle lifetime + small margin)
	var timer: SceneTreeTimer = get_tree().create_timer(lifetime + 0.2)
	timer.timeout.connect(queue_free)
