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
@onready var _beam_visual: ColorRect = $Beam/BeamVisual
@onready var _charm_field_visual: ColorRect = $CharmField/CharmFieldVisual

## VFX particle emitters (visual-only, no gameplay effect).
var _beam_glow: CPUParticles2D = null
var _charm_sparkle: CPUParticles2D = null

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
	# Visuals start hidden; shown on fire() flash or evolve().
	_beam_visual.hide()
	_charm_field_visual.hide()

	# Beam glow particles (fire window / evolved burst).
	_beam_glow = CPUParticles2D.new()
	_beam_glow.one_shot              = false
	_beam_glow.emitting              = false
	_beam_glow.amount                = 8
	_beam_glow.lifetime              = 0.3
	_beam_glow.spread                = 10.0
	_beam_glow.initial_velocity_min  = 20.0
	_beam_glow.initial_velocity_max  = 60.0
	_beam_glow.color                 = Color(1.0, 0.8, 1.0, 0.7)
	_beam.add_child(_beam_glow)

	# Charm sparkle particles (evolve persistent aura).
	_charm_sparkle = CPUParticles2D.new()
	_charm_sparkle.one_shot             = false
	_charm_sparkle.emitting             = false
	_charm_sparkle.amount               = 12
	_charm_sparkle.lifetime             = 0.8
	_charm_sparkle.spread               = 180.0
	_charm_sparkle.initial_velocity_min = 10.0
	_charm_sparkle.initial_velocity_max = 40.0
	_charm_sparkle.color                = Color(1.0, 0.4, 0.9, 0.6)
	_charm_field.add_child(_charm_sparkle)

func _process(dt: float) -> void:
	if evolved:
		_beam.rotation += _BEAM_ROTATION_SPEED * dt

func setup(player: Node, p_stats: StatBlock) -> void:
	super(player, p_stats)

func fire() -> void:
	_deal_beam_damage()
	_charm_nearby_enemies()
	if not evolved:
		_flash_beam()

## Flash the beam visual for 0.3 s (non-evolved mode).
func _flash_beam() -> void:
	_beam_visual.show()
	_beam_glow.emitting = true
	await get_tree().create_timer(0.3).timeout
	# Guard: weapon may have been freed or evolved during the await.
	if is_instance_valid(self) and not evolved:
		_beam_visual.hide()
		_beam_glow.emitting = false

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
	# Evolved: beam rotates continuously — keep visual always visible.
	_beam_visual.show()
	# CharmField aura is now always active — show its visual.
	_charm_field_visual.show()
	# VFX: denser always-on beam glow + persistent charm aura sparkle.
	_beam_glow.emitting = true
	_beam_glow.amount   = 16
	_charm_sparkle.emitting = true
	_charm_sparkle.amount   = 24

## Passive bonus: extends how long enemies stay charmed.
## value = passive Upgrade's effect_value (seconds per passive level).
func apply_passive(value: float) -> void:
	charm_duration += value

## Auto-charm handler for the evolved always-on CharmField.
func _on_charm_field_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("charm"):
		body.charm(charm_duration)
