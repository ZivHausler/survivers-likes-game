# See docs/notes/char-yinon.md
class_name YinonRocketBarrage3D extends NovaWeapon3D
## Yinon signature skill: "Rocket Barrage" — explosive AoE burst raining rockets.
## NovaWeapon3D with high damage, solid radius, slow cooldown.

func _ready() -> void:
	radius        = 6.0
	damage        = 24.0
	charm_duration = 0.0
	base_cooldown  = 3.0
	super()
