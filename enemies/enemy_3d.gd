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
## Squared-speed floor below which an RVO `velocity_computed` result is treated as
## "avoidance produced nothing" — the enemy then falls back to its desired velocity
## so it never freezes when the NavigationServer isn't simulating avoidance
## (no active nav map, or headless). See _on_velocity_computed.
const AVOID_EPSILON_SQ := 0.01

## Seconds between NavigationAgent3D path refreshes. Enemies steer toward the agent's
## next path corner every frame, but only re-run the A* query (set target_position)
## this often — so a swarm of ~50-200 doesn't re-path every physics frame. The player
## is slow relative to this window, so a slightly stale route is imperceptible.
const REPATH_INTERVAL := 0.3
## World-unit distance under which the navmesh "next corner" is treated as coincident
## with the enemy (no usable path step) → fall back to a straight line so we never
## freeze when navigation has no route (headless / inactive map / target reached).
const NAV_STEP_EPSILON := 0.05

## Bob frequency in Hz — how many bounces per second at full move speed.
const BOB_FREQ_HZ := 2.0
## Maximum Y-bob amplitude in world units (visual only, never gameplay-affecting).
const BOB_AMPLITUDE := 0.04
## Maximum forward-lean pitch angle in radians at full move speed.
const LEAN_MAX_RAD := 0.07

## Duration (seconds) of the knockback hop-back arc.
const KNOCKBACK_DURATION := 0.22
## Peak height (world units) of the knockback hop.
const KNOCKBACK_HOP_HEIGHT := 0.7

var data: EnemyData
var target: Node3D
var hp: float = 0.0
## Non-melee attack strategy (RangedAttack / DashAttack); null for MELEE (inline default).
var _attack: EnemyAttack = null
var _contact_cd: float = 0.0
## Seconds until the next nearest-player retarget scan (throttled — see _physics_process).
var _retarget_cd: float = 0.0
## Remaining charm time in seconds. While > 0, movement is suppressed.
var _charm_timer: float = 0.0
## Knockback (hop-back) state. While _knockback_timer > 0, nav/attack logic is
## suspended and the enemy is carried along _knockback_vel with a vertical hop arc.
var _knockback_timer: float = 0.0
var _knockback_vel: Vector3 = Vector3.ZERO
## Cached AnimationPlayer from the instanced model (or a created one); null if unavailable.
var _anim_player: AnimationPlayer = null
## Real clip names resolved once in setup() for the logical "idle"/"move" states.
## Empty string means "no matching clip" → _play_anim no-ops and the procedural bob
## is the visual safety net. See _resolve_anim_clips() / resolve_clip().
var _clip_idle: String = ""
var _clip_move: String = ""
## Resolved one-shot attack/cast gesture clip ("" if the model has none).
var _clip_attack: String = ""
## Seconds remaining of an active attack gesture. While > 0, the per-frame idle/move
## animation selection is suppressed so the gesture is not immediately overwritten.
var _attack_anim_left: float = 0.0
## Cached reference to the GLB model instance placed under _model pivot.
var _model_inst: Node3D = null
## True when a "move" animation was successfully loaded from a separate anim GLB.
var _anim_loaded: bool = false
## Phase accumulator (radians) for the procedural alive-bob; advances each physics frame.
var _bob_phase: float = 0.0

## True once the death sequence begins — blocks re-kills, contact damage, and movement
## during the 0.4 s dissolve animation before queue_free().
var _dying := false

## Accumulated time since the last NavigationAgent3D path refresh. Initialized to
## REPATH_INTERVAL so the very first _physics_process frame publishes a target and a
## route exists immediately (no one-interval stall on spawn).
var _repath_accum: float = REPATH_INTERVAL

## True once the first velocity_computed callback has been received.
## False on warmup frames (NavigationServer not yet joined); used by _apply_movement
## to fall back to a direct move_and_slide() so enemies never freeze on the first frame.
var _avoidance_active := false

