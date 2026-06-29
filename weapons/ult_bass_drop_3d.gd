class_name UltBassDrop3D extends UltimateWeapon3D
## Yuval's ultimate "Bass Drop": a massive sonic shockwave radiates from the
## player, damaging every enemy within radius and shoving them outward. Offensive.

## Maximum distance (world units) enemies are affected.
var radius: float = 16.0
## Base damage per hit.
var damage: float = 100.0

## Deep bass rumble cyan.
const RING_COLOR := Color(0.0, 0.9, 1.0)
## How far outward each hit enemy is shoved (world units).
const KNOCKBACK_DIST := 2.5

func _ready() -> void:
	ult_cooldown = 30.0
	vfx_id = &"bass_drop"
	vfx_color = RING_COLOR
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
		if e3d == null:
			continue
		var dist := origin.distance_to(e3d.global_position)
		if dist <= radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg)
				GameEvents.skill_hit.emit(vfx_id, vfx_color, e3d.global_position)
			# Shove the enemy outward from the origin by a small offset.
			var dir := (e3d.global_position - origin)
			dir.y = 0.0
			if dir.length_squared() < 0.0001:
				dir = Vector3(1.0, 0.0, 0.0)
			dir = dir.normalized()
			e3d.global_position += dir * KNOCKBACK_DIST
	_spawn_shockwave_ring(origin)

## Spawn a concentric expanding ring visual that fades out and then auto-frees.
func _spawn_shockwave_ring(origin: Vector3) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = Vector3(origin.x, 0.05, origin.z)

	# Thin torus-like ring: a flat cylinder (very short height) scaled large.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, 0.85)
	mat.emission_enabled = true
	mat.emission = RING_COLOR
	mat.emission_energy_multiplier = 6.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.5
	cyl.bottom_radius = 0.5
	cyl.height = 0.15
	ring.mesh = cyl
	ring.material_override = mat
	holder.add_child(ring)

	# Expand to `radius`, then fade.
	var target_scale := Vector3(radius * 2.0, 1.0, radius * 2.0)
	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", target_scale, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.45)
	tween.chain().tween_callback(holder.queue_free)
