# See docs/notes/vfx-system.md
class_name XpSparkle extends CPUParticles2D
## Small golden sparkle burst at the player's position when XP is collected.
## Auto-frees after particle lifetime + 0.2 s.
## Usage: instantiate xp_sparkle.tscn, add_child to scene, call play_at(pos).

func _ready() -> void:
	amount                 = 8
	lifetime               = 0.4
	one_shot               = true
	explosiveness          = 0.9
	spread                 = 180.0
	initial_velocity_min   = 20.0
	initial_velocity_max   = 60.0
	scale_amount_min       = 1.0
	scale_amount_max       = 3.0
	color                  = Color(1.0, 0.85, 0.1, 1.0)   # gold
	emitting               = false

func play_at(pos: Vector2) -> void:
	global_position = pos
	emitting = true
	var timer: SceneTreeTimer = get_tree().create_timer(lifetime + 0.2)
	timer.timeout.connect(queue_free)
