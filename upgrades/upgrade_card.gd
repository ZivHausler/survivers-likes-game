class_name UpgradeCard extends Control
## A single level-up choice rendered as a premium "tech playing card": a chamfered
## rounded-rectangle with ONE fat smooth neon border + soft glow and a header divider, over a
## rarity-tinted dark body. Content (level badge / icon / name / desc / stat) lives in a child
## VBox anchored inside the frame; a synergy tab may overhang the bottom edge. This node draws
## the frame BEHIND its children.
##
## The whole card is a single-hue unit: `accent` drives frame, glow and divider. `featured`
## cards (evolution / synergy) render a stronger glow (same size — cards only enlarge on
## hover). Purely visual — all picking logic stays in UpgradeUI.

## Corner chamfer size in px (the diagonal cut that gives the hex-tech silhouette).
const CHAMFER := 15.0

var accent: Color = Color(0.20, 0.95, 0.75, 1.0)
var featured: bool = false
var hovered: bool = false

func _ready() -> void:
	resized.connect(queue_redraw)

## Set the card's rarity hue and whether it is a featured (evolution/synergy) card.
func configure(a: Color, feat: bool) -> void:
	accent = a
	featured = feat
	queue_redraw()

## Toggle hover state (brighter frame + fuller glow).
func set_hovered(h: bool) -> void:
	hovered = h
	queue_redraw()

func _draw() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var c := CHAMFER
	# Chamfered rounded-rect as an octagon (four 45° corner cuts).
	var poly := PackedVector2Array([
		Vector2(c, 0), Vector2(w - c, 0),
		Vector2(w, c), Vector2(w, h - c),
		Vector2(w - c, h), Vector2(c, h),
		Vector2(0, h - c), Vector2(0, c),
	])
	# Body: vertical gradient (lighter top → darker bottom), rarity-tinted near-black.
	var top_col := Color(accent.r * 0.17, accent.g * 0.17, accent.b * 0.22, 0.97)
	var bot_col := Color(accent.r * 0.06, accent.g * 0.06, accent.b * 0.10, 0.99)
	var cols := PackedColorArray()
	for p in poly:
		cols.append(top_col.lerp(bot_col, clampf(p.y / h, 0.0, 1.0)))
	draw_polygon(poly, cols)

	var closed := poly.duplicate()
	closed.append(poly[0])

	# Soft single glow halo — two wide, low-alpha antialiased passes read as one blur,
	# not concentric rings.
	var glow_a := 0.22 if (featured or hovered) else 0.14
	draw_polyline(closed, Color(accent.r, accent.g, accent.b, glow_a * 0.5), 18.0, true)
	draw_polyline(closed, Color(accent.r, accent.g, accent.b, glow_a), 10.0, true)

	# ONE fat, smooth border line in the rarity hue (no inner stroke — keep it clean).
	var bw := 5.0 if (hovered or featured) else 4.0
	var border_col := accent.lightened(0.15) if hovered else accent
	draw_polyline(closed, border_col, bw, true)

	# Faint header divider under the level badge (single subtle line).
	var hy := 46.0
	draw_line(Vector2(28, hy), Vector2(w - 28, hy), Color(accent.r, accent.g, accent.b, 0.25), 1.0)

