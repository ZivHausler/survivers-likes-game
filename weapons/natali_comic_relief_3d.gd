# See docs/notes/char-natali.md
class_name NataliComicRelief3D extends NovaWeapon3D
## Natali skill: "Comic Relief" — a burst of joyful energy that damages enemies.
## NovaWeapon3D tuned for moderate damage, standard radius, no charm.

func _ready() -> void:
	radius         = 6.0
	damage         = 16.0
	charm_duration = 0.0
	base_cooldown  = 2.5
	super()
