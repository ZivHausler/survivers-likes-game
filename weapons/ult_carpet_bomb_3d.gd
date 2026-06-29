class_name UltCarpetBomb3D extends UltimateWeapon3D
## Yinon's ultimate "Carpet Bomb": over ~2 seconds, a sequence of ~8 explosions
## rains down at spread positions around the player, each dealing AoE damage to
## nearby enemies and spawning a visible orange explosion sphere. Offensive.

## Number of individual bomb detonations in one barrage.
const BLAST_COUNT := 8
## Total duration of the barrage in seconds.
const BARRAGE_DURATION := 2.0
## Radius in which each single explosion damages enemies.
const BLAST_RADIUS := 3.0
## How far from the player origin the blasts can be spread.
const SPREAD_RADIUS := 7.0
## Orange explosion color.
const BLAST_COLOR := Color(1.0, 0.45, 0.05)

var damage: float = 40.0

func _ready() -> void:
	ult_cooldown = 35.0
	vfx_id = &"carpet_bomb"
	vfx_color = BLAST_COLOR
	super()

## Detonate a single explosion at `pos`. Synchronous: damages enemies within
## BLAST_RADIUS and spawns an orange VFX sphere. Called from _do_ult's loop.
func _detonate_at(pos: Vector3) -> void:
	var dmg := damage * (stats.damage_mult if stats else 1.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var e3d := e as Node3D
		if e3d and e3d.global_position.distance_to(pos) <= BLAST_RADIUS:
			if e.has_method("take_damage"):
				e.take_damage(dmg)
				GameEvents.skill_hit.emit(vfx_id, vfx_color, e3d.global_position)
	_spawn_explosion_vfx(pos)

## Spawn a pop-and-fade orange explosion sphere at world position `pos`.
func _spawn_explosion_vfx(pos: Vector3) -> Node3D:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root

	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = Vector3(pos.x, 0.0, pos.z)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(BLAST_COLOR.r, BLAST_COLOR.g, BLAST_COLOR.b, 0.9)
	mat.emission_enabled = true
	mat.emission = BLAST_COLOR
	mat.emission_energy_multiplier = 6.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	var ball := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.6
	sph.height = 1.2
	ball.mesh = sph
	ball.position = Vector3(0.0, 0.6, 0.0)
	ball.material_override = mat
	holder.add_child(ball)

	# Pop outward then fade.
	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ball, "scale", Vector3(3.5, 3.5, 3.5), 0.3)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.35)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.35)
	tween.chain().tween_callback(holder.queue_free)
	return holder

func _do_ult() -> void:
	if not is_inside_tree():
		return
	var origin := _player_ref.global_position if is_instance_valid(_player_ref) else global_position
	var interval := BARRAGE_DURATION / float(BLAST_COUNT)

	for i in BLAST_COUNT:
		# Spread blasts in a rough ring with randomised angle and distance.
		var base_angle := float(i) * TAU / float(BLAST_COUNT)
		var angle := base_angle + randf_range(-0.4, 0.4)
		var dist := SPREAD_RADIUS * randf_range(0.4, 1.0)
		var offset := Vector3(cos(angle) * dist, 0.0, sin(angle) * dist)
		_detonate_at(origin + offset)

		await get_tree().create_timer(interval).timeout

		# Guard against self or player being freed mid-barrage.
		if not is_instance_valid(self):
			return
		if not is_instance_valid(_player_ref):
			return
