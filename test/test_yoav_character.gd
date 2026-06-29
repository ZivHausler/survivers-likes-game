# See docs/notes/char-yoav.md
extends GutTest
## Tests for Yoav (Wolt-Scooter Strafe) character: CharacterData structure,
## SkillData upgrade correctness, and weapon scene instantiation.

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _check_skill(sd: SkillData) -> void:
	var sid: StringName = sd.id
	assert_not_null(sd.skill_upgrade,   str(sid) + ": skill_upgrade must not be null")
	assert_not_null(sd.passive_upgrade, str(sid) + ": passive_upgrade must not be null")
	assert_not_null(sd.synergy_upgrade, str(sid) + ": synergy_upgrade must not be null")
	assert_eq(sd.skill_upgrade.kind,   Upgrade.Kind.SKILL,   str(sid) + ": skill_upgrade.kind must be SKILL")
	assert_eq(sd.passive_upgrade.kind, Upgrade.Kind.PASSIVE, str(sid) + ": passive_upgrade.kind must be PASSIVE")
	assert_eq(sd.synergy_upgrade.kind, Upgrade.Kind.SYNERGY, str(sid) + ": synergy_upgrade.kind must be SYNERGY")
	assert_eq(sd.skill_upgrade.max_level,   5, str(sid) + ": skill_upgrade max_level must be 5")
	assert_eq(sd.passive_upgrade.max_level, 5, str(sid) + ": passive_upgrade max_level must be 5")
	assert_eq(sd.synergy_upgrade.max_level, 1, str(sid) + ": synergy_upgrade max_level must be 1")
	assert_eq(sd.skill_upgrade.skill_id,   sid, str(sid) + ": skill_upgrade.skill_id must match")
	assert_eq(sd.passive_upgrade.skill_id, sid, str(sid) + ": passive_upgrade.skill_id must match")
	assert_eq(sd.synergy_upgrade.skill_id, sid, str(sid) + ": synergy_upgrade.skill_id must match")

func _check_weapon_scene(sd: SkillData) -> void:
	assert_not_null(sd.weapon_scene, str(sd.id) + ": weapon_scene must not be null")
	var w = add_child_autofree(sd.weapon_scene.instantiate())
	assert_true(w is Weapon3D, str(sd.id) + ": weapon_scene must instantiate as Weapon3D")

# ─────────────────────────────────────────────────────────────────────────────
# CharacterData loading
# ─────────────────────────────────────────────────────────────────────────────

func test_yoav_3d_loads() -> void:
	var cd: CharacterData = load("res://characters/yoav_3d.tres")
	assert_not_null(cd, "yoav_3d.tres must load")

func test_yoav_has_4_skills() -> void:
	var cd: CharacterData = load("res://characters/yoav_3d.tres")
	assert_eq(cd.skills.size(), 4, "Yoav must have exactly 4 skills")

func test_yoav_first_skill_is_signature() -> void:
	var cd: CharacterData = load("res://characters/yoav_3d.tres")
	assert_true(cd.skills[0].is_signature, "Yoav skills[0] must be signature")

func test_yoav_extra_skills_not_signature() -> void:
	var cd: CharacterData = load("res://characters/yoav_3d.tres")
	for i in range(1, cd.skills.size()):
		assert_false(cd.skills[i].is_signature,
			"Yoav skills[%d] must not be signature" % i)

func test_yoav_id() -> void:
	var cd: CharacterData = load("res://characters/yoav_3d.tres")
	assert_eq(cd.id, &"yoav", "CharacterData id must be 'yoav'")

func test_yoav_has_model() -> void:
	var cd: CharacterData = load("res://characters/yoav_3d.tres")
	assert_not_null(cd.model_scene, "Yoav must have a model_scene")

func test_yoav_stats_in_range() -> void:
	var cd: CharacterData = load("res://characters/yoav_3d.tres")
	assert_not_null(cd.base_stats, "Yoav must have base_stats")
	assert_true(cd.base_stats.max_hp > 0.0, "max_hp must be positive")
	assert_true(cd.base_stats.move_speed > 0.0, "move_speed must be positive")

# ─────────────────────────────────────────────────────────────────────────────
# Skill IDs
# ─────────────────────────────────────────────────────────────────────────────

