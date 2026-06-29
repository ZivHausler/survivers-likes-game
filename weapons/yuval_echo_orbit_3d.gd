# See docs/notes/char-yuval.md
class_name YuvalEchoOrbit3D extends OrbitWeapon3D
## Yuval skill: "Echo Orbit" — sound waves orbiting Yuval that buffet nearby enemies.

func _ready() -> void:
	orbit_count  = 3
	orbit_radius = 3.0
	orbit_speed  = TAU / 3.0
	damage       = 15.0
	base_cooldown = 2.5
	super()
