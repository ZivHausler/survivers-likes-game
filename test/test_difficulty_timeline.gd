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

func test_interval_starts_at_start_value() -> void:
	assert_almost_eq(tl.state_at(0.0).spawn_interval, 3.0, 0.001,
		"spawn_interval at t=0 must equal the start value (3.0s)")

func test_interval_is_clamped_to_floor() -> void:
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

# ── mini-boss boss_due (every 180 s) ─────────────────────────────────────────

func test_boss_not_due_at_t0() -> void:
	assert_false(tl.state_at(0.0).boss_due, "boss must not be due at t=0")

func test_boss_due_near_t180() -> void:
	var s: Dictionary = tl.state_at(180.0)
	assert_true(s.boss_due, "boss_due must be true when t reaches 180s (mini-boss period)")

func test_boss_due_true_at_t181() -> void:
	var s: Dictionary = tl.state_at(181.0)
	assert_true(s.boss_due, "boss_due must still be true just past 180s (before reset)")

func test_mark_boss_spawned_clears_flag_within_same_window() -> void:
	# First call at 185s sets flag
	var before: Dictionary = tl.state_at(185.0)
	assert_true(before.boss_due, "boss_due should be true at 185s")
	# Caller marks boss as spawned
	tl.mark_boss_spawned()
	# Another query within the same 180s window must NOT re-trigger
	var after: Dictionary = tl.state_at(185.0)
	assert_false(after.boss_due, "boss_due must be false after mark_boss_spawned() within the same window")

func test_boss_due_again_at_next_window_sequential_flow() -> void:
	# Realistic per-frame flow across consecutive windows (no skipped boundaries).
	# Window 1 (180s): becomes due, gets acknowledged, stays clear.
	assert_true(tl.state_at(185.0).boss_due, "boss_due true at 185s (window 1)")
	tl.mark_boss_spawned()
	assert_false(tl.state_at(190.0).boss_due, "boss_due false after mark within window 1")
	# Window 2 (360s): crossing the next boundary re-triggers exactly once.
	assert_true(tl.state_at(365.0).boss_due, "boss_due true at 365s (window 2)")

func test_consecutive_windows_each_trigger_once() -> void:
	# Walk windows 1 → 2 → 3 in order; each must trigger exactly once then clear.
	assert_true(tl.state_at(185.0).boss_due, "window 1 due")
	tl.mark_boss_spawned()
	assert_false(tl.state_at(190.0).boss_due, "window 1 cleared")

	assert_true(tl.state_at(365.0).boss_due, "window 2 due")
	tl.mark_boss_spawned()
	assert_false(tl.state_at(370.0).boss_due, "window 2 cleared")

	assert_true(tl.state_at(545.0).boss_due, "window 3 due")
	tl.mark_boss_spawned()
	assert_false(tl.state_at(550.0).boss_due, "window 3 cleared")

# ── hp_mult grows with time ───────────────────────────────────────────────────

func test_hp_mult_is_1_at_t0() -> void:
	assert_almost_eq(tl.state_at(0.0).hp_mult, 1.0, 0.001,
		"hp_mult must be ~1.0 at t=0 (no boost at start)")

func test_hp_mult_strictly_increases() -> void:
	var m0: float   = tl.state_at(0.0).hp_mult
	var m120: float = tl.state_at(120.0).hp_mult
	var m300: float = tl.state_at(300.0).hp_mult
	var m600: float = tl.state_at(600.0).hp_mult
	assert_true(m0 < m120 and m120 < m300 and m300 < m600,
		"hp_mult must strictly increase with time")

func test_hp_mult_doubles_at_t120() -> void:
	assert_almost_eq(tl.state_at(120.0).hp_mult, 2.0, 0.001,
		"hp_mult must be 2.0 at t=120 (doubles every 2 min)")

func test_hp_mult_is_approx_6_at_t600() -> void:
	assert_almost_eq(tl.state_at(600.0).hp_mult, 6.0, 0.001,
		"hp_mult must be ~6.0 at t=600 (10 min)")

# ── enemy_scale grows modestly ────────────────────────────────────────────────

func test_enemy_scale_is_1_at_t0() -> void:
	assert_almost_eq(tl.state_at(0.0).enemy_scale, 1.0, 0.001,
		"enemy_scale must be 1.0 at t=0")

func test_enemy_scale_strictly_increases() -> void:
	var s0: float   = tl.state_at(0.0).enemy_scale
	var s300: float = tl.state_at(300.0).enemy_scale
	var s600: float = tl.state_at(600.0).enemy_scale
	assert_true(s0 < s300 and s300 < s600,
		"enemy_scale must increase over time")

func test_enemy_scale_is_at_most_1_5_at_t600() -> void:
	# Ensure growth stays modest (not absurd)
	var s600: float = tl.state_at(600.0).enemy_scale
	assert_almost_eq(s600, 1.5, 0.001, "enemy_scale must be ~1.5 at t=600")
	assert_true(s600 <= 2.0, "enemy_scale must remain <= 2.0 at t=600 (keep subtle)")

# ── big_boss_due (fires once at t >= 600) ────────────────────────────────────

func test_big_boss_not_due_before_t600() -> void:
	assert_false(tl.state_at(0.0).big_boss_due,   "big_boss_due must be false at t=0")
	assert_false(tl.state_at(300.0).big_boss_due, "big_boss_due must be false at t=300")
	assert_false(tl.state_at(599.0).big_boss_due, "big_boss_due must be false at t=599")

func test_big_boss_due_at_t600() -> void:
	assert_true(tl.state_at(600.0).big_boss_due, "big_boss_due must be true at t=600")

func test_big_boss_due_at_t601() -> void:
	assert_true(tl.state_at(601.0).big_boss_due, "big_boss_due must be true just past t=600 (before ack)")

func test_mark_big_boss_spawned_clears_flag_permanently() -> void:
	var before: Dictionary = tl.state_at(605.0)
	assert_true(before.big_boss_due, "big_boss_due must be true at t=605")
	tl.mark_big_boss_spawned()
	# Must not re-trigger at any future time
	assert_false(tl.state_at(605.0).big_boss_due,  "big_boss_due must be false after ack (same t)")
	assert_false(tl.state_at(900.0).big_boss_due,  "big_boss_due must be false at t=900 after ack")
	assert_false(tl.state_at(9999.0).big_boss_due, "big_boss_due must never re-fire")

func test_big_boss_fires_only_once() -> void:
	# Simulate per-frame queries: first query triggers, then never again
	var fired: int = 0
	for i in range(595, 610):
		var s: Dictionary = tl.state_at(float(i))
		if s.big_boss_due:
			fired += 1
			tl.mark_big_boss_spawned()
	assert_eq(fired, 1, "big boss must fire exactly once across the 600s boundary")
