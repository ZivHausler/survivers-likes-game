extends Node
## HUD preview harness: instantiates the real HUD with stub player/game-manager data
## over an arena backdrop, renders it to res://_shots/hud.png, and quits. Lets me
## iterate on HUD layout/style visually. Run:  godot47.exe res://tools/hud_preview.tscn

class StubWeapon extends RefCounted:
	var frac: float
	func _init(f: float) -> void:
		frac = f
	func cooldown_fraction() -> float:
		return frac

class StubPlayer extends Node:
	var xp: float = 65.0
	var level: int = 5
	var weapons: Dictionary = {}
	var ultimate = null
	var passives: Dictionary = {}
	func xp_to_next(_lvl: int) -> float:
		return 100.0

class StubGM extends Node:
	func get_elapsed() -> float:
		return 92.0
	func get_kills() -> int:
		return 137

func _ready() -> void:
	# Backdrop: dark fill + an arena screenshot if one exists (judge contrast over gameplay).
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.14, 0.12)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var arena_img := Image.load_from_file("res://_shots/plaza.png")
	if arena_img != null:
		var tr := TextureRect.new()
		tr.texture = ImageTexture.create_from_image(arena_img)
		tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(tr)

	var gm := StubGM.new()
	gm.name = "GameManager3D"
	add_child(gm)

	var player := StubPlayer.new()
	player.name = "Player"
	player.add_to_group("player")
	player.weapons = {
		&"pistol": StubWeapon.new(1.0),
		&"laser_beam": StubWeapon.new(0.45),
		&"orbit_blade": StubWeapon.new(0.8),
		&"frost_nova": StubWeapon.new(0.15),
	}
	player.ultimate = StubWeapon.new(1.0)
	player.passives = {&"haste": 2, &"armor": 1, &"magnet": 3, &"regen": 1}
	add_child(player)

	var hud: CanvasLayer = load("res://ui/hud.tscn").instantiate()
	add_child(hud)

	for i in 8:
		await get_tree().process_frame
	GameEvents.player_hp_changed.emit(72.0, 100.0)
	GameEvents.player_leveled_up.emit(5)
	# Show a boss bar too so it's captured.
	GameEvents.boss_spawned.emit("THE ARCHITECT", 5000.0)
	GameEvents.boss_hp_changed.emit(3600.0, 5000.0)

	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://_shots/hud.png")
	print("HUD_SHOT_DONE")
	get_tree().quit()
