# See docs/notes/skills-overview-3-3.md
extends GutTest
## Integration tests for Task 3.3: 4 skills per character, upgrade correctness,
## and weapon_scene instantiation.
##
## Tests load the real .tres files (no editor required — just res:// resources).
## No physics is exercised; we check data integrity only.

# ─────────────────────────────────────────────────────────────────────────────
# CharacterData loading — 4 skills each
# ─────────────────────────────────────────────────────────────────────────────

func test_ziv_3d_has_4_skills() -> void:
	var cd: CharacterData = load("res://characters/ziv_3d.tres")
	assert_not_null(cd, "ziv_3d.tres must load")
	assert_eq(cd.skills.size(), 4, "Ziv must have exactly 4 skills")

func test_avihay_3d_has_4_skills() -> void:
	var cd: CharacterData = load("res://characters/avihay_3d.tres")
	assert_not_null(cd, "avihay_3d.tres must load")
	assert_eq(cd.skills.size(), 4, "Avihay must have exactly 4 skills")

func test_ziv_first_skill_is_signature() -> void:
	var cd: CharacterData = load("res://characters/ziv_3d.tres")
	assert_true(cd.skills[0].is_signature, "Ziv skills[0] must be signature")

func test_avihay_first_skill_is_signature() -> void:
	var cd: CharacterData = load("res://characters/avihay_3d.tres")
	assert_true(cd.skills[0].is_signature, "Avihay skills[0] must be signature")

func test_ziv_extra_skills_not_signature() -> void:
	var cd: CharacterData = load("res://characters/ziv_3d.tres")
	for i in range(1, cd.skills.size()):
		assert_false(cd.skills[i].is_signature,
			"Ziv skills[%d] must not be signature" % i)

func test_avihay_extra_skills_not_signature() -> void:
	var cd: CharacterData = load("res://characters/avihay_3d.tres")
	for i in range(1, cd.skills.size()):
		assert_false(cd.skills[i].is_signature,
			"Avihay skills[%d] must not be signature" % i)

# ─────────────────────────────────────────────────────────────────────────────
# Upgrade correctness — each new SkillData has 3 upgrades with matching skill_id
# ─────────────────────────────────────────────────────────────────────────────

func _check_skill(sd: SkillData) -> void:
	var sid: StringName = sd.id
	assert_not_null(sd.skill_upgrade,   str(sid) + ": skill_upgrade must not be null")
	assert_not_null(sd.passive_upgrade, str(sid) + ": passive_upgrade must not be null")
	assert_not_null(sd.synergy_upgrade, str(sid) + ": synergy_upgrade must not be null")
	# Kinds
	assert_eq(sd.skill_upgrade.kind,   Upgrade.Kind.SKILL,   str(sid) + ": skill_upgrade.kind must be SKILL (4)")
	assert_eq(sd.passive_upgrade.kind, Upgrade.Kind.PASSIVE, str(sid) + ": passive_upgrade.kind must be PASSIVE (1)")
	assert_eq(sd.synergy_upgrade.kind, Upgrade.Kind.SYNERGY, str(sid) + ": synergy_upgrade.kind must be SYNERGY (5)")
	# Max levels
	assert_eq(sd.skill_upgrade.max_level,   5, str(sid) + ": skill_upgrade max_level must be 5")
	assert_eq(sd.passive_upgrade.max_level, 5, str(sid) + ": passive_upgrade max_level must be 5")
	assert_eq(sd.synergy_upgrade.max_level, 1, str(sid) + ": synergy_upgrade max_level must be 1")
	# Matching skill_id
	assert_eq(sd.skill_upgrade.skill_id,   sid, str(sid) + ": skill_upgrade.skill_id must match")
	assert_eq(sd.passive_upgrade.skill_id, sid, str(sid) + ": passive_upgrade.skill_id must match")
	assert_eq(sd.synergy_upgrade.skill_id, sid, str(sid) + ": synergy_upgrade.skill_id must match")

func test_ziv_mirror_shards_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/ziv_mirror_shards.tres")
	assert_not_null(sd, "ziv_mirror_shards.tres must load")
	_check_skill(sd)

