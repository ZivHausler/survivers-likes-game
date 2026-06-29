# See docs/notes/char-ido.md
class_name IdoVenomOrbs3D extends OrbitWeapon3D
## Ido skill: "Venom Orbs" — three orbiting toxic spheres that poison nearby enemies.

func _ready() -> void:
	orbit_count  = 3
	orbit_radius = 3.0
	orbit_speed  = TAU / 2.8
	damage       = 14.0
	base_cooldown = 2.5
	super()
