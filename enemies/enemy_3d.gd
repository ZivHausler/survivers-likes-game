# See docs/notes/enemy-3d.md
class_name Enemy3D extends CharacterBody3D
## 3D enemy actor (CharacterBody3D). Gameplay on XZ plane (Y up).
## Steers toward target, deals contact damage, and emits enemy_killed_3d on death.
## Mirrors Enemy (CharacterBody2D) behavior verbatim; model wired in Phase 2.

## World-unit stand-off radius for ranged enemies (playtest-tunable; replaces 2D pixel value 140).
const RANGED_STANDOFF := 6.0
## World-unit contact-damage radius (playtest-tunable; replaces 2D `radius+12` pixels).
const CONTACT_RANGE := 1.5

var data: EnemyData
var target: Node3D
var hp: float = 0.0
var _contact_cd: float = 0.0
## Remaining charm time in seconds. While > 0, movement is suppressed.
var _charm_timer: float = 0.0

func setup(p_data: EnemyData, p_target: Node3D) -> void:
	data = p_data
	target = p_target
	hp = data.max_hp
	# Tint the placeholder mesh by data.color so the 3 variants look distinct.
	# Phase 2 swaps this for the real model under the Model child node.
	var mesh_inst := $Model/MeshInstance3D as MeshInstance3D
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
		GameEvents.enemy_killed_3d.emit(global_position, data.xp_value)
		queue_free()
		return
	# Non-lethal hit: flash the enemy mesh white for 0.08 s.
	HitFlash3D.flash(self, 0.08)

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
