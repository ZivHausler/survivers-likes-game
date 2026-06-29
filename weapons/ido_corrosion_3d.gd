# See docs/notes/char-ido.md
class_name IdoCorrosion3D extends NovaWeapon3D
## Ido skill: "Corrosion" — concentrated acid burst dealing high damage in a medium radius.

func _ready() -> void:
	radius        = 5.0
	damage        = 20.0
	charm_duration = 0.0
	base_cooldown  = 3.0
	super()
