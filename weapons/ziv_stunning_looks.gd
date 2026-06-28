# See docs/notes/weapon-ziv.md
class_name ZivStunningLooks extends Weapon
## Ziv's signature ability: "Stunning Looks"
##
## Fires a piercing rainbow beam that deals damage to all enemies it overlaps,
## then charms the nearest [charm_count] enemies within [charm_radius] pixels
## (suppressing their movement for [charm_duration] seconds).
##
## Evolution — "Absolutely Fabulous":
##   The beam rotates continuously and the CharmField becomes always-on,
##   auto-charming any enemy that enters its radius.

const MAX_LEVEL := 5

## Base beam damage per activation (multiplied by stats.damage_mult at fire time).
var beam_damage: float = 25.0
## Number of nearest enemies charmed per activation (non-evolved state).
var charm_count: int = 2
## Seconds enemies remain charmed per activation.
var charm_duration: float = 2.0
## Pixel radius within which enemies qualify for charming.
var charm_radius: float = 150.0

## Rotation speed of the evolved beam (radians per second).
const _BEAM_ROTATION_SPEED: float = TAU / 3.0

@onready var _beam: Area2D = $Beam
@onready var _charm_field: Area2D = $CharmField

func _ready() -> void:
	base_cooldown = 3.0
	super()
	# Keep Beam monitoring always on so get_overlapping_bodies() is populated
	# by the physics server before fire() is called.
	_beam.monitoring = true
	_beam.monitorable = true
	# CharmField stays off until evolve() activates it.
	_charm_field.monitoring   = false
	_charm_field.monitorable  = false

func _process(dt: float) -> void:
	if evolved:
		_beam.rotation += _BEAM_ROTATION_SPEED * dt

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

	# Non-evolved: sort all enemies by distance, charm the nearest N in radius.
	var all_enemies: Array = get_tree().get_nodes_in_group("enemies")
	var my_pos := global_position
	all_enemies.sort_custom(func(a: Node2D, b: Node2D) -> bool:
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
	beam_damage  += 10.0
	charm_count  += 1
	charm_duration += 0.5
	charm_radius += 20.0

func evolve() -> void:
	super()   # sets evolved = true
	# Beam sweeps continuously (rotation driven by _process); ensure it's on.
	_beam.monitoring   = true
	_beam.monitorable  = true
	# CharmField becomes always-on.
	_charm_field.monitoring  = true
	_charm_field.monitorable = true
	if not _charm_field.body_entered.is_connected(_on_charm_field_body_entered):
		_charm_field.body_entered.connect(_on_charm_field_body_entered)

## Auto-charm handler for the evolved always-on CharmField.
func _on_charm_field_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("charm"):
		body.charm(charm_duration)
