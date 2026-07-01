extends Control
## Draws two fat, wide, short "^" chevrons stacked close together — the synergy-hint mark.
## Drawn (not a text glyph) so the carets can be made wider, flatter and thicker than a font
## "^", and packed tight vertically.

@export var color: Color = Color(1.0, 0.82, 0.2, 1.0)
## Stroke thickness (how "fat" the chevrons are).
@export var thickness: float = 4.5
## Vertical rise of each chevron (small = flatter / less tall).
@export var span: float = 5.0
## Vertical distance between the two apexes (small = closer together).
@export var gap: float = 7.0

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	# Centre the whole mark's bounding box on the control's middle (so it lines up with the
	# icon beside it). Content spans from the top apex down to the bottom arms, so the apex
	# centre sits half a span above middle.
	var apex_center := size.y * 0.5 - span * 0.5
	_chevron(apex_center - gap * 0.5)
	_chevron(apex_center + gap * 0.5)

## One wide "^" with its apex at y=apex_y and arms fanning down/out to the control edges.
func _chevron(apex_y: float) -> void:
	var pad := 2.0
	var w := size.x
	var pts := PackedVector2Array([
		Vector2(pad, apex_y + span),
		Vector2(w * 0.5, apex_y),
		Vector2(w - pad, apex_y + span),
	])
	draw_polyline(pts, color, thickness, true)
