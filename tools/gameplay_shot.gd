extends Node
## Faithful gameplay screenshot: loads the REAL main_3d scene (arena + GameCamera3D + player
## + HUD + live spawner) exactly as it ships, lets it run a couple of seconds so enemies spawn
## and the HUD populates, then captures the composited viewport (3D world + HUD CanvasLayer)
## to res://_shots/gameplay_live.png and quits. This is the AUTHORITATIVE QA frame — it shows
## what the player actually sees, unlike the bare-arena tools/screenshot.tscn.
##   Run:  godot47.exe res://tools/gameplay_shot.tscn   (windowed — needs a GPU context)

func _ready() -> void:
	var main: Node = load("res://game/main_3d.tscn").instantiate()
	add_child(main)
	# Let GameManager3D.start() run, the spawner tick, enemies walk in, and the HUD populate.
	# Wait REAL time (not frame count — the windowed run renders far above realtime) so a proper
	# swarm builds; ~6s stays before auto-kills can bank enough XP to pop the level-up UI.
	await get_tree().create_timer(6.0).timeout
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://_shots/gameplay_live.png")
	print("LIVE_SHOT_DONE")
	get_tree().quit()
