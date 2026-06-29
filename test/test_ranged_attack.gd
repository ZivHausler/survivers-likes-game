# See docs/notes/enemy-attacks.md
extends GutTest

func test_approach_advances_when_far() -> void:
	# enemy far beyond attack_range → move toward target
	var v := RangedAttack.approach_velocity(Vector3.ZERO, Vector3(30, 0, 0), 12.0, 5.0)
	assert_true(v.x > 0.0, "far enemy moves toward target (+X)")

func test_approach_holds_when_too_close() -> void:
	# enemy well inside attack_range → hold position (no retreat)
	var v := RangedAttack.approach_velocity(Vector3(2, 0, 0), Vector3(0, 0, 0), 12.0, 5.0)
	assert_true(v.length() < 0.01, "too-close enemy holds position (no kite retreat)")

func test_approach_holds_within_range() -> void:
	# at roughly attack_range → hold (zero velocity)
	var v := RangedAttack.approach_velocity(Vector3(12, 0, 0), Vector3(0, 0, 0), 12.0, 5.0)
	assert_true(v.length() < 0.01, "enemy holds position when within attack_range")

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

func test_holding_enemy_fires_within_range() -> void:
	# Confirm approach threshold and fire threshold are consistent:
	# an enemy at exactly attack_range holds (zero velocity) and can fire.
	var attack_range := 12.0
	var speed := 5.0
	var enemy_pos := Vector3(attack_range, 0, 0)
	var target_pos := Vector3.ZERO
	var v := RangedAttack.approach_velocity(enemy_pos, target_pos, attack_range, speed)
	assert_true(v.length() < 0.01, "at attack_range: hold (zero velocity)")
	var ra := RangedAttack.new()
	assert_true(ra._can_fire(attack_range, true, attack_range), "at attack_range: can fire")
