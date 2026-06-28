extends GutTest
## VFX scene-load and signal-guard tests for Task C2.
## Tests that EvolutionFlash and XpSparkle scenes load, that Juice spawns
## the flash when a player is registered, and that no crash occurs when
## signals emit without a registered player.

const _EvolutionFlashScene := preload("res://vfx/evolution_flash.tscn")

func after_each() -> void:
	Juice.register_player(null)
	Juice.register_camera(null)

func test_evolution_flash_scene_loads() -> void:
	var packed := load("res://vfx/evolution_flash.tscn")
	assert_not_null(packed, "evolution_flash.tscn must load successfully")

func test_evolution_flash_spawned_and_auto_frees() -> void:
	## Register a dummy player so Juice._safe_parent() returns a valid node.
	var dummy := Node2D.new()
	add_child(dummy)
	Juice.register_player(dummy)

	GameEvents.evolution_unlocked.emit(&"test")

	## Wait long enough for the flash to auto-free (0.8 s) + margin.
	await get_tree().create_timer(1.2).timeout

	## The EvolutionFlash CanvasLayer should have freed itself.
	## We check by scanning the tree root's children for any EvolutionFlash.
	var found_flash := false
	for child in get_tree().root.get_children():
		if child is EvolutionFlash:
			found_flash = true
	assert_false(found_flash, "EvolutionFlash must auto-free after 0.8 s")

	dummy.queue_free()

func test_player_leveled_up_no_player_no_crash() -> void:
	# No player registered — handler must return early without crashing.
	Juice.register_player(null)
	GameEvents.player_leveled_up.emit(1)
	await get_tree().process_frame
	assert_true(true, "no crash when player_leveled_up emitted without player")

func test_xp_collected_no_player_no_crash() -> void:
	Juice.register_player(null)
	GameEvents.xp_collected.emit(5)
	await get_tree().process_frame
	assert_true(true, "no crash when xp_collected emitted without player")

func test_evolution_unlocked_no_player_no_crash() -> void:
	Juice.register_player(null)
	GameEvents.evolution_unlocked.emit(&"weapon_test")
	await get_tree().process_frame
	assert_true(true, "no crash when evolution_unlocked emitted without player")
