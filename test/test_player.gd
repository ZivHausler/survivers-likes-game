extends GutTest
## Unit tests for Player logic (leveling, damage, armor).
## Movement/camera require interactive playtest — see task-1A-report.md.

var PlayerScene = null

func before_all() -> void:
	PlayerScene = load("res://player/player.tscn")

func _make_char_data(max_hp: float = 100.0, armor: float = 0.0, pickup_range: float = 48.0) -> CharacterData:
	var sb := StatBlock.new()
	sb.max_hp = max_hp
	sb.armor = armor
	sb.pickup_range = pickup_range
	sb.move_speed = 120.0
	var cd := CharacterData.new()
	cd.base_stats = sb
	# weapon_scene intentionally null — player.setup() guards with: if data.weapon_scene
	return cd

func _make_player(max_hp: float = 100.0, armor: float = 0.0) -> Node:
	assert_not_null(PlayerScene, "player.tscn must exist before running tests")
	var player = add_child_autofree(PlayerScene.instantiate())
	player.setup(_make_char_data(max_hp, armor))
	return player

# ── xp_to_next formula ──────────────────────────────────────────────────────

func test_xp_to_next_level1() -> void:
	var p = _make_player()
	assert_eq(p.xp_to_next(1), 4, "xp_to_next(1): 2 + 1 + 1*1 = 4")

func test_xp_to_next_level2() -> void:
	var p = _make_player()
	assert_eq(p.xp_to_next(2), 8, "xp_to_next(2): 2 + 2 + 2*2 = 8")

func test_xp_to_next_level5() -> void:
	var p = _make_player()
	assert_eq(p.xp_to_next(5), 32, "xp_to_next(5): 2 + 5 + 5*5 = 32")

# ── add_xp leveling ──────────────────────────────────────────────────────────

func test_add_xp_exact_single_level_up() -> void:
	var p = _make_player()
	p.add_xp(4)  # xp_to_next(1) = 4 exactly
	assert_eq(p.level, 2, "Should advance to level 2 with exactly 4 XP")
	assert_eq(p.xp, 0, "No remainder after exact threshold")

func test_add_xp_multi_level_up_with_remainder() -> void:
	var p = _make_player()
	# level 1→2 costs 4, level 2→3 costs 8; total = 12; give 13 → 1 remainder
	p.add_xp(13)
	assert_eq(p.level, 3, "Should advance two levels")
	assert_eq(p.xp, 1, "Remainder 1 should carry over")

func test_add_xp_partial_no_level_up() -> void:
	var p = _make_player()
	p.add_xp(3)  # less than xp_to_next(1) = 4
	assert_eq(p.level, 1, "Should still be level 1")
	assert_eq(p.xp, 3, "XP should accumulate")

# ── take_damage ──────────────────────────────────────────────────────────────

func test_take_damage_subtracts_armor() -> void:
	var p = _make_player(100.0, 5.0)
	p.take_damage(20.0)  # dealt = max(0, 20 - 5) = 15
	assert_almost_eq(p.hp, 85.0, 0.001, "hp should be 85 after 15 dealt damage")

func test_take_damage_blocked_entirely_by_armor() -> void:
	var p = _make_player(100.0, 10.0)
	p.take_damage(5.0)  # dealt = max(0, 5 - 10) = 0
	assert_almost_eq(p.hp, 100.0, 0.001, "Armor fully blocks damage below armor value")

func test_take_damage_emits_player_hp_changed_with_values() -> void:
	var p = _make_player(100.0, 0.0)
	watch_signals(GameEvents)
	p.take_damage(30.0)  # hp: 100 → 70, max_hp stays 100
	assert_signal_emitted_with_parameters(GameEvents, "player_hp_changed", [70.0, 100.0])

func test_take_damage_emits_player_died_at_zero() -> void:
	var p = _make_player(100.0, 0.0)
	watch_signals(GameEvents)
	p.take_damage(100.0)
	assert_signal_emitted(GameEvents, "player_died")

func test_take_damage_emits_player_died_on_overkill() -> void:
	var p = _make_player(100.0, 0.0)
	watch_signals(GameEvents)
	p.take_damage(999.0)
	assert_signal_emitted(GameEvents, "player_died")

# ── get_pickup_range ─────────────────────────────────────────────────────────

func test_get_pickup_range_matches_stat() -> void:
	var p = _make_player()
	assert_almost_eq(p.get_pickup_range(), 48.0, 0.001, "pickup_range should match StatBlock default")

# ── setup() initial HP emission ──────────────────────────────────────────────

func test_setup_emits_initial_player_hp_changed() -> void:
	# Watch BEFORE setup() so the initial emission is captured.
	var player = add_child_autofree(PlayerScene.instantiate())
	watch_signals(GameEvents)
	player.setup(_make_char_data(80.0, 0.0))  # full HP at start: (max_hp, max_hp)
	assert_signal_emitted_with_parameters(GameEvents, "player_hp_changed", [80.0, 80.0])
