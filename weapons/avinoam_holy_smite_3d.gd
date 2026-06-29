# See docs/notes/char-avinoam.md
class_name AvinoamHolySmite3D extends NovaWeapon3D
## Avinoam signature skill: "Holy Smite" — divine AoE blast that smites all nearby enemies.
## NovaWeapon3D with high damage, wide radius, slower cooldown.

func _ready() -> void:
	radius        = 6.0
	damage        = 26.0
	charm_duration = 0.0
	base_cooldown  = 3.0
	super()
