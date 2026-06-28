extends GutTest
## Unit tests for Player.apply_stat_upgrade and GameManager._apply_upgrade routing.

# ── helpers ──────────────────────────────────────────────────────────────────

## Stub Weapon that records calls (extends Weapon so type-checking passes).
class StubWeapon extends Weapon:
	var level_up_called   := false
	var evolve_called     := false
	var passive_called    := false
	var passive_value     := 0.0
	var refresh_called    := false

	func _ready() -> void:
		# Do NOT call super() — we don't want the real timer setup in tests.
		pass

	func level_up() -> void:
		level_up_called = true

	func evolve() -> void:
		evolve_called = true

	func apply_passive(value: float) -> void:
		passive_called = true
		passive_value  = value

	func refresh_cooldown() -> void:
		refresh_called = true

var _player_scene: PackedScene = null

func before_all() -> void:
	_player_scene = load("res://player/player.tscn")

func _make_player(max_hp: float = 100.0) -> Player:
	var sb := StatBlock.new()
	sb.max_hp          = max_hp
	sb.move_speed      = 120.0
	sb.pickup_range    = 48.0
	sb.damage_mult     = 1.0
	sb.fire_rate_mult  = 1.0
	sb.armor           = 0.0
	var cd := CharacterData.new()
	cd.base_stats      = sb
	# weapon_scene intentionally null — we inject StubWeapon manually
	var p: Player = add_child_autofree(_player_scene.instantiate()) as Player
	p.setup(cd)
	return p

func _make_player_with_stub() -> Array:
	var p    := _make_player()
	var stub := add_child_autofree(StubWeapon.new()) as StubWeapon
	p.weapon  = stub
	return [p, stub]

func _make_upgrade(kind: int, ek: StringName = &"", ev: float = 0.0, mid: StringName = &"test") -> Upgrade:
	var u          := Upgrade.new()
	u.id           = mid
	u.kind         = kind
	u.max_level    = 5
	u.effect_kind  = ek
	u.effect_value = ev
	return u

func _make_game_manager(p: Player) -> GameManager:
	# autofree so GUT cleans it up — we intentionally don't add to tree here
	# so _ready() never fires (no signal wiring, no scene lookups).
	var gm: GameManager = autofree(GameManager.new())
	gm.player = p
	# upgrade_system not needed for _apply_upgrade routing tests
	return gm

# ── Player.apply_stat_upgrade ─────────────────────────────────────────────────

func test_apply_stat_max_hp_raises_stat_and_current_hp() -> void:
	var p := _make_player(100.0)
	p.apply_stat_upgrade(&"max_hp", 20.0)
	assert_almost_eq(p.stats.max_hp, 120.0, 0.001,
		"max_hp stat should increase by 20")
	assert_almost_eq(p.hp, 120.0, 0.001,
		"current hp should also increase by 20")

func test_apply_stat_max_hp_emits_hp_changed() -> void:
	var p := _make_player(80.0)
	watch_signals(GameEvents)
	p.apply_stat_upgrade(&"max_hp", 20.0)
	assert_signal_emitted_with_parameters(
		GameEvents, "player_hp_changed", [100.0, 100.0])

func test_apply_stat_move_speed() -> void:
	var p := _make_player()
	p.apply_stat_upgrade(&"move_speed", 15.0)
	assert_almost_eq(p.stats.move_speed, 135.0, 0.001)

func test_apply_stat_pickup_range() -> void:
	var p := _make_player()
	p.apply_stat_upgrade(&"pickup_range", 20.0)
	assert_almost_eq(p.stats.pickup_range, 68.0, 0.001)

func test_apply_stat_damage() -> void:
	var p := _make_player()
	p.apply_stat_upgrade(&"damage", 0.5)
	assert_almost_eq(p.stats.damage_mult, 1.5, 0.001)

func test_apply_stat_armor() -> void:
	var p := _make_player()
	p.apply_stat_upgrade(&"armor", 3.0)
	assert_almost_eq(p.stats.armor, 3.0, 0.001)

func test_apply_stat_fire_rate_changes_mult() -> void:
	var p := _make_player()
	p.apply_stat_upgrade(&"fire_rate", 0.3)
	assert_almost_eq(p.stats.fire_rate_mult, 1.3, 0.001)

func test_apply_stat_fire_rate_calls_refresh_on_stub_weapon() -> void:
	var arr   := _make_player_with_stub()
	var p     := arr[0] as Player
	var stub  := arr[1] as StubWeapon
	# fire_rate path must call weapon.refresh_cooldown()
	p.apply_stat_upgrade(&"fire_rate", 0.2)
	assert_almost_eq(p.stats.fire_rate_mult, 1.2, 0.001)
	assert_true(stub.refresh_called,
		"fire_rate upgrade must trigger weapon.refresh_cooldown()")

# ── GameManager._apply_upgrade routing ───────────────────────────────────────

func test_router_signature_calls_level_up() -> void:
	var arr  := _make_player_with_stub()
	var p    := arr[0] as Player
	var stub := arr[1] as StubWeapon
	var gm   := _make_game_manager(p)
	var u    := _make_upgrade(Upgrade.Kind.SIGNATURE)

	gm._apply_upgrade(u)

	assert_true(stub.level_up_called,
		"SIGNATURE upgrade must call weapon.level_up()")
	assert_false(stub.evolve_called)

