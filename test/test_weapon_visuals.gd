extends GutTest
## TDD guard: every attack scene must contain at least one CanvasItem that
## actually paints (Polygon2D, ColorRect, Sprite2D, Line2D, …).
## CollisionShape2D is an invisible debug shape — it does NOT count.
##
## RED phase: fails before visuals are added to bubble.tscn / ziv_stunning_looks.tscn
## GREEN phase: passes after the placeholder visual nodes are added.

const DRAWABLE_TYPES := ["Polygon2D", "ColorRect", "Sprite2D", "Line2D", "MeshInstance2D"]

## Return all descendants of `root` that are CanvasItem subclasses AND whose
## class name is in DRAWABLE_TYPES (i.e. they actually paint something).
func _visible_draw_nodes(root: Node) -> Array:
	var results: Array = []
	for node in _all_descendants(root):
		if node.get_class() in DRAWABLE_TYPES:
			results.append(node)
	return results

func _all_descendants(node: Node) -> Array:
	var out: Array = []
	for child in node.get_children():
		out.append(child)
		out.append_array(_all_descendants(child))
	return out

# ── Bubble ────────────────────────────────────────────────────────────────────

func test_bubble_has_visible_draw_node() -> void:
	var bubble: Node = autofree(load("res://weapons/bubble.tscn").instantiate())
	var draw_nodes := _visible_draw_nodes(bubble)
	assert_gt(draw_nodes.size(), 0,
		"bubble.tscn must contain at least one drawable node (Polygon2D/ColorRect/…) — found none. " +
		"Add a visual so the bubble is visible at runtime.")

# ── Ziv — Beam ───────────────────────────────────────────────────────────────

func test_ziv_beam_has_visible_draw_node() -> void:
	var weapon: Node2D = autofree(load("res://weapons/ziv_stunning_looks.tscn").instantiate())
	var beam: Node = weapon.get_node("Beam")
	var draw_nodes := _visible_draw_nodes(beam)
	assert_gt(draw_nodes.size(), 0,
		"Beam area in ziv_stunning_looks.tscn must have a drawable child " +
		"(Polygon2D/ColorRect sized ~400×16). Found none.")

## The beam ColorRect must be sized to match the hitbox dimensions (400 × 16).
func test_ziv_beam_visual_matches_hitbox_size() -> void:
	var weapon: Node2D = autofree(load("res://weapons/ziv_stunning_looks.tscn").instantiate())
	var beam: Node = weapon.get_node("Beam")
	var draw_nodes := _visible_draw_nodes(beam)
	if draw_nodes.is_empty():
		fail_test("No drawable node found in Beam — cannot check size")
		return
	# First drawable is the beam visual; it should cover roughly 400 × 16.
	var vis: Node = draw_nodes[0]
	if vis is ColorRect:
		var cr := vis as ColorRect
		assert_almost_eq(cr.size.x, 400.0, 1.0,
			"Beam ColorRect width should be ~400 px to match RectangleShape2D")
		assert_almost_eq(cr.size.y, 16.0, 1.0,
			"Beam ColorRect height should be ~16 px to match RectangleShape2D")

# ── Ziv — CharmField ─────────────────────────────────────────────────────────

func test_ziv_charm_field_has_visible_draw_node() -> void:
	var weapon: Node2D = autofree(load("res://weapons/ziv_stunning_looks.tscn").instantiate())
	var charm: Node = weapon.get_node("CharmField")
	var draw_nodes := _visible_draw_nodes(charm)
	assert_gt(draw_nodes.size(), 0,
		"CharmField area in ziv_stunning_looks.tscn must have a drawable child " +
		"(Polygon2D circle / ColorRect) so the charm aura is visible. Found none.")
