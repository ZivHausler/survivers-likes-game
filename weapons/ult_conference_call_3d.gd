class_name UltConferenceCall3D extends UltimateWeapon3D
## Avihay's ultimate "Conference Call": shields self, rings out a knockback
## blast, summons 2 temporary helper blips that chase and damage enemies,
## and (in co-op) shields other players too. Social / defensive.

## Radius of the knockback + damage ring (world units).
var radius: float = 10.0
## Base damage of the initial blast.
var damage: float = 60.0
## Seconds of invulnerability granted to self (and allies in co-op).
const SHIELD_DURATION := 3.0
## How far outward enemies are shoved by the knockback ring.
const KNOCKBACK_DIST := 2.0
## Number of helper blips summoned.
const HELPER_COUNT := 2
## Base damage-per-second for each helper (distributed via contact ticks).
const HELPER_DAMAGE := 15.0
## Blue summon-ring colour.
const RING_COLOR := Color(0.2, 0.5, 1.0, 0.80)

func _ready() -> void:
	ult_cooldown = 35.0
	vfx_id = &"conference_call"
	vfx_color = RING_COLOR
	super()

func _do_ult() -> void:
	if not is_inside_tree():
		return
	var origin := _player_ref.global_position if is_instance_valid(_player_ref) else global_position
	var dmg := damage * (stats.damage_mult if stats else 1.0)

	# ── 1. Self-shield ────────────────────────────────────────────────────────
	if is_instance_valid(_player_ref) and _player_ref.has_method("set_invulnerable"):
		_player_ref.set_invulnerable(SHIELD_DURATION)

	# ── 2. Knockback ring: damage + shove enemies outward ─────────────────────
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
			var away := e3d.global_position - origin
			away.y = 0.0
			if away.length_squared() < 0.0001:
				away = Vector3(1.0, 0.0, 0.0)
			e3d.global_position += away.normalized() * KNOCKBACK_DIST

	# ── 3. Summon helper blips ────────────────────────────────────────────────
	for i in HELPER_COUNT:
		_spawn_helper(origin, i)

	# ── 4. Team shield – no-op in solo (players group is empty except self) ───
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		if p == _player_ref:
			continue
		if p.has_method("set_invulnerable"):
			p.set_invulnerable(SHIELD_DURATION)

	# ── Visual: blue summon ring ──────────────────────────────────────────────
	_spawn_ring(origin)

## Spawn one helper blip offset slightly from `origin` (indexed by `idx`).
## Returns the helper node for testing; safe to ignore.
func _spawn_helper(origin: Vector3, idx: int) -> Node3D:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var helper := _ConferenceHelper.new()
	helper.contact_damage = HELPER_DAMAGE * (stats.damage_mult if stats else 1.0)
	parent.add_child(helper)
	# offset helpers so they do not stack on top of each other
	var angle := float(idx) * PI
	var offset := Vector3(cos(angle), 0.0, sin(angle)) * 1.0
	helper.global_position = origin + offset
	return helper

## Expanding blue telegraph ring that fades and then auto-frees.
func _spawn_ring(origin: Vector3) -> Node3D:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = Vector3(origin.x, 0.05, origin.z)

	var mat := StandardMaterial3D.new()
	mat.albedo_color = RING_COLOR
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
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

	var target_scale := Vector3(radius * 2.0, 1.0, radius * 2.0)
	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(ring, "scale", target_scale, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.45)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.45)
	tween.chain().tween_callback(holder.queue_free)
	return holder

## Self-contained helper that chases the nearest enemy and deals periodic
## contact damage for `LIFE_TIME` seconds, then queue_free()s itself.
## Safe if the player or any enemy disappears mid-lifetime.
class _ConferenceHelper extends Node3D:
	## Damage dealt per contact tick.
	var contact_damage: float = 15.0
	## Seconds this helper lives before auto-freeing.
	const LIFE_TIME := 6.0
	## Movement speed toward the nearest enemy (world units / s).
	const CHASE_SPEED := 5.0
	## Distance at which a damage tick fires.
	const CONTACT_RANGE := 1.5
	## Seconds between contact damage ticks.
	const DAMAGE_INTERVAL := 0.30

	var _elapsed: float = 0.0
	var _damage_cd: float = 0.0

	func _ready() -> void:
		name = "ConferenceHelper"
		# Small blue blip visual – self-contained material, auto-freed with node.
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.3, 0.6, 1.0, 0.90)
		mat.emission_enabled = true
		mat.emission = Color(0.2, 0.5, 1.0)
		mat.emission_energy_multiplier = 5.0
		var blip := MeshInstance3D.new()
		var sph := SphereMesh.new()
		sph.radius = 0.30
		sph.height = 0.60
		blip.mesh = sph
		blip.material_override = mat
		add_child(blip)

	func _process(delta: float) -> void:
		if not is_inside_tree():
			return
		_elapsed += delta
		_damage_cd -= delta
		if _elapsed >= LIFE_TIME:
			queue_free()
			return

		# Find nearest valid enemy.
		var nearest: Node3D = null
		var min_dist := 999999.0
		for e in get_tree().get_nodes_in_group("enemies"):
			if not is_instance_valid(e):
				continue
			var e3d := e as Node3D
			if e3d == null:
				continue
			var d := global_position.distance_to(e3d.global_position)
			if d < min_dist:
				min_dist = d
				nearest = e3d

		if not is_instance_valid(nearest):
			return

		# Chase.
		var dir := nearest.global_position - global_position
		if dir.length_squared() > 0.01:
			global_position += dir.normalized() * CHASE_SPEED * delta

		# Contact damage on cooldown.
		if min_dist < CONTACT_RANGE and _damage_cd <= 0.0:
			if nearest.has_method("take_damage"):
				nearest.take_damage(contact_damage)
			_damage_cd = DAMAGE_INTERVAL
