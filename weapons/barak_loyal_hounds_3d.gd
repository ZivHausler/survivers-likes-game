# See docs/notes/char-barak.md
class_name BarakLoyalHounds3D extends OrbitWeapon3D
## Barak signature skill: "Loyal Hounds" — three orbiting hound bodies that
## faithfully circle their master and bite any enemy that comes close.
## OrbitWeapon3D tuned for 3 hounds, standard radius, solid damage.

func _ready() -> void:
	orbit_count  = 3
	orbit_radius = 3.0
	orbit_speed  = TAU / 3.0
	damage       = 16.0
	base_cooldown = 2.5
	super()
