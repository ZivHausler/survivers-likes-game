class_name UltComicRelief3D extends UltimateWeapon3D
## Natali's ultimate "Comic Relief": stuns nearby enemies with laughter, heals
## self, and (in co-op) heals other players in the "players" group. Defensive/joy.

## Radius for charm and self-heal burst (world units).
var radius: float = 12.0
## Seconds enemies stay charmed / stunned.
const CHARM_DURATION := 2.5
## HP restored to Natali (and teammates in co-op).
const HEAL_AMOUNT := 20.0
## Burst colour: bright yellow "laughter".
const BURST_COLOR := Color(1.0, 0.95, 0.15)

func _ready() -> void:
	ult_cooldown = 30.0
	vfx_id = &"comic_relief"
	vfx_color = BURST_COLOR
	super()

func _do_ult() -> void:
	if not is_inside_tree():
		return
	var origin := _player_ref.global_position if is_instance_valid(_player_ref) else global_position

	# 1. Charm every nearby enemy.
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e):
			continue
		var e3d := e as Node3D
		if e3d and origin.distance_to(e3d.global_position) <= radius:
			if e.has_method("charm"):
				e.charm(CHARM_DURATION)

	# 2. Heal self.
	_heal(_player_ref)

	# 3. In co-op: heal other players (no-op solo since group only has one entry).
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		if p == _player_ref:
			continue
		_heal(p)

	_spawn_burst(origin)

## Restore HEAL_AMOUNT HP on `player`. Works with any node that exposes
## `func heal(amount)`, or falls back to direct `hp`/`stats.max_hp` + signal.
func _heal(player: Node) -> void:
	if not is_instance_valid(player):
		return
	if player.has_method("heal"):
		player.heal(HEAL_AMOUNT)
	elif "hp" in player and "stats" in player and player.stats != null:
		player.hp = minf(player.hp + HEAL_AMOUNT, player.stats.max_hp)
		GameEvents.player_hp_changed.emit(player.hp, player.stats.max_hp)

## Spawn a yellow expanding-burst VFX centred on `origin`. Auto-frees.
func _spawn_burst(origin: Vector3) -> Node3D:
	if not is_inside_tree():
		return null
	var tree := get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var holder := Node3D.new()
	parent.add_child(holder)
	holder.global_position = Vector3(origin.x, origin.y + 0.1, origin.z)

	# Emissive yellow material.
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(BURST_COLOR.r, BURST_COLOR.g, BURST_COLOR.b, 0.9)
	mat.emission_enabled = true
	mat.emission = BURST_COLOR
	mat.emission_energy_multiplier = 7.0
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA

	# Expanding sphere burst.
	var sphere := MeshInstance3D.new()
	var sph_mesh := SphereMesh.new()
	sph_mesh.radius = 1.0
	sph_mesh.height = 2.0
	sphere.mesh = sph_mesh
	sphere.material_override = mat
	holder.add_child(sphere)

	# Expand from 0 → radius and fade out, then free.
	var tween := holder.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sphere, "scale", Vector3(radius, radius, radius), 0.5)
	tween.tween_property(mat, "albedo_color:a", 0.0, 0.5)
	tween.tween_property(mat, "emission_energy_multiplier", 0.0, 0.5)
	tween.chain().tween_callback(holder.queue_free)
	return holder
