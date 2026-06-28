extends GutTest
## Decoupling tests for the Juice autoload skeleton.
## Verifies that emitting every GameEvents signal when Juice is present:
##   (a) does not raise an error or uncaught exception, and
##   (b) does not spawn any nodes into the test tree (handlers are empty stubs).

func test_juice_autoload_exists() -> void:
	assert_not_null(Juice, "Juice autoload must be registered")

func test_juice_is_node() -> void:
	assert_true(Juice is Node, "Juice must extend Node")

func _count_children_before_and_after(callable: Callable) -> void:
	var root: Node = get_tree().root
	var before: int = root.get_child_count()
	callable.call()
	await get_tree().process_frame
	var after: int = root.get_child_count()
	assert_eq(after, before, "Juice handler must not spawn nodes into the tree")

func test_enemy_killed_no_error_no_spawn() -> void:
	await _count_children_before_and_after(func() -> void:
		GameEvents.enemy_killed.emit(Vector2.ZERO, 1)
	)

func test_xp_collected_no_error_no_spawn() -> void:
	await _count_children_before_and_after(func() -> void:
		GameEvents.xp_collected.emit(5)
	)

func test_player_leveled_up_no_error_no_spawn() -> void:
	await _count_children_before_and_after(func() -> void:
		GameEvents.player_leveled_up.emit(2)
	)

func test_player_hp_changed_no_error_no_spawn() -> void:
	await _count_children_before_and_after(func() -> void:
		GameEvents.player_hp_changed.emit(80.0, 100.0)
	)

func test_player_died_no_error_no_spawn() -> void:
	await _count_children_before_and_after(func() -> void:
		GameEvents.player_died.emit()
	)

func test_evolution_unlocked_no_error_no_spawn() -> void:
	await _count_children_before_and_after(func() -> void:
		GameEvents.evolution_unlocked.emit(&"weapon_test")
	)
