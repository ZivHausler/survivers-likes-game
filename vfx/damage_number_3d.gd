# See docs/notes/juice-3d.md
class_name DamageNumber3D extends Label3D
## Floating 3D XP/damage number. Floats upward and fades over LIFETIME, then frees.
## Usage: instantiate damage_number_3d.tscn, add to scene, call setup().

const LIFETIME: float = 0.8   ## Total animation duration in seconds
const FLOAT_DIST: float = 1.5 ## World units to float upward over LIFETIME

func setup(value: int, pos: Vector3) -> void:
	text = str(value)
	global_position = pos
	modulate.a = 1.0
	var tween: Tween = create_tween().set_parallel(true)
	tween.tween_property(self, "global_position:y", pos.y + FLOAT_DIST, LIFETIME)
	tween.tween_property(self, "modulate:a", 0.0, LIFETIME)
	tween.finished.connect(queue_free)
