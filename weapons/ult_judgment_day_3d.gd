class_name UltJudgmentDay3D extends UltimateWeapon3D
## Avinoam's ultimate "Judgment Day": a bolt of holy thunder crashes down from
## the sky onto every enemy within `radius`, dealing heavy damage. Offensive.

## Height the lightning bolt descends from (world units).
const BOLT_HEIGHT := 16.0
## Electric white-blue bolt color.
const BOLT_COLOR := Color(0.85, 0.92, 1.0)

var radius: float = 12.0
var damage: float = 120.0

func _ready() -> void:
	ult_cooldown = 25.0
	vfx_id = &"judgment_day"
	vfx_color = Color(1.0, 0.95, 0.5)   # holy gold (hit sparks)
	super()

func _do_ult() -> void:
	if not is_inside_tree():
		return
	var origin := _player_ref.global_position if is_instance_valid(_player_ref) else global_position
	var dmg := damage * (stats.damage_mult if stats else 1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var e3d := e as Node3D
		if e3d and origin.distance_to(e3d.global_position) <= radius:
			_strike_bolt(e3d.global_position)   # thunder from above
			if e.has_method("take_damage"):
				e.take_damage(dmg)
				GameEvents.skill_hit.emit(vfx_id, vfx_color, e3d.global_position)

## Spawn a lightning bolt crashing straight down onto `pos`, plus a ground
## impact flash. Bright instant strike that fades over ~0.25 s, then auto-frees.
## Self-contained (own mesh + material + tween). Returns the holder for tests.
func _strike_bolt(pos: Vector3) -> Node3D:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = Vector3(pos.x, 0.0, pos.z)

	# Fresh emissive material per strike — never share a resource.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(BOLT_COLOR.r, BOLT_COLOR.g, BOLT_COLOR.b, 0.95)
	mat.emission_enabled = true
	mat.emission = BOLT_COLOR
	mat.emission_energy_multiplier = 9.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Vertical bolt: a tall thin column from the ground up to BOLT_HEIGHT.
	var bolt := MeshInstance3D.new()
	var col := CylinderMesh.new()
	col.top_radius = 0.20
	col.bottom_radius = 0.05
	col.height = BOLT_HEIGHT
	bolt.mesh = col
	bolt.position = Vector3(0.0, BOLT_HEIGHT * 0.5, 0.0)   # base at ground level
	bolt.material_override = mat
	holder.add_child(bolt)

	# Ground impact flash.
	var flash := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 1.4
	sph.height = 2.8
	flash.mesh = sph
	flash.position = Vector3(0.0, 0.4, 0.0)
	flash.material_override = mat
	holder.add_child(flash)

	# Instant strike, then fade + thin out, then free.
	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.25)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.25)
	tween.tween_property(bolt, "scale", Vector3(0.25, 1.0, 0.25), 0.25)
	tween.tween_property(flash, "scale", Vector3(2.0, 2.0, 2.0), 0.25)
	tween.chain().tween_callback(holder.queue_free)
	return holder
