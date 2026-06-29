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

## Cached reference to the beam's visual mesh so fire() can pulse it.
var _beam_mesh: MeshInstance3D = null

func _ready() -> void:
	base_cooldown = 3.0
	vfx_id = &"ziv_stunning_looks"
	vfx_color = Color(1.0, 0.4, 0.8)  # pink/charm
	super()
	# Keep Beam monitoring always on so get_overlapping_bodies() is populated
	# by the physics server before fire() is called.
	_beam.monitoring = true
	_beam.monitorable = true
	# CharmField stays off until evolve() activates it.
	_charm_field.monitoring  = false
	_charm_field.monitorable = false
	_setup_visuals()

## Programmatically add emissive mesh visuals to Beam and CharmField so they
## are clearly visible in the dark arena.  Materials are created fresh here —
## no shared-resource mutation.
func _setup_visuals() -> void:
	# Beam: a box matching the BoxShape3D (1.5 × 0.5 × 8.0), offset to centre on z=-4
	# and raised to torso height (y=1.0) so it does not clip into the ground.
	var beam_mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(1.5, 0.5, 8.0)
	beam_mesh_inst.mesh = box
	beam_mesh_inst.position = Vector3(0.0, 1.0, -4.0)
	var beam_mat := StandardMaterial3D.new()
	beam_mat.albedo_color = Color(vfx_color.r, vfx_color.g, vfx_color.b, 0.9)
	beam_mat.emission_enabled = true
	beam_mat.emission = vfx_color
	beam_mat.emission_energy_multiplier = 4.0
	beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	beam_mesh_inst.material_override = beam_mat
	_beam.add_child(beam_mesh_inst)
	_beam_mesh = beam_mesh_inst
	# CharmField: a large semi-transparent sphere indicating the charm radius.
	# Centred at torso height (y=1.0) so it reads correctly above the ground.
	var charm_mesh_inst := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = charm_radius
	sphere.height  = charm_radius * 2.0
	charm_mesh_inst.mesh = sphere
	charm_mesh_inst.position = Vector3(0.0, 1.0, 0.0)
	var charm_mat := StandardMaterial3D.new()
	charm_mat.albedo_color = Color(vfx_color.r, vfx_color.g, vfx_color.b, 0.12)
	charm_mat.emission_enabled = true
	charm_mat.emission = vfx_color
	charm_mat.emission_energy_multiplier = 1.0
	charm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	charm_mesh_inst.material_override = charm_mat
	_charm_field.add_child(charm_mesh_inst)

func _process(dt: float) -> void:
	if evolved:
		_beam.rotation.y += _BEAM_ROTATION_SPEED * dt

func setup(player: Node, p_stats: StatBlock) -> void:
	super(player, p_stats)

func fire() -> void:
	# Non-evolved: aim the beam at the nearest enemy before dealing damage.
	if not evolved:
		var nearest := _nearest_enemy_xz()
		if nearest:
			_beam.rotation.y = aim_angle_to(global_position, nearest.global_position)
	_pulse_beam()
	_deal_beam_damage()
	_charm_nearby_enemies()

## Return the Y rotation (radians) required to make the beam's local -Z axis face `to`
## from `from` on the XZ plane.  Pure — no scene access, fully unit-testable.
static func aim_angle_to(from: Vector3, to: Vector3) -> float:
	var dx := to.x - from.x
	var dz := to.z - from.z
	return atan2(-dx, -dz)

## Return the nearest "enemies"-group Node3D by XZ distance, or null if none.
func _nearest_enemy_xz() -> Node3D:
	if not is_inside_tree():
		return null
	var all_enemies := get_tree().get_nodes_in_group("enemies")
	var nearest: Node3D = null
	var best_d2 := INF
	var my_pos := global_position
	for e in all_enemies:
		var en := e as Node3D
		if not is_instance_valid(en):
			continue
		var dx := en.global_position.x - my_pos.x
		var dz := en.global_position.z - my_pos.z
		var d2 := dx * dx + dz * dz
		if d2 < best_d2:
			best_d2 = d2
			nearest = en
	return nearest

## Flash the beam bright on fire, then tween back to the resting energy.
## Gives clear visual feedback that the ability has triggered.
func _pulse_beam() -> void:
	if _beam_mesh == null or not is_instance_valid(_beam_mesh):
		return
	var mat := _beam_mesh.material_override as StandardMaterial3D
	if mat == null:
		return
	mat.emission_energy_multiplier = 12.0
	if not is_inside_tree():
		return
	var tw := create_tween()
	tw.tween_property(mat, "emission_energy_multiplier", 4.0, 0.18)

func _deal_beam_damage() -> void:
	var damage := beam_damage * stats.damage_mult
	for body in _beam.get_overlapping_bodies():
		if body.is_in_group("enemies"):
			body.take_damage(damage)
			if damage > 0.0:
				GameEvents.skill_hit.emit(vfx_id, vfx_color, body.global_position)

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
