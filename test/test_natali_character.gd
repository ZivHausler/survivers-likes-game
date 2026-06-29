# See docs/notes/char-natali.md
extends GutTest
## Tests for Natali's CharacterData, SkillData roster, upgrade correctness,
## weapon_scene instantiation, and focused test of the bespoke Laughter fire()
## heal behaviour (hp increases but never exceeds max_hp).

# ─────────────────────────────────────────────────────────────────────────────
# Stub player — minimal interface for NataliLaughter3D.fire()
# ─────────────────────────────────────────────────────────────────────────────
class StubPlayer extends Node3D:
	var hp: float = 50.0
	var stats: StatBlock

	func _init() -> void:
		stats = StatBlock.new()
		stats.max_hp = 100.0

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _make_stats(dmg: float = 1.0, rate: float = 1.0) -> StatBlock:
	var s := StatBlock.new()
	s.damage_mult    = dmg
	s.fire_rate_mult = rate
	return s

func _make_laughter() -> NataliLaughter3D:
	var scene := load("res://weapons/natali_laughter_3d.tscn")
	assert_not_null(scene, "natali_laughter_3d.tscn must exist")
	var w: NataliLaughter3D = add_child_autofree(scene.instantiate()) as NataliLaughter3D
	return w

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

func test_natali_3d_loads() -> void:
	var cd: CharacterData = load("res://characters/natali_3d.tres")
	assert_not_null(cd, "natali_3d.tres must load")

func test_natali_3d_has_4_skills() -> void:
	var cd: CharacterData = load("res://characters/natali_3d.tres")
	assert_eq(cd.skills.size(), 4, "Natali must have exactly 4 skills")

func test_natali_first_skill_is_signature() -> void:
	var cd: CharacterData = load("res://characters/natali_3d.tres")
	assert_true(cd.skills[0].is_signature, "Natali skills[0] must be signature")

func test_natali_extra_skills_not_signature() -> void:
	var cd: CharacterData = load("res://characters/natali_3d.tres")
	for i in range(1, cd.skills.size()):
		assert_false(cd.skills[i].is_signature,
			"Natali skills[%d] must not be signature" % i)

func test_natali_skills_ids_correct() -> void:
	var cd: CharacterData = load("res://characters/natali_3d.tres")
	var ids: Array = cd.skills.map(func(s: SkillData) -> StringName: return s.id)
	assert_true(ids.has(&"natali_laughter"),     "natali_laughter must be in Natali skills")
	assert_true(ids.has(&"natali_joy_orbit"),    "natali_joy_orbit must be in Natali skills")
	assert_true(ids.has(&"natali_comic_relief"), "natali_comic_relief must be in Natali skills")
	assert_true(ids.has(&"natali_giggle_burst"), "natali_giggle_burst must be in Natali skills")

func test_natali_model_scene_assigned() -> void:
	var cd: CharacterData = load("res://characters/natali_3d.tres")
	assert_not_null(cd.model_scene, "Natali model_scene must not be null")

func test_natali_base_stats_sane() -> void:
	var cd: CharacterData = load("res://characters/natali_3d.tres")
	assert_not_null(cd.base_stats, "base_stats must not be null")
	assert_gt(cd.base_stats.max_hp, 0.0, "max_hp must be positive")
	assert_gt(cd.base_stats.move_speed, 0.0, "move_speed must be positive")

# ═════════════════════════════════════════════════════════════════════════════
# SkillData upgrade correctness
# ═════════════════════════════════════════════════════════════════════════════

func test_natali_laughter_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/natali_laughter.tres")
	assert_not_null(sd, "natali_laughter.tres must load")
	_check_skill(sd)

func test_natali_joy_orbit_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/natali_joy_orbit.tres")
	assert_not_null(sd, "natali_joy_orbit.tres must load")
	_check_skill(sd)

func test_natali_comic_relief_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/natali_comic_relief.tres")
	assert_not_null(sd, "natali_comic_relief.tres must load")
	_check_skill(sd)

func test_natali_giggle_burst_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/natali_giggle_burst.tres")
	assert_not_null(sd, "natali_giggle_burst.tres must load")
	_check_skill(sd)

# ═════════════════════════════════════════════════════════════════════════════
# weapon_scene instantiates as Weapon3D
# ═════════════════════════════════════════════════════════════════════════════

func _check_weapon_scene(sd: SkillData) -> void:
	assert_not_null(sd.weapon_scene, str(sd.id) + ": weapon_scene must not be null")
	var w = add_child_autofree(sd.weapon_scene.instantiate())
	assert_true(w is Weapon3D, str(sd.id) + ": weapon_scene must instantiate as Weapon3D")

func test_natali_laughter_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/natali_laughter.tres")
	_check_weapon_scene(sd)

func test_natali_joy_orbit_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/natali_joy_orbit.tres")
	_check_weapon_scene(sd)

func test_natali_comic_relief_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/natali_comic_relief.tres")
	_check_weapon_scene(sd)

func test_natali_giggle_burst_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/natali_giggle_burst.tres")
	_check_weapon_scene(sd)

# ═════════════════════════════════════════════════════════════════════════════
# BESPOKE: NataliLaughter3D.fire() heal behaviour
# ═════════════════════════════════════════════════════════════════════════════

func test_laughter_fire_heals_player() -> void:
	## fire() must increase the stub player's hp.
	var w := _make_laughter()
	var player := StubPlayer.new()
	add_child_autofree(player)
	player.hp = 40.0
	player.stats.max_hp = 100.0
	w.setup(player, _make_stats())
	var before: float = player.hp
	w.fire()
	assert_gt(player.hp, before, "fire() must increase player hp")

func test_laughter_fire_heal_capped_at_max_hp() -> void:
	## fire() must not push hp above max_hp.
	var w := _make_laughter()
	var player := StubPlayer.new()
	add_child_autofree(player)
	player.hp = 98.0
	player.stats.max_hp = 100.0
	w.setup(player, _make_stats())
	w.fire()
	assert_eq(player.hp, 100.0, "hp must be clamped to max_hp after heal")

func test_laughter_fire_does_not_overheal() -> void:
	## Starting at max_hp: hp must not exceed max_hp after fire().
	var w := _make_laughter()
	var player := StubPlayer.new()
	add_child_autofree(player)
	player.hp = 100.0
	player.stats.max_hp = 100.0
	w.setup(player, _make_stats())
	w.fire()
	assert_eq(player.hp, 100.0, "hp must not exceed max_hp when already full")

func test_laughter_fire_heal_amount_positive() -> void:
	## HEAL_AMOUNT constant must be positive.
	var w := _make_laughter()
	assert_gt(NataliLaughter3D.HEAL_AMOUNT, 0.0, "HEAL_AMOUNT must be positive")

func test_laughter_fire_no_crash_without_player() -> void:
	## fire() must not crash when setup() was not called with a valid player.
	var w := _make_laughter()
	var stats := _make_stats()
	w.stats = stats
	# Do NOT call setup — _player_ref stays null.
	# Should complete without error.
	w.fire()
	assert_true(true, "fire() must not crash without a player reference")

func test_laughter_defaults() -> void:
	var w := _make_laughter()
	assert_almost_eq(w.radius, 6.0, 0.001, "default radius must be 6.0")
	assert_almost_eq(w.damage, 6.0, 0.001, "default damage must be 6.0")
	assert_almost_eq(w.base_cooldown, 3.0, 0.001, "default base_cooldown must be 3.0")
