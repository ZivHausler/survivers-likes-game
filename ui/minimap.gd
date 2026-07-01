class_name Minimap extends Control
## Circular radar minimap: player fixed at center, enemies plotted relative to the
## player within `world_radius`. Duck-typed on `global_position` so it no-ops safely
## in tests/previews where the player is a plain stub. Enemies come from the
## "enemies" group (see spawning/spawner_3d.gd).

var world_radius: float = 90.0  # world units mapped to the radar edge
var _player: Node = null

func set_player(p: Node) -> void:
	_player = p

func _process(_dt: float) -> void:
	queue_redraw()

func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5 - 2.0
	# Dish + rim.
	draw_circle(c, r, Color(0.04, 0.06, 0.10, 0.78))
	draw_arc(c, r, 0.0, TAU, 56, Color(0.30, 0.80, 1.0, 0.75), 2.0)
	# Cross hairs.
	draw_line(c - Vector2(r, 0), c + Vector2(r, 0), Color(0.30, 0.80, 1.0, 0.12), 1.0)
	draw_line(c - Vector2(0, r), c + Vector2(0, r), Color(0.30, 0.80, 1.0, 0.12), 1.0)
	# Player marker (always centered).
	draw_circle(c, 3.5, Color(0.45, 0.95, 1.0))
	if _player == null or not is_instance_valid(_player) or not ("global_position" in _player):
		return
	var pp = _player.global_position
	var origin := Vector2(pp.x, pp.z)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(e) or not ("global_position" in e):
			continue
		var ep = e.global_position
		var rel := (Vector2(ep.x, ep.z) - origin) / world_radius * r
		if rel.length() > r:
			rel = rel.normalized() * r
		draw_circle(c + rel, 2.0, Color(1.0, 0.32, 0.5))
