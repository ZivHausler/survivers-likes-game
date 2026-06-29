# See docs/notes/skills-overview-3-3.md
class_name ZivSelfieFlash3D extends NovaWeapon3D
## Ziv skill: "Selfie Flash" — blinding burst of light that damages nearby enemies.
## NovaWeapon3D with tuned params: moderate radius, high damage, no charm.

func _ready() -> void:
	radius        = 5.5
	damage        = 22.0
	charm_duration = 0.0
	base_cooldown  = 3.0
	super()
