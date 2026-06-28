# See docs/notes/vfx-system.md
class_name ScreenShake extends Node
## Trauma-based camera shake. Add as a child of Camera2D.
## Call add_trauma(amount) to trigger shake; trauma decays automatically.

const MAX_OFFSET: float = 8.0  ## Peak pixel offset at trauma = 1.0
const DECAY: float = 2.5       ## Trauma units shed per second

var trauma: float = 0.0

## Add shake energy. Multiple calls accumulate; clamped to [0, 1].
func add_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _process(dt: float) -> void:
	if trauma <= 0.0:
		return
	# Decay always; camera offset is a bonus if the camera is available
	trauma = max(0.0, trauma - DECAY * dt)
	var cam := get_parent() as Camera2D
	if not is_instance_valid(cam):
		return
	if trauma > 0.0:
		cam.offset = _offset_for(trauma, Time.get_ticks_msec() * 0.001)
	else:
		cam.offset = Vector2.ZERO

## Pure helper — testable without a live Camera2D.
## Magnitude = trauma^2 * MAX_OFFSET; direction varies with time seed.
static func _offset_for(p_trauma: float, t: float) -> Vector2:
	if p_trauma <= 0.0:
		return Vector2.ZERO
	var mag: float = p_trauma * p_trauma * MAX_OFFSET
	var angle: float = fmod(t * 37.0 + p_trauma * 13.0, TAU)
	return Vector2(cos(angle), sin(angle)) * mag
