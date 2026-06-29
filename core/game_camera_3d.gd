## Orbitable follow camera for the 3D arena.
class_name GameCamera3D extends Camera3D
## The camera follows the target by smoothly tracking a `_pivot` toward the target's
## position, then sits on a sphere of `distance` (radius) around that pivot. CRUCIALLY,
## the SAME pivot drives both the camera position and look_at(), so following is pure
## translation — moving the player never tilts or swivels the view. Orientation changes
## ONLY when dragging: left-drag orbits (yaw) and tilts (pitch) around the sphere.
## Middle-click resets to the default view; the mouse wheel zooms (scales the radius).
## Supports trauma-based screen shake via add_trauma() (transient, fired on hits — not
## by movement).
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
## How fast the pivot eases toward the target each second (higher = tighter follow).
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

## Steepest allowed tilt (most top-down). Stops the camera flipping over the target.
const PITCH_MIN: float = -85.0
## Flattest allowed tilt (most side-on). Stops the view going fully horizontal.
const PITCH_MAX: float = -25.0
## View the middle-click reset returns to.
const DEFAULT_PITCH: float = -65.0
const DEFAULT_YAW: float = 0.0

var _trauma: float = 0.0
## The point the camera orbits and look_at()s. Eases toward the target each frame, so
## the camera follows by pure translation; the same pivot drives position AND look_at,
## so movement never rotates the view. The orbit angles are fixed (set via the editor
## or reset_view); the mouse cannot change them.
var _pivot: Vector3 = Vector3.ZERO
## True once the pivot has snapped to a valid target. Avoids easing in from the origin
## when target is assigned after _ready() (e.g. by GameManager3D in code).
var _snapped: bool = false

func _ready() -> void:
	if target:
		_pivot = target.global_position
		_snapped = true
		_apply_orbit()

func _physics_process(delta: float) -> void:
	if not target:
		return
	# Snap on the first valid frame (avoids easing from the origin when target is
	# assigned after _ready), then ease the pivot toward the target — pure translation.
	if not _snapped:
		_snapped = true
		_pivot = target.global_position
	_pivot = _pivot.lerp(target.global_position, clampf(follow_speed * delta, 0.0, 1.0))
	_trauma = decay_trauma(_trauma, delta)
	_apply_orbit()

## Place the camera on the orbit sphere around the current pivot and aim at it. Both the
## position and look_at use the same pivot, so following is rotation-free; shake offset
## is layered onto the position only (so a hit jolts the view without moving the pivot).
func _apply_orbit() -> void:
	global_position = compute_position(_pivot, distance * zoom, pitch_degrees, yaw_degrees) \
		+ shake_offset(_trauma, Time.get_ticks_msec() * 0.001)
	look_at(_pivot, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_MIDDLE and mb.pressed:
			reset_view()
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom = clamp_zoom(zoom - ZOOM_STEP)
		elif mb.pressed and mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom = clamp_zoom(zoom + ZOOM_STEP)

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