## Boss classification — set by Spawner3D via configure_boss() after setup().
enum BossKind { NONE, MINI, BIG }
var boss_kind: int = BossKind.NONE
var boss_name: String = ""
## Floating world-space HP bar for mini-bosses only (null otherwise).
var _health_bar: HealthBar3D = null
## Local-space Y offset of the mini-boss head bar (scales with the boss body).
const MINI_BOSS_BAR_OFFSET_Y := 2.5

@onready var _model: Node3D = $Model
@onready var _placeholder: MeshInstance3D = $Model/MeshInstance3D
## RVO avoidance agent; routes the actual move so the swarm flows around obstacles
## and each other. velocity_computed is connected in _ready().
@onready var _agent: NavigationAgent3D = $NavigationAgent3D

func _ready() -> void:
	if _agent:
		_agent.velocity_computed.connect(_on_velocity_computed)

func setup(p_data: EnemyData, p_target: Node3D) -> void:
	data = p_data
	target = p_target
	hp = data.max_hp
	# FIX 3: raise the NavigationAgent3D speed cap to match the enemy's actual move_speed
	# so fast enemies (move_speed > tscn default 12.0) are not RVO-clamped.
	if _agent and data:
		_agent.max_speed = max(_agent.max_speed, data.move_speed)
	_attack = _make_attack(data)

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
		# NOTE: the cel/rim Stylize overlay is intentionally NOT applied to enemies.
		# Per design direction, the new neon visual treatment is reserved for NEW assets
		# we create; existing mob models keep their original materials + per-variant tint.
		# Cache AnimationPlayer if the mesh GLB embedded one.
		_anim_player = model_inst.find_child("AnimationPlayer", true, false) as AnimationPlayer
		# BUG B FIX: attempt skeletal animation from a separate anim-only GLB.
		# Falls back gracefully if the file is absent or track paths do not retarget.
		_anim_loaded = _try_load_anim(model_inst, data)
		# Resolve logical idle/move states to real clip names (supports both the legacy
		# injected-"move" convention and self-contained Quaternius GLBs).
		_resolve_anim_clips()
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

## Pick the attack strategy for this enemy's data. MELEE → null (inline default).
## Legacy is_ranged=true is treated as RANGED for back-compat.
func _make_attack(d: EnemyData) -> EnemyAttack:
	var kind: int = d.attack_kind
	if kind == EnemyData.AttackKind.MELEE and d.is_ranged:
		kind = EnemyData.AttackKind.RANGED
	match kind:
		EnemyData.AttackKind.RANGED:
			return RangedAttack.new()
		EnemyData.AttackKind.DASHER:
			return DashAttack.new()
		_:
			return null

## Tag this enemy as a boss. Called by Spawner3D AFTER setup() (so `data` is set).
## BIG  → announce to the HUD via GameEvents.boss_spawned (no head bar).
## MINI → attach a HealthBar3D above the head, starting full.
func configure_boss(kind: int, p_name: String = "") -> void:
	boss_kind = kind
	boss_name = p_name
	if kind == BossKind.BIG:
		GameEvents.boss_spawned.emit(p_name, data.max_hp)
	elif kind == BossKind.MINI:
		_health_bar = HealthBar3D.new()
		add_child(_health_bar)
		_health_bar.position = Vector3(0.0, MINI_BOSS_BAR_OFFSET_Y, 0.0)
		_health_bar.set_ratio(1.0)

## Suppress enemy movement for `duration` seconds.
## Stacks by taking the maximum remaining time (mirrors 2D charm logic).
func charm(duration: float) -> void:
	_charm_timer = max(_charm_timer, duration)

