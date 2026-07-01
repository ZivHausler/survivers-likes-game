# See docs/notes/juice-3d.md
extends GutTest
## Decoupling tests for the Juice3D autoload.
## Verifies that:
##   (a) Juice3D connects all six GameEvents signals in _ready(),
##   (b) effect spawning is guarded when no player is registered (no crash, no spawn),
##   (c) with a player registered, enemy_killed_3d spawns a DeathPop3D + DamageNumber3D,
##   (d) player_hp_changed with a decrease runs the flash+trauma path without crashing.

## Duck-typed camera stub that records add_trauma() calls.
class StubCamera extends Node3D:
	var trauma_calls: Array = []
	func add_trauma(amount: float) -> void:
		trauma_calls.append(amount)

func after_each() -> void:
	# Reset Juice3D singleton state to avoid cross-test contamination.
	Juice3D.register_player(null)
	Juice3D.register_camera(null)
	Juice3D._last_hp = -1.0

# ── Autoload basics ───────────────────────────────────────────────────────────

func test_juice_3d_autoload_exists() -> void:
	assert_not_null(Juice3D, "Juice3D autoload must be registered")

func test_juice_3d_is_node() -> void:
	assert_true(Juice3D is Node, "Juice3D must extend Node")

# ── Signal connections ────────────────────────────────────────────────────────

func test_enemy_killed_3d_signal_is_connected() -> void:
	assert_true(
		GameEvents.enemy_killed_3d.is_connected(Juice3D._on_enemy_killed_3d),
		"Juice3D must connect enemy_killed_3d in _ready()"
	)

func test_xp_collected_signal_is_connected() -> void:
	assert_true(
		GameEvents.xp_collected.is_connected(Juice3D._on_xp_collected),
		"Juice3D must connect xp_collected in _ready()"
	)

func test_player_leveled_up_signal_is_connected() -> void:
	assert_true(
		GameEvents.player_leveled_up.is_connected(Juice3D._on_player_leveled_up),
		"Juice3D must connect player_leveled_up in _ready()"
	)

func test_player_hp_changed_signal_is_connected() -> void:
	assert_true(
		GameEvents.player_hp_changed.is_connected(Juice3D._on_player_hp_changed),
		"Juice3D must connect player_hp_changed in _ready()"
	)

func test_player_died_signal_is_connected() -> void:
	assert_true(
		GameEvents.player_died.is_connected(Juice3D._on_player_died),
		"Juice3D must connect player_died in _ready()"
	)

func test_evolution_unlocked_signal_is_connected() -> void:
	assert_true(
		GameEvents.evolution_unlocked.is_connected(Juice3D._on_evolution_unlocked),
		"Juice3D must connect evolution_unlocked in _ready()"
	)

# ── Guards: no player registered → no crash, no spawn ────────────────────────

func _count_children_before_and_after(callable: Callable) -> void:
	# Track newly-ADDED children by instance id rather than a raw count. Other tests'
	# queue_free'd nodes may be reaped during the awaited frame (a removal, not a spawn),
	# which would flake a before/after count comparison. We only care that this handler
	# adds nothing to root when there is no registered player.
	var root: Node = get_tree().root
	var before_ids := {}
	for c in root.get_children():
		before_ids[c.get_instance_id()] = true
	callable.call()
	await get_tree().process_frame
	var added := 0
	for c in root.get_children():
		if not before_ids.has(c.get_instance_id()):
			added += 1
	assert_eq(added, 0, "Juice3D handler must not spawn nodes into root when no player")

func test_enemy_killed_3d_no_player_no_crash_no_spawn() -> void:
	await _count_children_before_and_after(func() -> void:
		GameEvents.enemy_killed_3d.emit(Vector3.ZERO, 5)
	)

func test_xp_collected_no_player_no_crash_no_spawn() -> void:
	await _count_children_before_and_after(func() -> void:
		GameEvents.xp_collected.emit(5)
	)

func test_player_leveled_up_no_player_no_crash_no_spawn() -> void:
	await _count_children_before_and_after(func() -> void:
		GameEvents.player_leveled_up.emit(2)
	)

func test_player_hp_changed_no_player_no_crash() -> void:
	# Decrease path with no player — must not crash.
	Juice3D._last_hp = 100.0
	GameEvents.player_hp_changed.emit(50.0, 100.0)
	await get_tree().process_frame
	assert_true(true, "hp_changed decrease must not crash without player")

