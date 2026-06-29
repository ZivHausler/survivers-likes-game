# See docs/notes/char-ido.md
class_name IdoToxicCloud3D extends NovaWeapon3D
## Ido signature skill: "Toxic Cloud" — bespoke DoT fire().
## Overrides fire() to apply poison tick to all enemies within radius
## on each pulse. Low cooldown creates a trail-like repeated-tick effect.

func _ready() -> void:
	radius        = 6.0
	damage        = 8.0
	charm_duration = 0.0
	base_cooldown  = 1.0
	super()

## Bespoke fire(): poison tick — damages all enemies in radius each pulse.
## Intentionally low cooldown so ticks fire frequently, simulating a DoT trail.
func fire() -> void:
	if not stats:
		return
	var all_enemies: Array = get_tree().get_nodes_in_group("enemies")
	var origin: Vector3 = global_position
	var targets: Array = affected_enemies(all_enemies, origin)
	var dmg: float = damage * stats.damage_mult
	for enemy in targets:
		if enemy.has_method("take_damage"):
			enemy.take_damage(dmg)