## Route this frame's desired velocity through RVO avoidance when available; the
## actual move_and_slide() then happens in _on_velocity_computed. Falls back to a
## direct move when there is no agent or we are outside the scene tree (headless
## unit tests), preserving the original synchronous behavior.
##
## FIX 1 — first-frame/warmup fallback: until the NavigationServer has joined the
## agent to a map and emitted the first velocity_computed callback (_avoidance_active
## is false), we also call move_and_slide() directly so the enemy moves with its
## desired velocity. Once active, only the callback's move_and_slide() runs — never
## double-moving in the steady state.
func _apply_movement(_dt: float) -> void:
	if _agent and _agent.avoidance_enabled and is_inside_tree():
		_agent.set_velocity(velocity)
		if not _avoidance_active:
			move_and_slide()   # warmup fallback: desired velocity until first callback
	else:
		move_and_slide()

## Avoidance result: the navigation server's collision-free velocity. Apply it and
## perform the real move. velocity_computed fires during the physics step.
## FIX 2 — stale-velocity guard: no-op when data is null (e.g. a queued callback
## arrives after setup() hasn't run, or the enemy was freed mid-frame).
func _on_velocity_computed(safe_velocity: Vector3) -> void:
	if data == null:
		return
	if _dying:
		return  # no movement callbacks while dissolving
	if _knockback_timer > 0.0:
		return  # knockback drives movement directly; ignore RVO this window
	_avoidance_active = true
	# Defense in depth: RVO only yields a non-zero safe velocity when its navigation
	# map is active AND avoidance actually simulates (it does not in headless, and
	# would not without a NavigationRegion activating the map). If RVO returns ~zero
	# while this frame's DESIRED velocity (already assigned to `velocity` in
	# _physics_process) is real, keep the desired velocity so the enemy never freezes;
	# otherwise adopt the avoided velocity. Result: RVO steering when it works, plain
	# collision-slide toward the target when it doesn't.
	if not (safe_velocity.length_squared() < AVOID_EPSILON_SQ and velocity.length_squared() >= AVOID_EPSILON_SQ):
		velocity = safe_velocity
	move_and_slide()

func _physics_process(dt: float) -> void:
	_retarget_cd -= dt
	if _retarget_cd <= 0.0:
		_retarget_cd = 0.4
		var players := get_tree().get_nodes_in_group("player")
		var alive: Array = []
		for p in players:
			if is_instance_valid(p) and (not p.has_method("is_downed") or not p.is_downed()):
				alive.append(p)
		var nearest := nearest_target(global_position, alive)
		if nearest != null:
			target = nearest
	if data == null:
		return
	if _dying:
		return  # no movement or contact damage while dissolving
	# Knockback takes priority: carry the enemy along the hop with a vertical arc,
	# bypassing nav/attack logic until the short window elapses.
	if _knockback_timer > 0.0:
		_knockback_timer = max(0.0, _knockback_timer - dt)
		velocity = _knockback_vel
		move_and_slide()
		if _model:
			# Parabolic hop: 0 at start/end, peak at mid — sin over the [0,PI] arc.
			var progress: float = 1.0 - (_knockback_timer / KNOCKBACK_DURATION)
			_model.position.y = sin(progress * PI) * KNOCKBACK_HOP_HEIGHT
		if _knockback_timer == 0.0 and _model:
			_model.position.y = 0.0  # settle flush with the ground when the hop ends
		return
	# Tick charm timer and suppress movement while charmed.
	_charm_timer = max(0.0, _charm_timer - dt)
	if _charm_timer > 0.0:
		velocity = Vector3.ZERO
		_apply_movement(dt)
		return
	if not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	to_target.y = 0.0  # Move only on XZ plane.
	var dist := to_target.length()
	if _attack:
		velocity = _attack.desired_velocity(self, target, dt)
	else:
		var desired := 0.0 if (data.is_ranged and dist < RANGED_STANDOFF) else data.move_speed
		if desired > 0.0:
			# Route toward the player along the baked navmesh so we go AROUND terrain,
			# not straight into it. RVO (set_velocity, below) then handles the last-meter
			# dodging and enemy-vs-enemy jostling on top of the routed velocity.
			velocity = _path_toward(target.global_position, desired, dt)
		else:
			velocity = Vector3.ZERO   # ranged enemy holding its stand-off distance
	_apply_movement(dt)
	_attack_anim_left = max(0.0, _attack_anim_left - dt)
	var moving: bool = velocity.length_squared() > MOVE_THRESHOLD * MOVE_THRESHOLD
	# Rotate Model toward movement direction (visual only — collision body stays upright).
	if _model and moving:
		_model.rotation.y = face_angle(velocity)
	# While a cast/attack gesture is playing, keep it on screen — don't overwrite it with
	# the per-frame idle/move clip (the gesture is the visible "spell throw" telegraph).
	if _attack_anim_left <= 0.0:
		if _model and moving:
			_play_anim("move")
		else:
			_play_anim("idle")
	# BUG B FALLBACK: procedural alive-motion — always applied when a real model is present.
	# Gives a vertical bob + forward lean while moving so enemies never look frozen-sliding
	# even if skeletal retargeting failed. Visual only; never affects steering or contact.
	_apply_bob(dt, velocity)
	if _attack:
		_attack.attack_tick(self, target, dt)
	else:
		# Melee contact damage with 0.5 s cooldown (unchanged).
		_contact_cd = max(0.0, _contact_cd - dt)
		if dist < CONTACT_RANGE and _contact_cd == 0.0 and is_instance_valid(target) and target.has_method("take_damage"):
			target.take_damage(data.contact_damage)
			_contact_cd = 0.5

