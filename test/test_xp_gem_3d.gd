# See docs/notes/xp-gem-3d.md
extends GutTest
## Unit tests for XPGem3D.
## Magnet movement is XZ-only; magnet_step() is a pure static helper for testability.
## Collection logic mirrors test_xp_gem.gd (2D) verbatim.

# ---------------------------------------------------------------------------
# Stub player: Node3D in group "player" with the two methods XPGem3D calls.
# ---------------------------------------------------------------------------
class StubPlayer3D extends Node3D:
	var xp_total: int = 0
	var _pickup_range: float = 9999.0

	func get_pickup_range() -> float:
		return _pickup_range

	func add_xp(amount: int) -> void:
		xp_total += amount

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
var GemScene = null
var _player: StubPlayer3D

func before_all() -> void:
	GemScene = load("res://pickups/xp_gem_3d.tscn")

func before_each() -> void:
	_player = add_child_autofree(StubPlayer3D.new())
	_player.add_to_group("player")

func _make_gem(value: int) -> XPGem3D:
	var gem: XPGem3D = add_child_autofree(GemScene.instantiate())
	gem.setup(value, _player)
	return gem

# ---------------------------------------------------------------------------
# in_pickup_range — latch gate
# ---------------------------------------------------------------------------

func test_in_pickup_range_false_when_outside() -> void:
	assert_false(XPGem3D.in_pickup_range(Vector3(10.0, 0.0, 0.0), Vector3.ZERO, 5.0),
			"gem beyond pickup_range must not be in range")

func test_in_pickup_range_true_when_inside() -> void:
	assert_true(XPGem3D.in_pickup_range(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 5.0),
			"gem within pickup_range must be in range")

func test_in_pickup_range_ignores_height() -> void:
	# A tall Y gap must not push a horizontally-close gem out of range.
	assert_true(XPGem3D.in_pickup_range(Vector3(1.0, 50.0, 0.0), Vector3.ZERO, 5.0),
			"range check is XZ-only; Y difference must be ignored")

# ---------------------------------------------------------------------------
# next_magnet_speed — acceleration ramp
# ---------------------------------------------------------------------------

func test_next_magnet_speed_accelerates() -> void:
	var s := XPGem3D.next_magnet_speed(XPGem3D.MAGNET_SPEED_MIN, 0.1)
	assert_gt(s, XPGem3D.MAGNET_SPEED_MIN, "magnet speed must increase each step")

func test_next_magnet_speed_caps_at_max() -> void:
	var s := XPGem3D.next_magnet_speed(XPGem3D.MAGNET_SPEED_MAX, 1.0)
	assert_almost_eq(s, XPGem3D.MAGNET_SPEED_MAX, 0.001,
			"magnet speed must not exceed MAGNET_SPEED_MAX")

func test_peak_magnet_speed_beats_player() -> void:
	# The whole point: a latched gem must be able to out-run the player.
	# Player base move speeds are ~8 u/s; peak magnet speed must clear that with margin.
	assert_gt(XPGem3D.MAGNET_SPEED_MAX, 20.0,
			"peak magnet speed must comfortably exceed any player move speed")

# ---------------------------------------------------------------------------
# magnet_delta — homing step
# ---------------------------------------------------------------------------

func test_magnet_delta_y_component_always_zero() -> void:
	var delta := XPGem3D.magnet_delta(Vector3(2.0, 5.0, 0.0), Vector3.ZERO, 10.0, 0.1)
	assert_almost_eq(delta.y, 0.0, 0.001, "magnet y-component must always be 0 (XZ plane)")

func test_magnet_delta_moves_toward_player() -> void:
	var delta := XPGem3D.magnet_delta(Vector3(3.0, 0.0, 0.0), Vector3.ZERO, 5.0, 0.1)
	assert_true(delta.x < 0.0, "gem at +X must move in -X toward the player")

