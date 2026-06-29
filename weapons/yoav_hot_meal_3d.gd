# See docs/notes/char-yoav.md
class_name YoavHotMeal3D extends NovaWeapon3D
## Yoav skill: "Hot Meal" — scorching food delivery explodes on impact.
## NovaWeapon3D with higher damage and default radius.

func _ready() -> void:
	radius        = 6.0
	damage        = 20.0
	charm_duration = 0.0
	base_cooldown  = 2.5
	super()
