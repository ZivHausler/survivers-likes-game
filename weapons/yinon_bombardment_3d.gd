# See docs/notes/char-yinon.md
class_name YinonBombardment3D extends NovaWeapon3D
## Yinon skill: "Bombardment" — sustained artillery barrage with wide area coverage.
## NovaWeapon3D with largest radius in the kit, moderate damage.

func _ready() -> void:
	radius        = 7.0
	damage        = 18.0
	charm_duration = 0.0
	base_cooldown  = 2.5
	super()
