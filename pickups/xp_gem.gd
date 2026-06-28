# See docs/notes/xp-gem.md
class_name XPGem extends Area2D

## XP pickup that magnets toward the player when in range.
## Calls player.add_xp() and emits GameEvents.xp_collected on overlap.

const MAGNET_SPEED_MAX: float = 300.0

var _value: int = 0
var _player: Node2D = null
var _collected: bool = false

func setup(value: int, player: Node2D) -> void:
	_value = value
	_player = player
	body_entered.connect(_on_body_entered)

func _process(dt: float) -> void:
	if _collected:
		return
	if not is_instance_valid(_player):
		return
	var dist: float = global_position.distance_to(_player.global_position)
	var range_val: float = _player.get_pickup_range()
	if dist <= range_val:
		var direction: Vector2 = (_player.global_position - global_position).normalized()
		# Accelerate more as the gem gets closer (inverted lerp so t→1 as dist→0)
		var t: float = clamp(1.0 - dist / max(range_val, 1.0), 0.0, 1.0)
		var speed: float = lerp(60.0, MAGNET_SPEED_MAX, t)
		global_position += direction * speed * dt

func _on_body_entered(body: Node) -> void:
	if body == _player:
		_collect()

## Public for unit tests — also called by _on_body_entered.
func _collect() -> void:
	if _collected:
		return
	_collected = true
	if is_instance_valid(_player):
		_player.add_xp(_value)
	GameEvents.xp_collected.emit(_value)
	queue_free()