## Shove the enemy `distance` world units along `dir` (XZ plane) as a short hop-back:
## suspends nav/attack for KNOCKBACK_DURATION and plays a vertical arc. Called by
## orbit weapons on orb contact. No-op while dying, and no-op for mini/big bosses —
## bosses stand their ground and are never knocked around. Takes the stronger of any
## overlapping knockback so a fresh hit always registers.
func apply_knockback(dir: Vector3, distance: float) -> void:
	if _dying or data == null:
		return
	if boss_kind != BossKind.NONE:
		return  # bosses are immune to knockback
	var flat := Vector3(dir.x, 0.0, dir.z)
	if flat.length_squared() < 0.0001:
		flat = Vector3(1.0, 0.0, 0.0)
	var vel := flat.normalized() * (distance / KNOCKBACK_DURATION)
	if _knockback_timer > 0.0 and _knockback_vel.length_squared() >= vel.length_squared():
		return  # already hopping at least this hard; don't weaken it
	_knockback_vel = vel
	_knockback_timer = KNOCKBACK_DURATION

func take_damage(amount: float) -> void:
	if data == null:
		return
	if _dying:
		return  # dissolving — ignore further hits so signals/XP don't fire twice
	hp -= amount
	if hp <= 0.0:
		# Big boss announces death so the HUD bar hides before the node is freed.
		if boss_kind == BossKind.BIG:
			GameEvents.boss_died.emit()
		# Bosses (mini + big) trigger a screen shake on death; normal enemies do not.
		if boss_kind != BossKind.NONE:
			GameEvents.boss_killed_3d.emit(boss_kind)
		# All kill side-effects (signal + XP) fire here, exactly as before.
		# Only queue_free() is deferred so the dissolve can play (~0.4 s).
		GameEvents.enemy_killed_3d.emit(global_position, data.xp_value)
		_dying = true
		_start_dissolve_death()
		return
	# Non-lethal hit: drive boss HP feedback, then flash.
	if boss_kind == BossKind.BIG:
		GameEvents.boss_hp_changed.emit(hp, data.max_hp)
	elif boss_kind == BossKind.MINI and is_instance_valid(_health_bar):
		var denom := maxf(data.max_hp, 0.0001)
		_health_bar.set_ratio(hp / denom)
	# Non-lethal hit: flash the enemy mesh white for 0.08 s.
	HitFlash3D.flash(self, 0.08)

