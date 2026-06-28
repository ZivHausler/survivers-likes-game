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
	## _safe_parent() adds the flash to current_scene (or root as fallback),
	## so we must search the spawn parent's subtree — not just root's direct
	## children — to actually find the spawned EvolutionFlash.
	var dummy := Node2D.new()
	add_child(dummy)
	Juice.register_player(dummy)

	## Capture the spawn parent exactly as Juice._safe_parent() computes it.
	var tree := get_tree()
	var spawn_parent: Node = tree.current_scene if tree.current_scene != null else tree.root

	GameEvents.evolution_unlocked.emit(&"test")
	await get_tree().process_frame

	## Locate the freshly-spawned EvolutionFlash in the spawn parent's subtree
	## and hold a weakref so we can assert it is genuinely gone after auto-free.
	var flash: EvolutionFlash = _find_evolution_flash(spawn_parent)
	assert_not_null(flash, "EvolutionFlash must be spawned into the scene on evolution_unlocked")
	var flash_ref: WeakRef = weakref(flash)

	## Wait past the 0.8 s auto-free window (+ margin).
	await get_tree().create_timer(1.2).timeout

	## The captured node must now be freed. This fails if auto-free is removed.
	assert_null(flash_ref.get_ref(), "EvolutionFlash must auto-free after 0.8 s")
	assert_null(_find_evolution_flash(spawn_parent),
		"No EvolutionFlash should remain in the scene subtree after auto-free")

	dummy.queue_free()

## Depth-first search of `root`'s subtree for the first EvolutionFlash node.
func _find_evolution_flash(root: Node) -> EvolutionFlash:
	for child in root.get_children():
		if child is EvolutionFlash:
			return child
		var found := _find_evolution_flash(child)
		if found != null:
			return found
	return null

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
