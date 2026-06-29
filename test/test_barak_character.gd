# See docs/notes/char-barak.md
extends GutTest
## Tests for Barak's CharacterData, SkillData roster, upgrade correctness,
## and weapon_scene instantiation.

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _check_skill(sd: SkillData) -> void:
	var sid: StringName = sd.id
	assert_not_null(sd.skill_upgrade,   str(sid) + ": skill_upgrade must not be null")
	assert_not_null(sd.passive_upgrade, str(sid) + ": passive_upgrade must not be null")
	assert_not_null(sd.synergy_upgrade, str(sid) + ": synergy_upgrade must not be null")
	assert_eq(sd.skill_upgrade.kind,   Upgrade.Kind.SKILL,   str(sid) + ": skill_upgrade.kind must be SKILL (4)")
	assert_eq(sd.passive_upgrade.kind, Upgrade.Kind.PASSIVE, str(sid) + ": passive_upgrade.kind must be PASSIVE (1)")
	assert_eq(sd.synergy_upgrade.kind, Upgrade.Kind.SYNERGY, str(sid) + ": synergy_upgrade.kind must be SYNERGY (5)")
	assert_eq(sd.skill_upgrade.max_level,   5, str(sid) + ": skill_upgrade max_level must be 5")
	assert_eq(sd.passive_upgrade.max_level, 5, str(sid) + ": passive_upgrade max_level must be 5")
	assert_eq(sd.synergy_upgrade.max_level, 1, str(sid) + ": synergy_upgrade max_level must be 1")
	assert_eq(sd.skill_upgrade.skill_id,   sid, str(sid) + ": skill_upgrade.skill_id must match")
	assert_eq(sd.passive_upgrade.skill_id, sid, str(sid) + ": passive_upgrade.skill_id must match")
	assert_eq(sd.synergy_upgrade.skill_id, sid, str(sid) + ": synergy_upgrade.skill_id must match")

# ═════════════════════════════════════════════════════════════════════════════
# CharacterData loading
# ═════════════════════════════════════════════════════════════════════════════

func test_barak_3d_loads() -> void:
	var cd: CharacterData = load("res://characters/barak_3d.tres")
	assert_not_null(cd, "barak_3d.tres must load")

func test_barak_3d_has_4_skills() -> void:
	var cd: CharacterData = load("res://characters/barak_3d.tres")
	assert_eq(cd.skills.size(), 4, "Barak must have exactly 4 skills")

func test_barak_first_skill_is_signature() -> void:
	var cd: CharacterData = load("res://characters/barak_3d.tres")
	assert_true(cd.skills[0].is_signature, "Barak skills[0] must be signature")

func test_barak_extra_skills_not_signature() -> void:
	var cd: CharacterData = load("res://characters/barak_3d.tres")
	for i in range(1, cd.skills.size()):
		assert_false(cd.skills[i].is_signature,
			"Barak skills[%d] must not be signature" % i)

func test_barak_skills_ids_correct() -> void:
	var cd: CharacterData = load("res://characters/barak_3d.tres")
	var ids: Array = cd.skills.map(func(s: SkillData) -> StringName: return s.id)
	assert_true(ids.has(&"barak_loyal_hounds"), "barak_loyal_hounds must be in Barak skills")
	assert_true(ids.has(&"barak_pack_tactics"), "barak_pack_tactics must be in Barak skills")
	assert_true(ids.has(&"barak_howl"),         "barak_howl must be in Barak skills")
	assert_true(ids.has(&"barak_fetch"),        "barak_fetch must be in Barak skills")

func test_barak_model_scene_assigned() -> void:
	var cd: CharacterData = load("res://characters/barak_3d.tres")
	assert_not_null(cd.model_scene, "Barak model_scene must not be null")

func test_barak_base_stats_sane() -> void:
	var cd: CharacterData = load("res://characters/barak_3d.tres")
	assert_not_null(cd.base_stats, "base_stats must not be null")
	assert_gt(cd.base_stats.max_hp, 0.0, "max_hp must be positive")
	assert_gt(cd.base_stats.move_speed, 0.0, "move_speed must be positive")

# ═════════════════════════════════════════════════════════════════════════════
# SkillData upgrade correctness
# ═════════════════════════════════════════════════════════════════════════════

func test_barak_loyal_hounds_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/barak_loyal_hounds.tres")
	assert_not_null(sd, "barak_loyal_hounds.tres must load")
	_check_skill(sd)

func test_barak_pack_tactics_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/barak_pack_tactics.tres")
	assert_not_null(sd, "barak_pack_tactics.tres must load")
	_check_skill(sd)

func test_barak_howl_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/barak_howl.tres")
	assert_not_null(sd, "barak_howl.tres must load")
	_check_skill(sd)

func test_barak_fetch_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/barak_fetch.tres")
	assert_not_null(sd, "barak_fetch.tres must load")
	_check_skill(sd)

# ═════════════════════════════════════════════════════════════════════════════
# weapon_scene instantiates as Weapon3D
# ═════════════════════════════════════════════════════════════════════════════

func _check_weapon_scene(sd: SkillData) -> void:
	assert_not_null(sd.weapon_scene, str(sd.id) + ": weapon_scene must not be null")
	var w = add_child_autofree(sd.weapon_scene.instantiate())
	assert_true(w is Weapon3D, str(sd.id) + ": weapon_scene must instantiate as Weapon3D")

func test_barak_loyal_hounds_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/barak_loyal_hounds.tres")
	_check_weapon_scene(sd)

func test_barak_pack_tactics_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/barak_pack_tactics.tres")
	_check_weapon_scene(sd)

func test_barak_howl_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/barak_howl.tres")
	_check_weapon_scene(sd)

func test_barak_fetch_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/barak_fetch.tres")
	_check_weapon_scene(sd)

# ═════════════════════════════════════════════════════════════════════════════
# Signature weapon defaults
# ═════════════════════════════════════════════════════════════════════════════

func test_barak_loyal_hounds_orbit_defaults() -> void:
	var scene := load("res://weapons/barak_loyal_hounds_3d.tscn")
	assert_not_null(scene, "barak_loyal_hounds_3d.tscn must exist")
	var w: BarakLoyalHounds3D = add_child_autofree(scene.instantiate()) as BarakLoyalHounds3D
	assert_eq(w.orbit_count, 3, "loyal_hounds orbit_count must be 3")
	assert_almost_eq(w.damage, 16.0, 0.001, "loyal_hounds damage must be 16.0")