## Kick off the dissolve-death visual.  All kill side-effects (signals, XP) have
## already fired in take_damage() before this is called.
## If there is no real model instance (headless tests / no-model fallback path),
## queue_free() is called immediately so existing test behaviour is unchanged.
func _start_dissolve_death() -> void:
	# Disable collision so hurtboxes and distance-contact checks can't re-trigger.
	set_collision_layer(0)
	set_collision_mask(0)
	# Remove from the enemies group so targeting systems (weapons, AI) skip us.
	if is_in_group(&"enemies"):
		remove_from_group(&"enemies")
	# No real model → free immediately (preserves current headless-test behaviour).
	if _model_inst == null:
		queue_free()
		return
	# Resolve edge colour from VisualPalette autoload (guarded: not present in some tests).
	var vp := get_node_or_null("/root/VisualPalette")
	var edge_col: Color = vp.role(&"enemy_secondary") if vp else Color(1.0, 0.2, 0.6)
	# Load the dissolve shader (ResourceLoader caches it across instances).
	var shader := load("res://shaders/dissolve_death.gdshader") as Shader
	# Apply a fresh ShaderMaterial to every MeshInstance3D under the model pivot.
	var meshes: Array[Node] = _model.find_children("*", "MeshInstance3D", true, false)
	for node: Node in meshes:
		var mi := node as MeshInstance3D
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("progress", 0.0)
		mat.set_shader_parameter("edge_color", edge_col)
		mi.material_override = mat
	# Tween progress 0 → 1 over 0.4 s on all meshes in parallel, then free.
	var tween := create_tween()
	for node: Node in meshes:
		var mat := (node as MeshInstance3D).material_override as ShaderMaterial
		tween.parallel().tween_property(mat, "shader_parameter/progress", 1.0, 0.4)
	tween.tween_callback(queue_free)

## Play a logical animation state ("idle" / "move"); silently no-ops if the
## AnimationPlayer or a matching clip is absent (procedural bob covers it).
## The logical name is mapped to the real clip resolved in _resolve_anim_clips()
## so this works for both separate-anim-GLB models and self-contained Quaternius
## GLBs ("CharacterArmature|Idle" etc.). Any other name is played verbatim.
func _play_anim(anim_name: String) -> void:
	if not _anim_player:
		return
	var clip := anim_name
	if anim_name == "idle":
		clip = _clip_idle
	elif anim_name == "move":
		clip = _clip_move
	if clip.is_empty() or not _anim_player.has_animation(clip):
		return
	if _anim_player.current_animation == clip:
		return
	_anim_player.play(clip)

## Map the logical "idle"/"move" states onto real AnimationPlayer clip names once,
## so _play_anim() never scans the clip list per frame. Handles two model conventions:
##  1. Legacy: _try_load_anim injects a literal "move" clip; "idle" may be embedded.
##  2. Self-contained GLBs (CC0 Quaternius monsters) whose clips are named
##     "CharacterArmature|Idle", "Walk"/"Run", "Flying_Idle"/"Fast_Flying", etc.
## Resolved locomotion/idle clips are forced to loop so they don't freeze after one
## cycle (imported GLB clips often default to LOOP_NONE).
func _resolve_anim_clips() -> void:
	_clip_idle = ""
	_clip_move = ""
	if _anim_player == null:
		return
	var clips := _anim_player.get_animation_list()
	_clip_idle = resolve_clip(clips, PackedStringArray(["idle", "flying_idle"]))
	_clip_move = resolve_clip(clips, PackedStringArray(["move", "run", "walk", "fast_flying", "flying"]))
	# One-shot cast/attack gesture — NOT looped (plays once per shot).
	_clip_attack = resolve_clip(clips, PackedStringArray(
			["attack", "cast", "shoot", "punch", "headbutt", "bite_front", "throw"]))
	_force_loop(_anim_player, _clip_idle)
	_force_loop(_anim_player, _clip_move)

