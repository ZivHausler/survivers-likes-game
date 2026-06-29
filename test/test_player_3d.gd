# See docs/notes/player-3d.md
extends GutTest
## Unit tests for Player3D logic (leveling, damage, armor, stat upgrades, velocity mapping).
## Mirrors test_player.gd coverage against the CharacterBody3D implementation.

var Player3DScene = null

func before_all() -> void:
	Player3DScene = load("res://player/player_3d.tscn")

func _make_char_data(max_hp: float = 100.0, armor: float = 0.0, pickup_range: float = 48.0) -> CharacterData:
	var sb := StatBlock.new()
	sb.max_hp = max_hp
	sb.armor = armor
	sb.pickup_range = pickup_range
	sb.move_speed = 120.0
	var cd := CharacterData.new()
	cd.base_stats = sb
	# weapon_scene intentionally null — Player3D.setup() guards with: if data.weapon_scene
	return cd

func _make_player(max_hp: float = 100.0, armor: float = 0.0) -> Player3D:
	assert_not_null(Player3DScene, "player_3d.tscn must exist before running tests")
	var player: Player3D = add_child_autofree(Player3DScene.instantiate())
	player.setup(_make_char_data(max_hp, armor))
	return player

# ── move_to_velocity (pure static, no Input/tree needed) ─────────────────────

func test_move_to_velocity_up_maps_to_negative_z() -> void:
	var v := Player3D.move_to_velocity(Vector2(0.0, -1.0), 100.0)
	assert_almost_eq(v.x, 0.0, 0.001, "x should be 0")
	assert_almost_eq(v.y, 0.0, 0.001, "y must stay 0 (XZ plane)")
	assert_almost_eq(v.z, -100.0, 0.001, "'up' action maps to -Z")

func test_move_to_velocity_right_maps_to_positive_x() -> void:
	var v := Player3D.move_to_velocity(Vector2(1.0, 0.0), 120.0)
	assert_almost_eq(v.x, 120.0, 0.001, "'right' action maps to +X")
	assert_almost_eq(v.y, 0.0, 0.001, "y must stay 0")
	assert_almost_eq(v.z, 0.0, 0.001, "z should be 0")

func test_move_to_velocity_diagonal() -> void:
	var v := Player3D.move_to_velocity(Vector2(1.0, 1.0), 10.0)
	assert_almost_eq(v.x, 10.0, 0.001)
	assert_almost_eq(v.y, 0.0, 0.001, "y must stay 0")
	assert_almost_eq(v.z, 10.0, 0.001)

func test_move_to_velocity_zero_dir_gives_zero_vector() -> void:
	assert_eq(Player3D.move_to_velocity(Vector2.ZERO, 120.0), Vector3.ZERO)

# ── xp_to_next formula ──────────────────────────────────────────────────────

func test_xp_to_next_level1() -> void:
	var p := _make_player()
	assert_eq(p.xp_to_next(1), 10, "5 + 1*3 + 1*1*2 = 10")

func test_xp_to_next_level2() -> void:
	var p := _make_player()
	assert_eq(p.xp_to_next(2), 19, "5 + 2*3 + 2*2*2 = 19")

func test_xp_to_next_level3() -> void:
	var p := _make_player()
	assert_eq(p.xp_to_next(3), 32, "5 + 3*3 + 3*3*2 = 32")

func test_xp_to_next_level5() -> void:
	var p := _make_player()
	assert_eq(p.xp_to_next(5), 70, "5 + 5*3 + 5*5*2 = 70")

# ── add_xp leveling ──────────────────────────────────────────────────────────

func test_add_xp_exact_single_level_up() -> void:
	var p := _make_player()
	p.add_xp(10)  # xp_to_next(1) = 10 exactly
	assert_eq(p.level, 2, "Should advance to level 2")
	assert_eq(p.xp, 0, "No remainder after exact threshold")

func test_add_xp_multi_level_up_with_remainder() -> void:
	var p := _make_player()
	# level 1→2 costs 10, level 2→3 costs 19; total = 29; give 30 → 1 remainder
	p.add_xp(30)
	assert_eq(p.level, 3, "Should advance two levels")
	assert_eq(p.xp, 1, "Remainder 1 should carry over")

func test_add_xp_partial_no_level_up() -> void:
	var p := _make_player()
	p.add_xp(5)  # less than xp_to_next(1) = 10
	assert_eq(p.level, 1, "Should still be level 1")
	assert_eq(p.xp, 5, "XP should accumulate")

