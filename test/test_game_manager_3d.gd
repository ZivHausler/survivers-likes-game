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

	# Clear skill_system so the legacy UpgradeSystem path is exercised by this test.
	manager.skill_system = null
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

	# Clear skill_system so the legacy UpgradeSystem path is exercised.
	# Build a system where everything is maxed → has_available_choices() = false.
	manager.skill_system = null
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

# ---------------------------------------------------------------------------
# SkillSystem helpers
# ---------------------------------------------------------------------------

## Build a minimal SkillData for testing, with SKILL/PASSIVE/SYNERGY upgrades.
func _make_test_skill_data(skill_id: StringName, is_sig: bool = false) -> SkillData:
	var su := Upgrade.new()
	su.id = StringName(str(skill_id) + "_skill"); su.kind = Upgrade.Kind.SKILL
	su.max_level = 5; su.skill_id = skill_id

	var pu := Upgrade.new()
	pu.id = StringName(str(skill_id) + "_passive"); pu.kind = Upgrade.Kind.PASSIVE
	pu.max_level = 5; pu.skill_id = skill_id; pu.effect_value = 0.5

	var syn := Upgrade.new()
	syn.id = StringName(str(skill_id) + "_synergy"); syn.kind = Upgrade.Kind.SYNERGY
	syn.max_level = 1; syn.skill_id = skill_id

	var s := SkillData.new()
	s.id = skill_id
	s.skill_upgrade = su; s.passive_upgrade = pu; s.synergy_upgrade = syn
	s.is_signature = is_sig
	return s

## Build a minimal SkillSystem with one signature skill and optional generic pool.
func _make_skill_system_for_test(generics: Array = []) -> SkillSystem:
	var s := _make_test_skill_data(&"tskill", true)
	return SkillSystem.new([s], generics)

# ---------------------------------------------------------------------------
# Stub player that records skill calls
# ---------------------------------------------------------------------------
class StubPlayer3D extends Node3D:
	var acquired: Dictionary = {}   # skill_id → PackedScene
	var leveled: Array = []
	var passived: Dictionary = {}   # skill_id → value
	var evolved: Array = []
	var stat_upgrades: Dictionary = {}
	## Recorded set_invulnerable() call arguments, in order.
	var invuln_calls: Array = []

	var stats: StatBlock
	var weapon: Node3D = null
	var level: int = 1

	func acquire_skill(skill_id: StringName, ws) -> void:
		acquired[skill_id] = ws
	func level_skill(skill_id: StringName) -> void:
		leveled.append(skill_id)
	func apply_skill_passive(skill_id: StringName, v: float) -> void:
		passived[skill_id] = v
	func evolve_skill(skill_id: StringName) -> void:
		evolved.append(skill_id)
	# Note: apply_stat_upgrade is defined so Object.has_method("apply_stat_upgrade") → true.
	func apply_stat_upgrade(kind: StringName, v: float) -> void:
		stat_upgrades[kind] = stat_upgrades.get(kind, 0.0) + v
	func set_invulnerable(duration: float, _blink: bool = true) -> void:
		invuln_calls.append(duration)

# ---------------------------------------------------------------------------
# SkillSystem integration: built at start
# ---------------------------------------------------------------------------

func test_skill_system_built_from_ziv_3d_at_start() -> void:
	var root    := _make_run_scene()
	var manager := root.get_node("GameManager3D") as GameManager3D
	assert_not_null(manager.skill_system,
		"SkillSystem must be built from ziv_3d.tres at start (skills array non-empty)")

func test_skill_system_has_available_choices_at_start() -> void:
	var root    := _make_run_scene()
	var manager := root.get_node("GameManager3D") as GameManager3D
	if manager.skill_system == null:
		fail_test("skill_system is null — prerequisite failed"); return
	assert_true(manager.skill_system.has_available_choices(),
		"SkillSystem must have available choices at the start of a run")

func test_signature_acquired_in_player_weapons_at_start() -> void:
	var root   := _make_run_scene()
	var player := root.get_node("Player") as Player3D
	assert_true(player.has_skill(&"ziv_mirror_shards"),
		"Player must have ziv_mirror_shards (signature) weapon in weapons dict after GameManager start()")

# ---------------------------------------------------------------------------
# SkillSystem routing via _route_skill_upgrade
# ---------------------------------------------------------------------------

