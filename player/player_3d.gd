# See docs/notes/player-3d.md
class_name Player3D extends CharacterBody3D
## 3D player actor (CharacterBody3D). Gameplay on XZ plane (Y up).
## Owns WASD movement and all HP/XP/level/stat logic — ported verbatim from Player (2D).
## Model rendering: setup() installs the CharacterData model under the Model Node3D child,
## hides the capsule placeholder, caches the model's AnimationPlayer, and plays idle/walk.
## Face direction is driven by the pure-static face_angle() helper in _physics_process()
## without rotating the collision body.

## Velocity below this length plays idle animation instead of walk.
const WALK_THRESHOLD := 0.05

var stats: StatBlock
var weapon: Node3D = null
var level: int = 1
var xp: int = 0
var hp: float = 0.0

## Cached AnimationPlayer from the instanced model; null if model has none or model_scene unset.
var _anim_player: AnimationPlayer = null

@onready var _model: Node3D = $Model
@onready var _placeholder: MeshInstance3D = $Model/MeshInstance3D

func setup(data: CharacterData) -> void:
	stats = data.base_stats.duplicate_stats()
	hp = stats.max_hp
	# Only attach 3D weapons — all current Weapon subclasses extend Node2D and will be
	# skipped here. Guard prevents crashing when weapon_scene is null OR a 2D scene.
	if data.weapon_scene:
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
		if data.model_tint != Color.WHITE:
			_apply_tint(model_inst, data.model_tint)
		_anim_player = model_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		if _anim_player and _anim_player.has_animation("idle"):
			_anim_player.play("idle")

	GameEvents.player_hp_changed.emit(hp, stats.max_hp)

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

func _physics_process(_dt: float) -> void:
	if not stats:
		return
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
	# 5 + lvl*3 + lvl²*2  →  lvl1=10, lvl2=19, lvl3=32, lvl5=70, lvl10=235
	return 5 + lvl * 3 + lvl * lvl * 2

func add_xp(amount: int) -> void:
	xp += amount
	while xp >= xp_to_next(level):
		xp -= xp_to_next(level)
		level += 1
		GameEvents.player_leveled_up.emit(level)

func take_damage(amount: float) -> void:
	var dealt: float = max(0.0, amount - stats.armor)
	hp -= dealt
	GameEvents.player_hp_changed.emit(hp, stats.max_hp)
	if hp <= 0.0:
		GameEvents.player_died.emit()

func get_pickup_range() -> float:
	return stats.pickup_range

## Apply a per-level stat delta from a GENERIC upgrade.
## Mirrors Player.apply_stat_upgrade exactly; weapon.refresh_cooldown() guard preserved.
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
			if weapon:
				weapon.refresh_cooldown()
		&"damage":
			stats.damage_mult += value
		&"armor":
			stats.armor += value
