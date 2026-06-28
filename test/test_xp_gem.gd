extends GutTest
## Unit tests for XPGem collection logic.
## Magnet movement is interactive-only (manual playtest required — see task-2B-report.md).

# ---------------------------------------------------------------------------
# Stub player: Node2D in group "player" with the two methods XPGem calls.
# ---------------------------------------------------------------------------
class StubPlayer extends Node2D:
	var xp_total: int = 0

	func get_pickup_range() -> float:
		return 9999.0  # always within magnet range

	func add_xp(amount: int) -> void:
		xp_total += amount

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------
var GemScene = null
var _player: StubPlayer

func before_all() -> void:
	GemScene = load("res://pickups/xp_gem.tscn")

func before_each() -> void:
	_player = add_child_autofree(StubPlayer.new())
	_player.add_to_group("player")

func _make_gem(value: int) -> XPGem:
	var gem: XPGem = add_child_autofree(GemScene.instantiate())
	gem.setup(value, _player)
	return gem

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

func test_collect_adds_xp_to_player() -> void:
	var gem := _make_gem(10)
	gem._collect()
	assert_eq(_player.xp_total, 10, "Player should receive 10 XP on first collection")

func test_collect_emits_xp_collected_signal() -> void:
	var gem := _make_gem(5)
	watch_signals(GameEvents)
	gem._collect()
	assert_signal_emitted_with_parameters(GameEvents, "xp_collected", [5])

func test_no_double_collection() -> void:
	var gem := _make_gem(10)
	gem._collect()
	gem._collect()  # second call must be a no-op
	assert_eq(_player.xp_total, 10, "XP must only be added once even if _collect() is called twice")

func test_collect_safe_with_null_player() -> void:
	var gem := _make_gem(7)
	gem._player = null  # simulate freed/null player
	gem._collect()      # must not crash
	assert_true(gem._collected, "Gem should still mark itself collected even with null player")
