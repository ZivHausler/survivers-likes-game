# See docs/notes/xp-gem-3d.md
class_name XPGem3D extends Area3D

## XP pickup (3D) that magnets toward the player when in range.
## Calls player.add_xp() and emits GameEvents.xp_collected on overlap.
## Mirrors XPGem (Area2D) behavior verbatim; movement on XZ plane (Y up).
## 1 world unit ≈ 16 px: MAGNET_SPEED_MAX = 300 / 16 ≈ 19.0; min speed = 60 / 16 ≈ 4.0.

const MAGNET_SPEED_MAX: float = 19.0  # 300 px / 16
const MAGNET_SPEED_MIN: float = 4.0   # 60 px / 16

var _value: int = 0
var _player: Node3D = null
var _collected: bool = false


func _ready() -> void:
	# Gentle scale pulse so the gem reads as "alive" on screen.
	var tween := create_tween().set_loops()
	tween.tween_property(self, "scale", Vector3(1.15, 1.15, 1.15), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "scale", Vector3(0.85, 0.85, 0.85), 0.6) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func setup(value: int, player: Node3D) -> void:
	_value = value
	_player = player
	# Apply tier color to the gem mesh so the orb's color signals its XP value.
	# A fresh StandardMaterial3D is created per gem — never mutates a shared resource.
	var mesh := get_node_or_null("MeshInstance3D") as MeshInstance3D
	if mesh:
		var c := tier_color(_value)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = c
		mat.emission_enabled = true
		mat.emission = c
		mat.emission_energy_multiplier = 2.0
		mesh.material_override = mat
	body_entered.connect(_on_body_entered)


## Maps an XP value to a tier color.
## Tiers (low value = cool color, high value = hot/rare color):
##   1–2   → blue   Color(0.3, 0.6, 1.0)   easiest / earliest enemies
##   3–5   → green  Color(0.3, 1.0, 0.4)
##   6–15  → yellow Color(1.0, 0.9, 0.2)
##   16–49 → orange Color(1.0, 0.55, 0.1)
##   50+   → magenta Color(1.0, 0.2, 0.6)  bosses / late-game
static func tier_color(value: int) -> Color:
	if value >= 50:
		return Color(1.0, 0.2, 0.6)   # magenta — boss / late-game
	if value >= 16:
		return Color(1.0, 0.55, 0.1)  # orange
	if value >= 6:
		return Color(1.0, 0.9, 0.2)   # yellow
	if value >= 3:
		return Color(0.3, 1.0, 0.4)   # green
	return Color(0.3, 0.6, 1.0)       # blue — lowest tier


func _process(dt: float) -> void:
	if _collected:
		return
	if not is_instance_valid(_player):
		return
	var delta := magnet_step(global_position, _player.global_position,
			_player.get_pickup_range(), dt)
	global_position += delta


func _on_body_entered(body: Node3D) -> void:
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


## Pure static magnet helper — returns the position delta for one physics step.
## Movement is on the XZ plane (y component is always 0).
## Returns Vector3.ZERO when outside `pickup_range`.
## Speed lerps from MAGNET_SPEED_MIN to MAGNET_SPEED_MAX as dist → 0.
static func magnet_step(gem_pos: Vector3, player_pos: Vector3,
		pickup_range: float, dt: float) -> Vector3:
	var diff: Vector3 = player_pos - gem_pos
	diff.y = 0.0
	var dist: float = diff.length()
	if dist > pickup_range:
		return Vector3.ZERO
	if dist < 0.001:
		return Vector3.ZERO
	var t: float = clamp(1.0 - dist / max(pickup_range, 1.0), 0.0, 1.0)
	var speed: float = lerp(MAGNET_SPEED_MIN, MAGNET_SPEED_MAX, t)
	return diff.normalized() * speed * dt
