class_name UltHounds3D extends UltimateWeapon3D
## Barak's ultimate "Release the Hounds": spawns HOUND_COUNT hound minions that
## chase the nearest enemies and deal contact damage for HOUND_LIFETIME seconds,
## then auto-despawn. Type: pack. Cooldown: 30 s.

const HOUND_COUNT    := 3
const HOUND_LIFETIME := 8.0    # seconds before auto-despawn
const HOUND_SPEED    := 7.0    # world units / second
const HOUND_DAMAGE   := 18.0   # damage per hit
const HOUND_HIT_CD   := 0.55   # seconds between hits on the same enemy
const HOUND_RANGE    := 1.0    # distance to trigger a hit (world units)

# Brown / amber hound colour to match Barak's palette.
const HOUND_COLOR := Color(0.6, 0.35, 0.1, 1.0)
const PUFF_COLOR  := Color(0.8, 0.55, 0.25, 0.85)

func _ready() -> void:
	ult_cooldown = 30.0
	vfx_id       = &"hounds_release"
	vfx_color    = HOUND_COLOR
	super()

func _do_ult() -> void:
	if not is_inside_tree():
		return
	var origin := _player_ref.global_position if is_instance_valid(_player_ref) \
	              else global_position
	var dmg := HOUND_DAMAGE * (stats.damage_mult if stats else 1.0)

	_spawn_puff(origin)
	for i in range(HOUND_COUNT):
		_spawn_hound(origin, dmg, i)

# ─────────────────────────────────────────────────────────────────────────────
# Hound spawning
# ─────────────────────────────────────────────────────────────────────────────

func _spawn_hound(origin: Vector3, dmg: float, index: int) -> Node3D:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root

	var hound := _UltHoundNode.new()
	hound.damage    = dmg
	hound.speed     = HOUND_SPEED
	hound.hit_cd    = HOUND_HIT_CD
	hound.hit_range = HOUND_RANGE
	parent.add_child(hound)

	# Spread hounds slightly so they don't stack.
	var spread_angle := TAU * float(index) / float(HOUND_COUNT)
	hound.global_position = origin + Vector3(cos(spread_angle) * 0.6, 0.0, sin(spread_angle) * 0.6)

	# Build simple visual: a small brown emissive capsule as the hound body.
	var mi := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.28
	mesh.height = 0.70
	mi.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = HOUND_COLOR
	mat.emission_enabled = true
	mat.emission = HOUND_COLOR
	mat.emission_energy_multiplier = 1.5
	mi.material_override = mat
	mi.position = Vector3(0.0, 0.35, 0.0)   # raise off ground
	hound.add_child(mi)

	# Lifetime despawn timer.
	var life := Timer.new()
	life.wait_time = HOUND_LIFETIME
	life.one_shot  = true
	life.autostart = true
	life.timeout.connect(hound.queue_free)
	hound.add_child(life)

	return hound

func _spawn_puff(origin: Vector3) -> void:
	if not is_inside_tree():
		return
	var tree := get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = origin

	var puff := MeshInstance3D.new()
	var sph  := SphereMesh.new()
	sph.radius = 0.6
	sph.height = 1.2
	puff.mesh  = sph
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PUFF_COLOR
	mat.emission_enabled = true
	mat.emission = PUFF_COLOR
	mat.emission_energy_multiplier = 2.5
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	puff.material_override = mat
	holder.add_child(puff)

	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(mat,   "albedo_color:a",         0.0, 0.4)
	tween.tween_property(holder, "scale", Vector3(2.5, 2.5, 2.5), 0.4)
	tween.chain().tween_callback(holder.queue_free)

# ─────────────────────────────────────────────────────────────────────────────
# Inner hound node — handles its own chase + contact damage
# ─────────────────────────────────────────────────────────────────────────────

## A self-contained hound Node3D: chases the nearest enemy each frame and
## deals `damage` on contact. Lives in the "hounds" group.
class _UltHoundNode extends Node3D:
	var damage   : float = 18.0
	var speed    : float = 7.0
	var hit_cd   : float = 0.55
	var hit_range: float = 1.0

	## instance_id → Time.get_ticks_msec() expiry for per-enemy hit cooldown.
	var _hit_timers: Dictionary = {}

	func _ready() -> void:
		add_to_group("hounds")

	func _process(delta: float) -> void:
		if not is_inside_tree():
			return
		var target := _nearest_enemy()
		if target == null:
			return
		# Move toward target.
		var dir := (target.global_position - global_position)
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			global_position += dir.normalized() * speed * delta

		# Contact damage when close enough.
		if dir.length() <= hit_range:
			_try_damage(target)

	func _nearest_enemy() -> Node3D:
		if not is_inside_tree():
			return null
		var best: Node3D = null
		var best_dist := INF
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var e3d := e as Node3D
			if e3d == null:
				continue
			var d := global_position.distance_to(e3d.global_position)
			if d < best_dist:
				best_dist = d
				best = e3d
		return best

	func _try_damage(enemy: Node3D) -> void:
		if not is_instance_valid(enemy):
			return
		var eid := enemy.get_instance_id()
		var now := Time.get_ticks_msec()
		if _hit_timers.has(eid) and _hit_timers[eid] > now:
			return
		_hit_timers[eid] = now + int(hit_cd * 1000.0)
		if enemy.has_method("take_damage"):
			enemy.take_damage(damage)

	## Synchronous test helper: immediately apply damage to `enemy` ignoring
	## cooldown. Useful for unit tests that cannot advance the physics clock.
	func hit_now(enemy: Node3D) -> void:
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(damage)