## Play the one-shot attack/cast gesture (if the model has one) and lock idle/move
## selection for `duration` seconds so the per-frame logic doesn't immediately overwrite
## it. Called by RangedAttack at windup start. No-op when the model has no attack clip.
func play_attack_gesture(duration: float) -> void:
	if _anim_player == null or _clip_attack.is_empty():
		return
	_attack_anim_left = maxf(duration, 0.0)
	if _anim_player.current_animation != _clip_attack:
		_anim_player.play(_clip_attack)

## Force a clip to loop linearly if it currently has no loop. No-op for "" / missing clips.
static func _force_loop(ap: AnimationPlayer, clip: String) -> void:
	if ap == null or clip.is_empty() or not ap.has_animation(clip):
		return
	var a := ap.get_animation(clip)
	if a and a.loop_mode == Animation.LOOP_NONE:
		a.loop_mode = Animation.LOOP_LINEAR

## Resolve a logical animation state to an actual clip name from `clips`.
## `candidates` is ordered most-preferred first. Matching priority:
##   1. exact (case-insensitive)
##   2. leaf node name — the part after the last "|" or "/" (Quaternius "Armature|Clip")
##   3. substring (case-insensitive)
## Returns "" when nothing matches. Pure/static — unit-testable without a scene tree.
static func resolve_clip(clips: PackedStringArray, candidates: PackedStringArray) -> String:
	# Pass 1: exact case-insensitive match.
	for cand in candidates:
		for c in clips:
			if c.to_lower() == cand.to_lower():
				return c
	# Pass 2: leaf node (after the last "|" or "/") equals the candidate.
	for cand in candidates:
		for c in clips:
			var leaf := c
			var bar := leaf.rfind("|")
			if bar >= 0:
				leaf = leaf.substr(bar + 1)
			var slash := leaf.rfind("/")
			if slash >= 0:
				leaf = leaf.substr(slash + 1)
			if leaf.to_lower() == cand.to_lower():
				return c
	# Pass 3: substring.
	for cand in candidates:
		for c in clips:
			if cand.to_lower() in c.to_lower():
				return c
	return ""

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

	# Duplicate so we never mutate the shared, cached source Animation resource
	# (retargeting rewrites track paths in place and must not leak across enemies).
	var move_anim: Animation = (first_anim as Animation).duplicate(true) as Animation

	# The anim GLB keys node-path tracks (RootNode/bug_body/…), but the skinned mesh
	# imports its rig as a Skeleton3D, so those paths never resolve. Retarget each
	# track onto the matching skeleton bone (leaf node name == bone name). Without a
	# skeleton (non-skinned model) the original node-path tracks are kept as-is.
	var skel: Skeleton3D = find_skeleton(model_inst)
	if skel:
		var anim_root: Node = tgt_ap.get_node_or_null(tgt_ap.root_node)
		if anim_root == null:
			anim_root = tgt_ap.get_parent()
		if anim_root:
			retarget_tracks_to_skeleton(move_anim, skel, anim_root.get_path_to(skel))

	# Add the animation to the global library (create if absent) as "move".
	var lib: AnimationLibrary
	if tgt_ap.has_animation_library(""):
		lib = tgt_ap.get_animation_library("") as AnimationLibrary
	else:
		lib = AnimationLibrary.new()
		tgt_ap.add_animation_library("", lib)
	if not lib.has_animation("move"):
		lib.add_animation("move", move_anim)

	# Free the temporary animation scene; the Animation resource lives on via lib.
	anim_inst.queue_free()

	_anim_player = tgt_ap
	_anim_player.play("move")
	# Confirm the animation is present and playing (track-path mismatch won't crash,
	# but is_playing will still return true; procedural bob is the visual safety net).
	return _anim_player.has_animation("move") and _anim_player.is_playing()

## Recursively find the first Skeleton3D under `root` (depth-first). Null if none.
## Skinned GLB meshes import their armature as a Skeleton3D, which is what skeletal
## animation tracks must address (via a ":bonename" subpath).
static func find_skeleton(root: Node) -> Skeleton3D:
	if root is Skeleton3D:
		return root as Skeleton3D
	for child in root.get_children():
		var found := find_skeleton(child)
		if found:
			return found
	return null

