# See docs/notes/char-barak.md
class_name BarakHowl3D extends NovaWeapon3D
## Barak skill: "Howl" — a fearsome howl that disorients nearby enemies (charm).
## NovaWeapon3D with wide radius, moderate damage, and brief charm (disorient).

func _ready() -> void:
	radius         = 6.5
	damage         = 12.0
	charm_duration = 1.5
	base_cooldown  = 3.0
	super()
