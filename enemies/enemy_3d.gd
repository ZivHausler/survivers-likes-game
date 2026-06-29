# See docs/notes/enemy-3d.md
class_name Enemy3D extends CharacterBody3D
## 3D enemy actor (CharacterBody3D). Gameplay on XZ plane (Y up).
## Steers toward target, deals contact damage, and emits enemy_killed_3d on death.
## Mirrors Enemy (CharacterBody2D) behavior verbatim.
## Phase 2: setup() instances the real monster model from data.model_scene (GLB),
## hides the sphere placeholder, applies scale/offset, caches AnimationPlayer, and
## plays idle/move animations (best-effort; falls back to static rest-pose on failure).
## Playtest bug fixes: albedo tint applied to all model surfaces (BUG A);
## procedural alive-bob added (BUG B fallback) with best-effort skeletal anim transfer.

## World-unit stand-off radius for ranged enemies (playtest-tunable; replaces 2D pixel value 140).
const RANGED_STANDOFF := 6.0
## World-unit contact-damage radius (playtest-tunable; replaces 2D `radius+12` pixels).
const CONTACT_RANGE := 1.5
## Velocity length below which we play "idle" rather than "move".
const MOVE_THRESHOLD := 0.05

## Bob frequency in Hz — how many bounces per second at full move speed.
const BOB_FREQ_HZ := 2.0
## Maximum Y-bob amplitude in world units (visual only, never gameplay-affecting).
const BOB_AMPLITUDE := 0.04
## Maximum forward-lean pitch angle in radians at full move speed.
const LEAN_MAX_RAD := 0.07

var data: EnemyData
var target: Node3D
var hp: float = 0.0
var _contact_cd: float = 0.0
## Remaining charm time in seconds. While > 0, movement is suppressed.
var _charm_timer: float = 0.0
## Cached AnimationPlayer from the instanced model (or a created one); null if unavailable.
var _anim_player: AnimationPlayer = null
## Cached reference to the GLB model instance placed under _model pivot.
var _model_inst: Node3D = null
## True when a "move" animation was successfully loaded from a separate anim GLB.
var _anim_loaded: bool = false
## Phase accumulator (radians) for the procedural alive-bob; advances each physics frame.
var _bob_phase: float = 0.0

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
		_model_inst = model_inst
		# BUG A FIX: apply texture-preserving albedo tint so each variant renders as a
		# distinct color even when the GLB's embedded textures fail to import (unknown MIME /
		# missing embed). Reuses the same duplicate-material approach as boss tinting in
		# Spawner3D — if a surface already has a real albedo_texture (e.g. diatryma feathers),
		# the texture is kept and albedo_color multiplies it.
		Spawner3D.apply_model_tint(model_inst, data.color)
		# Cache AnimationPlayer if the mesh GLB embedded one.
		_anim_player = model_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		# BUG B FIX: attempt skeletal animation from a separate anim-only GLB.
		# Falls back gracefully if the file is absent or track paths do not retarget.
		_anim_loaded = _try_load_anim(model_inst, data)
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
	var moving: bool = velocity.length_squared() > MOVE_THRESHOLD * MOVE_THRESHOLD
	# Rotate Model toward movement direction (visual only — collision body stays upright).
	if _model and moving:
		_model.rotation.y = face_angle(velocity)
		_play_anim("move")
	else:
		_play_anim("idle")
	# BUG B FALLBACK: procedural alive-motion — always applied when a real model is present.
	# Gives a vertical bob + forward lean while moving so enemies never look frozen-sliding
	# even if skeletal retargeting failed. Visual only; never affects steering or contact.
	_apply_bob(dt, velocity)
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

## Procedural alive-motion: vertical bob + forward lean while moving.
## Applied to the _model pivot (visual-only; never touches velocity or collision shape).
## _bob_phase is reset when not moving so the model returns to upright rest cleanly.
func _apply_bob(dt: float, vel: Vector3) -> void:
	if not _model or _model_inst == null:
		return
	var flat_speed: float = Vector3(vel.x, 0.0, vel.z).length()
	var moving: bool = flat_speed > MOVE_THRESHOLD
	if moving:
		_bob_phase = fmod(_bob_phase + dt * TAU * BOB_FREQ_HZ, TAU)
		var speed_ratio: float = min(flat_speed / max(data.move_speed, 0.001), 1.0)
		_model.position.y = compute_bob_offset(speed_ratio, _bob_phase, BOB_AMPLITUDE)
		_model.rotation.x = -LEAN_MAX_RAD * speed_ratio
	else:
		_bob_phase = 0.0
		_model.position.y = 0.0
		_model.rotation.x = 0.0

