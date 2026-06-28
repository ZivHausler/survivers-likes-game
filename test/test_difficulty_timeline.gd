# See docs/notes/difficulty-timeline.md
extends GutTest
## Unit tests for DifficultyTimeline pure logic.
## Interactive verification (enemy streaming, boss appearance) requires a playtest scene — see docs/notes/spawner.md.

var tl: DifficultyTimeline

func before_each() -> void:
	tl = DifficultyTimeline.new()

# ── spawn_interval decreases over time ───────────────────────────────────────

func test_interval_strictly_decreasing_from_0_to_240() -> void:
	var i0: float = tl.state_at(0.0).spawn_interval
	var i240: float = tl.state_at(240.0).spawn_interval
	assert_true(i0 > i240, "spawn_interval at t=0 must be greater than at t=240")

func test_interval_is_clamped_to_floor() -> void:
	var floor_val: float = tl.state_at(0.0).spawn_interval  # get any reference to confirm floor exists
	# At a very large t, interval must not go below the documented floor (0.25s)
	var huge: float = tl.state_at(9999.0).spawn_interval
	assert_true(huge >= 0.25, "spawn_interval must not go below 0.25s floor")

func test_interval_does_not_go_negative() -> void:
	assert_true(tl.state_at(9999.0).spawn_interval > 0.0, "spawn_interval must always be positive")

# ── allowed_variants thresholds ──────────────────────────────────────────────

func test_swarmer_present_at_t0() -> void:
	var v: Array = tl.state_at(0.0).allowed_variants
	assert_true(&"swarmer" in v, "swarmer must be allowed at t=0")

func test_tank_not_present_at_t10() -> void:
	var v: Array = tl.state_at(10.0).allowed_variants
	assert_false(&"tank" in v, "tank must NOT be allowed at t=10 (threshold is 60s)")

func test_tank_present_at_t90() -> void:
	var v: Array = tl.state_at(90.0).allowed_variants
	assert_true(&"tank" in v, "tank must be allowed at t=90 (threshold passed at 60s)")

func test_spitter_not_present_at_t50() -> void:
	var v: Array = tl.state_at(50.0).allowed_variants
	assert_false(&"spitter" in v, "spitter must NOT be allowed at t=50 (threshold is 120s)")

func test_spitter_present_at_t130() -> void:
	var v: Array = tl.state_at(130.0).allowed_variants
	assert_true(&"spitter" in v, "spitter must be allowed at t=130 (threshold passed at 120s)")

# ── boss_due ─────────────────────────────────────────────────────────────────

func test_boss_not_due_at_t0() -> void:
	assert_false(tl.state_at(0.0).boss_due, "boss must not be due at t=0")

func test_boss_due_near_t300() -> void:
	# Feed elapsed time values near the 300s boundary
	# Simulate: boss not yet spawned, t just crossed 300
	var s: Dictionary = tl.state_at(300.0)
	assert_true(s.boss_due, "boss_due must be true when t reaches 300s")

func test_boss_due_true_at_t301() -> void:
	var s: Dictionary = tl.state_at(301.0)
	assert_true(s.boss_due, "boss_due must still be true just past 300s (before reset)")

func test_mark_boss_spawned_clears_flag_within_same_window() -> void:
	# First call at 305s sets flag
	var before: Dictionary = tl.state_at(305.0)
	assert_true(before.boss_due, "boss_due should be true at 305s")
	# Caller marks boss as spawned
	tl.mark_boss_spawned()
	# Another query within the same 300s window must NOT re-trigger
	var after: Dictionary = tl.state_at(305.0)
	assert_false(after.boss_due, "boss_due must be false after mark_boss_spawned() within the same window")

func test_boss_due_again_at_600s() -> void:
	tl.mark_boss_spawned()
	# Move to the next 300s window
	var s: Dictionary = tl.state_at(600.0)
	assert_true(s.boss_due, "boss_due must be true again at t=600s (second 300s boundary)")

func test_mark_boss_spawned_at_600_clears_again() -> void:
	tl.mark_boss_spawned()          # clear first window
	var before: Dictionary = tl.state_at(600.0)
	assert_true(before.boss_due)
	tl.mark_boss_spawned()          # clear second window
	var after: Dictionary = tl.state_at(600.0)
	assert_false(after.boss_due, "boss_due must be false after second mark_boss_spawned()")
