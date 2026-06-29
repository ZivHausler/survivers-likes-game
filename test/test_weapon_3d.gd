# See docs/notes/weapon-system-3d.md
extends GutTest
## Unit tests for Weapon3D base class.
## Mirrors the 2D Weapon behavior: timer cooldown formula, level/evolve lifecycle.
## Weapon3D is instantiated directly (no scene file needed — it is a plain Node3D).

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _make_stats(dmg: float = 1.0, rate: float = 1.0) -> StatBlock:
	var s := StatBlock.new()
	s.damage_mult    = dmg
	s.fire_rate_mult = rate
	return s

func _make_weapon(base_cd: float = 2.0, rate: float = 1.0) -> Weapon3D:
	var w: Weapon3D = add_child_autofree(Weapon3D.new()) as Weapon3D
	var player: Node3D = add_child_autofree(Node3D.new()) as Node3D
	w.base_cooldown = base_cd
	w.setup(player, _make_stats(1.0, rate))
	return w

# ─────────────────────────────────────────────────────────────────────────────
# Cooldown formula: max(0.05, base_cooldown / fire_rate_mult)
# ─────────────────────────────────────────────────────────────────────────────

func test_cooldown_formula_base_case() -> void:
	var w := _make_weapon(2.0, 1.0)
	assert_almost_eq(w._timer.wait_time, 2.0, 0.001,
		"wait_time should equal base_cooldown when fire_rate_mult=1")

func test_cooldown_formula_with_rate_multiplier() -> void:
	var w := _make_weapon(4.0, 2.0)
	assert_almost_eq(w._timer.wait_time, 2.0, 0.001,
		"wait_time should be base_cooldown/fire_rate_mult")

func test_cooldown_clamps_to_minimum() -> void:
	var w := _make_weapon(0.01, 1000.0)
	assert_almost_eq(w._timer.wait_time, 0.05, 0.001,
		"wait_time must not fall below 0.05 (minimum)")

func test_refresh_cooldown_updates_timer() -> void:
	var w := _make_weapon(2.0, 1.0)
	w.stats.fire_rate_mult = 4.0
	w.refresh_cooldown()
	assert_almost_eq(w._timer.wait_time, 0.5, 0.001,
		"refresh_cooldown must recalculate wait_time from current stats")

# ─────────────────────────────────────────────────────────────────────────────
# level_up()
# ─────────────────────────────────────────────────────────────────────────────

func test_starts_at_level_1() -> void:
	var w := _make_weapon()
	assert_eq(w.level, 1, "weapon should start at level 1")

func test_level_up_increments_level() -> void:
	var w := _make_weapon()
	w.level_up()
	assert_eq(w.level, 2, "level must be 2 after one level_up")

func test_level_up_refreshes_cooldown() -> void:
	var w := _make_weapon(2.0, 1.0)
	w.stats.fire_rate_mult = 2.0   # change rate before level_up
	w.level_up()
	assert_almost_eq(w._timer.wait_time, 1.0, 0.001,
		"level_up must refresh cooldown to reflect current stats")

# ─────────────────────────────────────────────────────────────────────────────
# evolve() and is_max_level()
# ─────────────────────────────────────────────────────────────────────────────

func test_evolved_starts_false() -> void:
	var w := _make_weapon()
	assert_false(w.evolved, "evolved must start false")

func test_evolve_sets_flag() -> void:
	var w := _make_weapon()
	w.evolve()
	assert_true(w.evolved, "evolved must be true after evolve()")

func test_is_not_max_at_level_1() -> void:
	var w := _make_weapon()
	assert_false(w.is_max_level(5), "level 1 weapon should not be at max level 5")

func test_is_max_after_enough_level_ups() -> void:
	var w := _make_weapon()
	for _i in range(4):   # 4 level-ups: 1 → 5
		w.level_up()
	assert_true(w.is_max_level(5),
		"should be max level 5 after 4 level_ups from level 1")

func test_apply_passive_is_noop_on_base() -> void:
	# Base Weapon3D.apply_passive is a no-op; calling it must not crash.
	var w := _make_weapon()
	w.apply_passive(1.0)
	assert_true(true, "apply_passive on base Weapon3D must not crash")
