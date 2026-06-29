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

# ---------------------------------------------------------------------------
# Stub weapon (3D) — records calls; duck-typed to match weapon API
# ---------------------------------------------------------------------------
class StubWeapon3D extends Node3D:
	var level_up_called   := false
	var evolve_called     := false
	var passive_called    := false
	var passive_value     := 0.0
	var refresh_called    := false
	func setup(_player, _stats) -> void: pass
	func level_up() -> void:            level_up_called = true
	func evolve() -> void:              evolve_called = true
	func apply_passive(v: float) -> void: passive_called = true; passive_value = v
	func refresh_cooldown() -> void:    refresh_called = true

# ---------------------------------------------------------------------------
# Stub UpgradeUI — records present() calls; emits chosen() on demand
# ---------------------------------------------------------------------------
class StubUpgradeUI3D extends Node:
	signal chosen(upgrade: Upgrade)
	var present_count: int = 0
	func present(_system, _player) -> void: present_count += 1
	func pick(u: Upgrade) -> void:          chosen.emit(u)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
func _make_upgrade_3d(kind: int, ek: StringName = &"", ev: float = 0.0, mid: StringName = &"test3d") -> Upgrade:
	var u          := Upgrade.new()
	u.id           = mid
	u.kind         = kind
	u.max_level    = 5
	u.effect_kind  = ek
	u.effect_value = ev
	return u

func _make_upgrade_system_3d() -> UpgradeSystem:
	var ch := CharacterData.new()
	ch.id = &"ziv"; ch.max_signature_level = 5
	ch.passive_id = &"zpas3d"; ch.evolution_id = &"zevo3d"
	var sig := _make_upgrade_3d(Upgrade.Kind.SIGNATURE, &"", 0.0, &"zsig3d")
	sig.max_level = 5
	var pas := _make_upgrade_3d(Upgrade.Kind.PASSIVE,   &"", 0.0, &"zpas3d")
	pas.max_level = 5
	var evo := _make_upgrade_3d(Upgrade.Kind.EVOLUTION, &"", 0.0, &"zevo3d")
	evo.max_level = 1
	return UpgradeSystem.new(ch, [], sig, pas, evo)

# ---------------------------------------------------------------------------
# _apply_upgrade routing
# ---------------------------------------------------------------------------

func test_3d_apply_upgrade_signature_calls_level_up() -> void:
	var root := _make_run_scene()
	var manager := root.get_node("GameManager3D") as GameManager3D
	var player  := root.get_node("Player") as Player3D
	var stub := StubWeapon3D.new()
	add_child_autofree(stub)
	player.weapon = stub

	var u := _make_upgrade_3d(Upgrade.Kind.SIGNATURE)
	manager._apply_upgrade(u)

	assert_true(stub.level_up_called, "SIGNATURE must call weapon.level_up()")
	assert_false(stub.evolve_called,  "SIGNATURE must not call weapon.evolve()")

func test_3d_apply_upgrade_evolution_calls_evolve() -> void:
	var root := _make_run_scene()
	var manager := root.get_node("GameManager3D") as GameManager3D
	var player  := root.get_node("Player") as Player3D
	var stub := StubWeapon3D.new()
	add_child_autofree(stub)
	player.weapon = stub

	var u := _make_upgrade_3d(Upgrade.Kind.EVOLUTION)
	manager._apply_upgrade(u)

	assert_true(stub.evolve_called,      "EVOLUTION must call weapon.evolve()")
	assert_false(stub.level_up_called,   "EVOLUTION must not call weapon.level_up()")

func test_3d_apply_upgrade_passive_calls_apply_passive_with_value() -> void:
	var root := _make_run_scene()
	var manager := root.get_node("GameManager3D") as GameManager3D
	var player  := root.get_node("Player") as Player3D
	var stub := StubWeapon3D.new()
	add_child_autofree(stub)
	player.weapon = stub

	var u := _make_upgrade_3d(Upgrade.Kind.PASSIVE, &"", 0.75)
	manager._apply_upgrade(u)

	assert_true(stub.passive_called, "PASSIVE must call weapon.apply_passive()")
	assert_almost_eq(stub.passive_value, 0.75, 0.001,
			"PASSIVE must pass effect_value to apply_passive()")

