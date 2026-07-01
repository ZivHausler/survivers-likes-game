extends Node
## Map tour from the REAL gameplay POV: loads the live main_3d scene, then walks the player
## to several locations across the Garden and captures the composited frame (real GameCamera3D
## following + HUD + live enemies) at each. This shows what the player actually sees in
## DIFFERENT parts of the map — not just the spawn — so QA can judge every area, not one spot.
##   Run:  godot47.exe res://tools/map_tour_shot.tscn   (windowed — needs a GPU context)

# (name, world x, world z) — representative spots that exercise each zone + prop language.
const STOPS := [
	["spawn",      0.0,   0.0],    # plaza centre + medallion + arena-ring props
	["north_path", 0.0,   52.0],   # stone path, path lamps/bollards, hero-tree landmark
	["garden_ne",  46.0,  44.0],   # grass quadrant: flowerbed + ornamental trees + bushes
	["pond",       44.0, -44.0],   # pond shore + shore flowers
	["grass_sw",  -44.0, -40.0],   # grass + dirt path + flowerbed + mushrooms
]

func _ready() -> void:
	var main: Node = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	# Let GameManager3D.start() run and the first enemies/HUD settle.
	await get_tree().create_timer(3.0, true).timeout
	var player := main.get_node_or_null("Player") as Node3D
	if player == null:
		push_error("map_tour: no Player")
		get_tree().quit()
		return
	for s in STOPS:
		var name: String = s[0]
		player.global_position = Vector3(s[1], player.global_position.y, s[2])
		# Let the follow camera ease to the new pivot (follow_speed ~10) and enemies re-path.
		await get_tree().create_timer(1.6, true).timeout
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://_shots/tour_%s.png" % name)
		print("TOUR_SHOT ", name)
	print("MAP_TOUR_DONE")
	get_tree().quit()