func test_add_xp_emits_player_leveled_up() -> void:
	var p := _make_player()
	watch_signals(GameEvents)
	p.add_xp(10)
	assert_signal_emitted(GameEvents, "player_leveled_up")

# ── take_damage ──────────────────────────────────────────────────────────────

func test_take_damage_subtracts_armor() -> void:
	var p := _make_player(100.0, 5.0)
	p.take_damage(20.0)  # dealt = max(0, 20 - 5) = 15
	assert_almost_eq(p.hp, 85.0, 0.001, "hp should be 85 after 15 dealt damage")

func test_take_damage_blocked_entirely_by_armor() -> void:
	var p := _make_player(100.0, 10.0)
	p.take_damage(5.0)  # dealt = max(0, 5 - 10) = 0
	assert_almost_eq(p.hp, 100.0, 0.001, "Armor fully blocks damage below armor value")

func test_take_damage_emits_player_hp_changed_with_values() -> void:
	var p := _make_player(100.0, 0.0)
	watch_signals(GameEvents)
	p.take_damage(30.0)  # hp: 100 → 70
	assert_signal_emitted_with_parameters(GameEvents, "player_hp_changed", [70.0, 100.0])

func test_take_damage_emits_player_died_at_zero() -> void:
	var p := _make_player(100.0, 0.0)
	watch_signals(GameEvents)
	p.take_damage(100.0)
	assert_signal_emitted(GameEvents, "player_died")

func test_take_damage_emits_player_died_on_overkill() -> void:
	var p := _make_player(100.0, 0.0)
	watch_signals(GameEvents)
	p.take_damage(999.0)
	assert_signal_emitted(GameEvents, "player_died")

# ── get_pickup_range ─────────────────────────────────────────────────────────

func test_get_pickup_range_matches_stat() -> void:
	var p := _make_player()
	assert_almost_eq(p.get_pickup_range(), 48.0, 0.001)

# ── setup() ──────────────────────────────────────────────────────────────────

func test_setup_emits_initial_player_hp_changed() -> void:
	var player: Player3D = add_child_autofree(Player3DScene.instantiate())
	watch_signals(GameEvents)
	player.setup(_make_char_data(80.0, 0.0))
	assert_signal_emitted_with_parameters(GameEvents, "player_hp_changed", [80.0, 80.0])

func test_setup_null_weapon_scene_leaves_weapon_null() -> void:
	var p := _make_player()
	assert_null(p.weapon, "weapon must remain null when weapon_scene is null")

# ── apply_stat_upgrade ───────────────────────────────────────────────────────

func test_apply_stat_upgrade_move_speed() -> void:
	var p := _make_player()
	var before := p.stats.move_speed
	p.apply_stat_upgrade(&"move_speed", 10.0)
	assert_almost_eq(p.stats.move_speed, before + 10.0, 0.001)

func test_apply_stat_upgrade_max_hp_raises_stat_and_current_hp() -> void:
	var p := _make_player(100.0, 0.0)
	watch_signals(GameEvents)
	p.apply_stat_upgrade(&"max_hp", 20.0)
	assert_almost_eq(p.stats.max_hp, 120.0, 0.001)
	assert_almost_eq(p.hp, 120.0, 0.001)
	assert_signal_emitted(GameEvents, "player_hp_changed")

func test_apply_stat_upgrade_pickup_range() -> void:
	var p := _make_player()
	p.apply_stat_upgrade(&"pickup_range", 5.0)
	assert_almost_eq(p.stats.pickup_range, 53.0, 0.001)

func test_apply_stat_upgrade_fire_rate() -> void:
	var p := _make_player()
	var before := p.stats.fire_rate_mult
	p.apply_stat_upgrade(&"fire_rate", 0.5)
	assert_almost_eq(p.stats.fire_rate_mult, before + 0.5, 0.001)

func test_apply_stat_upgrade_damage() -> void:
	var p := _make_player()
	var before := p.stats.damage_mult
	p.apply_stat_upgrade(&"damage", 0.2)
	assert_almost_eq(p.stats.damage_mult, before + 0.2, 0.001)

func test_apply_stat_upgrade_armor() -> void:
	var p := _make_player()
	p.apply_stat_upgrade(&"armor", 3.0)
	assert_almost_eq(p.stats.armor, 3.0, 0.001)
