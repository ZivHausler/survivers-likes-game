# See docs/notes/char-yuval.md
class_name YuvalResonance3D extends NovaWeapon3D
## Yuval skill: "Resonance" — a wide harmonic pulse that stuns enemies in a large area.
## NovaWeapon3D with wide radius, moderate damage, and short stun (charm_duration).

func _ready() -> void:
	radius        = 7.0
	damage        = 12.0
	charm_duration = 1.5
	base_cooldown  = 3.0
	super()
