# See docs/notes/player-3d.md
class_name Player3D extends CharacterBody3D
## 3D player actor (CharacterBody3D). Gameplay on XZ plane (Y up).
## Owns WASD movement and all HP/XP/level/stat logic — ported verbatim from Player (2D).
## Multi-weapon: `weapons` dictionary maps skill_id (StringName) → Weapon3D for all acquired
## skills. Convenience pointer `weapon` tracks the first (signature) weapon for back-compat.
## Model rendering: setup() installs the CharacterData model under the Model Node3D child,
## hides the capsule placeholder, caches the model's AnimationPlayer, and plays idle/walk.
## Face direction is driven by the pure-static face_angle() helper in _physics_process()
## without rotating the collision body.

## Velocity below this length plays idle animation instead of walk.
const WALK_THRESHOLD := 0.05

## Seconds of remaining invulnerability (i-frames). Counts down in _physics_process.
var _invuln_timer: float = 0.0

var stats: StatBlock
## All acquired skills: skill_id → Weapon3D. Populated by acquire_skill().
var weapons: Dictionary = {}
## Convenience back-compat pointer — the first acquired weapon (signature).
## Set automatically by acquire_skill() on the first call. Also set by the legacy
## single-weapon fallback in setup() when data.skills is empty and data.weapon_scene is set.
var weapon: Node3D = null
var level: int = 1
var xp: int = 0
var hp: float = 0.0

## Cached AnimationPlayer from the instanced model; null if model has none or model_scene unset.
var _anim_player: AnimationPlayer = null

@onready var _model: Node3D = $Model
@onready var _placeholder: MeshInstance3D = $Model/MeshInstance3D

## Acquire a skill by skill_id. Instantiates weapon_scene, guards Node3D, adds as child,
## calls weapon.setup(self, stats), stores in weapons[skill_id]. Sets the convenience
## `weapon` pointer if this is the first acquired skill. No-op if already owned.
## Returns true while the player is invulnerable (i-frame window active).
func is_invulnerable() -> bool:
	return _invuln_timer > 0.0

## Grant invulnerability for `duration` seconds. Takes the max so multiple callers
## never shorten an existing window.
func set_invulnerable(duration: float) -> void:
	_invuln_timer = max(_invuln_timer, duration)

func acquire_skill(skill_id: StringName, weapon_scene: PackedScene) -> void:
	if weapons.has(skill_id):
		return
	var inst := weapon_scene.instantiate()
	if not inst is Node3D:
		inst.free()
		return
	add_child(inst)
	inst.setup(self, stats)
	weapons[skill_id] = inst
	if weapon == null:
		weapon = inst

## Returns true iff the skill_id weapon has been acquired.
func has_skill(skill_id: StringName) -> bool:
	return weapons.has(skill_id)

## Level up the weapon for skill_id. No-op if not owned.
func level_skill(skill_id: StringName) -> void:
	if weapons.has(skill_id):
		weapons[skill_id].level_up()

## Apply the passive bonus value to the weapon for skill_id. No-op if not owned.
func apply_skill_passive(skill_id: StringName, value: float) -> void:
	if weapons.has(skill_id):
		weapons[skill_id].apply_passive(value)

## Evolve the weapon for skill_id. No-op if not owned.
func evolve_skill(skill_id: StringName) -> void:
	if weapons.has(skill_id):
		weapons[skill_id].evolve()

func setup(data: CharacterData) -> void:
	stats = data.base_stats.duplicate_stats()
	hp = stats.max_hp

	# Backward-compat single-weapon fallback:
	# When data.skills is empty AND data.weapon_scene is set, use the old direct
	# instantiation path so that test_player_3d.gd and tests without SkillData stay green.
	# When data.skills is non-empty, GameManager3D will call acquire_skill() for the
	# signature after setup() returns — do NOT auto-instantiate here.
	if data.skills.is_empty() and data.weapon_scene:
		var inst := data.weapon_scene.instantiate()
		if inst is Node3D:
			weapon = inst
			add_child(weapon)
			weapon.setup(self, stats)
		else:
			inst.free()

	# Install rigged character model if provided; otherwise keep the capsule placeholder.
	# Tunable defaults: model_scale=1.0 ≈ native Kenney GLB size (~1.8 m); Y offset 0.
	# Adjust model_scale in the .tres file and the Model node's Y position in the scene for
	# precise ground contact — these are MANUAL PLAYTEST items.
	if data.model_scene:
		if not _model:
			return
		if _placeholder:
			_placeholder.hide()
		var model_inst := data.model_scene.instantiate()
		_model.add_child(model_inst)
		_model.scale = Vector3.ONE * data.model_scale
		if data.model_texture:
			_apply_texture(model_inst, data.model_texture)
		if data.model_tint != Color.WHITE:
			_apply_tint(model_inst, data.model_tint)
		_anim_player = model_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _anim_player and _anim_player.has_animation("idle"):
			_anim_player.play("idle")

	GameEvents.player_hp_changed.emit(hp, stats.max_hp)

