# See docs/notes/vfx-system.md
class_name EvolutionFlash extends CanvasLayer
## Full-screen white additive flash for evolution or level-up events.
## All children are created in _ready(); auto-frees after ~0.8 s.
## Usage: instantiate evolution_flash.tscn, add_child to scene.
## Call set_intensity(0.4) for the softer level-up variant.

var _rect: ColorRect = null

func _ready() -> void:
	# Full-screen white rect with additive blend.
	_rect = ColorRect.new()
	_rect.anchor_left   = Control.ANCHOR_BEGIN
	_rect.anchor_top    = Control.ANCHOR_BEGIN
	_rect.anchor_right  = Control.ANCHOR_END
	_rect.anchor_bottom = Control.ANCHOR_END
	_rect.color = Color(1.0, 1.0, 1.0, 0.85)
	_rect.material = CanvasItemMaterial.new()
	(_rect.material as CanvasItemMaterial).blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	add_child(_rect)

	# Radial burst of particles around screen centre.
	var burst := CPUParticles2D.new()
	burst.position    = get_viewport().get_visible_rect().size * 0.5
	burst.amount      = 40
	burst.lifetime    = 0.5
	burst.one_shot    = true
	burst.explosiveness = 0.95
	burst.spread      = 180.0
	burst.initial_velocity_min = 80.0
	burst.initial_velocity_max = 200.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 5.0
	burst.color       = Color(1.0, 1.0, 1.0, 0.9)
	burst.emitting    = true
	add_child(burst)

	# Auto-free after flash window.
	var timer: SceneTreeTimer = get_tree().create_timer(0.8)
	timer.timeout.connect(queue_free)

## Scale the flash intensity. 1.0 = full evolution flash; 0.4 = softer level-up flash.
func set_intensity(v: float) -> void:
	if _rect:
		var c := _rect.color
		c.a = 0.85 * v
		_rect.color = c
