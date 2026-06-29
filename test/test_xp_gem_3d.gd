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
# magnet_step — pure static helper
# ---------------------------------------------------------------------------

func test_magnet_step_returns_zero_when_outside_range() -> void:
	var gem_pos    := Vector3(10.0, 0.0, 0.0)
	var player_pos := Vector3.ZERO
	var delta := XPGem3D.magnet_step(gem_pos, player_pos, 5.0, 0.016)
	assert_eq(delta, Vector3.ZERO,
			"magnet_step should return zero when dist > pickup_range")

func test_magnet_step_returns_nonzero_when_within_range() -> void:
	var gem_pos    := Vector3(3.0, 0.0, 0.0)
	var player_pos := Vector3.ZERO
	var delta := XPGem3D.magnet_step(gem_pos, player_pos, 5.0, 0.016)
	assert_true(delta.length() > 0.0,
			"magnet_step should return non-zero delta when within pickup_range")

func test_magnet_step_y_component_always_zero() -> void:
	# Gem at a different height than player — y must be zeroed.
	var gem_pos    := Vector3(2.0, 5.0, 0.0)
	var player_pos := Vector3(0.0, 0.0, 0.0)
	var delta := XPGem3D.magnet_step(gem_pos, player_pos, 10.0, 0.1)
	assert_almost_eq(delta.y, 0.0, 0.001,
			"magnet y-component must always be 0 (XZ plane movement)")

func test_magnet_step_moves_toward_player() -> void:
	# Gem is at +X, player at origin → delta.x should be negative (moving toward origin).
	var gem_pos    := Vector3(3.0, 0.0, 0.0)
	var player_pos := Vector3.ZERO
	var delta := XPGem3D.magnet_step(gem_pos, player_pos, 5.0, 1.0)
	assert_true(delta.x < 0.0,
			"gem to the +X of player should move in -X direction toward player")
	assert_almost_eq(delta.y, 0.0, 0.001, "y must stay 0")

func test_magnet_step_faster_when_closer() -> void:
	# At dist ≈ 0.5 the lerp t is high → faster than at dist ≈ 4.9.
	var player_pos := Vector3.ZERO
	var dt := 1.0
	var delta_far   := XPGem3D.magnet_step(Vector3(4.9, 0.0, 0.0), player_pos, 5.0, dt)
	var delta_close := XPGem3D.magnet_step(Vector3(0.5, 0.0, 0.0), player_pos, 5.0, dt)
	assert_true(delta_close.length() > delta_far.length(),
			"gem closer to player should move faster (magnet accelerates)")

func test_magnet_step_boundary_at_exact_range_is_nonzero() -> void:
	# dist == pickup_range: t = clamp(1 - 1, 0, 1) = 0 → speed = MAGNET_SPEED_MIN (4.0)
	var delta := XPGem3D.magnet_step(Vector3(5.0, 0.0, 0.0), Vector3.ZERO, 5.0, 1.0)
	assert_true(delta.length() > 0.0,
			"at exactly pickup_range distance the gem should still move")

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
