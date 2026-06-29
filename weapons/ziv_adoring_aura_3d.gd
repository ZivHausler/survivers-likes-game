# See docs/notes/skills-overview-3-3.md
class_name ZivAdoringAura3D extends NovaWeapon3D
## Ziv skill: "Adoring Aura" — irresistible charm wave that enchants nearby enemies.
## NovaWeapon3D with charm_duration > 0: low damage, wide radius, strong charm.

func _ready() -> void:
	radius         = 7.0
	damage         = 8.0
	charm_duration = 2.5
	base_cooldown  = 3.5
	super()
