extends Node3D
## Dev harness: builds the NEW tiled floor (FloorBuilder) + clustered props (GardenScatter)
## from garden_map, renders overview + gameplay-cam PNGs to res://_shots/, and quits.
## Untextured/flat-color on purpose — this previews the ZONE LAYOUT + prop placement before
## textures (Task 11) and arena integration (Task 12). Run:
##   godot47.exe res://tools/floor_preview.tscn   (windowed — needs a GPU context)

func _ready() -> void:
	var root := Node3D.new()
	root.name = "PreviewRoot"
	add_child(root)

	# Soft neutral lighting so flat-color tiles read clearly.
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.46, 0.5, 0.56)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 1, 1)
	env.ambient_light_energy = 0.6
	env.glow_enabled = true
	env.glow_intensity = 0.5
	env.glow_bloom = 0.1
	we.environment = env
	add_child(we)
	var dl := DirectionalLight3D.new()
	dl.rotation_degrees = Vector3(-55, -35, 0)
	dl.light_energy = 1.1
	add_child(dl)

	var fb = load("res://arena/floor/floor_builder.gd").new()
	fb.recipe_path = "res://arena/maps/garden_map.gd"
	root.add_child(fb)  # _ready() defers the GardenFloor build under root

	var gs = load("res://arena/floor/prop_scatter.gd").new()
	gs.recipe_path = "res://arena/maps/garden_map.gd"
	gs.clear_radius = 12.0
	root.add_child(gs)  # _ready() defers Props + nav under root

	# Let both deferred builds land.
	for i in 45:
		await get_tree().process_frame

	if not DirAccess.dir_exists_absolute("res://_shots"):
		DirAccess.make_dir_absolute("res://_shots")

	var cam := Camera3D.new()
	add_child(cam)
	var shots := [
		{ "name": "floor_overview", "pos": Vector3(0, 200, 155), "look": Vector3(0, 0, 0) },
		{ "name": "floor_gameplay", "pos": Vector3(0, 34, 44),  "look": Vector3(0, 0, 8) },
		{ "name": "floor_hub",      "pos": Vector3(0, 26, 34),  "look": Vector3(0, 0, 0) },
	]
	for s in shots:
		cam.position = s["pos"]
		cam.look_at(s["look"], Vector3.UP)
		cam.current = true
		for i in 5:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://_shots/%s.png" % s["name"])
		print("SHOT ", s["name"])
	print("FLOOR_PREVIEW_DONE")
	get_tree().quit()
