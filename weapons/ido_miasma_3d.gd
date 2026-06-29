# See docs/notes/char-ido.md
class_name IdoMiasma3D extends NovaWeapon3D
## Ido skill: "Miasma" — a wide toxic cloud pulse that deals moderate damage.

func _ready() -> void:
	radius        = 6.5
	damage        = 16.0
	charm_duration = 0.0
	base_cooldown  = 2.5
	super()