func test_magnet_delta_lands_exactly_when_overshooting() -> void:
	# Big step (speed*dt >> dist) must land on the player, not overshoot past it.
	var gem_pos := Vector3(1.0, 0.0, 0.0)
	var delta := XPGem3D.magnet_delta(gem_pos, Vector3.ZERO, 100.0, 1.0)
	assert_almost_eq((gem_pos + delta).length(), 0.0, 0.001,
			"an overshooting step must land exactly on the player (no tunnelling)")

func test_magnet_delta_zero_at_player() -> void:
	var delta := XPGem3D.magnet_delta(Vector3.ZERO, Vector3.ZERO, 10.0, 0.1)
	assert_eq(delta, Vector3.ZERO, "no movement when already on the player")

# ---------------------------------------------------------------------------
# Latch + acceleration integration — the fast-player regression
# ---------------------------------------------------------------------------

func test_gem_catches_fast_moving_player_after_latch() -> void:
	# Reproduces the bug: player moving faster than the initial magnet speed.
	# Once latched, the gem must accelerate and eventually collect regardless.
	_player._pickup_range = 5.0
	_player.global_position = Vector3.ZERO
	var gem := _make_gem(7)
	gem.global_position = Vector3(3.0, 0.0, 0.0)  # inside pickup range → will latch
	# Drive the player away at 12 u/s (faster than MAGNET_SPEED_MIN=4) for up to 3 s.
	var dt := 1.0 / 60.0
	for i in range(180):
		_player.global_position += Vector3(12.0 * dt, 0.0, 0.0)
		gem._process(dt)
		if gem._collected:
			break
	assert_true(gem._collected,
			"a latched gem must catch and collect even a player fleeing faster than MAGNET_SPEED_MIN")

func test_gem_latches_and_stays_latched_when_player_flees_out_of_range() -> void:
	_player._pickup_range = 5.0
	_player.global_position = Vector3.ZERO
	var gem := _make_gem(3)
	gem.global_position = Vector3(4.0, 0.0, 0.0)  # in range → latches on first process
	gem._process(1.0 / 60.0)
	assert_true(gem._magnetized, "gem must latch once inside pickup range")
	# Teleport player far away (beyond range). Latch must persist and keep homing.
	_player.global_position = Vector3(100.0, 0.0, 0.0)
	gem._process(1.0 / 60.0)
	assert_true(gem._magnetized,
			"gem must remain magnetized even after the player leaves pickup range")

# ---------------------------------------------------------------------------
# _collect() — collection logic
# ---------------------------------------------------------------------------

func test_collect_adds_xp_to_player() -> void:
	var gem := _make_gem(10)
	gem._collect()
	assert_eq(_player.xp_total, 10,
			"Player should receive 10 XP on first collection")

func test_collect_emits_xp_collected_signal() -> void:
	var gem := _make_gem(5)
	watch_signals(GameEvents)
	gem._collect()
	assert_signal_emitted_with_parameters(GameEvents, "xp_collected", [5])

func test_no_double_collection() -> void:
	var gem := _make_gem(10)
	gem._collect()
	gem._collect()  # second call must be a no-op
	assert_eq(_player.xp_total, 10,
			"XP must only be added once even if _collect() is called twice")

func test_collect_sets_collected_flag() -> void:
	var gem := _make_gem(7)
	gem._collect()
	assert_true(gem._collected, "Gem must mark itself collected")

func test_collect_safe_with_null_player() -> void:
	var gem := _make_gem(7)
	gem._player = null  # simulate freed/null player
	gem._collect()      # must not crash
	assert_true(gem._collected,
			"Gem should still mark itself collected even with null player")

func test_second_collect_is_noop_for_xp() -> void:
	var gem := _make_gem(20)
	gem._collect()
	var xp_after_first := _player.xp_total
	gem._collect()
	assert_eq(_player.xp_total, xp_after_first,
			"Second _collect() must not add more XP")
