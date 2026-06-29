extends GutTest
## EnemyData gains attack archetype + per-archetype tunables (defaults + enum).

func test_default_is_melee() -> void:
	var d := EnemyData.new()
	assert_eq(d.attack_kind, EnemyData.AttackKind.MELEE, "default attack_kind is MELEE")

func test_enum_values() -> void:
	assert_eq(int(EnemyData.AttackKind.MELEE), 0)
	assert_eq(int(EnemyData.AttackKind.RANGED), 1)
	assert_eq(int(EnemyData.AttackKind.DASHER), 2)

func test_ranged_and_dash_param_defaults_present() -> void:
	var d := EnemyData.new()
	assert_true(d.attack_range > 0.0, "attack_range default > 0")
	assert_true(d.attack_cooldown > 0.0, "attack_cooldown default > 0")
	assert_true(d.projectile_speed > 0.0, "projectile_speed default > 0")
	assert_true(d.dash_speed > 0.0, "dash_speed default > 0")
	assert_true(d.dash_duration > 0.0, "dash_duration default > 0")
