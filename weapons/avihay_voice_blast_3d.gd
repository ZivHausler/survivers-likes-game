# See docs/notes/skills-overview-3-3.md
class_name AvihayVoiceBlast3D extends NovaWeapon3D
## Avihay skill: "Voice Blast" — sonic shockwave from yelling too loud on comms.
## NovaWeapon3D with high damage, moderate radius, no charm.

func _ready() -> void:
	radius        = 6.0
	damage        = 25.0
	charm_duration = 0.0
	base_cooldown  = 3.0
	super()
