# See docs/notes/enemy.md
class_name Enemy extends CharacterBody2D

var data: EnemyData
var target: Node2D
var hp: float = 0.0
var _contact_cd: float = 0.0
## Remaining charm time in seconds. While > 0, movement is suppressed.
var _charm_timer: float = 0.0
## Per-enemy wobble phase offset (radians).
var _wobble_phase: float = 0.0

func setup(p_data: EnemyData, p_target: Node2D) -> void:
	data = p_data
	target = p_target
	hp = data.max_hp
	_wobble_phase = randf() * TAU

	var sprite := $Sprite as Sprite2D
	var body := $Body as CanvasItem

	if data.texture != null:
		sprite.texture = data.texture
		sprite.modulate = data.color.lerp(Color.WHITE, 0.5)
		sprite.visible = true
		body.visible = false
	else:
		body.modulate = data.color
		sprite.visible = false
		body.visible = true

## Suppress enemy movement for `duration` seconds.
## Called by ZivStunningLooks. Stacks by taking the maximum remaining time.
func charm(duration: float) -> void:
	_charm_timer = max(_charm_timer, duration)

func _physics_process(dt: float) -> void:
	if data == null:
		return
	# Procedural wobble — visual only, never affects movement/velocity.
	var sprite := $Sprite as Sprite2D
	if sprite.visible:
		_wobble_phase += dt * 4.0
		var squash: float = 1.0 + 0.06 * sin(_wobble_phase)
		sprite.scale = Vector2(squash, 2.0 - squash) * 0.5
	# Tick charm timer and suppress movement while charmed.
	_charm_timer = max(0.0, _charm_timer - dt)
	if _charm_timer > 0.0:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if not is_instance_valid(target):
		return
	var to_target := target.global_position - global_position
	var dist := to_target.length()
	var desired := 0.0 if (data.is_ranged and dist < 140.0) else data.move_speed
	velocity = to_target.normalized() * desired
	move_and_slide()
	_contact_cd = max(0.0, _contact_cd - dt)
	if dist < data.radius + 12.0 and _contact_cd == 0.0 and target.has_method("take_damage"):
		target.take_damage(data.contact_damage)
		_contact_cd = 0.5

func take_damage(amount: float) -> void:
	if data == null:
		return
	hp -= amount
	if hp <= 0.0:
		GameEvents.enemy_killed.emit(global_position, data.xp_value)
		queue_free()
