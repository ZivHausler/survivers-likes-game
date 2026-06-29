# See docs/notes/enemy-3d.md
class_name Enemy3D extends CharacterBody3D
## 3D enemy actor (CharacterBody3D). Gameplay on XZ plane (Y up).
## Steers toward target, deals contact damage, and emits enemy_killed_3d on death.
## Mirrors Enemy (CharacterBody2D) behavior verbatim.
## Phase 2: setup() instances the real monster model from data.model_scene (GLB),
## hides the sphere placeholder, applies scale/offset, caches AnimationPlayer, and
## plays idle/move animations (best-effort; falls back to static rest-pose on failure).

## World-unit stand-off radius for ranged enemies (playtest-tunable; replaces 2D pixel value 140).
const RANGED_STANDOFF := 6.0
## World-unit contact-damage radius (playtest-tunable; replaces 2D `radius+12` pixels).
const CONTACT_RANGE := 1.5
## Velocity length below which we play "idle" rather than "move".
const MOVE_THRESHOLD := 0.05

var data: EnemyData
var target: Node3D
var hp: float = 0.0
var _contact_cd: float = 0.0
## Remaining charm time in seconds. While > 0, movement is suppressed.
var _charm_timer: float = 0.0
## Cached AnimationPlayer from the instanced model; null if model has none.
var _anim_player: AnimationPlayer = null

@onready var _model: Node3D = $Model
@onready var _placeholder: MeshInstance3D = $Model/MeshInstance3D

func setup(p_data: EnemyData, p_target: Node3D) -> void:
	data = p_data
	target = p_target
	hp = data.max_hp

	if data.model_scene:
		# Hide the sphere placeholder — real monster model takes over.
		if _placeholder:
			_placeholder.hide()
		# Instance model under Model pivot; apply scale + Y offset for ground contact.
		var model_inst := data.model_scene.instantiate()
		model_inst.position.y = data.model_y_offset
		_model.add_child(model_inst)
		_model.scale = Vector3.ONE * data.model_scale
		# Cache AnimationPlayer if the mesh GLB embedded one.
		_anim_player = model_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		# Best-effort idle: play immediately if clip present.
		_play_anim("idle")
	else:
		# Fallback path (no model_scene): tint the sphere placeholder by data.color
		# so 2D-only .tres resources still look distinct in 3D.
		var mesh_inst := _placeholder
		if mesh_inst:
			var mat := StandardMaterial3D.new()
			mat.albedo_color = data.color
			mesh_inst.material_override = mat

## Suppress enemy movement for `duration` seconds.
## Stacks by taking the maximum remaining time (mirrors 2D charm logic).
func charm(duration: float) -> void:
	_charm_timer = max(_charm_timer, duration)

func _physics_process(dt: float) -> void:
	if data == null:
		return
	# Tick charm timer and suppress movement while charmed.
	_charm_timer = max(0.0, _charm_timer - dt)
	if _charm_timer > 0.0:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	to_target.y = 0.0  # Move only on XZ plane.
	var dist := to_target.length()
	var desired := 0.0 if (data.is_ranged and dist < RANGED_STANDOFF) else data.move_speed
	velocity = steer_velocity(global_position, target.global_position, desired)
	move_and_slide()
	# Rotate Model toward movement direction (visual only — collision body stays upright).
	if _model and velocity.length_squared() > MOVE_THRESHOLD * MOVE_THRESHOLD:
		_model.rotation.y = face_angle(velocity)
		_play_anim("move")
	else:
		_play_anim("idle")
	# Contact damage with 0.5 s cooldown.
	_contact_cd = max(0.0, _contact_cd - dt)
	if dist < CONTACT_RANGE and _contact_cd == 0.0 and is_instance_valid(target) and target.has_method("take_damage"):
		target.take_damage(data.contact_damage)
		_contact_cd = 0.5

func take_damage(amount: float) -> void:
	if data == null:
		return
	hp -= amount
	if hp <= 0.0:
		# Death visuals handled by Juice3D / HitFlash3D + the death pop particle;
		# _play_anim("die") would never render because queue_free() follows immediately.
		GameEvents.enemy_killed_3d.emit(global_position, data.xp_value)
		queue_free()
		return
	# Non-lethal hit: flash the enemy mesh white for 0.08 s.
	HitFlash3D.flash(self, 0.08)

## Attempt to play a named animation clip; silently no-ops if AnimationPlayer or clip absent.
## FBX→GLB animation clips are imported as "Take 001"; enemies load separate animation GLBs
## so this will usually no-op (rest-pose static) unless the mesh GLB has embedded clips.
func _play_anim(anim_name: String) -> void:
	if not _anim_player:
		return
	if not _anim_player.has_animation(anim_name):
		return
	if _anim_player.current_animation == anim_name:
		return
	_anim_player.play(anim_name)

## Pure static steering helper — unit-testable without a live physics step.
## Returns XZ-flattened direction from `from` toward `to`, scaled by `speed`.
## The Y component is always 0.
static func steer_velocity(from: Vector3, to: Vector3, speed: float) -> Vector3:
	var delta := to - from
	delta.y = 0.0
	var dist := delta.length()
	if dist < 0.001:
		return Vector3.ZERO
	return delta.normalized() * speed

## Pure static heading helper — unit-testable without Input or scene tree.
## Returns Y-axis rotation (radians) a Model Node3D should face given an XZ velocity.
## Zero-length velocity returns 0.0 — never NaN. Mirrors Player3D.face_angle().
static func face_angle(velocity: Vector3) -> float:
	if velocity.is_zero_approx():
		return 0.0
	return atan2(velocity.x, velocity.z)
