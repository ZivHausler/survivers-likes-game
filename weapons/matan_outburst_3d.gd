# See docs/notes/char-matan.md
class_name MatanOutburst3D extends NovaWeapon3D
## Matan skill: "Outburst" — a sudden explosion of pent-up frustration dealing heavy damage.
## NovaWeapon3D with high damage, standard radius.

func _ready() -> void:
	radius        = 6.0
	damage        = 20.0
	charm_duration = 0.0
	base_cooldown  = 3.0
	super()
