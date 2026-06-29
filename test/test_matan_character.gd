# See docs/notes/char-matan.md
extends GutTest
## Tests for Matan "Irritation Aura" character (Phase 5).
## Verifies: CharacterData loads with 4 SkillData; each SkillData has 3 upgrades
## with correct Kinds + matching skill_id; weapon_scene instantiates as Weapon3D.

# ─────────────────────────────────────────────────────────────────────────────
# CharacterData loading
# ─────────────────────────────────────────────────────────────────────────────

func test_matan_3d_loads() -> void:
	var cd: CharacterData = load("res://characters/matan_3d.tres")
	assert_not_null(cd, "matan_3d.tres must load")

func test_matan_3d_has_4_skills() -> void:
	var cd: CharacterData = load("res://characters/matan_3d.tres")
	assert_not_null(cd, "matan_3d.tres must load")
	assert_eq(cd.skills.size(), 4, "Matan must have exactly 4 skills")

func test_matan_first_skill_is_signature() -> void:
	var cd: CharacterData = load("res://characters/matan_3d.tres")
	assert_true(cd.skills[0].is_signature, "Matan skills[0] must be signature")

func test_matan_other_skills_not_signature() -> void:
	var cd: CharacterData = load("res://characters/matan_3d.tres")
	for i in range(1, cd.skills.size()):
		assert_false(cd.skills[i].is_signature,
			"Matan skills[%d] must not be signature" % i)

func test_matan_skill_ids_correct() -> void:
	var cd: CharacterData = load("res://characters/matan_3d.tres")
	var ids: Array = cd.skills.map(func(s: SkillData) -> StringName: return s.id)
	assert_true(ids.has(&"matan_irritation_aura"),  "matan_irritation_aura must be in skills")
	assert_true(ids.has(&"matan_annoyance_orbit"),  "matan_annoyance_orbit must be in skills")
	assert_true(ids.has(&"matan_outburst"),         "matan_outburst must be in skills")
	assert_true(ids.has(&"matan_pestering_swarm"),  "matan_pestering_swarm must be in skills")

func test_matan_model_assigned() -> void:
	var cd: CharacterData = load("res://characters/matan_3d.tres")
	assert_not_null(cd.model_scene, "Matan model_scene must not be null")

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

func test_matan_irritation_aura_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/matan_irritation_aura.tres")
	assert_not_null(sd, "matan_irritation_aura.tres must load")
	_check_skill(sd)

func test_matan_annoyance_orbit_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/matan_annoyance_orbit.tres")
	assert_not_null(sd, "matan_annoyance_orbit.tres must load")
	_check_skill(sd)

func test_matan_outburst_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/matan_outburst.tres")
	assert_not_null(sd, "matan_outburst.tres must load")
	_check_skill(sd)

func test_matan_pestering_swarm_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/matan_pestering_swarm.tres")
	assert_not_null(sd, "matan_pestering_swarm.tres must load")
	_check_skill(sd)

# ─────────────────────────────────────────────────────────────────────────────
# weapon_scene instantiates as Weapon3D
# ─────────────────────────────────────────────────────────────────────────────

func _check_weapon_scene(sd: SkillData) -> void:
	assert_not_null(sd.weapon_scene, str(sd.id) + ": weapon_scene must not be null")
	var w = add_child_autofree(sd.weapon_scene.instantiate())
	assert_true(w is Weapon3D, str(sd.id) + ": weapon_scene must instantiate as Weapon3D")

func test_matan_irritation_aura_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/matan_irritation_aura.tres")
	_check_weapon_scene(sd)

func test_matan_annoyance_orbit_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/matan_annoyance_orbit.tres")
	_check_weapon_scene(sd)

func test_matan_outburst_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/matan_outburst.tres")
	_check_weapon_scene(sd)

func test_matan_pestering_swarm_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/matan_pestering_swarm.tres")
	_check_weapon_scene(sd)

# ─────────────────────────────────────────────────────────────────────────────
# Weapon params within expected ranges (no assert_le/ge — use assert_true)
# ─────────────────────────────────────────────────────────────────────────────

func test_matan_irritation_aura_params() -> void:
	var sd: SkillData = load("res://characters/skills/matan_irritation_aura.tres")
	var w = add_child_autofree(sd.weapon_scene.instantiate()) as NovaWeapon3D
	assert_true(w is NovaWeapon3D, "Irritation Aura must be a NovaWeapon3D")
	assert_true(w.charm_duration > 0.0, "Irritation Aura must have charm_duration > 0")
	assert_true(w.radius > 5.0,         "Irritation Aura radius must be > 5")

func test_matan_pestering_swarm_params() -> void:
	var sd: SkillData = load("res://characters/skills/matan_pestering_swarm.tres")
	var w = add_child_autofree(sd.weapon_scene.instantiate()) as OrbitWeapon3D
	assert_true(w is OrbitWeapon3D, "Pestering Swarm must be an OrbitWeapon3D")
	assert_eq(w.orbit_count, 5, "Pestering Swarm must start with 5 orbs")
	assert_true(w.orbit_speed > TAU / 2.0, "Pestering Swarm must be fast (orbit_speed > TAU/2)")
