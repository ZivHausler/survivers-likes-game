# See docs/notes/skills-overview-3-3.md
class_name AvihayGroupCall3D extends OrbitWeapon3D
## Avihay skill: "Group Call" — orbiting call-bubble rings that ping nearby enemies.
## OrbitWeapon3D with moderate count, large radius, steady damage.

func _ready() -> void:
	orbit_count  = 4
	orbit_radius = 4.0
	orbit_speed  = TAU / 4.0
	damage       = 15.0
	base_cooldown = 2.5
	super()