func test_3d_apply_upgrade_generic_calls_apply_stat_upgrade() -> void:
	var root    := _make_run_scene()
	var manager := root.get_node("GameManager3D") as GameManager3D
	var player  := root.get_node("Player") as Player3D
	var orig    := player.stats.move_speed

	var u := _make_upgrade_3d(Upgrade.Kind.GENERIC, &"move_speed", 2.0)
	manager._apply_upgrade(u)

	assert_almost_eq(player.stats.move_speed, orig + 2.0, 0.001,
			"GENERIC move_speed must raise stat via apply_stat_upgrade")

# ---------------------------------------------------------------------------
# Stacked level-up queue
# ---------------------------------------------------------------------------

func test_3d_stacked_levelups_resolve_in_sequence_and_unpause() -> void:
	var root    := _make_run_scene()
	var manager := root.get_node("GameManager3D") as GameManager3D
	var player  := root.get_node("Player") as Player3D

	var ui: StubUpgradeUI3D = StubUpgradeUI3D.new()
	add_child_autofree(ui)
	manager._upgrade_ui = ui
	ui.chosen.connect(manager._on_upgrade_chosen)

	manager.upgrade_system = _make_upgrade_system_3d()

	var u1 := _make_upgrade_3d(Upgrade.Kind.GENERIC, &"move_speed", 1.0, &"m1")
	var u2 := _make_upgrade_3d(Upgrade.Kind.GENERIC, &"armor",      1.0, &"m2")

	# Simulate two synchronous level-ups (as add_xp() would produce).
	manager._on_player_leveled_up(2)   # starts: _choosing=true, tree paused, present #1
	manager._on_player_leveled_up(3)   # queued: _pending_levelups = 1

	assert_eq(ui.present_count, 1, "Only one choice shown at a time")
	assert_true(get_tree().paused, "Tree should be paused during level-up")

	ui.pick(u1)  # resolves first; second queued one starts
	assert_eq(ui.present_count, 2, "Queued level-up must present its own choice")
	assert_true(get_tree().paused, "Tree stays paused until all resolved")

	ui.pick(u2)  # resolves second; all done
	assert_eq(manager._pending_levelups, 0, "No pending level-ups remain")
	assert_false(manager._choosing, "_choosing cleared after last resolution")
	assert_false(get_tree().paused,  "Tree must be unpaused after all level-ups")

	get_tree().paused = false  # safety reset

# ---------------------------------------------------------------------------
# Softlock guard: when all upgrades maxed, grant bonus without pausing
# ---------------------------------------------------------------------------

func test_3d_softlock_guard_grants_bonus_when_all_maxed() -> void:
	var root    := _make_run_scene()
	var manager := root.get_node("GameManager3D") as GameManager3D
	var player  := root.get_node("Player") as Player3D

	var ui := StubUpgradeUI3D.new()
	add_child_autofree(ui)
	manager._upgrade_ui = ui

	# Build a system where everything is maxed → has_available_choices() = false.
	var sys := _make_upgrade_system_3d()
	sys.levels[&"zsig3d"] = 5
	sys.levels[&"zpas3d"] = 5
	sys.evolved = true
	manager.upgrade_system = sys

	var hp_before := player.stats.max_hp
	manager._on_player_leveled_up(2)

	assert_false(get_tree().paused, "Tree must NOT be paused when all maxed")
	assert_eq(ui.present_count, 0, "Picker must NOT be shown when all maxed")
	assert_almost_eq(player.stats.max_hp, hp_before + 5.0, 0.001,
			"_grant_max_bonus must add 5 max_hp")

# ---------------------------------------------------------------------------
# player_died → RunState.last_run
# ---------------------------------------------------------------------------

