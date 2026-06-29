# See docs/notes/char-yuval.md
class_name YuvalBassDrop3D extends NovaWeapon3D
## Yuval skill: "Bass Drop" — a devastating low-frequency shockwave in a tight radius.

func _ready() -> void:
	radius        = 5.0
	damage        = 24.0
	charm_duration = 0.0
	base_cooldown  = 3.0
	super()