func test_player_died_no_player_no_crash() -> void:
	GameEvents.player_died.emit()
	await get_tree().process_frame
	assert_true(true, "player_died must not crash without player")

func test_evolution_unlocked_no_player_no_crash_no_spawn() -> void:
	await _count_children_before_and_after(func() -> void:
		GameEvents.evolution_unlocked.emit(&"weapon_test")
	)

# ── Effect spawning with player registered ────────────────────────────────────

func _effect_parent() -> Node:
	var cs := get_tree().current_scene
	return cs if cs != null else get_tree().root

func test_enemy_killed_3d_with_player_spawns_death_pop() -> void:
	var dummy: Node3D = add_child_autofree(Node3D.new())
	Juice3D.register_player(dummy)
	var parent: Node = _effect_parent()
	var before: int = parent.get_children().filter(func(c: Node) -> bool:
		return c is DeathPop3D).size()
	GameEvents.enemy_killed_3d.emit(Vector3(1.0, 0.0, 1.0), 3)
	await get_tree().process_frame
	var after: int = parent.get_children().filter(func(c: Node) -> bool:
		return c is DeathPop3D).size()
	assert_gt(after, before, "DeathPop3D must be spawned in scene when player is registered")

func test_enemy_killed_3d_with_player_spawns_damage_number() -> void:
	var dummy: Node3D = add_child_autofree(Node3D.new())
	Juice3D.register_player(dummy)
	var parent: Node = _effect_parent()
	var before: int = parent.get_children().filter(func(c: Node) -> bool:
		return c is DamageNumber3D).size()
	GameEvents.enemy_killed_3d.emit(Vector3(1.0, 0.0, 1.0), 7)
	await get_tree().process_frame
	var after: int = parent.get_children().filter(func(c: Node) -> bool:
		return c is DamageNumber3D).size()
	assert_gt(after, before, "DamageNumber3D must be spawned in scene when player is registered")

func test_player_hp_changed_decrease_with_player_no_crash() -> void:
	var dummy: Node3D = add_child_autofree(Node3D.new())
	Juice3D.register_player(dummy)
	Juice3D._last_hp = 100.0
	# No camera registered — _add_trauma must no-op safely
	GameEvents.player_hp_changed.emit(70.0, 100.0)
	await get_tree().process_frame
	assert_true(true, "hp_changed decrease with player must not crash even without camera")

# ── boss-only screen shake on death ───────────────────────────────────────────

func test_boss_killed_3d_signal_is_connected() -> void:
	assert_true(
		GameEvents.boss_killed_3d.is_connected(Juice3D._on_boss_killed_3d),
		"Juice3D must connect boss_killed_3d in _ready()"
	)

func test_normal_enemy_kill_does_not_shake_camera() -> void:
	var cam: StubCamera = add_child_autofree(StubCamera.new())
	Juice3D.register_camera(cam)
	var dummy: Node3D = add_child_autofree(Node3D.new())
	Juice3D.register_player(dummy)
	GameEvents.enemy_killed_3d.emit(Vector3.ZERO, 5)
	await get_tree().process_frame
	assert_eq(cam.trauma_calls.size(), 0, "normal enemy death must NOT shake the camera")

func test_mini_boss_kill_shakes_camera_once() -> void:
	var cam: StubCamera = add_child_autofree(StubCamera.new())
	Juice3D.register_camera(cam)
	GameEvents.boss_killed_3d.emit(Enemy3D.BossKind.MINI)
	await get_tree().process_frame
	assert_eq(cam.trauma_calls.size(), 1, "mini-boss death must shake once")
	assert_gt(cam.trauma_calls[0], 0.0, "shake trauma must be positive")

func test_big_boss_kill_shakes_harder_than_mini() -> void:
	var cam: StubCamera = add_child_autofree(StubCamera.new())
	Juice3D.register_camera(cam)
	GameEvents.boss_killed_3d.emit(Enemy3D.BossKind.MINI)
	GameEvents.boss_killed_3d.emit(Enemy3D.BossKind.BIG)
	await get_tree().process_frame
	assert_eq(cam.trauma_calls.size(), 2, "two boss deaths → two shakes")
	assert_gt(cam.trauma_calls[1], cam.trauma_calls[0],
		"big-boss shake must exceed mini-boss shake")
