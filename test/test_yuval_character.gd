# See docs/notes/char-yuval.md
extends GutTest
## Tests for Yuval character data, skills, and Soundwave weapon.
##
## Data integrity tests: CharacterData loads with 4 SkillData; each SkillData has
## 3 upgrades with correct Kinds and matching skill_id; weapon_scene instantiates
## as Weapon3D.

# ─────────────────────────────────────────────────────────────────────────────
# Stub enemy — inline inner class.
# ─────────────────────────────────────────────────────────────────────────────
class StubEnemy extends Node3D:
	var damage_received: float = 0.0
	var hit_count: int = 0
	var charm_calls: int = 0
	var last_charm_duration: float = 0.0

	func take_damage(amount: float) -> void:
		damage_received += amount
		hit_count += 1

	func charm(duration: float) -> void:
		last_charm_duration = max(last_charm_duration, duration)
		charm_calls += 1

# ─────────────────────────────────────────────────────────────────────────────
# Scene / resource caches
# ─────────────────────────────────────────────────────────────────────────────
var _SoundwaveScene: PackedScene = null

func before_all() -> void:
	_SoundwaveScene = load("res://weapons/yuval_soundwave_3d.tscn")

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _make_stats(dmg: float = 1.0) -> StatBlock:
	var s := StatBlock.new()
	s.damage_mult    = dmg
	s.fire_rate_mult = 1.0
	return s

func _make_soundwave() -> YuvalSoundwave3D:
	assert_not_null(_SoundwaveScene, "yuval_soundwave_3d.tscn must exist")
	var w: YuvalSoundwave3D = add_child_autofree(_SoundwaveScene.instantiate()) as YuvalSoundwave3D
	var player: Node3D = add_child_autofree(Node3D.new()) as Node3D
	w.setup(player, _make_stats())
	return w

func _make_stub_enemy(xpos: float = 0.0, zpos: float = 0.0) -> StubEnemy:
	var e := StubEnemy.new()
	add_child_autofree(e)
	e.add_to_group("enemies")
	e.global_position = Vector3(xpos, 0.0, zpos)
	return e

# ═════════════════════════════════════════════════════════════════════════════
# CharacterData loading
# ═════════════════════════════════════════════════════════════════════════════

func test_yuval_3d_loads() -> void:
	var cd: CharacterData = load("res://characters/yuval_3d.tres")
	assert_not_null(cd, "yuval_3d.tres must load")

func test_yuval_3d_has_4_skills() -> void:
	var cd: CharacterData = load("res://characters/yuval_3d.tres")
	assert_eq(cd.skills.size(), 4, "Yuval must have exactly 4 skills")

func test_yuval_first_skill_is_signature() -> void:
	var cd: CharacterData = load("res://characters/yuval_3d.tres")
	assert_true(cd.skills[0].is_signature, "Yuval skills[0] must be is_signature")

func test_yuval_extra_skills_not_signature() -> void:
	var cd: CharacterData = load("res://characters/yuval_3d.tres")
	for i in range(1, cd.skills.size()):
		assert_false(cd.skills[i].is_signature,
			"Yuval skills[%d] must not be signature" % i)

func test_yuval_skill_ids_correct() -> void:
	var cd: CharacterData = load("res://characters/yuval_3d.tres")
	var ids: Array = cd.skills.map(func(s: SkillData) -> StringName: return s.id)
	assert_true(ids.has(&"yuval_soundwave"),   "yuval_soundwave must be in Yuval skills")
	assert_true(ids.has(&"yuval_echo_orbit"),  "yuval_echo_orbit must be in Yuval skills")
	assert_true(ids.has(&"yuval_bass_drop"),   "yuval_bass_drop must be in Yuval skills")
	assert_true(ids.has(&"yuval_resonance"),   "yuval_resonance must be in Yuval skills")

# ═════════════════════════════════════════════════════════════════════════════
# Upgrade correctness helper
# ═════════════════════════════════════════════════════════════════════════════

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

func test_yuval_soundwave_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/yuval_soundwave.tres")
	assert_not_null(sd, "yuval_soundwave.tres must load")
	_check_skill(sd)

func test_yuval_echo_orbit_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/yuval_echo_orbit.tres")
	assert_not_null(sd, "yuval_echo_orbit.tres must load")
	_check_skill(sd)