func test_ziv_selfie_flash_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/ziv_selfie_flash.tres")
	assert_not_null(sd, "ziv_selfie_flash.tres must load")
	_check_skill(sd)

func test_ziv_adoring_aura_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/ziv_adoring_aura.tres")
	assert_not_null(sd, "ziv_adoring_aura.tres must load")
	_check_skill(sd)

func test_avihay_group_call_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/avihay_group_call.tres")
	assert_not_null(sd, "avihay_group_call.tres must load")
	_check_skill(sd)

func test_avihay_voice_blast_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/avihay_voice_blast.tres")
	assert_not_null(sd, "avihay_voice_blast.tres must load")
	_check_skill(sd)

func test_avihay_mass_dm_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/avihay_mass_dm.tres")
	assert_not_null(sd, "avihay_mass_dm.tres must load")
	_check_skill(sd)

# ─────────────────────────────────────────────────────────────────────────────
# weapon_scene instantiates as Weapon3D
# ─────────────────────────────────────────────────────────────────────────────

func _check_weapon_scene(sd: SkillData) -> void:
	assert_not_null(sd.weapon_scene, str(sd.id) + ": weapon_scene must not be null")
	var w = add_child_autofree(sd.weapon_scene.instantiate())
	assert_true(w is Weapon3D, str(sd.id) + ": weapon_scene must instantiate as Weapon3D")

func test_ziv_mirror_shards_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/ziv_mirror_shards.tres")
	_check_weapon_scene(sd)

func test_ziv_selfie_flash_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/ziv_selfie_flash.tres")
	_check_weapon_scene(sd)

func test_ziv_adoring_aura_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/ziv_adoring_aura.tres")
	_check_weapon_scene(sd)

func test_avihay_group_call_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/avihay_group_call.tres")
	_check_weapon_scene(sd)

func test_avihay_voice_blast_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/avihay_voice_blast.tres")
	_check_weapon_scene(sd)

func test_avihay_mass_dm_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/avihay_mass_dm.tres")
	_check_weapon_scene(sd)

# ─────────────────────────────────────────────────────────────────────────────
# Skill IDs are unique across both characters
# ─────────────────────────────────────────────────────────────────────────────

func test_all_skill_ids_unique() -> void:
	var ziv: CharacterData = load("res://characters/ziv_3d.tres")
	var avihay: CharacterData = load("res://characters/avihay_3d.tres")
	var all_ids: Dictionary = {}
	for sd: SkillData in ziv.skills:
		assert_false(all_ids.has(sd.id), "Duplicate skill id: " + str(sd.id))
		all_ids[sd.id] = true
	for sd: SkillData in avihay.skills:
		assert_false(all_ids.has(sd.id), "Duplicate skill id: " + str(sd.id))
		all_ids[sd.id] = true

# ─────────────────────────────────────────────────────────────────────────────
# New skills are properly wired in character data
# ─────────────────────────────────────────────────────────────────────────────

func test_ziv_skills_ids_correct() -> void:
	var cd: CharacterData = load("res://characters/ziv_3d.tres")
	var ids: Array = cd.skills.map(func(s: SkillData) -> StringName: return s.id)
	assert_true(ids.has(&"ziv_charm"),        "ziv_charm must be in Ziv skills")
	assert_true(ids.has(&"ziv_mirror_shards"), "ziv_mirror_shards must be in Ziv skills")
	assert_true(ids.has(&"ziv_selfie_flash"),  "ziv_selfie_flash must be in Ziv skills")
	assert_true(ids.has(&"ziv_adoring_aura"),  "ziv_adoring_aura must be in Ziv skills")

func test_avihay_skills_ids_correct() -> void:
	var cd: CharacterData = load("res://characters/avihay_3d.tres")
	var ids: Array = cd.skills.map(func(s: SkillData) -> StringName: return s.id)
	assert_true(ids.has(&"avihay_spam"),       "avihay_spam must be in Avihay skills")
	assert_true(ids.has(&"avihay_group_call"), "avihay_group_call must be in Avihay skills")
	assert_true(ids.has(&"avihay_voice_blast"),"avihay_voice_blast must be in Avihay skills")
	assert_true(ids.has(&"avihay_mass_dm"),    "avihay_mass_dm must be in Avihay skills")
