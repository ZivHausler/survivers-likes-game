# See docs/notes/weapon-nova-3d.md
class_name NovaWeapon3D extends Weapon3D
## Reusable archetype: AoE pulse that deals damage (and optionally charms)
## all enemies within `radius` world units on every fire() tick.
##
## Subclasses set damage / radius / charm_duration in _ready() before super().
## The selection logic lives in the pure `affected_enemies()` helper so it can
## be unit-tested without a physics server.
##
## 1 unit ≈ 16 px; gameplay on XZ plane.

## World-unit radius of the nova effect.
var radius: float = 6.0
## Damage dealt per pulse (multiplied by stats.damage_mult). 0 = no damage.
var damage: float = 18.0
## Seconds enemies are charmed per pulse. 0.0 = no charm.
var charm_duration: float = 0.0

func _init() -> void:
	base_cooldown = 2.5

func _ready() -> void:
	super()

## On fire: find affected enemies (pure helper), then apply damage / charm.
func fire() -> void:
	if not stats:
		return
	var all_enemies: Array = get_tree().get_nodes_in_group("enemies")
	var origin: Vector3 = global_position
	var targets: Array = affected_enemies(all_enemies, origin)
	var dmg: float = damage * stats.damage_mult
	for enemy in targets:
		if damage > 0.0 and enemy.has_method("take_damage"):
			enemy.take_damage(dmg)
		if charm_duration > 0.0 and enemy.has_method("charm"):
			enemy.charm(charm_duration)

## Level up: +1.0 radius, +6 damage; if this is a charming variant also +0.3 s.
func level_up() -> void:
	super()
	radius  += 1.0
	damage  += 6.0
	if charm_duration > 0.0:
		charm_duration += 0.3

## Evolve: large radius boost (synergy effect). Subclasses may call super() then extend.
func evolve() -> void:
	super()
	radius *= 1.75

## Passive bonus: increases radius.
func apply_passive(value: float) -> void:
	radius += value

# ─────────────────────────────────────────────────────────────────────────────
# Pure / testable helper
# ─────────────────────────────────────────────────────────────────────────────

## Return the subset of `enemies` whose XZ distance from `origin` is ≤ radius.
## Y component of positions is ignored (game is on XZ plane).
## Pure: does not query physics, so usable in unit tests without a live scene tree.
func affected_enemies(enemies: Array, origin: Vector3) -> Array:
	var result: Array = []
	for enemy in enemies:
		var pos: Vector3 = (enemy as Node3D).global_position
		var dx: float = pos.x - origin.x
		var dz: float = pos.z - origin.z
		if sqrt(dx * dx + dz * dz) <= radius:
			result.append(enemy)
	return result