## Recursively set albedo_texture on all MeshInstance3D surfaces under node.
## Duplicates each surface's active material and sets albedo_texture so the skin atlas
## is applied. Falls back to a new StandardMaterial3D when no existing material is found.
## albedo_color is left WHITE so the texture shows true colors; texture_filter NEAREST
## suits the low-poly Kenney atlas. Called from setup() when data.model_texture is set.
func _apply_texture(node: Node, tex: Texture2D) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var existing: Material = mi.get_active_material(i)
				var mat: StandardMaterial3D
				if existing is StandardMaterial3D:
					mat = (existing as StandardMaterial3D).duplicate() as StandardMaterial3D
				else:
					mat = StandardMaterial3D.new()
					mat.albedo_color = Color.WHITE
				mat.albedo_texture = tex
				mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
				mi.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_texture(child, tex)

## Recursively set albedo tint on all MeshInstance3D surfaces under node.
## Duplicates each surface's existing material and sets albedo_color so the texture
## atlas is preserved and just tinted. Falls back to a blank StandardMaterial3D only
## when no existing material is found for a surface.
## Only called when model_tint != Color.WHITE (see setup()).
func _apply_tint(node: Node, tint: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				var existing: Material = mi.get_active_material(i)
				if existing:
					var mat: Material = existing.duplicate()
					if mat is BaseMaterial3D:
						(mat as BaseMaterial3D).albedo_color = tint
					mi.set_surface_override_material(i, mat)
				else:
					var mat := StandardMaterial3D.new()
					mat.albedo_color = tint
					mi.set_surface_override_material(i, mat)
	for child in node.get_children():
		_apply_tint(child, tint)

func _physics_process(dt: float) -> void:
	if not stats:
		return
	# Invulnerability i-frame countdown + model blink.
	var was_invuln := _invuln_timer > 0.0
	_invuln_timer = max(0.0, _invuln_timer - dt)
	if _invuln_timer > 0.0:
		# Blink: alternate Model visibility every 0.1 s while invulnerable.
		_model.visible = fmod(_invuln_timer, 0.2) < 0.1
	elif was_invuln:
		# Timer just reached 0 — guarantee the model is visible again.
		_model.visible = true
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = move_to_velocity(dir, stats.move_speed)
	move_and_slide()
	# Rotate Model toward movement heading (only visual; collision body stays upright).
	if velocity.length() > WALK_THRESHOLD:
		_model.rotation.y = face_angle(velocity)
		_play_anim("walk")
	else:
		_play_anim("idle")

## Attempt to play a named animation clip; silently no-ops if AnimationPlayer or clip absent.
func _play_anim(anim_name: String) -> void:
	if not _anim_player:
		return
	if not _anim_player.has_animation(anim_name):
		return
	if _anim_player.current_animation == anim_name:
		return
	_anim_player.play(anim_name)

## Pure static heading helper — unit-testable without Input or scene tree.
## Returns Y-axis rotation (radians) a Model should face given an XZ velocity vector.
## Zero-length velocity returns 0.0 — never NaN.
static func face_angle(velocity: Vector3) -> float:
	if velocity.is_zero_approx():
		return 0.0
	return atan2(velocity.x, velocity.z)

## Pure XZ mapping helper — unit-testable without Input or scene tree.
## "up" on screen (move_up action, dir.y = -1) maps to -Z (away from camera).
static func move_to_velocity(dir: Vector2, speed: float) -> Vector3:
	return Vector3(dir.x, 0.0, dir.y) * speed

func xp_to_next(lvl: int) -> int:
	# Superlinear (quadratic) curve — same formula as 2D Player.
	# Fast early game: 2 + lvl + lvl²  →  lvl1=4, lvl2=8, lvl3=14, lvl5=32, lvl10=112
	return 2 + lvl + lvl * lvl

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		GameEvents.player_leveled_up.emit(level)

func take_damage(amount: float) -> void:
	if _invuln_timer > 0.0:
		return
	var dealt: float = max(0.0, amount - stats.armor)
	hp -= dealt
	GameEvents.player_hp_changed.emit(hp, stats.max_hp)
	if hp <= 0.0:
		GameEvents.player_died.emit()

## Restore HP by amount, clamped to max_hp, and notify the HUD via GameEvents.
## Guard against null stats so tests with partially-set-up players stay safe.
func heal(amount: float) -> void:
	if not stats:
		return
	hp = minf(hp + amount, stats.max_hp)
	GameEvents.player_hp_changed.emit(hp, stats.max_hp)

func get_pickup_range() -> float:
	return stats.pickup_range

## Apply a per-level stat delta from a GENERIC upgrade.
## fire_rate refreshes ALL acquired weapons so every weapon benefits from the cooldown change.
func apply_stat_upgrade(kind: StringName, value: float) -> void:
	match kind:
		&"move_speed":
			stats.move_speed += value
		&"max_hp":
			stats.max_hp += value
			hp += value
			GameEvents.player_hp_changed.emit(hp, stats.max_hp)
		&"pickup_range":
			stats.pickup_range += value
		&"fire_rate":
			stats.fire_rate_mult += value
			# Refresh ALL acquired weapons in the multi-weapon flow.
			# In the legacy single-weapon flow, weapons is empty and weapon is set directly.
			if not weapons.is_empty():
				for w in weapons.values():
					w.refresh_cooldown()
			elif weapon != null:
				weapon.refresh_cooldown()
		&"damage":
			stats.damage_mult += value
		&"armor":
			stats.armor += value
