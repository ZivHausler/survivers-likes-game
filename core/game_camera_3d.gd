# See docs/notes/game-camera-3d.md
class_name GameCamera3D extends Camera3D
## Tilted top-down perspective camera for the 3D arena.
## Follows a target on XZ only; camera Y = `height` (constant) and pitch stay fixed.

@export var target: Node3D
@export var height: float = 14.0
@export var pitch_degrees: float = -55.0
## Distance pulled back along +Z from the target (so the tilt reads correctly).
@export var distance: float = 10.0
@export var follow_speed: float = 10.0

func _ready() -> void:
	basis = compute_pitch_basis(pitch_degrees)
	if target:
		global_position = compute_position(target.global_position, height, distance)

func _physics_process(delta: float) -> void:
	if not target:
		return
	var desired := compute_position(target.global_position, height, distance)
	global_position = global_position.lerp(desired, clampf(follow_speed * delta, 0.0, 1.0))
	# Keep pitch locked in case something else mutates the basis.
	basis = compute_pitch_basis(pitch_degrees)

## Return the world-space camera position given a target's position.
## X tracks target X; Y is always `height` (ignores target Y); Z = target.z + distance.
static func compute_position(target_pos: Vector3, height: float, distance: float) -> Vector3:
	return Vector3(target_pos.x, height, target_pos.z + distance)

## Return a Basis that is a pure X-axis rotation by pitch_deg degrees.
static func compute_pitch_basis(pitch_deg: float) -> Basis:
	return Basis.from_euler(Vector3(deg_to_rad(pitch_deg), 0.0, 0.0))
