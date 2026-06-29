# See docs/notes/char-avinoam.md
class_name AvinoamSmiteOrbs3D extends OrbitWeapon3D
## Avinoam skill: "Smite Orbs" — three holy orbs orbiting the player, striking enemies on contact.
## OrbitWeapon3D with 3 orbs at medium radius, steady divine damage.

func _ready() -> void:
	orbit_count  = 3
	orbit_radius = 3.0
	orbit_speed  = TAU / 3.0
	damage       = 16.0
	base_cooldown = 2.5
	super()
