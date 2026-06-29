# See docs/notes/char-barak.md
class_name BarakFetch3D extends NovaWeapon3D
## Barak skill: "Fetch" — the hounds retrieve a powerful burst strike,
## dealing heavy damage in a moderate radius.
## NovaWeapon3D tuned for high damage with standard radius.

func _ready() -> void:
	radius         = 5.5
	damage         = 20.0
	charm_duration = 0.0
	base_cooldown  = 3.5
	super()