func test_yoav_skill_ids_correct() -> void:
	var cd: CharacterData = load("res://characters/yoav_3d.tres")
	var ids: Array = cd.skills.map(func(s: SkillData) -> StringName: return s.id)
	assert_true(ids.has(&"yoav_drive_by"),       "yoav_drive_by must be in Yoav skills")
	assert_true(ids.has(&"yoav_delivery_orbit"), "yoav_delivery_orbit must be in Yoav skills")
	assert_true(ids.has(&"yoav_hot_meal"),       "yoav_hot_meal must be in Yoav skills")
	assert_true(ids.has(&"yoav_express_run"),    "yoav_express_run must be in Yoav skills")

func test_yoav_signature_is_drive_by() -> void:
	var cd: CharacterData = load("res://characters/yoav_3d.tres")
	assert_eq(cd.skills[0].id, &"yoav_drive_by", "Signature must be yoav_drive_by")

# ─────────────────────────────────────────────────────────────────────────────
# Upgrade correctness per skill
# ─────────────────────────────────────────────────────────────────────────────

func test_yoav_drive_by_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_drive_by.tres")
	assert_not_null(sd, "yoav_drive_by.tres must load")
	_check_skill(sd)

func test_yoav_delivery_orbit_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_delivery_orbit.tres")
	assert_not_null(sd, "yoav_delivery_orbit.tres must load")
	_check_skill(sd)

func test_yoav_hot_meal_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_hot_meal.tres")
	assert_not_null(sd, "yoav_hot_meal.tres must load")
	_check_skill(sd)

func test_yoav_express_run_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_express_run.tres")
	assert_not_null(sd, "yoav_express_run.tres must load")
	_check_skill(sd)

# ─────────────────────────────────────────────────────────────────────────────
# Weapon scene instantiation
# ─────────────────────────────────────────────────────────────────────────────

func test_yoav_drive_by_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_drive_by.tres")
	_check_weapon_scene(sd)

func test_yoav_delivery_orbit_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_delivery_orbit.tres")
	_check_weapon_scene(sd)

func test_yoav_hot_meal_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_hot_meal.tres")
	_check_weapon_scene(sd)

func test_yoav_express_run_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_express_run.tres")
	_check_weapon_scene(sd)

# ─────────────────────────────────────────────────────────────────────────────
# Weapon params
# ─────────────────────────────────────────────────────────────────────────────

func test_yoav_drive_by_is_nova() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_drive_by.tres")
	var w = add_child_autofree(sd.weapon_scene.instantiate())
	assert_true(w is NovaWeapon3D, "Drive-By must be a NovaWeapon3D")

func test_yoav_drive_by_fast_cooldown() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_drive_by.tres")
	var w: YoavDriveBy3D = add_child_autofree(sd.weapon_scene.instantiate()) as YoavDriveBy3D
	assert_true(w.base_cooldown <= 2.0, "Drive-By cooldown must be fast (<=2.0s)")

func test_yoav_delivery_orbit_is_orbit() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_delivery_orbit.tres")
	var w = add_child_autofree(sd.weapon_scene.instantiate())
	assert_true(w is OrbitWeapon3D, "Delivery Orbit must be an OrbitWeapon3D")

func test_yoav_delivery_orbit_has_4_orbiters() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_delivery_orbit.tres")
	var w: YoavDeliveryOrbit3D = add_child_autofree(sd.weapon_scene.instantiate()) as YoavDeliveryOrbit3D
	assert_eq(w.orbit_count, 4, "Delivery Orbit must have 4 orbiters")

func test_yoav_express_run_has_6_orbiters() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_express_run.tres")
	var w: YoavExpressRun3D = add_child_autofree(sd.weapon_scene.instantiate()) as YoavExpressRun3D
	assert_eq(w.orbit_count, 6, "Express Run must have 6 orbiters")

func test_yoav_express_run_is_fast() -> void:
	var sd: SkillData = load("res://characters/skills/yoav_express_run.tres")
	var w: YoavExpressRun3D = add_child_autofree(sd.weapon_scene.instantiate()) as YoavExpressRun3D
	# TAU/1.5 ≈ 4.19 rad/s; base OrbitWeapon3D default is TAU/3 ≈ 2.09 — confirm we are faster
	assert_true(w.orbit_speed > TAU / 2.0, "Express Run orbit_speed must be fast (> TAU/2)")
