# See docs/notes/char-barak.md
class_name BarakPackTactics3D extends OrbitWeapon3D
## Barak skill: "Pack Tactics" — five orbiting pack members that coordinate attacks.
## OrbitWeapon3D tuned for larger pack size with lighter individual hits.

func _ready() -> void:
	orbit_count  = 5
	orbit_radius = 3.5
	orbit_speed  = TAU / 2.5
	damage       = 12.0
	base_cooldown = 2.0
	super()
