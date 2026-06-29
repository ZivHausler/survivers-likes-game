# See docs/notes/enemy-attacks.md
extends GutTest

func test_kite_advances_when_far() -> void:
	# enemy far beyond attack_range → move toward target
	var v := RangedAttack.kite_velocity(Vector3.ZERO, Vector3(30, 0, 0), 12.0, 5.0)
	assert_true(v.x > 0.0, "far enemy moves toward target (+X)")

func test_kite_backs_off_when_too_close() -> void:
	# enemy well inside attack_range → retreat (away from target)
	var v := RangedAttack.kite_velocity(Vector3(2, 0, 0), Vector3(0, 0, 0), 12.0, 5.0)
	assert_true(v.x > 0.0, "too-close enemy retreats away from target (+X, away from origin)")

func test_kite_holds_in_band() -> void:
	# at roughly attack_range → ~hold (near-zero speed)
	var v := RangedAttack.kite_velocity(Vector3(12, 0, 0), Vector3(0, 0, 0), 12.0, 5.0)
	assert_true(v.length() <= 1.0, "enemy holds position within the standoff band")

func test_should_fire_requires_range_los_and_cooldown() -> void:
	var ra := RangedAttack.new()
	# in range + LOS clear + cooldown ready → can fire
	assert_true(ra._can_fire(10.0, true, 12.0), "fires when in range, LOS clear, cd ready")
	# out of range
	assert_false(ra._can_fire(40.0, true, 12.0), "no fire out of attack_range")
	# blocked LOS
	assert_false(ra._can_fire(10.0, false, 12.0), "no fire when LOS blocked (terrain cover)")

func test_cooldown_blocks_refire() -> void:
	var ra := RangedAttack.new()
	ra._cooldown_left = 1.0
	assert_false(ra._ready_to_fire(), "cooldown blocks immediate refire")
	ra._cooldown_left = 0.0
	assert_true(ra._ready_to_fire(), "fires once cooldown elapsed")
