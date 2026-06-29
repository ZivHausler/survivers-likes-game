# See docs/notes/char-matan.md
class_name MatanAnnoyanceOrbit3D extends OrbitWeapon3D
## Matan skill: "Annoyance Orbit" — three buzzing irritants circling the player,
## constantly pestering nearby enemies.
## OrbitWeapon3D with 3 orbs, moderate damage.

func _ready() -> void:
	orbit_count  = 3
	orbit_radius = 3.0
	orbit_speed  = TAU / 3.0
	damage       = 14.0
	base_cooldown = 2.5
	super()