func test_yuval_bass_drop_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/yuval_bass_drop.tres")
	assert_not_null(sd, "yuval_bass_drop.tres must load")
	_check_skill(sd)

func test_yuval_resonance_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/yuval_resonance.tres")
	assert_not_null(sd, "yuval_resonance.tres must load")
	_check_skill(sd)

# ═════════════════════════════════════════════════════════════════════════════
# weapon_scene instantiates as Weapon3D
# ═════════════════════════════════════════════════════════════════════════════

func _check_weapon_scene(sd: SkillData) -> void:
	assert_not_null(sd.weapon_scene, str(sd.id) + ": weapon_scene must not be null")
	var w = add_child_autofree(sd.weapon_scene.instantiate())
	assert_true(w is Weapon3D, str(sd.id) + ": weapon_scene must instantiate as Weapon3D")

func test_yuval_soundwave_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/yuval_soundwave.tres")
	_check_weapon_scene(sd)

func test_yuval_echo_orbit_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/yuval_echo_orbit.tres")
	_check_weapon_scene(sd)

func test_yuval_bass_drop_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/yuval_bass_drop.tres")
	_check_weapon_scene(sd)

func test_yuval_resonance_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/yuval_resonance.tres")
	_check_weapon_scene(sd)

# ═════════════════════════════════════════════════════════════════════════════
# YuvalSoundwave3D — initial params and nova+charm behavior
# ═════════════════════════════════════════════════════════════════════════════

func test_soundwave_initial_damage() -> void:
	var w := _make_soundwave()
	assert_almost_eq(w.damage, 15.0, 0.001, "Soundwave damage must start at 15.0")

func test_soundwave_initial_radius() -> void:
	var w := _make_soundwave()
	assert_almost_eq(w.radius, 6.0, 0.001, "Soundwave radius must start at 6.0")

func test_soundwave_initial_charm_duration() -> void:
	var w := _make_soundwave()
	assert_almost_eq(w.charm_duration, 2.0, 0.001, "Soundwave charm_duration (stun) must start at 2.0")

func test_soundwave_initial_cooldown() -> void:
	var w := _make_soundwave()
	assert_almost_eq(w.base_cooldown, 2.5, 0.001, "Soundwave base_cooldown must be 2.5")

func test_soundwave_fire_damages_enemy_in_radius() -> void:
	var w := _make_soundwave()
	var e := _make_stub_enemy(3.0, 0.0)
	w.fire()
	assert_gt(e.hit_count, 0, "Enemy in radius must take damage from Soundwave fire()")

func test_soundwave_fire_charms_enemy_in_radius() -> void:
	var w := _make_soundwave()
	var e := _make_stub_enemy(3.0, 0.0)
	w.fire()
	assert_gt(e.charm_calls, 0, "Enemy in radius must be charmed/stunned by Soundwave fire()")

func test_soundwave_fire_does_not_hit_enemy_outside_radius() -> void:
	var w := _make_soundwave()
	var e := _make_stub_enemy(15.0, 0.0)
	w.fire()
	assert_eq(e.hit_count, 0, "Enemy outside radius must not be hit by Soundwave")

func test_soundwave_affected_enemies_within_radius() -> void:
	var w := _make_soundwave()
	# Nodes must be in the scene tree for global_position to work.
	var close: StubEnemy = add_child_autofree(StubEnemy.new()) as StubEnemy
	close.global_position = Vector3(4.0, 0.0, 0.0)
	var far: StubEnemy = add_child_autofree(StubEnemy.new()) as StubEnemy
	far.global_position = Vector3(12.0, 0.0, 0.0)
	var result := w.affected_enemies([close, far], Vector3.ZERO)
	assert_eq(result.size(), 1, "Only enemy within radius=6 must be returned")
	assert_true(result.has(close), "The close enemy must be in affected list")

func test_soundwave_level_up_increases_radius() -> void:
	var w := _make_soundwave()
	var before := w.radius
	w.level_up()
	assert_gt(w.radius, before, "Soundwave radius must increase after level_up")

func test_soundwave_level_up_increases_charm_duration() -> void:
	var w := _make_soundwave()
	var before := w.charm_duration
	w.level_up()
	assert_gt(w.charm_duration, before, "Soundwave charm_duration must increase after level_up")