## Pure static helper: Y bob offset from normalized speed, phase, and amplitude.
## Returns sin(phase) * amplitude * speed_ratio — zero when speed_ratio == 0.
## Testable without a scene tree (no engine state dependencies).
static func compute_bob_offset(speed_ratio: float, phase: float, amplitude: float) -> float:
	return sin(phase) * amplitude * speed_ratio

## BUG B: attempt to transfer a skeletal animation from a separate anim-only GLB into
## the mesh model's AnimationPlayer. Returns true if a "move" animation was loaded and
## the AnimationPlayer confirmed it is playing. Falls back gracefully on any failure.
##
## Strategy: derive the anim GLB path from the model_scene path (same directory,
## strip "_mesh" suffix, try "_run" / "_walk" / "_move" suffixes). Copy the first
## animation found into a library named "" (global) as "move" so _play_anim("move")
## resolves it correctly.
func _try_load_anim(model_inst: Node3D, p_data: EnemyData) -> bool:
	if not p_data.model_scene:
		return false
	var mesh_path: String = p_data.model_scene.resource_path
	if mesh_path.is_empty():
		return false

	# Derive base name: "bug_mesh.glb" → "bug", "plant_mesh.glb" → "plant", etc.
	var dir: String = mesh_path.get_base_dir()
	var stem: String = mesh_path.get_file().get_basename()  # e.g. "bug_mesh"
	var sep: int = stem.rfind("_mesh")
	var base: String = stem.left(sep) if sep >= 0 else stem

	# Probe for the run/walk/move GLB in the same directory.
	var anim_path: String = ""
	for suffix: String in ["_run", "_walk", "_move"]:
		var candidate: String = dir.path_join(base + suffix + ".glb")
		if ResourceLoader.exists(candidate):
			anim_path = candidate
			break
	if anim_path.is_empty():
		return false

	var anim_scene: PackedScene = ResourceLoader.load(anim_path) as PackedScene
	if not anim_scene:
		return false
	var anim_inst: Node = anim_scene.instantiate()
	if not anim_inst:
		return false

	# Temporarily parent under self so the AnimationPlayer's node paths can resolve.
	add_child(anim_inst)
	if anim_inst is Node3D:
		(anim_inst as Node3D).visible = false

	var src_ap: AnimationPlayer = anim_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if src_ap == null:
		anim_inst.queue_free()
		return false

	var names: PackedStringArray = src_ap.get_animation_list()
	if names.is_empty():
		anim_inst.queue_free()
		return false

	# Get the first animation resource (typically the run/walk cycle).
	var first_anim: Animation = src_ap.get_animation(names[0])
	if first_anim == null:
		anim_inst.queue_free()
		return false

	# Get or create an AnimationPlayer on the mesh model instance.
	var tgt_ap: AnimationPlayer = model_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
	if tgt_ap == null:
		tgt_ap = AnimationPlayer.new()
		model_inst.add_child(tgt_ap)

	# Add the animation to the global library (create if absent) as "move".
	var lib: AnimationLibrary
	if tgt_ap.has_animation_library(""):
		lib = tgt_ap.get_animation_library("") as AnimationLibrary
	else:
		lib = AnimationLibrary.new()
		tgt_ap.add_animation_library("", lib)
	if not lib.has_animation("move"):
		lib.add_animation("move", first_anim)

	# Free the temporary animation scene; the Animation resource lives on via lib.
	anim_inst.queue_free()

	_anim_player = tgt_ap
	_anim_player.play("move")
	# Confirm the animation is present and playing (track-path mismatch won't crash,
	# but is_playing will still return true; procedural bob is the visual safety net).
	return _anim_player.has_animation("move") and _anim_player.is_playing()

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
