# See docs/notes/xp-gem-3d.md
class_name XPGem3D extends Area3D

## XP pickup (3D) that magnets toward the player when in range.
## Calls player.add_xp() and emits GameEvents.xp_collected on overlap.
## Movement on XZ plane (Y up). 1 world unit ≈ 16 px.
##
## Magnet behaviour: once the gem first enters the player's pickup range it LATCHES
## (`_magnetized`) and homes in for good — it never un-magnetizes, even if the player
## outruns it. While latched it ACCELERATES every frame (starting at MAGNET_SPEED_MIN,
## ramping by MAGNET_ACCEL up to MAGNET_SPEED_MAX), so it always overtakes the player
## regardless of move speed. An arrival snap collects it if a fast step would otherwise
## overshoot, so it can never tunnel past.

## Peak magnet speed (world u/s). Well above any realistic player move speed so a
## latched gem always closes the gap.
const MAGNET_SPEED_MAX: float = 40.0
## Initial magnet speed the instant the gem latches (world u/s).
const MAGNET_SPEED_MIN: float = 4.0
## How fast the magnet speed ramps up while latched (world u/s²).
const MAGNET_ACCEL: float = 60.0
## Distance (world u) at which a latched gem is close enough to auto-collect, as a
## safety net for the physics overlap when moving fast.
const COLLECT_DIST: float = 0.35

var _value: int = 0
var _player: Node3D = null
var _collected: bool = false
## True once the gem has entered pickup range; latched for the gem's lifetime.
var _magnetized: bool = false
## Current magnet speed (world u/s); ramps from MIN to MAX while latched.
var _magnet_speed: float = 0.0


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


## Maps an XP value to a tier color sourced from VisualPalette.
## Tiers (low value = cool color, high value = hot/rare color):
##   1–2   → pickup_low    blue    easiest / earliest enemies
##   3–5   → pickup_mid    green
##   6–15  → pickup_high   yellow
##   16–49 → pickup_higher orange
##   50+   → pickup_top    magenta bosses / late-game
static func tier_color(value: int) -> Color:
	if value >= 50:
		return VisualPalette.role(&"pickup_top")     # magenta — boss / late-game
	if value >= 16:
		return VisualPalette.role(&"pickup_higher")  # orange
	if value >= 6:
		return VisualPalette.role(&"pickup_high")    # yellow
	if value >= 3:
		return VisualPalette.role(&"pickup_mid")     # green
	return VisualPalette.role(&"pickup_low")         # blue — lowest tier


func _process(dt: float) -> void:
	if _collected:
		return
	if not is_instance_valid(_player):
		return
	var player_pos: Vector3 = _player.global_position
	# Latch on first entry into pickup range; never release afterwards.
	if not _magnetized:
		if in_pickup_range(global_position, player_pos, _player.get_pickup_range()):
			_magnetized = true
			_magnet_speed = MAGNET_SPEED_MIN
		else:
			return
	# Accelerate, then home in (delta lands exactly on the player if it would overshoot).
	_magnet_speed = next_magnet_speed(_magnet_speed, dt)
	global_position += magnet_delta(global_position, player_pos, _magnet_speed, dt)
	# Arrival safety net: collect once close, in case a fast step skipped the overlap.
	var flat := Vector3(player_pos.x - global_position.x, 0.0, player_pos.z - global_position.z)
	if flat.length() < COLLECT_DIST:
		_collect()


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


## Pure: is the gem within `pickup_range` of the player (XZ distance)?
## Used once to latch magnetization; afterwards distance is ignored.
static func in_pickup_range(gem_pos: Vector3, player_pos: Vector3,
		pickup_range: float) -> bool:
	var diff: Vector3 = player_pos - gem_pos
	diff.y = 0.0
	return diff.length() <= pickup_range

## Pure: the next magnet speed after `dt` — accelerates by MAGNET_ACCEL, capped at
## MAGNET_SPEED_MAX. This is what makes a latched gem move "faster and faster".
static func next_magnet_speed(current: float, dt: float) -> float:
	return min(current + MAGNET_ACCEL * dt, MAGNET_SPEED_MAX)

## Pure static magnet helper — position delta for one step at `speed` (XZ plane, y=0).
## If the step would reach or overshoot the player, returns the exact remaining diff
## so the gem lands on the player instead of tunnelling past it.
static func magnet_delta(gem_pos: Vector3, player_pos: Vector3,
		speed: float, dt: float) -> Vector3:
	var diff: Vector3 = player_pos - gem_pos
	diff.y = 0.0
	var dist: float = diff.length()
	if dist < 0.001:
		return Vector3.ZERO
	var step: float = speed * dt
	if step >= dist:
		return diff  # land exactly on the player — no overshoot
	return diff.normalized() * step
