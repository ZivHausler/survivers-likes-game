extends GutTest

func test_constants():
	assert_eq(RespawnRules.DOWNED_TIME, 10.0)
	assert_eq(RespawnRules.REVIVE_HP_FRACTION, 0.5)
	assert_eq(RespawnRules.REVIVE_INVULN, 4.0)

func test_respawn_delay_progression():
	assert_eq(RespawnRules.respawn_delay(0), 15.0)
	assert_eq(RespawnRules.respawn_delay(1), 24.0)
	assert_eq(RespawnRules.respawn_delay(2), 33.0)
	assert_eq(RespawnRules.respawn_delay(4), 51.0)

func test_respawn_delay_caps_at_60():
	assert_eq(RespawnRules.respawn_delay(5), 60.0)
	assert_eq(RespawnRules.respawn_delay(99), 60.0)
