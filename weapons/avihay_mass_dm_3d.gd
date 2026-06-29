# See docs/notes/skills-overview-3-3.md
class_name AvihayMassDM3D extends OrbitWeapon3D
## Avihay skill: "Mass DM" — barrage of tiny notification pings orbiting fast.
## OrbitWeapon3D with more orbiters, faster speed, lower damage each.

func _ready() -> void:
	orbit_count  = 6
	orbit_radius = 2.5
	orbit_speed  = TAU   # full rotation per second
	damage       = 9.0
	base_cooldown = 2.0
	super()
