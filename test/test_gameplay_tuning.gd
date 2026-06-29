extends GutTest
## Regression guards for gameplay-tuning requirements (v1 vertical slice):
##   - Boss XP value is significantly larger than a normal tank
##   - Signature skill cap is 5 for all characters

# ── Boss XP ──────────────────────────────────────────────────────────────────

func test_boss_xp_value_constant_is_large() -> void:
	# BOSS_XP_VALUE must exceed a normal tank (xp_value = 10) by a large margin.
	assert_true(
		Spawner.BOSS_XP_VALUE >= 20,
		"BOSS_XP_VALUE (%d) must be >= 20 to reward killing a boss" % Spawner.BOSS_XP_VALUE
	)

func test_boss_xp_exceeds_normal_tank() -> void:
	var tank: EnemyData = load("res://enemies/tank.tres") as EnemyData
	assert_not_null(tank, "tank.tres must exist")
	assert_true(
		Spawner.BOSS_XP_VALUE > tank.xp_value,
		"Boss XP (%d) must exceed normal tank xp_value (%d)" % [Spawner.BOSS_XP_VALUE, tank.xp_value]
	)

# ── Skill cap ─────────────────────────────────────────────────────────────────

func test_ziv_max_signature_level_is_5() -> void:
	var ziv: CharacterData = load("res://characters/ziv.tres") as CharacterData
	assert_not_null(ziv, "ziv.tres must exist")
	assert_eq(ziv.max_signature_level, 5, "Ziv's skill cap must be 5")

func test_avihay_max_signature_level_is_5() -> void:
	var avihay: CharacterData = load("res://characters/avihay.tres") as CharacterData
	assert_not_null(avihay, "avihay.tres must exist")
	assert_eq(avihay.max_signature_level, 5, "Avihay's skill cap must be 5")

func test_ziv_signature_upgrade_max_level_is_5() -> void:
	var sig = load("res://upgrades/ziv/signature.tres")
	assert_not_null(sig, "ziv signature.tres must exist")
	assert_eq(sig.max_level, 5, "Ziv signature upgrade max_level must be 5")

func test_avihay_signature_upgrade_max_level_is_5() -> void:
	var sig = load("res://upgrades/avihay/signature.tres")
	assert_not_null(sig, "avihay signature.tres must exist")
	assert_eq(sig.max_level, 5, "Avihay signature upgrade max_level must be 5")
