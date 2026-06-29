# See docs/notes/char-yinon.md
extends GutTest
## Tests for Yinon (Rocket Artillery) character: CharacterData structure,
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

func test_yinon_3d_loads() -> void:
	var cd: CharacterData = load("res://characters/yinon_3d.tres")
	assert_not_null(cd, "yinon_3d.tres must load")

func test_yinon_has_4_skills() -> void:
	var cd: CharacterData = load("res://characters/yinon_3d.tres")
	assert_eq(cd.skills.size(), 4, "Yinon must have exactly 4 skills")

func test_yinon_first_skill_is_signature() -> void:
	var cd: CharacterData = load("res://characters/yinon_3d.tres")
	assert_true(cd.skills[0].is_signature, "Yinon skills[0] must be signature")

func test_yinon_extra_skills_not_signature() -> void:
	var cd: CharacterData = load("res://characters/yinon_3d.tres")
	for i in range(1, cd.skills.size()):
		assert_false(cd.skills[i].is_signature,
			"Yinon skills[%d] must not be signature" % i)

func test_yinon_id() -> void:
	var cd: CharacterData = load("res://characters/yinon_3d.tres")
	assert_eq(cd.id, &"yinon", "CharacterData id must be 'yinon'")

func test_yinon_has_model() -> void:
	var cd: CharacterData = load("res://characters/yinon_3d.tres")
	assert_not_null(cd.model_scene, "Yinon must have a model_scene")

func test_yinon_stats_in_range() -> void:
	var cd: CharacterData = load("res://characters/yinon_3d.tres")
	assert_not_null(cd.base_stats, "Yinon must have base_stats")
	assert_true(cd.base_stats.max_hp > 0.0, "max_hp must be positive")
	assert_true(cd.base_stats.move_speed > 0.0, "move_speed must be positive")

# ─────────────────────────────────────────────────────────────────────────────
# Skill IDs
# ─────────────────────────────────────────────────────────────────────────────

func test_yinon_skill_ids_correct() -> void:
	var cd: CharacterData = load("res://characters/yinon_3d.tres")
	var ids: Array = cd.skills.map(func(s: SkillData) -> StringName: return s.id)
	assert_true(ids.has(&"yinon_rocket_barrage"), "yinon_rocket_barrage must be in Yinon skills")
	assert_true(ids.has(&"yinon_cluster_bomb"),   "yinon_cluster_bomb must be in Yinon skills")
	assert_true(ids.has(&"yinon_airstrike"),       "yinon_airstrike must be in Yinon skills")
	assert_true(ids.has(&"yinon_bombardment"),     "yinon_bombardment must be in Yinon skills")

func test_yinon_signature_is_rocket_barrage() -> void:
	var cd: CharacterData = load("res://characters/yinon_3d.tres")
	assert_eq(cd.skills[0].id, &"yinon_rocket_barrage", "Signature must be yinon_rocket_barrage")

# ─────────────────────────────────────────────────────────────────────────────
# Upgrade correctness per skill
# ─────────────────────────────────────────────────────────────────────────────

func test_yinon_rocket_barrage_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/yinon_rocket_barrage.tres")
	assert_not_null(sd, "yinon_rocket_barrage.tres must load")
	_check_skill(sd)

func test_yinon_cluster_bomb_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/yinon_cluster_bomb.tres")
	assert_not_null(sd, "yinon_cluster_bomb.tres must load")
	_check_skill(sd)

func test_yinon_airstrike_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/yinon_airstrike.tres")
	assert_not_null(sd, "yinon_airstrike.tres must load")
	_check_skill(sd)

func test_yinon_bombardment_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/yinon_bombardment.tres")
	assert_not_null(sd, "yinon_bombardment.tres must load")
	_check_skill(sd)

# ─────────────────────────────────────────────────────────────────────────────
# Weapon scene instantiation
# ─────────────────────────────────────────────────────────────────────────────

func test_yinon_rocket_barrage_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/yinon_rocket_barrage.tres")
	_check_weapon_scene(sd)

func test_yinon_cluster_bomb_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/yinon_cluster_bomb.tres")
	_check_weapon_scene(sd)

func test_yinon_airstrike_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/yinon_airstrike.tres")
	_check_weapon_scene(sd)

func test_yinon_bombardment_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/yinon_bombardment.tres")
	_check_weapon_scene(sd)

# ─────────────────────────────────────────────────────────────────────────────
# Weapon params
# ─────────────────────────────────────────────────────────────────────────────

func test_yinon_rocket_barrage_is_nova() -> void:
	var sd: SkillData = load("res://characters/skills/yinon_rocket_barrage.tres")
	var w = add_child_autofree(sd.weapon_scene.instantiate())
	assert_true(w is NovaWeapon3D, "Rocket Barrage must be a NovaWeapon3D")

func test_yinon_cluster_bomb_is_orbit() -> void:
	var sd: SkillData = load("res://characters/skills/yinon_cluster_bomb.tres")
	var w = add_child_autofree(sd.weapon_scene.instantiate())
	assert_true(w is OrbitWeapon3D, "Cluster Bomb must be an OrbitWeapon3D")

func test_yinon_cluster_bomb_has_4_orbiters() -> void:
	var sd: SkillData = load("res://characters/skills/yinon_cluster_bomb.tres")
	var w: YinonClusterBomb3D = add_child_autofree(sd.weapon_scene.instantiate()) as YinonClusterBomb3D
	assert_eq(w.orbit_count, 4, "Cluster Bomb must have 4 orbiters")

func test_yinon_airstrike_damage_highest() -> void:
	var sd: SkillData = load("res://characters/skills/yinon_airstrike.tres")
	var w: YinonAirstrike3D = add_child_autofree(sd.weapon_scene.instantiate()) as YinonAirstrike3D
	assert_true(w.damage >= 25.0, "Airstrike must have high damage (>=25)")

func test_yinon_bombardment_widest_radius() -> void:
	var sd: SkillData = load("res://characters/skills/yinon_bombardment.tres")
	var w: YinonBombardment3D = add_child_autofree(sd.weapon_scene.instantiate()) as YinonBombardment3D
	assert_true(w.radius >= 6.5, "Bombardment must have wide radius (>=6.5)")
