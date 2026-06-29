# See docs/notes/char-yoav.md
class_name YoavDeliveryOrbit3D extends OrbitWeapon3D
## Yoav skill: "Delivery Orbit" — 4 flying parcels orbiting the scooter, clipping enemies.
## OrbitWeapon3D with 4 orbiters, steady damage.

func _ready() -> void:
	orbit_count  = 4
	orbit_radius = 3.0
	orbit_speed  = TAU / 3.0
	damage       = 13.0
	base_cooldown = 2.5
	super()
