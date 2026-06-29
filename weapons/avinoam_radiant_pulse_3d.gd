# See docs/notes/char-avinoam.md
class_name AvinoamRadiantPulse3D extends NovaWeapon3D
## Avinoam skill: "Radiant Pulse" — wide burst of holy light that scorches nearby enemies.
## NovaWeapon3D with broad radius, moderate damage.

func _ready() -> void:
	radius        = 6.5
	damage        = 18.0
	charm_duration = 0.0
	base_cooldown  = 2.5
	super()