func test_router_evolution_calls_evolve() -> void:
	var arr  := _make_player_with_stub()
	var p    := arr[0] as Player
	var stub := arr[1] as StubWeapon
	var gm   := _make_game_manager(p)
	var u    := _make_upgrade(Upgrade.Kind.EVOLUTION)

	gm._apply_upgrade(u)

	assert_true(stub.evolve_called,
		"EVOLUTION upgrade must call weapon.evolve()")
	assert_false(stub.level_up_called)

func test_router_passive_calls_apply_passive_with_value() -> void:
	var arr  := _make_player_with_stub()
	var p    := arr[0] as Player
	var stub := arr[1] as StubWeapon
	var gm   := _make_game_manager(p)
	var u    := _make_upgrade(Upgrade.Kind.PASSIVE, &"", 0.75)

	gm._apply_upgrade(u)

	assert_true(stub.passive_called,
		"PASSIVE upgrade must call weapon.apply_passive()")
	assert_almost_eq(stub.passive_value, 0.75, 0.001)

func test_router_generic_calls_apply_stat_upgrade() -> void:
	var p  := _make_player(100.0)
	var gm := _make_game_manager(p)
	var u  := _make_upgrade(Upgrade.Kind.GENERIC, &"max_hp", 30.0)

	gm._apply_upgrade(u)

	assert_almost_eq(p.stats.max_hp, 130.0, 0.001,
		"GENERIC max_hp upgrade should raise stat via apply_stat_upgrade")

# ── Stacked level-up queue ────────────────────────────────────────────────────

## Stub UpgradeUI: records present() calls; emits chosen() on demand.
class StubUpgradeUI extends Node:
	signal chosen(upgrade: Upgrade)
	var present_count: int = 0
	func present(_system, _player) -> void:
		present_count += 1
	func pick(u: Upgrade) -> void:
		chosen.emit(u)

func _make_upgrade_system() -> UpgradeSystem:
	var ch := CharacterData.new()
	ch.id = &"ziv"; ch.max_signature_level = 5
	ch.passive_id = &"pas"; ch.evolution_id = &"evo"
	var sig := _make_upgrade(Upgrade.Kind.SIGNATURE, &"", 0.0, &"sig")
	var pas := _make_upgrade(Upgrade.Kind.PASSIVE,   &"", 0.0, &"pas")
	var evo := _make_upgrade(Upgrade.Kind.EVOLUTION, &"", 0.0, &"evo")
	return UpgradeSystem.new(ch, [], sig, pas, evo)

## Two thresholds crossed in one add_xp() must each get their own choice,
## both rewards applied in sequence, and the tree ends UNPAUSED.
func test_stacked_levelups_resolve_in_sequence_and_unpause() -> void:
	var p  := _make_player(100.0)
	# GameManager must be in the tree so get_tree().paused works.
	var gm: GameManager = add_child_autofree(GameManager.new()) as GameManager
	# _ready() ran on add_child (found no siblings) — wire manually now.
	gm.player         = p
	gm.upgrade_system = _make_upgrade_system()
	var ui: StubUpgradeUI = StubUpgradeUI.new()
	gm._upgrade_ui = ui
	ui.chosen.connect(gm._on_upgrade_chosen)

	var u1 := _make_upgrade(Upgrade.Kind.GENERIC, &"move_speed", 10.0, &"g1")
	var u2 := _make_upgrade(Upgrade.Kind.GENERIC, &"armor",       3.0, &"g2")

	# Simulate add_xp crossing two thresholds: two synchronous emits.
	gm._on_player_leveled_up(2)   # starts: _choosing=true, paused, present #1
	gm._on_player_leveled_up(3)   # queued: _pending_levelups = 1

	assert_eq(ui.present_count, 1, "Only one choice should be presented at a time")
	assert_true(get_tree().paused, "Tree should be paused during level-up choice")

	# Player picks the first upgrade.
	ui.pick(u1)
	assert_eq(ui.present_count, 2, "Queued level-up must present its own choice")
	assert_true(get_tree().paused, "Tree stays paused until all level-ups resolved")

	# Player picks the second upgrade.
	ui.pick(u2)

	assert_eq(gm._pending_levelups, 0, "No level-ups left pending")
	assert_false(gm._choosing, "_choosing cleared after last resolution")
	assert_false(get_tree().paused, "Tree must be unpaused after all level-ups")

	# Both rewards applied (no lost upgrade).
	assert_almost_eq(p.stats.move_speed, 130.0, 0.001, "u1 (move_speed +10) applied")
	assert_almost_eq(p.stats.armor,        3.0, 0.001, "u2 (armor +3) applied")
	assert_eq(gm.upgrade_system.levels.get(&"g1", 0), 1, "u1 recorded in system")
	assert_eq(gm.upgrade_system.levels.get(&"g2", 0), 1, "u2 recorded in system")

	ui.free()
	get_tree().paused = false  # safety reset for subsequent tests
