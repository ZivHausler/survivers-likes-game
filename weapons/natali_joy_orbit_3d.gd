# See docs/notes/char-natali.md
class_name NataliJoyOrbit3D extends OrbitWeapon3D
## Natali skill: "Joy Orbit" — three orbiting cheerful sparks that hit nearby enemies.
## OrbitWeapon3D tuned for moderate count, standard radius, light-to-moderate damage.

func _ready() -> void:
	orbit_count  = 3
	orbit_radius = 3.0
	orbit_speed  = TAU / 3.0
	damage       = 14.0
	base_cooldown = 2.5
	super()
