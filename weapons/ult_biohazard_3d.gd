class_name UltBiohazard3D extends UltimateWeapon3D
## Ido's ultimate "Biohazard": a toxic cloud erupts around Ido, instantly damaging
## all nearby enemies, then a lingering poison field continues to tick every 0.5 s
## for 5 s before fading. Offensive / toxic.

## Radius of the immediate burst and the lingering field (world units).
var radius: float = 12.0
## Immediate burst damage.
var damage: float = 90.0
## Per-tick damage of the lingering field (fraction of burst damage).
const TICK_DAMAGE_MULT := 0.20
## How long the poison field lingers (seconds).
const FIELD_DURATION := 5.0
## Interval between damage ticks while the field is active (seconds).
const TICK_INTERVAL := 0.5
## Green toxic colour used for mesh and emission.
const TOXIC_COLOR := Color(0.15, 0.9, 0.1, 0.55)

func _ready() -> void:
	ult_cooldown = 28.0
	vfx_id = &"biohazard"
	vfx_color = Color(0.2, 1.0, 0.15)   # bright toxic green
	super()

func _do_ult() -> void:
	if not is_inside_tree():
		return
	var origin := _player_ref.global_position if is_instance_valid(_player_ref) else global_position
	var dmg := damage * (stats.damage_mult if stats else 1.0)

	# ── Immediate burst ───────────────────────────────────────────────────────
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var e3d := e as Node3D
		if e3d and origin.distance_to(e3d.global_position) <= radius:
			if e.has_method("take_damage"):
				e.take_damage(dmg)
			GameEvents.skill_hit.emit(vfx_id, vfx_color, e3d.global_position)

	# ── Lingering poison field ────────────────────────────────────────────────
	_spawn_poison_field(origin, dmg)

## Spawn a self-contained green cloud at `origin` that ticks damage every
## TICK_INTERVAL for FIELD_DURATION seconds, then auto-frees. Safe if enemies
## or the player disappear while the field is active.
func _spawn_poison_field(origin: Vector3, burst_dmg: float) -> Node3D:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root

	var field := Node3D.new()
	parent.add_child(field)
	field.global_position = origin

	# ── Visual: expanding green dome ──────────────────────────────────────────
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TOXIC_COLOR
	mat.emission_enabled = true
	mat.emission = Color(0.1, 0.7, 0.05)
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED   # visible from inside the dome

	var cloud := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = radius * 0.5
	sph.height = radius * 0.8
	cloud.mesh = sph
	cloud.material_override = mat
	cloud.position = Vector3(0.0, radius * 0.25, 0.0)
	field.add_child(cloud)

	# ── Expand on spawn ───────────────────────────────────────────────────────
	cloud.scale = Vector3(0.1, 0.1, 0.1)
	var expand := field.create_tween()
	expand.tween_property(cloud, "scale", Vector3(1.0, 1.0, 1.0), 0.6) \
		.set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_OUT)

	# ── Damage timer ──────────────────────────────────────────────────────────
	var max_ticks := int(FIELD_DURATION / TICK_INTERVAL)
	# Use an Array so the lambda captures a reference, not a copy of the int.
	var tick_state := [0]
	var tick_dmg := burst_dmg * TICK_DAMAGE_MULT

	var timer := Timer.new()
	timer.wait_time = TICK_INTERVAL
	timer.one_shot = false
	field.add_child(timer)

	timer.timeout.connect(func() -> void:
		tick_state[0] += 1
		# Damage any enemies still inside the field.
		if field.is_inside_tree():
			for e in field.get_tree().get_nodes_in_group("enemies"):
				if not is_instance_valid(e):
					continue
				var e3d := e as Node3D
				if e3d and origin.distance_to(e3d.global_position) <= radius:
					if e.has_method("take_damage"):
						e.take_damage(tick_dmg)

		if tick_state[0] >= max_ticks:
			timer.stop()
			# Fade out then free.
			if is_instance_valid(field) and field.is_inside_tree():
				var fade := field.create_tween()
				fade.set_parallel(true)
				fade.tween_property(mat, "albedo_color:a", 0.0, 0.8)
				fade.tween_property(mat, "emission_energy_multiplier", 0.0, 0.8)
				fade.chain().tween_callback(field.queue_free)
			else:
				if is_instance_valid(field):
					field.queue_free()
	)
	timer.start()
	return field
