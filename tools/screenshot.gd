extends Node3D
## Headless-ish screenshot harness: loads the arena, renders it from several camera
## angles, and writes PNGs to res://_shots/ for visual review. Run with:
##   godot47.exe res://tools/screenshot.tscn
## (windowed — needs a GPU context). Quits when done.

const SHOTS := [
	{ "name": "overview",  "pos": Vector3(0, 175, 150),  "look": Vector3(0, 0, 10) },
	{ "name": "plaza",     "pos": Vector3(0, 55, 70),    "look": Vector3(0, 0, 16) },
	# Gameplay framing: MOBA cam pitch ~-65 deg, player near origin.
	{ "name": "gameplay",  "pos": Vector3(0, 30, 14),    "look": Vector3(0, 0, 0) },
	{ "name": "garden_nw", "pos": Vector3(-40, 40, -20), "look": Vector3(-40, 0, 40) },
]

func _ready() -> void:
	var arena: Node3D = load("res://arena/arena_3d.tscn").instantiate()
	add_child(arena)
	if not DirAccess.dir_exists_absolute("res://_shots"):
		DirAccess.make_dir_absolute("res://_shots")
	var cam := Camera3D.new()
	add_child(cam)
	# Let the deferred scatter (_ready call_deferred) build obstacles + nav.
	for i in 30:
		await get_tree().process_frame
	for s in SHOTS:
		cam.position = s["pos"]
		cam.look_at(s["look"], Vector3.UP)
		cam.current = true
		for i in 5:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		img.save_png("res://_shots/%s.png" % s["name"])
		print("SHOT ", s["name"])
	print("SCREENSHOTS_DONE")
	get_tree().quit()