func _make_manager_with_stub_player_and_skill_system() -> Array:
	var root := Node3D.new()
	add_child_autofree(root)
	var stub := StubPlayer3D.new()
	stub.name = "StubPlayer"
	stub.stats = StatBlock.new()
	root.add_child(stub)

	var manager := GameManager3D.new()
	manager.name = "GM"
	# We set _player and skill_system directly, bypassing start().
	root.add_child(manager)  # triggers _ready → start() but root has no "Player" node of type Player3D
	# Re-assign after start():
	manager._player = stub
	manager.skill_system = _make_skill_system_for_test()
	manager._skill_by_id[&"tskill"] = _make_test_skill_data(&"tskill", true)
	return [manager, stub]


func test_route_skill_first_acquire_calls_acquire_skill() -> void:
	var arr     := _make_manager_with_stub_player_and_skill_system()
	var manager := arr[0] as GameManager3D
	var stub    := arr[1] as StubPlayer3D

	# Build a SKILL upgrade for a non-signature skill (level 0 initially).
	# weapon_scene must be non-null so _route_skill_upgrade's guard passes.
	var non_sig := _make_test_skill_data(&"other", false)
	non_sig.weapon_scene = load("res://weapons/ziv_stunning_looks_3d.tscn")
	manager.skill_system = SkillSystem.new([_make_test_skill_data(&"tskill", true), non_sig], [])
	manager._skill_by_id[&"other"] = non_sig

	var u := non_sig.skill_upgrade
	# Apply it so level goes 0→1 (acquisition).
	manager.skill_system.apply(u)
	manager._route_skill_upgrade(u)

	assert_true(stub.acquired.has(&"other"),
		"SKILL card at level 1 (first acquire) must call acquire_skill")
	assert_true(stub.leveled.is_empty(),
		"First acquire must NOT call level_skill")


func test_route_skill_when_owned_calls_level_skill() -> void:
	var arr     := _make_manager_with_stub_player_and_skill_system()
	var manager := arr[0] as GameManager3D
	var stub    := arr[1] as StubPlayer3D

	# Use the signature skill (already at level 1 from SkillSystem init).
	# Apply the skill upgrade again to go to level 2.
	var sig := manager.skill_system._skills[0] as SkillData
	manager.skill_system.apply(sig.skill_upgrade)  # level 1→2
	manager._route_skill_upgrade(sig.skill_upgrade)

	assert_true(stub.leveled.has(sig.id),
		"SKILL card at level > 1 must call level_skill, not acquire_skill")
	assert_false(stub.acquired.has(sig.id),
		"Level-up must NOT call acquire_skill")


func test_route_passive_calls_apply_skill_passive() -> void:
	var arr     := _make_manager_with_stub_player_and_skill_system()
	var manager := arr[0] as GameManager3D
	var stub    := arr[1] as StubPlayer3D

	# Mark skill as owned so PASSIVE is offered.
	var sig := manager.skill_system._skills[0] as SkillData
	sig.passive_upgrade.effect_value = 0.75
	manager.skill_system.apply(sig.passive_upgrade)
	manager._route_skill_upgrade(sig.passive_upgrade)

	assert_true(stub.passived.has(sig.id),
		"PASSIVE card must call apply_skill_passive")
	assert_almost_eq(stub.passived.get(sig.id, 0.0), 0.75, 0.001,
		"PASSIVE must pass correct effect_value")


func test_route_synergy_calls_evolve_skill() -> void:
	var arr     := _make_manager_with_stub_player_and_skill_system()
	var manager := arr[0] as GameManager3D
	var stub    := arr[1] as StubPlayer3D

	var sig := manager.skill_system._skills[0] as SkillData
	# Artificially mark synergy available state.
	manager.skill_system.levels[sig.skill_upgrade.id] = 5
	manager.skill_system.levels[sig.passive_upgrade.id] = 1
	manager._route_skill_upgrade(sig.synergy_upgrade)

	assert_true(stub.evolved.has(sig.id),
		"SYNERGY card must call evolve_skill")


