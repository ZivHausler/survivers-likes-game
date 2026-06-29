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

func test_variants_load_with_expected_kind() -> void:
	var archer := load("res://enemies/archer.tres") as EnemyData
	var magician := load("res://enemies/magician.tres") as EnemyData
	var dasher := load("res://enemies/dasher.tres") as EnemyData
	assert_not_null(archer, "archer.tres must load as EnemyData")
	assert_not_null(magician, "magician.tres must load as EnemyData")
	assert_not_null(dasher, "dasher.tres must load as EnemyData")
	assert_eq(archer.attack_kind, EnemyData.AttackKind.RANGED, "archer is RANGED")
	assert_eq(magician.attack_kind, EnemyData.AttackKind.RANGED, "magician is RANGED")
	assert_eq(dasher.attack_kind, EnemyData.AttackKind.DASHER, "dasher is DASHER")
	assert_not_null(archer.model_scene, "archer has model_scene set")
