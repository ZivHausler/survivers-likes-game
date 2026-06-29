## Tilted top-down perspective camera for the 3D arena with mouse-wheel zoom.
class_name GameCamera3D extends Camera3D
## Follows a target on XZ only; camera Y = `height` (constant) and pitch stay fixed.
## Supports trauma-based screen shake via add_trauma(). Pure static shake helpers are
## unit-testable: shake_offset(0, t) always returns Vector3.ZERO.
## Mouse wheel zooms the camera in/out by scaling height and distance.

@export var target: Node3D
@export var height: float = 14.0
@export var pitch_degrees: float = -65.0
## Distance pulled back along +Z from the target (so the tilt reads correctly).
## Kept in sync with the pitch+height so the camera aims at the target:
## atan(height/distance) = atan(14/6.5) ≈ 65°.
@export var distance: float = 6.5
@export var follow_speed: float = 10.0
## Current zoom multiplier applied to height and distance; 1.0 = default.
@export var zoom: float = 1.0

## Peak world-unit offset magnitude at trauma = 1.0.
const SHAKE_MAX_OFFSET: float = 0.5
## Trauma units shed per second.
const SHAKE_DECAY: float = 1.5
## Minimum zoom multiplier (zoomed all the way in).
const ZOOM_MIN: float = 0.45
## Maximum zoom multiplier (zoomed all the way out).
const ZOOM_MAX: float = 2.2
## Zoom change per mouse-wheel notch.
const ZOOM_STEP: float = 0.12

var _trauma: float = 0.0
## Tracks the smooth-follow base position separately so shake offset is layered on top
## without feeding back into the lerp next frame.
var _base_position: Vector3 = Vector3.ZERO
## True once we've snapped to the target at least once; prevents lerping from origin
## when target is assigned after _ready() (e.g. assigned by GameManager3D in code).
var _snapped: bool = false

func _ready() -> void:
	basis = compute_pitch_basis(pitch_degrees)
	if target:
		_base_position = compute_position(target.global_position, height * zoom, distance * zoom)
		global_position = _base_position
		_snapped = true

func _physics_process(delta: float) -> void:
	if not target:
		return
	var desired := compute_position(target.global_position, height * zoom, distance * zoom)
	# Snap on the first frame the target is valid (avoids lerping from origin when
	# target is assigned after _ready, e.g. by GameManager3D).
	if not _snapped:
		_snapped = true
		_base_position = desired
	_base_position = _base_position.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))
	# Decay trauma and apply shake offset layered on top of the base follow position.
	_trauma = decay_trauma(_trauma, delta)
	global_position = _base_position + shake_offset(_trauma, Time.get_ticks_msec() * 0.001)
	# Keep pitch locked in case something else mutates the basis.
	basis = compute_pitch_basis(pitch_degrees)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				zoom = clamp_zoom(zoom - ZOOM_STEP)
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				zoom = clamp_zoom(zoom + ZOOM_STEP)

## Add shake energy (accumulates, clamped to [0, 1]).
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

## Pure static helper — reduce trauma toward 0 at SHAKE_DECAY rate; clamp at 0.
## Unit-testable without a live camera.
static func decay_trauma(trauma: float, dt: float) -> float:
	return maxf(0.0, trauma - SHAKE_DECAY * dt)

## Pure static helper — compute a world-space shake offset for a given trauma and time seed.
## Returns Vector3.ZERO when trauma <= 0 (so trauma=0 → no movement, existing tests stay green).
## Magnitude scales as trauma^2 * SHAKE_MAX_OFFSET; direction varies with `seed_t`.
static func shake_offset(trauma: float, seed_t: float) -> Vector3:
	if trauma <= 0.0:
		return Vector3.ZERO
	var mag: float = trauma * trauma * SHAKE_MAX_OFFSET
	var angle_h: float = fmod(seed_t * 37.0 + trauma * 13.0, TAU)
	var angle_v: float = fmod(seed_t * 23.0 + trauma * 7.0, TAU)
	return Vector3(cos(angle_h) * mag, sin(angle_v) * mag * 0.3, sin(angle_h) * mag * 0.5)

## Return the world-space camera position given a target's position.
## X tracks target X; Y is always `height` (ignores target Y); Z = target.z + distance.
static func compute_position(target_pos: Vector3, height: float, distance: float) -> Vector3:
	return Vector3(target_pos.x, height, target_pos.z + distance)

## Return a Basis that is a pure X-axis rotation by pitch_deg degrees.
static func compute_pitch_basis(pitch_deg: float) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(pitch_deg), 0.0, 0.0))

## Pure static helper — clamp a zoom value to [ZOOM_MIN, ZOOM_MAX].
static func clamp_zoom(z: float) -> float:
	return clampf(z, ZOOM_MIN, ZOOM_MAX)
