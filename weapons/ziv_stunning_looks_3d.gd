# See docs/notes/weapon-ziv-3d.md
class_name ZivStunningLooks3D extends Weapon3D
## Ziv's 3D signature ability: "Stunning Looks"
##
## Fires a piercing beam (Area3D BoxShape) that deals damage to all enemies it overlaps,
## then charms the nearest [charm_count] enemies within [charm_radius] world units
## (suppressing their movement for [charm_duration] seconds).
##
## All distances are in 3D world units on the XZ plane (1 unit ≈ 16 px).
##
## Evolution — "Absolutely Fabulous":
##   The beam rotates continuously about the Y axis and the CharmField becomes
##   always-on, auto-charming any enemy that enters its radius.

const MAX_LEVEL := 5

## Base beam damage per activation (multiplied by stats.damage_mult at fire time).
var beam_damage: float = 25.0
## Number of nearest enemies charmed per activation (non-evolved state).
var charm_count: int = 2
## Seconds enemies remain charmed per activation.
var charm_duration: float = 2.0
## World-unit radius within which enemies qualify for charming (150 px / 16 ≈ 9.0).
var charm_radius: float = 9.0

## Rotation speed of the evolved beam about Y axis (radians per second).
const _BEAM_ROTATION_SPEED: float = TAU / 3.0

@onready var _beam: Area3D = $Beam
@onready var _charm_field: Area3D = $CharmField

func _ready() -> void:
	base_cooldown = 3.0
	super()
	# Keep Beam monitoring always on so get_overlapping_bodies() is populated
	# by the physics server before fire() is called.
	_beam.monitoring = true
	_beam.monitorable = true
	# CharmField stays off until evolve() activates it.
	_charm_field.monitoring  = false
	_charm_field.monitorable = false

func _process(dt: float) -> void:
	if evolved:
		_beam.rotation.y += _BEAM_ROTATION_SPEED * dt

func setup(player: Node, p_stats: StatBlock) -> void:
	super(player, p_stats)

func fire() -> void:
	_deal_beam_damage()
	_charm_nearby_enemies()

func _deal_beam_damage() -> void:
	var damage := beam_damage * stats.damage_mult
	for body in _beam.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.take_damage(damage)

func _charm_nearby_enemies() -> void:
	if evolved:
		# In evolved state the CharmField signal handles auto-charming;
		# also re-charm every currently-overlapping enemy on each fire tick.
		for body in _charm_field.get_overlapping_bodies():
			if body.is_in_group("enemies") and body.has_method("charm"):
				body.charm(charm_duration)
		return

	# Non-evolved: sort all enemies by XZ distance, charm the nearest N in radius.
	var all_enemies: Array = get_tree().get_nodes_in_group("enemies")
	var my_pos := global_position
	all_enemies.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return a.global_position.distance_to(my_pos) < b.global_position.distance_to(my_pos))
	var count := 0
	for enemy in all_enemies:
		if count >= charm_count:
			break
		if enemy.global_position.distance_to(my_pos) <= charm_radius \
				and enemy.has_method("charm"):
			enemy.charm(charm_duration)
			count += 1

func level_up() -> void:
	super()
	beam_damage    += 10.0
	charm_count    += 1
	charm_duration += 0.5
	charm_radius   += 1.25   # 20 px / 16 = 1.25 world units per level

func evolve() -> void:
	super()   # sets evolved = true
	# Beam sweeps continuously (Y-rotation driven by _process); ensure it's on.
	_beam.monitoring  = true
	_beam.monitorable = true
	# CharmField becomes always-on.
	_charm_field.monitoring  = true
	_charm_field.monitorable = true
	if not _charm_field.body_entered.is_connected(_on_charm_field_body_entered):
		_charm_field.body_entered.connect(_on_charm_field_body_entered)

## Passive bonus: extends how long enemies stay charmed.
## value = passive Upgrade's effect_value (seconds per passive level).
func apply_passive(value: float) -> void:
	charm_duration += value

## Auto-charm handler for the evolved always-on CharmField.
func _on_charm_field_body_entered(body: Node3D) -> void:
	if body.is_in_group("enemies") and body.has_method("charm"):
		body.charm(charm_duration)
