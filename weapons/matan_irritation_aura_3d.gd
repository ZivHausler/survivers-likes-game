# See docs/notes/char-matan.md
class_name MatanIrritationAura3D extends NovaWeapon3D
## Matan signature skill: "Irritation Aura" — a wide distracting aura that taunts and
## charms all nearby enemies while dealing light damage.
## NovaWeapon3D with charm_duration > 0: wide radius, low damage, strong distract.

func _ready() -> void:
	radius         = 7.0
	damage         = 10.0
	charm_duration = 2.0
	base_cooldown  = 2.5
	super()
