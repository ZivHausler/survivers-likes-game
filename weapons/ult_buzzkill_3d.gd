class_name UltBuzzkill3D extends UltimateWeapon3D
## Matan's ultimate "Buzzkill": a self-buff that amps damage, speed, and fire-rate
## for ~6 s, then reverts cleanly. Other players are slowed/debuffed (no-op solo).
## Type: pest. Cooldown: 30 s.

## Buff multipliers applied to self stats.
const DAMAGE_MULT   := 1.5
const SPEED_MULT    := 1.4
const FIRE_RATE_MULT := 1.5
## How long the buff lasts (seconds).
const BUFF_DURATION := 6.0

## Orange-red aura color.
const AURA_COLOR := Color(1.0, 0.4, 0.1)

## True while the buff is active — prevents double-application.
var _buff_active: bool = false

## Additive deltas stored at apply time for exact revert.
## Using deltas (not snapshots) means concurrent stat upgrades survive revert.
var _delta_damage_mult: float   = 0.0
var _delta_move_speed: float    = 0.0
var _delta_fire_rate_mult: float = 0.0

## Team debuff deltas per other player (empty in solo — no-op).
## Each entry: { "player": Node, "move_speed": float, "fire_rate_mult": float }
var _team_debuff_deltas: Array = []

## Reference to the aura Node3D so we can remove it on revert.
var _aura_holder: Node3D = null

func _ready() -> void:
	ult_cooldown = 30.0
	vfx_id = &"buzzkill"
	vfx_color = AURA_COLOR
	super()

func _do_ult() -> void:
	if not is_inside_tree():
		return
	_apply_buff()
	# Schedule revert after BUFF_DURATION seconds.
	get_tree().create_timer(BUFF_DURATION).timeout.connect(_revert_buff, CONNECT_ONE_SHOT)

## Store additive deltas, apply them to stats, apply team debuff, refresh weapon cooldowns, spawn aura.
## Public so unit tests can call it directly without a running timer.
## When _player_ref is null (unit-test mode) falls back to the `stats` field.
func _apply_buff() -> void:
	if _buff_active:
		return
	var s: StatBlock = null
	if is_instance_valid(_player_ref):
		s = _player_ref.get("stats") as StatBlock
	if s == null:
		s = stats
	if s == null:
		return
	# Compute additive deltas from current base values.
	# Storing the delta (not the original) means concurrent += upgrades are preserved on revert.
	_delta_damage_mult    = s.damage_mult    * (DAMAGE_MULT    - 1.0)
	_delta_move_speed     = s.move_speed     * (SPEED_MULT     - 1.0)
	_delta_fire_rate_mult = s.fire_rate_mult * (FIRE_RATE_MULT - 1.0)
	# Apply buff as additive deltas.
	s.damage_mult    += _delta_damage_mult
	s.move_speed     += _delta_move_speed
	s.fire_rate_mult += _delta_fire_rate_mult
	_buff_active = true
	# Debuff other players at apply time (no-op in solo — players group contains only self).
	_team_debuff_deltas.clear()
	if is_inside_tree():
		for p in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(p) or p == _player_ref:
				continue
			var ps: StatBlock = p.get("stats") as StatBlock
			if ps == null:
				continue
			# slow to 70% → remove 30 % of current value
			var d_speed: float = ps.move_speed    * (1.0 - 0.7)
			# reduce fire rate to 75% → remove 25 % of current value
			var d_fire: float  = ps.fire_rate_mult * (1.0 - 0.75)
			ps.move_speed    -= d_speed
			ps.fire_rate_mult -= d_fire
			_team_debuff_deltas.append({ "player": p, "move_speed": d_speed, "fire_rate_mult": d_fire })
	# Refresh weapon cooldowns so faster fire rate takes effect immediately.
	_refresh_weapons()
	# Spawn visual aura on the player.
	_spawn_aura()

## Restore stats by subtracting the stored additive deltas (concurrent += upgrades survive).
## Undo team debuffs by adding back the exact deltas subtracted at apply time.
## Public so unit tests can call it directly.
func _revert_buff() -> void:
	if not _buff_active:
		return
	var s: StatBlock = null
	if is_instance_valid(_player_ref):
		s = _player_ref.get("stats") as StatBlock
	if s == null:
		s = stats
	if s != null:
		s.damage_mult    -= _delta_damage_mult
		s.move_speed     -= _delta_move_speed
		s.fire_rate_mult -= _delta_fire_rate_mult
	_buff_active = false
	# Undo team debuffs by adding back the exact deltas subtracted at apply time.
	for entry in _team_debuff_deltas:
		var p = entry["player"]
		if not is_instance_valid(p):
			continue
		var ps: StatBlock = p.get("stats") as StatBlock
		if ps == null:
			continue
		ps.move_speed    += entry["move_speed"]
		ps.fire_rate_mult += entry["fire_rate_mult"]
	_team_debuff_deltas.clear()
	_refresh_weapons()
	# Remove visual aura.
	if is_instance_valid(_aura_holder):
		_aura_holder.queue_free()
	_aura_holder = null

## Refresh all acquired weapons' cooldowns the same way Player3D.apply_stat_upgrade does.
func _refresh_weapons() -> void:
	if not is_instance_valid(_player_ref):
		return
	var ws = _player_ref.get("weapons")
	var w0 = _player_ref.get("weapon")
	if ws is Dictionary and not ws.is_empty():
		for w in ws.values():
			if is_instance_valid(w) and w.has_method("refresh_cooldown"):
				w.refresh_cooldown()
	elif w0 != null and is_instance_valid(w0) and w0.has_method("refresh_cooldown"):
		w0.refresh_cooldown()

## Spawn a red/orange pulsing emissive ring parented to the player for the buff duration.
func _spawn_aura() -> void:
	if not is_instance_valid(_player_ref):
		return
	# Clean up any stale aura from a previous (already-reverted) activation.
	if is_instance_valid(_aura_holder):
		_aura_holder.queue_free()
	_aura_holder = null

	var holder := Node3D.new()
	_player_ref.add_child(holder)
	holder.position = Vector3.ZERO
	_aura_holder = holder

	# Fresh emissive material — never share.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(AURA_COLOR.r, AURA_COLOR.g, AURA_COLOR.b, 0.75)
	mat.emission_enabled = true
	mat.emission = AURA_COLOR
	mat.emission_energy_multiplier = 5.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Flat ring around the player's feet.
	var ring := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius    = 0.9
	cyl.bottom_radius = 0.9
	cyl.height        = 0.2
	ring.mesh = cyl
	ring.position = Vector3(0.0, 0.1, 0.0)
	ring.material_override = mat
	holder.add_child(ring)

	# Pulse: repeatedly scale the ring in and out while the buff is active.
	var tween := holder.create_tween().set_loops()
	tween.set_parallel(false)
	tween.tween_property(ring, "scale", Vector3(1.3, 1.0, 1.3), 0.4)
	tween.tween_property(ring, "scale", Vector3(0.8, 1.0, 0.8), 0.4)
