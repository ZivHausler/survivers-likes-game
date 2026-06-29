# See docs/notes/char-natali.md
class_name NataliGiggleBurst3D extends NovaWeapon3D
## Natali skill: "Giggle Burst" — a wide laugh wave that deals moderate damage.
## NovaWeapon3D tuned for wider radius and slightly higher damage.

func _ready() -> void:
	radius         = 6.5
	damage         = 18.0
	charm_duration = 0.0
	base_cooldown  = 3.0
	super()
