# See docs/notes/char-yinon.md
class_name YinonAirstrike3D extends NovaWeapon3D
## Yinon skill: "Airstrike" — precision bombing run dealing the highest damage per hit.
## NovaWeapon3D with very high damage, tight radius, deliberate cooldown.

func _ready() -> void:
	radius        = 5.0
	damage        = 28.0
	charm_duration = 0.0
	base_cooldown  = 3.0
	super()
