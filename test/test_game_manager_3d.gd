# See docs/notes/game-manager-3d.md
extends GutTest
## Unit tests for GameManager3D.
## Tests the run setup (player gets weapon) and the gem-spawning response to enemy kills.
## Uses real Player3D + stub Spawner3D to keep tests focused and fast.

# ---------------------------------------------------------------------------
# Stub spawner — accepts setup() call without loading/spawning enemies.
# ---------------------------------------------------------------------------
class StubSpawner3D extends Node3D:
	var setup_called: bool = false
	var setup_target = null
	func setup(target: Node3D) -> void:
		setup_called = true
		setup_target = target

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
var Player3DScene = null

func before_all() -> void:
	Player3DScene = load("res://player/player_3d.tscn")

# Build a minimal scene root with Player3D + StubSpawner3D + GameManager3D.
# Returns the root node (add_child_autofree so it's cleaned up after each test).
func _make_run_scene() -> Node3D:
	var root := Node3D.new()
	add_child_autofree(root)

	var player: Player3D = Player3DScene.instantiate() as Player3D
	player.name = "Player"
	root.add_child(player)

	var spawner := StubSpawner3D.new()
	spawner.name = "Spawner3D"
	root.add_child(spawner)

	var manager := GameManager3D.new()
	manager.name = "GameManager3D"
	root.add_child(manager)  # triggers _ready() → start()
	return root

# ---------------------------------------------------------------------------
# Player setup — weapon is attached
# ---------------------------------------------------------------------------

func test_player_has_weapon_after_start() -> void:
	var root := _make_run_scene()
	var player := root.get_node("Player") as Player3D
	assert_not_null(player.weapon,
			"Player3D should have a weapon assigned after GameManager3D.start()")

func test_weapon_is_node3d() -> void:
	var root := _make_run_scene()
	var player := root.get_node("Player") as Player3D
	if player.weapon == null:
		fail_test("weapon is null — cannot check type")
		return
	assert_true(player.weapon is Node3D,
			"weapon should be a Node3D (ZivStunningLooks3D)")

# ---------------------------------------------------------------------------
# Spawner wiring
# ---------------------------------------------------------------------------

func test_spawner_setup_called_with_player() -> void:
	var root := _make_run_scene()
	var spawner := root.get_node("Spawner3D") as StubSpawner3D
	var player  := root.get_node("Player")  as Player3D
	assert_true(spawner.setup_called,
			"spawner.setup() should be called during GameManager3D.start()")
	assert_eq(spawner.setup_target, player,
			"spawner should receive the Player3D as its target")

# ---------------------------------------------------------------------------
# Enemy kill → XPGem3D spawned
# ---------------------------------------------------------------------------

func test_enemy_killed_spawns_xp_gem() -> void:
	var root := _make_run_scene()
	await get_tree().process_frame  # let start() settle

	var pos := Vector3(3.0, 0.0, 1.0)
	GameEvents.enemy_killed_3d.emit(pos, 7)
	await get_tree().process_frame  # deferred add_child

	var gem_count := 0
	for child in root.get_children():
		if child is XPGem3D:
			gem_count += 1
	assert_eq(gem_count, 1,
			"exactly one XPGem3D should be added as child of root after enemy kill")

func test_enemy_killed_increments_kill_count() -> void:
	var root := _make_run_scene()
	await get_tree().process_frame
	var manager := root.get_node_or_null("GameManager3D") as GameManager3D
	assert_not_null(manager, "GameManager3D must be findable in the test scene")
	GameEvents.enemy_killed_3d.emit(Vector3.ZERO, 1)
	await get_tree().process_frame
	assert_eq(manager.kills, 1,
			"kill counter should increment on enemy_killed_3d signal")

func test_two_kills_spawn_two_gems() -> void:
	var root := _make_run_scene()
	await get_tree().process_frame
	GameEvents.enemy_killed_3d.emit(Vector3(1.0, 0.0, 0.0), 3)
	GameEvents.enemy_killed_3d.emit(Vector3(2.0, 0.0, 0.0), 5)
	await get_tree().process_frame

	var gem_count := 0
	for child in root.get_children():
		if child is XPGem3D:
			gem_count += 1
	assert_eq(gem_count, 2,
			"two enemy kills should produce two XPGem3D nodes")

# ---------------------------------------------------------------------------
# Player stats are world-scaled
# ---------------------------------------------------------------------------

func test_player_pickup_range_is_world_scaled() -> void:
	var root := _make_run_scene()
	var player := root.get_node("Player") as Player3D
	# pickup_range = 5.0 (80 px / 16)
	assert_almost_eq(player.get_pickup_range(), 5.0, 0.001,
			"pickup_range should be 5.0 (80 px / 16) after world-scale setup")

func test_player_move_speed_is_world_scaled() -> void:
	var root := _make_run_scene()
	var player := root.get_node("Player") as Player3D
	# move_speed = 7.5 (120 px / 16)
	assert_almost_eq(player.stats.move_speed, 7.5, 0.001,
			"move_speed should be 7.5 (120 px / 16) after world-scale setup")
