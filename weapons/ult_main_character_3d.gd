class_name UltMainCharacter3D extends UltimateWeapon3D
## Ziv's ultimate "Main Character Moment": charms every nearby enemy for 3 s,
## making them fight for Ziv. Defensive / crowd-control. Type: charm.

## Charm radius (world units).
var radius: float = 12.0
## Duration enemies stay charmed (seconds).
const CHARM_DURATION := 3.0
## Ring color: pink/magenta.
const RING_COLOR := Color(1.0, 0.3, 0.8)

func _ready() -> void:
	ult_cooldown = 30.0
	vfx_id = &"main_character_moment"
	vfx_color = RING_COLOR
	super()

func _do_ult() -> void:
	if not is_inside_tree():
		return
	var origin := _player_ref.global_position if is_instance_valid(_player_ref) else global_position
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var e3d := e as Node3D
		if e3d and origin.distance_to(e3d.global_position) <= radius:
			if e.has_method("charm"):
				e.charm(CHARM_DURATION)
	_spawn_ring(origin)

## Spawn an expanding pink ring centred on `origin`. Self-contained, auto-frees.
func _spawn_ring(origin: Vector3) -> Node3D:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = Vector3(origin.x, origin.y + 0.1, origin.z)

	# Emissive pink material.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(RING_COLOR.r, RING_COLOR.g, RING_COLOR.b, 0.85)
	mat.emission_enabled = true
	mat.emission = RING_COLOR
	mat.emission_energy_multiplier = 6.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Flat torus-like ring: thin cylinder (large radius, small height).
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.0
	cyl.bottom_radius = 1.0
	cyl.height = 0.25
	ring.mesh = cyl
	ring.material_override = mat
	holder.add_child(ring)

	# Expand from 0 → radius, fade alpha 0.85 → 0, then free.
	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", Vector3(radius, 1.0, radius), 0.6)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.6)
	tween.chain().tween_callback(holder.queue_free)
	return holder