## Rewrite an animation's node-path transform tracks (e.g. "RootNode/bug_body/bug_thorax1")
## into skeleton-bone tracks (e.g. "RootNode/Skeleton3D:bug_thorax1") so an animation
## authored against a plain Node3D rig can drive a skinned Skeleton3D. Each track's leaf
## node name is matched against the skeleton's bone names: matches are repointed at the
## bone, everything else (unmatched leaves, non-transform tracks) is dropped to avoid
## unresolved-track warnings. `skel_rel` is the skeleton's path relative to the target
## AnimationPlayer's root_node. Mutates `anim` in place; returns the count of kept tracks.
static func retarget_tracks_to_skeleton(anim: Animation, skel: Skeleton3D, skel_rel: NodePath) -> int:
	var base: String = String(skel_rel)
	var kept := 0
	# Iterate high→low so remove_track() doesn't shift indices we have yet to visit.
	for t in range(anim.get_track_count() - 1, -1, -1):
		var ttype := anim.track_get_type(t)
		if ttype != Animation.TYPE_POSITION_3D and ttype != Animation.TYPE_ROTATION_3D \
				and ttype != Animation.TYPE_SCALE_3D:
			anim.remove_track(t)
			continue
		var p := anim.track_get_path(t)
		var nc := p.get_name_count()
		if nc == 0:
			anim.remove_track(t)
			continue
		var bone_name := String(p.get_name(nc - 1))
		if skel.find_bone(bone_name) == -1:
			anim.remove_track(t)
			continue
		anim.track_set_path(t, NodePath(base + ":" + bone_name))
		kept += 1
	return kept

## Route toward `goal` (the player) using the NavigationAgent3D so the enemy follows
## the navmesh AROUND carved terrain instead of steering blindly into it. The A* query
## (target_position assignment) is throttled to REPATH_INTERVAL so a large swarm stays
## cheap; the per-frame steer reads the agent's next path corner. Falls back to a plain
## straight line when there is no agent / we are outside the tree (headless unit tests),
## and nav_desired_velocity falls back again if the corner yields no usable step — so
## the enemy never freezes when navigation has no route.
func _path_toward(goal: Vector3, speed: float, dt: float) -> Vector3:
	if _agent == null or not is_inside_tree():
		return steer_velocity(global_position, goal, speed)
	_repath_accum += dt
	if _repath_accum >= REPATH_INTERVAL:
		_repath_accum = 0.0
		_agent.target_position = goal
	var next_corner := _agent.get_next_path_position()
	return nav_desired_velocity(global_position, next_corner, goal, speed)

## Pure static path-follow helper — unit-testable without a live NavigationServer.
## Steers from `from` toward `next_corner` (the navmesh path point) when that corner is
## a meaningful step away; otherwise falls back to a straight line toward `target` so
## the enemy keeps moving when navigation produced no usable path (headless / inactive
## map / already at the corner). Always XZ-flattened; Y is 0.
static func nav_desired_velocity(from: Vector3, next_corner: Vector3, target: Vector3, speed: float) -> Vector3:
	var to_next := next_corner - from
	to_next.y = 0.0
	if to_next.length() > NAV_STEP_EPSILON:
		return to_next.normalized() * speed
	return steer_velocity(from, target, speed)

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

## Pure static targeting helper — unit-testable without a live scene tree.
## Returns the candidate closest to `from` (by squared distance), ignoring
## null/freed entries. Returns null when no valid candidate exists.
static func nearest_target(from: Vector3, candidates: Array) -> Node3D:
	var best: Node3D = null
	var best_d := INF
	for c in candidates:
		if c == null or not is_instance_valid(c):
			continue
		var d := from.distance_squared_to((c as Node3D).global_position)
		if d < best_d:
			best_d = d
			best = c
	return best
