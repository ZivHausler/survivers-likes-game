class_name HealthBar3D extends Node3D
## A world-space health bar that floats above a mini-boss and faces the active
## camera. Built entirely in code (no .tscn). The fill quad is anchored at the bar's
## LEFT edge via a pivot node, so set_ratio() shrinks it from the right. Visual only —
## never touches collision, navigation, or contact damage.

const WIDTH := 1.0      ## Bar width in world units (at unit scale; see _process facing).
const HEIGHT := 0.16    ## Bar height in world units.
const FILL_EPSILON := 0.002  ## Fill quad sits slightly in front of the background quad.

const COLOR_BG := Color(0.07, 0.05, 0.05, 1.0)
const COLOR_FILL := Color(0.9, 0.12, 0.1, 1.0)

var _bg: MeshInstance3D = null
var _fill_pivot: Node3D = null
var _fill: MeshInstance3D = null

func _ready() -> void:
	_bg = _make_quad(WIDTH, HEIGHT, COLOR_BG, 0.0)
	add_child(_bg)
	# Pivot anchored at the bar's left edge; the fill quad is offset +WIDTH/2 so its
	# left edge coincides with the pivot. Scaling the pivot's x grows/shrinks the fill
	# from the left.
	_fill_pivot = Node3D.new()
	_fill_pivot.position = Vector3(-WIDTH * 0.5, 0.0, FILL_EPSILON)
	add_child(_fill_pivot)
	_fill = _make_quad(WIDTH, HEIGHT, COLOR_FILL, 0.0)
	_fill.position = Vector3(WIDTH * 0.5, 0.0, 0.0)
	_fill_pivot.add_child(_fill)
	set_ratio(1.0)

## Build an unshaded, double-sided, depth-test-disabled quad of the given size/color.
func _make_quad(w: float, h: float, color: Color, z: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var quad := QuadMesh.new()
	quad.size = Vector2(w, h)
	mi.mesh = quad
	mi.position = Vector3(0.0, 0.0, z)
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.no_depth_test = true
	mat.albedo_color = color
	mi.material_override = mat
	return mi

## Set the fill fraction in [0, 1]; clamps out-of-range input.
func set_ratio(r: float) -> void:
	if _fill_pivot == null:
		return
	var s := compute_fill_scale(r)
	_fill_pivot.scale.x = s

## Pure helper: clamp a ratio into [0, 1]. Unit-testable without a scene tree.
static func compute_fill_scale(ratio: float) -> float:
	return clampf(ratio, 0.0, 1.0)

## Billboard: orient the bar to the active camera each frame so it reads as a flat
## rectangle from the angled follow-cam. Uses the camera basis (unit scale) so the bar
## renders at a consistent on-screen size regardless of the boss's body scale. No-ops
## headlessly when there is no active camera.
func _process(_dt: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	global_transform = Transform3D(cam.global_transform.basis, global_position)
