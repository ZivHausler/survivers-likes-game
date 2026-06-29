# See docs/notes/char-avinoam.md
extends GutTest
## Tests for Avinoam "Divine Smite" character (Phase 5).
## Verifies: CharacterData loads with 4 SkillData; each SkillData has 3 upgrades
## with correct Kinds + matching skill_id; weapon_scene instantiates as Weapon3D.

# ─────────────────────────────────────────────────────────────────────────────
# CharacterData loading
# ─────────────────────────────────────────────────────────────────────────────

func test_avinoam_3d_loads() -> void:
	var cd: CharacterData = load("res://characters/avinoam_3d.tres")
	assert_not_null(cd, "avinoam_3d.tres must load")

func test_avinoam_3d_has_4_skills() -> void:
	var cd: CharacterData = load("res://characters/avinoam_3d.tres")
	assert_not_null(cd, "avinoam_3d.tres must load")
	assert_eq(cd.skills.size(), 4, "Avinoam must have exactly 4 skills")

func test_avinoam_first_skill_is_signature() -> void:
	var cd: CharacterData = load("res://characters/avinoam_3d.tres")
	assert_true(cd.skills[0].is_signature, "Avinoam skills[0] must be signature")

func test_avinoam_other_skills_not_signature() -> void:
	var cd: CharacterData = load("res://characters/avinoam_3d.tres")
	for i in range(1, cd.skills.size()):
		assert_false(cd.skills[i].is_signature,
			"Avinoam skills[%d] must not be signature" % i)

func test_avinoam_skill_ids_correct() -> void:
	var cd: CharacterData = load("res://characters/avinoam_3d.tres")
	var ids: Array = cd.skills.map(func(s: SkillData) -> StringName: return s.id)
	assert_true(ids.has(&"avinoam_holy_smite"),    "avinoam_holy_smite must be in skills")
	assert_true(ids.has(&"avinoam_smite_orbs"),    "avinoam_smite_orbs must be in skills")
	assert_true(ids.has(&"avinoam_radiant_pulse"), "avinoam_radiant_pulse must be in skills")
	assert_true(ids.has(&"avinoam_judgment"),      "avinoam_judgment must be in skills")

func test_avinoam_model_assigned() -> void:
	var cd: CharacterData = load("res://characters/avinoam_3d.tres")
	assert_not_null(cd.model_scene, "Avinoam model_scene must not be null")

# ─────────────────────────────────────────────────────────────────────────────
# Upgrade correctness helper
# ─────────────────────────────────────────────────────────────────────────────

func _check_skill(sd: SkillData) -> void:
	var sid: StringName = sd.id
	assert_not_null(sd.skill_upgrade,   str(sid) + ": skill_upgrade must not be null")
	assert_not_null(sd.passive_upgrade, str(sid) + ": passive_upgrade must not be null")
	assert_not_null(sd.synergy_upgrade, str(sid) + ": synergy_upgrade must not be null")
	assert_eq(sd.skill_upgrade.kind,   Upgrade.Kind.SKILL,   str(sid) + ": skill kind must be SKILL (4)")
	assert_eq(sd.passive_upgrade.kind, Upgrade.Kind.PASSIVE, str(sid) + ": passive kind must be PASSIVE (1)")
	assert_eq(sd.synergy_upgrade.kind, Upgrade.Kind.SYNERGY, str(sid) + ": synergy kind must be SYNERGY (5)")
	assert_eq(sd.skill_upgrade.max_level,   5, str(sid) + ": skill max_level must be 5")
	assert_eq(sd.passive_upgrade.max_level, 5, str(sid) + ": passive max_level must be 5")
	assert_eq(sd.synergy_upgrade.max_level, 1, str(sid) + ": synergy max_level must be 1")
	assert_eq(sd.skill_upgrade.skill_id,   sid, str(sid) + ": skill_upgrade.skill_id must match")
	assert_eq(sd.passive_upgrade.skill_id, sid, str(sid) + ": passive_upgrade.skill_id must match")
	assert_eq(sd.synergy_upgrade.skill_id, sid, str(sid) + ": synergy_upgrade.skill_id must match")

# ─────────────────────────────────────────────────────────────────────────────
# Upgrade correctness per skill
# ─────────────────────────────────────────────────────────────────────────────

func test_avinoam_holy_smite_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/avinoam_holy_smite.tres")
	assert_not_null(sd, "avinoam_holy_smite.tres must load")
	_check_skill(sd)

func test_avinoam_smite_orbs_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/avinoam_smite_orbs.tres")
	assert_not_null(sd, "avinoam_smite_orbs.tres must load")
	_check_skill(sd)

func test_avinoam_radiant_pulse_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/avinoam_radiant_pulse.tres")
	assert_not_null(sd, "avinoam_radiant_pulse.tres must load")
	_check_skill(sd)

func test_avinoam_judgment_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/avinoam_judgment.tres")
	assert_not_null(sd, "avinoam_judgment.tres must load")
	_check_skill(sd)

# ─────────────────────────────────────────────────────────────────────────────
# weapon_scene instantiates as Weapon3D
# ─────────────────────────────────────────────────────────────────────────────

func _check_weapon_scene(sd: SkillData) -> void:
	assert_not_null(sd.weapon_scene, str(sd.id) + ": weapon_scene must not be null")
	var w = add_child_autofree(sd.weapon_scene.instantiate())
	assert_true(w is Weapon3D, str(sd.id) + ": weapon_scene must instantiate as Weapon3D")

func test_avinoam_holy_smite_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/avinoam_holy_smite.tres")
	_check_weapon_scene(sd)

func test_avinoam_smite_orbs_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/avinoam_smite_orbs.tres")
	_check_weapon_scene(sd)

func test_avinoam_radiant_pulse_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/avinoam_radiant_pulse.tres")
	_check_weapon_scene(sd)

func test_avinoam_judgment_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/avinoam_judgment.tres")
	_check_weapon_scene(sd)

# ─────────────────────────────────────────────────────────────────────────────
# Weapon params within expected ranges (no assert_le/ge — use assert_true)
# ─────────────────────────────────────────────────────────────────────────────

func test_avinoam_holy_smite_params() -> void:
	var sd: SkillData = load("res://characters/skills/avinoam_holy_smite.tres")
	var w = add_child_autofree(sd.weapon_scene.instantiate()) as NovaWeapon3D
	assert_true(w is NovaWeapon3D, "Holy Smite must be a NovaWeapon3D")
	assert_true(w.damage > 20.0, "Holy Smite damage must be > 20")
	assert_true(w.radius > 5.0,  "Holy Smite radius must be > 5")

func test_avinoam_smite_orbs_params() -> void:
	var sd: SkillData = load("res://characters/skills/avinoam_smite_orbs.tres")
	var w = add_child_autofree(sd.weapon_scene.instantiate()) as OrbitWeapon3D
	assert_true(w is OrbitWeapon3D, "Smite Orbs must be an OrbitWeapon3D")
	assert_eq(w.orbit_count, 3, "Smite Orbs must start with 3 orbs")
	assert_true(w.damage > 10.0, "Smite Orbs damage must be > 10")
