## Orbitable follow camera for the 3D arena.
class_name GameCamera3D extends Camera3D
## The camera sits on a sphere of `distance` (radius) around `target`. Left-drag orbits
## (yaw) and tilts (pitch) by moving the camera around that sphere; the camera always
## look_at()s the target, so the target stays perfectly centered from any angle.
## Middle-click resets to the default view; the mouse wheel zooms (scales the radius).
## Supports trauma-based screen shake via add_trauma().
##
## The math helpers (compute_position / clamp_pitch / clamp_zoom / shake_offset /
## decay_trauma) are pure & static, so they are unit-testable without a live camera.
## Orientation is delegated to Node3D.look_at (engine primitive), which guarantees the
## target is centered given a correct position.

@export var target: Node3D
## Downward tilt in degrees (negative looks down). Drag-mutable, clamped to
## [PITCH_MIN, PITCH_MAX]. Determines the camera's elevation on the orbit sphere.
@export var pitch_degrees: float = -65.0
## Orbit angle around the target's Y axis, in degrees. Drag-mutable, wraps freely.
@export var yaw_degrees: float = 0.0
## Orbit radius: straight-line distance from the target to the camera. At pitch -65°
## this gives ≈ height 14 / pull-back 6.5 — the approved framing.
@export var distance: float = 15.4
@export var follow_speed: float = 10.0
## Current zoom multiplier applied to the orbit radius; 1.0 = default.
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

## Degrees of yaw/pitch change per pixel of left-drag.
const DRAG_SENSITIVITY: float = 0.3
## Steepest allowed tilt (most top-down). Stops the camera flipping over the target.
const PITCH_MIN: float = -85.0
## Flattest allowed tilt (most side-on). Stops the view going fully horizontal.
const PITCH_MAX: float = -25.0
## View the middle-click reset returns to.
const DEFAULT_PITCH: float = -65.0
const DEFAULT_YAW: float = 0.0

var _trauma: float = 0.0
## Tracks the smooth-follow base position separately so shake offset is layered on top
## without feeding back into the lerp next frame.
var _base_position: Vector3 = Vector3.ZERO
## True once we've snapped to the target at least once; prevents lerping from origin
## when target is assigned after _ready() (e.g. assigned by GameManager3D in code).
var _snapped: bool = false
## True while the left mouse button is held (orbit/tilt drag in progress).
var _dragging: bool = false

func _ready() -> void:
	if target:
		_base_position = compute_position(target.global_position, distance * zoom, pitch_degrees, yaw_degrees)
		global_position = _base_position
		_snapped = true
		look_at(target.global_position, Vector3.UP)

func _physics_process(delta: float) -> void:
	if not target:
		return
	var desired := compute_position(target.global_position, distance * zoom, pitch_degrees, yaw_degrees)
	# Snap on the first frame the target is valid (avoids lerping from origin when
	# target is assigned after _ready, e.g. by GameManager3D).
	if not _snapped:
		_snapped = true
		_base_position = desired
	_base_position = _base_position.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))
	# Decay trauma and apply shake offset layered on top of the base follow position.
	_trauma = decay_trauma(_trauma, delta)
	global_position = _base_position + shake_offset(_trauma, Time.get_ticks_msec() * 0.001)
	# Always aim at the target so it stays centered, regardless of follow lag / orbit.
	look_at(target.global_position, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_LEFT:
			_dragging = mb.pressed
		elif mb.button_index == MOUSE_BUTTON_MIDDLE and mb.pressed:
			reset_view()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clamp_zoom(zoom - ZOOM_STEP)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clamp_zoom(zoom + ZOOM_STEP)
	elif event is InputEventMouseMotion and _dragging:
		var mm := event as InputEventMouseMotion
		# Horizontal drag orbits (yaw); vertical drag tilts (pitch), clamped.
		yaw_degrees = wrapf(yaw_degrees + mm.relative.x * DRAG_SENSITIVITY, -180.0, 180.0)
		pitch_degrees = clamp_pitch(pitch_degrees + mm.relative.y * DRAG_SENSITIVITY)

## Snap the view back to the default tilt and facing.
func reset_view() -> void:
	pitch_degrees = DEFAULT_PITCH
	yaw_degrees = DEFAULT_YAW

## Current orbit angle in radians (for camera-relative movement consumers).
func yaw_radians() -> float:
	return deg_to_rad(yaw_degrees)

## Add shake energy (accumulates, clamped to [0, 1]).
func add_trauma(amount: float) -> void:
	_trauma = clampf(_trauma + amount, 0.0, 1.0)

## Pure static helper — reduce trauma toward 0 at SHAKE_DECAY rate; clamp at 0.
static func decay_trauma(trauma: float, dt: float) -> float:
	return maxf(0.0, trauma - SHAKE_DECAY * dt)

## Pure static helper — world-space shake offset for a given trauma and time seed.
## Returns Vector3.ZERO when trauma <= 0 (so trauma=0 → no movement).
static func shake_offset(trauma: float, seed_t: float) -> Vector3:
	if trauma <= 0.0:
		return Vector3.ZERO
	var mag: float = trauma * trauma * SHAKE_MAX_OFFSET
	var angle_h: float = fmod(seed_t * 37.0 + trauma * 13.0, TAU)
	var angle_v: float = fmod(seed_t * 23.0 + trauma * 7.0, TAU)
	return Vector3(cos(angle_h) * mag, sin(angle_v) * mag * 0.3, sin(angle_h) * mag * 0.5)

## Pure static helper — the camera's world position on the orbit sphere.
## `radius` is the straight-line distance from the target; `pitch_deg` (negative = down)
## sets the elevation; `yaw_deg` sets the azimuth. The result is always exactly `radius`
## from `target_pos`, sitting above it, so look_at(target) keeps the target centered.
static func compute_position(target_pos: Vector3, radius: float, pitch_deg: float, yaw_deg: float) -> Vector3:
	var elevation := deg_to_rad(-pitch_deg)  # angle above the horizontal plane
	var yaw := deg_to_rad(yaw_deg)
	var horizontal := radius * cos(elevation)
	return target_pos + Vector3(
		horizontal * sin(yaw),
		radius * sin(elevation),
		horizontal * cos(yaw))

## Pure static helper — clamp a pitch value to [PITCH_MIN, PITCH_MAX].
static func clamp_pitch(deg: float) -> float:
	return clampf(deg, PITCH_MIN, PITCH_MAX)

## Pure static helper — clamp a zoom value to [ZOOM_MIN, ZOOM_MAX].
static func clamp_zoom(z: float) -> float:
	return clampf(z, ZOOM_MIN, ZOOM_MAX)
