# See docs/notes/char-yoav.md
class_name YoavDriveBy3D extends NovaWeapon3D
## Yoav signature skill: "Drive-By" — lightning-fast scooter strafe blasts nearby enemies.
## NovaWeapon3D with fast cooldown, moderate damage and radius.

func _ready() -> void:
	radius        = 5.5
	damage        = 18.0
	charm_duration = 0.0
	base_cooldown  = 2.0
	super()
