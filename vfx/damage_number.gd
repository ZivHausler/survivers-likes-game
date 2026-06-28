# See docs/notes/vfx-system.md
class_name DamageNumber extends Label
## Floating damage / XP number. Floats upward and fades out, then frees itself.
## Usage: instantiate damage_number.tscn, add to scene, call setup().

const LIFETIME: float = 0.8    ## Total animation duration in seconds
const FLOAT_DIST: float = 30.0  ## Pixels to float upward over LIFETIME

func setup(amount: int, pos: Vector2) -> void:
	text = str(amount)
	global_position = pos
	modulate.a = 1.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:y", pos.y - FLOAT_DIST, LIFETIME)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME)
	tween.finished.connect(queue_free)
