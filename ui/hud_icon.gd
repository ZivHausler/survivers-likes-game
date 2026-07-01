# See docs/notes/hud.md
class_name HUDIcon extends Control
## Crisp in-engine icons for the command-bar HUD. Drawn via polygons/arcs; sharp at 1440p.

enum Type { CLOCK = 0, SKULL = 1, HEART = 2, CHEVRON = 3, ULTIMATE = 4 }

@export var icon_type: Type = Type.CLOCK
@export var icon_color: Color = Color(0.9, 0.95, 1.0)

func _draw() -> void:
	match icon_type:
		Type.CLOCK:    _draw_clock()
		Type.SKULL:    _draw_skull()
		Type.HEART:    _draw_heart()
		Type.CHEVRON:  _draw_chevron()
		Type.ULTIMATE: _draw_ultimate()

func _draw_clock() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.42
	draw_arc(c, r, 0.0, TAU, 32, icon_color, 2.0)
	for i in 4:
		var angle := i * TAU / 4.0 - PI / 2.0
		draw_line(c + Vector2(cos(angle), sin(angle)) * r * 0.70,
		          c + Vector2(cos(angle), sin(angle)) * r * 0.90, icon_color, 2.0)
	draw_line(c, c + Vector2(-r * 0.35, -r * 0.45), icon_color, 2.5)
	draw_line(c, c + Vector2(0.0, -r * 0.65), icon_color, 1.5)

func _draw_skull() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.38
	draw_circle(c + Vector2(0.0, -r * 0.10), r * 0.62, icon_color)
	draw_circle(c + Vector2(-r * 0.23, -r * 0.18), r * 0.16, Color.BLACK)
	draw_circle(c + Vector2( r * 0.23, -r * 0.18), r * 0.16, Color.BLACK)
	draw_line(c + Vector2(-r * 0.42, r * 0.22), c + Vector2(r * 0.42, r * 0.22), icon_color, 2.0)
	for i in 3:
		var x := c.x + (i - 1) * r * 0.30
		draw_line(Vector2(x, c.y + r * 0.22), Vector2(x, c.y + r * 0.50), icon_color, 2.0)

func _draw_heart() -> void:
	var c := size * 0.5
	var s := minf(size.x, size.y) / 32.0
	var pts := PackedVector2Array()
	for i in 40:
		var t := i / 40.0 * TAU
		var x :=  16.0 * pow(sin(t), 3)
		var y := -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(c + Vector2(x, y) * s)
	draw_polygon(pts, PackedColorArray([icon_color]))

func _draw_chevron() -> void:
	var c := size * 0.5
	var w := size.x * 0.65
	var h := size.y * 0.40
	draw_polyline(PackedVector2Array([
		c + Vector2(-w * 0.5,  h * 0.25),
		c + Vector2(0.0,      -h * 0.50),
		c + Vector2( w * 0.5,  h * 0.25),
	]), icon_color, 3.0)

func _draw_ultimate() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.40
	var pts := PackedVector2Array()
	for i in 8:
		var outer_a := i / 8.0 * TAU - PI / 2.0
		var inner_a := (i + 0.5) / 8.0 * TAU - PI / 2.0
		pts.append(c + Vector2(cos(outer_a), sin(outer_a)) * r)
		pts.append(c + Vector2(cos(inner_a), sin(inner_a)) * r * 0.45)
	draw_polygon(pts, PackedColorArray([icon_color]))
