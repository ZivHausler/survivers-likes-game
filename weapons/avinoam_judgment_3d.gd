# See docs/notes/char-avinoam.md
class_name AvinoamJudgment3D extends NovaWeapon3D
## Avinoam skill: "Judgment" — concentrated divine wrath with high damage in a focused radius.
## NovaWeapon3D with high damage, narrower radius, slightly faster cooldown.

func _ready() -> void:
	radius        = 5.0
	damage        = 22.0
	charm_duration = 0.0
	base_cooldown  = 2.5
	super()
