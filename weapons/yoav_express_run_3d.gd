# See docs/notes/char-yoav.md
class_name YoavExpressRun3D extends OrbitWeapon3D
## Yoav skill: "Express Run" — 6 high-speed delivery drones zipping around the scooter.
## OrbitWeapon3D with 6 fast orbiters and lighter damage per hit.

func _ready() -> void:
	orbit_count  = 6
	orbit_radius = 3.0
	orbit_speed  = TAU / 1.5   # fast — twice base speed
	damage       = 9.0
	base_cooldown = 2.0
	super()