func test_route_generic_calls_apply_stat_upgrade_via_skill_path() -> void:
	var arr     := _make_manager_with_stub_player_and_skill_system()
	var manager := arr[0] as GameManager3D
	var stub    := arr[1] as StubPlayer3D

	var u := Upgrade.new()
	u.id = &"ms_test"; u.kind = Upgrade.Kind.GENERIC
	u.effect_kind = &"move_speed"; u.effect_value = 2.0
	manager._route_skill_upgrade(u)

	assert_almost_eq(stub.stat_upgrades.get(&"move_speed", 0.0), 2.0, 0.001,
		"GENERIC via skill path must call apply_stat_upgrade")

# ---------------------------------------------------------------------------
# Character tres: skills array
# ---------------------------------------------------------------------------

func test_ziv_3d_has_non_empty_skills_array() -> void:
	var cd := load("res://characters/ziv_3d.tres") as CharacterData
	assert_not_null(cd, "ziv_3d.tres must load"); if cd == null: return
	assert_true(cd.skills.size() > 0, "ziv_3d.skills must be non-empty")

func test_ziv_3d_skills_first_is_signature() -> void:
	var cd := load("res://characters/ziv_3d.tres") as CharacterData
	assert_not_null(cd, "ziv_3d.tres must load"); if cd == null: return
	if cd.skills.is_empty(): fail_test("skills empty"); return
	var s := cd.skills[0] as SkillData
	assert_not_null(s, "skills[0] must be a SkillData"); if s == null: return
	assert_true(s.is_signature, "ziv_3d skills[0] must be marked is_signature")
	assert_not_null(s.weapon_scene, "ziv_3d signature must have a weapon_scene")

func test_ziv_3d_skill_has_three_upgrades() -> void:
	var cd := load("res://characters/ziv_3d.tres") as CharacterData
	assert_not_null(cd); if cd == null or cd.skills.is_empty(): return
	var s := cd.skills[0] as SkillData
	if s == null: return
	assert_eq(s.skill_upgrade.kind,   Upgrade.Kind.SKILL,   "skill_upgrade must be SKILL kind")
	assert_eq(s.passive_upgrade.kind, Upgrade.Kind.PASSIVE, "passive_upgrade must be PASSIVE kind")
	assert_eq(s.synergy_upgrade.kind, Upgrade.Kind.SYNERGY, "synergy_upgrade must be SYNERGY kind")

func test_avihay_3d_has_non_empty_skills_array() -> void:
	var cd := load("res://characters/avihay_3d.tres") as CharacterData
	assert_not_null(cd, "avihay_3d.tres must load"); if cd == null: return
	assert_true(cd.skills.size() > 0, "avihay_3d.skills must be non-empty")

func test_avihay_3d_skills_first_is_signature() -> void:
	var cd := load("res://characters/avihay_3d.tres") as CharacterData
	assert_not_null(cd, "avihay_3d.tres must load"); if cd == null: return
	if cd.skills.is_empty(): fail_test("skills empty"); return
	var s := cd.skills[0] as SkillData
	assert_not_null(s, "skills[0] must be a SkillData"); if s == null: return
	assert_true(s.is_signature, "avihay_3d skills[0] must be marked is_signature")
	assert_not_null(s.weapon_scene, "avihay_3d signature must have a weapon_scene")

# ---------------------------------------------------------------------------
# Post-levelup invulnerability
# ---------------------------------------------------------------------------

## Build a manager wired to a StubPlayer3D and a StubUpgradeUI3D, using the
## legacy UpgradeSystem path so the tests don't depend on external .tres files.
## Mirrors the pattern in test_3d_stacked_levelups_resolve_in_sequence_and_unpause
## (ui added via add_child_autofree so start() does not auto-connect chosen).
func _make_invuln_test_scene() -> Array:
	var root := Node3D.new()
	add_child_autofree(root)

	var stub := StubPlayer3D.new()
	stub.name = "StubPlayer"
	stub.stats = StatBlock.new()
	root.add_child(stub)

	var manager := GameManager3D.new()
	manager.name = "GM"
	root.add_child(manager)  # triggers _ready → start(); no UpgradeUI node found so no auto-connect

	# UI added outside root so start() didn't auto-connect chosen; we connect manually.
	var ui := StubUpgradeUI3D.new()
	add_child_autofree(ui)
	manager._player = stub
	manager.skill_system = null
	manager.upgrade_system = _make_upgrade_system_3d()
	manager._upgrade_ui = ui
	ui.chosen.connect(manager._on_upgrade_chosen)

	return [manager, stub, ui]