func test_3d_player_died_sets_runstate_last_run() -> void:
	# Use an off-tree manager so get_tree() returns null and change_scene_to_file
	# is skipped by the null guard — keeps the test from queueing a scene change.
	var manager: GameManager3D = autofree(GameManager3D.new())
	# _ready() is NOT called (manager is not in the tree), so no signal connections
	# are made. Set fields directly.
	manager.elapsed = 42.0
	manager.kills   = 7

	manager._on_player_died()

	assert_eq(RunState.last_run.get("kills", -1), 7,
			"last_run.kills must match manager.kills at time of death")
	assert_almost_eq(float(RunState.last_run.get("time", -1.0)), 42.0, 0.001,
			"last_run.time must match manager.elapsed at time of death")

# ---------------------------------------------------------------------------
# CharacterData loading
# ---------------------------------------------------------------------------

func test_ziv_3d_loads_as_character_data() -> void:
	var cd := load("res://characters/ziv_3d.tres") as CharacterData
	assert_not_null(cd, "ziv_3d.tres must load as CharacterData")
	if cd == null: return
	assert_not_null(cd.weapon_scene, "ziv_3d must have a weapon_scene")
	assert_almost_eq(cd.base_stats.move_speed,   7.5, 0.001, "move_speed world-scaled")
	assert_almost_eq(cd.base_stats.pickup_range, 5.0, 0.001, "pickup_range world-scaled")
	assert_almost_eq(cd.base_stats.max_hp,     100.0, 0.001, "max_hp correct")

func test_avihay_3d_loads_as_character_data() -> void:
	var cd := load("res://characters/avihay_3d.tres") as CharacterData
	assert_not_null(cd, "avihay_3d.tres must load as CharacterData")
	if cd == null: return
	assert_not_null(cd.weapon_scene, "avihay_3d must have a weapon_scene")
	assert_almost_eq(cd.base_stats.max_hp, 90.0, 0.001, "avihay max_hp correct")

func test_ziv_3d_has_3d_weapon_scene() -> void:
	var cd := load("res://characters/ziv_3d.tres") as CharacterData
	assert_not_null(cd, "ziv_3d.tres must load")
	if cd == null: return
	var inst := cd.weapon_scene.instantiate()
	assert_true(inst is Node3D,
			"ziv_3d weapon_scene must instantiate as Node3D (not 2D)")
	inst.free()

func test_avihay_3d_has_3d_weapon_scene() -> void:
	var cd := load("res://characters/avihay_3d.tres") as CharacterData
	assert_not_null(cd, "avihay_3d.tres must load")
	if cd == null: return
	var inst := cd.weapon_scene.instantiate()
	assert_true(inst is Node3D,
			"avihay_3d weapon_scene must instantiate as Node3D (not 2D)")
	inst.free()

# ---------------------------------------------------------------------------
# UpgradeSystem from ziv_3d.tres
# ---------------------------------------------------------------------------

func test_upgrade_system_builds_from_ziv_3d() -> void:
	var cd := load("res://characters/ziv_3d.tres") as CharacterData
	assert_not_null(cd, "ziv_3d.tres must load")
	if cd == null: return
	assert_not_null(cd.signature_upgrade, "ziv_3d must have signature_upgrade")
	assert_not_null(cd.passive_upgrade,   "ziv_3d must have passive_upgrade")
	assert_not_null(cd.evolution_upgrade, "ziv_3d must have evolution_upgrade")

	var generic_pool: Array = []
	for path in GameManager3D.GENERIC_UPGRADE_PATHS:
		var u := load(path) as Upgrade
		if u: generic_pool.append(u)

	var sys := UpgradeSystem.new(cd, generic_pool,
			cd.signature_upgrade, cd.passive_upgrade, cd.evolution_upgrade)
	assert_not_null(sys, "UpgradeSystem must construct from ziv_3d.tres")
	assert_true(sys.has_available_choices(),
			"UpgradeSystem must have available choices at level 1")

	var rng := RandomNumberGenerator.new(); rng.seed = 42
	var choices := sys.build_choices(rng, 3)
	assert_true(choices.size() > 0, "build_choices must return at least one choice")
