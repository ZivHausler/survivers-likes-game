# See docs/notes/char-yuval.md
class_name YuvalSoundwave3D extends NovaWeapon3D
## Yuval signature skill: "Soundwave" — sonic pulse that stuns/charms enemies.
## NovaWeapon3D with charm_duration > 0 (stun represented as charm).

func _ready() -> void:
	radius        = 6.0
	damage        = 15.0
	charm_duration = 2.0
	base_cooldown  = 2.5
	super()