func test_invuln_granted_on_final_levelup_resolve() -> void:
	var arr     := _make_invuln_test_scene()
	var manager := arr[0] as GameManager3D
	var stub    := arr[1] as StubPlayer3D

	var u := _make_upgrade_3d(Upgrade.Kind.GENERIC, &"move_speed", 1.0, &"spd_invtest")
	manager._on_player_leveled_up(2)   # starts: _choosing=true, present #1
	(arr[2] as StubUpgradeUI3D).pick(u)  # resolves final → should grant invuln

	assert_true(stub.invuln_calls.size() > 0,
		"set_invulnerable must be called once after the final level-up resolves")
	assert_almost_eq(stub.invuln_calls[0], GameManager3D.LEVELUP_INVULN, 0.001,
		"set_invulnerable must be called with LEVELUP_INVULN (2.0)")

	get_tree().paused = false  # safety reset


func test_invuln_not_granted_while_pending_levelups_remain() -> void:
	var arr     := _make_invuln_test_scene()
	var manager := arr[0] as GameManager3D
	var stub    := arr[1] as StubPlayer3D
	var ui      := arr[2] as StubUpgradeUI3D

	var u1 := _make_upgrade_3d(Upgrade.Kind.GENERIC, &"move_speed", 1.0, &"sp_iv1")
	var u2 := _make_upgrade_3d(Upgrade.Kind.GENERIC, &"armor",      1.0, &"sp_iv2")

	# Simulate two synchronous level-ups.
	manager._on_player_leveled_up(2)  # starts: _choosing=true, _pending=0
	manager._on_player_leveled_up(3)  # queued: _pending=1

	ui.pick(u1)  # resolves first; second starts → invuln must NOT be granted yet
	assert_true(stub.invuln_calls.is_empty(),
		"set_invulnerable must NOT be called while a second level-up is still pending")

	ui.pick(u2)  # resolves final → now grant invuln
	assert_true(stub.invuln_calls.size() > 0,
		"set_invulnerable must be called after the last queued level-up resolves")

	get_tree().paused = false  # safety reset

# ---------------------------------------------------------------------------
# Camera target wiring (Bug 1 regression tests)
# ---------------------------------------------------------------------------

## Build a run scene that includes a GameCamera3D sibling, so GameManager3D.start()
## can assign cam.target = player in code (the exported NodePath does not resolve).
func _make_run_scene_with_camera() -> Node3D:
	var root := Node3D.new()
	add_child_autofree(root)

	var player: Player3D = Player3DScene.instantiate() as Player3D
	player.name = "Player"
	root.add_child(player)

	var spawner := StubSpawner3D.new()
	spawner.name = "Spawner3D"
	root.add_child(spawner)

	var cam := GameCamera3D.new()
	cam.name = "GameCamera3D"
	root.add_child(cam)

	var manager := GameManager3D.new()
	manager.name = "GameManager3D"
	root.add_child(manager)  # triggers _ready() → start()
	return root

func test_camera_target_is_non_null_after_start() -> void:
	var root := _make_run_scene_with_camera()
	var cam := root.get_node("GameCamera3D") as GameCamera3D
	assert_not_null(cam.target,
		"GameCamera3D.target must be non-null after GameManager3D.start()")

func test_camera_target_is_the_player() -> void:
	var root   := _make_run_scene_with_camera()
	var cam    := root.get_node("GameCamera3D") as GameCamera3D
	var player := root.get_node("Player") as Player3D
	assert_eq(cam.target, player,
		"GameCamera3D.target must be the Player3D node assigned by GameManager3D")

func test_camera_y_leaves_origin_after_physics_step() -> void:
	var root := _make_run_scene_with_camera()
	var cam  := root.get_node("GameCamera3D") as GameCamera3D
	# Invoke _physics_process directly — Camera3D may not run physics frames
	# automatically in headless mode; direct invocation is equivalent and reliable.
	cam._physics_process(0.016)
	var expected := GameCamera3D.compute_position(
		cam.target.global_position, cam.distance * cam.zoom, cam.pitch_degrees, cam.yaw_degrees)
	assert_almost_eq(cam.global_position.y, expected.y, 0.1,
		"Camera global_position.y must reach the orbit height above the target after first physics step, not stay at origin")
	assert_true(cam.global_position.y > cam.target.global_position.y + 1.0,
		"Camera must sit above the target, not at origin")
