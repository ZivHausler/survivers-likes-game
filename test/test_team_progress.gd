extends GutTest

func test_xp_curve_mirrors_player():
	# 2 + lvl + lvl*lvl
	assert_eq(TeamProgress.xp_to_next(1), 4)
	assert_eq(TeamProgress.xp_to_next(2), 8)
	assert_eq(TeamProgress.xp_to_next(3), 14)

func test_add_xp_no_level():
	var t := TeamProgress.new()
	assert_eq(t.add_xp(3), 0)
	assert_eq(t.level, 1)
	assert_eq(t.xp, 3)

func test_add_xp_single_level():
	var t := TeamProgress.new()
	assert_eq(t.add_xp(4), 1)   # needs 4 for lvl1->2
	assert_eq(t.level, 2)
	assert_eq(t.xp, 0)

func test_add_xp_multi_level_in_one_call():
	var t := TeamProgress.new()
	# 4 (->2) + 8 (->3) = 12 grants exactly 2 levels
	assert_eq(t.add_xp(12), 2)
	assert_eq(t.level, 3)
	assert_eq(t.xp, 0)

func test_carryover_remainder():
	var t := TeamProgress.new()
	assert_eq(t.add_xp(5), 1)   # 4 consumed, 1 carried
	assert_eq(t.level, 2)
	assert_eq(t.xp, 1)
