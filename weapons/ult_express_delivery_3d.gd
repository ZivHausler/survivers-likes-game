class_name UltExpressDelivery3D extends UltimateWeapon3D
## Yoav's ultimate "Express Delivery": three rapid plow-through LINE strikes,
## each lancing forward along a lane and damaging every enemy it passes through.
## Offensive / rush type.

## Length of each line strike (world units).
const LINE_LENGTH := 14.0
## Half-width of the perpendicular damage corridor.
const LINE_WIDTH := 2.0
## Number of strikes per activation.
const STRIKE_COUNT := 3
## Seconds between consecutive strikes.
const STRIKE_DELAY := 0.25
## Base damage per strike (before damage_mult).
const DAMAGE := 90.0
## Bright white dash colour.
const DASH_COLOR := Color(1.0, 1.0, 1.0)

func _ready() -> void:
	ult_cooldown = 30.0
	vfx_id = &"express_delivery"
	vfx_color = DASH_COLOR
	super()

func _do_ult() -> void:
	if not is_inside_tree():
		return
	for i in STRIKE_COUNT:
		if i > 0:
			await get_tree().create_timer(STRIKE_DELAY).timeout
			if not is_instance_valid(self) or not is_instance_valid(_player_ref):
				return
			if not is_inside_tree():
				return
		var origin := _player_ref.global_position if is_instance_valid(_player_ref) else global_position
		var dir := _pick_direction(origin, i)
		_strike_line(origin, dir)

## Choose a strike direction: toward the nearest enemy, spread by strike index,
## or along +Z forward if no enemies are present.
func _pick_direction(origin: Vector3, strike_index: int = 0) -> Vector3:
	var best_dist := INF
	var best_pos := Vector3.ZERO
	var found := false
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var e3d := e as Node3D
		if not e3d:
			continue
		var d := origin.distance_to(e3d.global_position)
		if d < best_dist:
			best_dist = d
			best_pos = e3d.global_position
			found = true
	var base_dir: Vector3
	if found:
		base_dir = (best_pos - origin)
		base_dir.y = 0.0
		base_dir = base_dir.normalized()
	else:
		base_dir = Vector3.FORWARD
	# Spread each strike ±30° so three strikes fan out a bit.
	var spread_deg := (strike_index - 1) * 30.0
	var spread_rad := deg_to_rad(spread_deg)
	var cos_a := cos(spread_rad)
	var sin_a := sin(spread_rad)
	return Vector3(
		base_dir.x * cos_a - base_dir.z * sin_a,
		0.0,
		base_dir.x * sin_a + base_dir.z * cos_a
	).normalized()

## Synchronous helper — exposed so tests can call it directly without the
## timed loop. Damages all enemies whose projection onto the ray [origin →
## origin + dir*LINE_LENGTH] puts them within LINE_WIDTH of the line.
func _strike_line(origin: Vector3, dir: Vector3) -> void:
	if not is_inside_tree():
		return
	var dmg := DAMAGE * (stats.damage_mult if stats else 1.0)
	var dir2d := Vector2(dir.x, dir.z).normalized()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var e3d := e as Node3D
		if not e3d:
			continue
		var to_e := e3d.global_position - origin
		var to_e2d := Vector2(to_e.x, to_e.z)
		var proj := to_e2d.dot(dir2d)       # signed projection along strike direction
		if proj < 0.0 or proj > LINE_LENGTH:
			continue                          # behind origin or beyond lane end
		var perp := (to_e2d - dir2d * proj).length()
		if perp > LINE_WIDTH:
			continue                          # outside the damage corridor
		if e.has_method("take_damage"):
			e.take_damage(dmg)
			GameEvents.skill_hit.emit(vfx_id, vfx_color, e3d.global_position)
	_spawn_dash_vfx(origin, dir)

## Spawn a thin bright white streak along the strike lane. Self-contained,
## auto-frees after a short fade. Returns the holder node for tests.
func _spawn_dash_vfx(origin: Vector3, dir: Vector3) -> Node3D:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var holder := Node3D.new()
	parent.add_child(holder)
	# Centre the streak half-way along the lane.
	holder.global_position = origin + dir * (LINE_LENGTH * 0.5)
	# Orient -Z forward (Godot convention) along dir.
	var fwd := dir.normalized()
	var up := Vector3.UP
	var right := up.cross(fwd)
	if right.length_squared() < 0.001:
		right = Vector3.RIGHT
	right = right.normalized()
	up = fwd.cross(right).normalized()
	holder.basis = Basis(right, up, -fwd)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(DASH_COLOR.r, DASH_COLOR.g, DASH_COLOR.b, 0.9)
	mat.emission_enabled = true
	mat.emission = DASH_COLOR
	mat.emission_energy_multiplier = 12.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Thin stretched box — the "dash" streak.
	var streak := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(LINE_WIDTH * 0.35, 0.25, LINE_LENGTH)
	streak.mesh = box
	streak.material_override = mat
	holder.add_child(streak)

	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.18)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.18)
	tween.tween_property(streak, "scale", Vector3(0.1, 0.1, 1.0), 0.18)
	tween.chain().tween_callback(holder.queue_free)
	return holder
