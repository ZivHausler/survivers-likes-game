class_name RadialCooldown extends Control
## A circular cooldown ring: draws a filled ring arc for `fraction` (0..1)
## plus a label. Used center-bottom for the ultimate. 1.0 = full/ready.

var fraction: float = 1.0
var label: String = "ULT"
var ready_color := Color(1.0, 0.85, 0.2)
var cooling_color := Color(0.5, 0.5, 0.55)

func set_fraction(f: float) -> void:
	fraction = clampf(f, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var radius := minf(size.x, size.y) * 0.5 - 4.0
	# Background ring.
	draw_arc(c, radius, 0.0, TAU, 48, Color(0,0,0,0.5), 6.0, true)
	# Filled portion (clockwise from top).
	var col := ready_color if fraction >= 1.0 else cooling_color
	var end := -PI/2 + TAU * fraction
	draw_arc(c, radius, -PI/2, end, 48, col, 6.0, true)
	# Center fill when ready.
	if fraction >= 1.0:
		draw_circle(c, radius - 6.0, Color(ready_color.r, ready_color.g, ready_color.b, 0.25))
