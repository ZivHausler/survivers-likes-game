# See docs/notes/char-ido.md
extends GutTest
## Tests for Ido character data, skills, and bespoke Toxic Cloud fire() behavior.
##
## Data integrity tests: CharacterData loads with 4 SkillData; each SkillData has
## 3 upgrades with correct Kinds and matching skill_id; weapon_scene instantiates
## as Weapon3D.
##
## Bespoke fire() tests: IdoToxicCloud3D.fire() applies take_damage() to enemies
## within radius on each call (DoT tick), and does not hit enemies outside radius.

# ─────────────────────────────────────────────────────────────────────────────
# Stub enemy — inline inner class.
# ─────────────────────────────────────────────────────────────────────────────
class StubEnemy extends Node3D:
	var damage_received: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		damage_received += amount
		hit_count += 1

# ─────────────────────────────────────────────────────────────────────────────
# Scene / resource caches
# ─────────────────────────────────────────────────────────────────────────────
var _ToxicCloudScene: PackedScene = null

func before_all() -> void:
	_ToxicCloudScene = load("res://weapons/ido_toxic_cloud_3d.tscn")

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _make_stats(dmg: float = 1.0) -> StatBlock:
	var s := StatBlock.new()
	s.damage_mult    = dmg
	s.fire_rate_mult = 1.0
	return s

func _make_toxic_cloud() -> IdoToxicCloud3D:
	assert_not_null(_ToxicCloudScene, "ido_toxic_cloud_3d.tscn must exist")
	var w: IdoToxicCloud3D = add_child_autofree(_ToxicCloudScene.instantiate()) as IdoToxicCloud3D
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

func test_ido_3d_loads() -> void:
	var cd: CharacterData = load("res://characters/ido_3d.tres")
	assert_not_null(cd, "ido_3d.tres must load")

func test_ido_3d_has_4_skills() -> void:
	var cd: CharacterData = load("res://characters/ido_3d.tres")
	assert_eq(cd.skills.size(), 4, "Ido must have exactly 4 skills")

func test_ido_first_skill_is_signature() -> void:
	var cd: CharacterData = load("res://characters/ido_3d.tres")
	assert_true(cd.skills[0].is_signature, "Ido skills[0] must be is_signature")

func test_ido_extra_skills_not_signature() -> void:
	var cd: CharacterData = load("res://characters/ido_3d.tres")
	for i in range(1, cd.skills.size()):
		assert_false(cd.skills[i].is_signature,
			"Ido skills[%d] must not be signature" % i)

func test_ido_skill_ids_correct() -> void:
	var cd: CharacterData = load("res://characters/ido_3d.tres")
	var ids: Array = cd.skills.map(func(s: SkillData) -> StringName: return s.id)
	assert_true(ids.has(&"ido_toxic_cloud"),  "ido_toxic_cloud must be in Ido skills")
	assert_true(ids.has(&"ido_venom_orbs"),   "ido_venom_orbs must be in Ido skills")
	assert_true(ids.has(&"ido_miasma"),       "ido_miasma must be in Ido skills")
	assert_true(ids.has(&"ido_corrosion"),    "ido_corrosion must be in Ido skills")

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

func test_ido_toxic_cloud_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/ido_toxic_cloud.tres")
	assert_not_null(sd, "ido_toxic_cloud.tres must load")
	_check_skill(sd)

func test_ido_venom_orbs_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/ido_venom_orbs.tres")
	assert_not_null(sd, "ido_venom_orbs.tres must load")
	_check_skill(sd)

func test_ido_miasma_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/ido_miasma.tres")
	assert_not_null(sd, "ido_miasma.tres must load")
	_check_skill(sd)

func test_ido_corrosion_upgrade_correctness() -> void:
	var sd: SkillData = load("res://characters/skills/ido_corrosion.tres")
	assert_not_null(sd, "ido_corrosion.tres must load")
	_check_skill(sd)

# ═════════════════════════════════════════════════════════════════════════════
# weapon_scene instantiates as Weapon3D
# ═════════════════════════════════════════════════════════════════════════════

func _check_weapon_scene(sd: SkillData) -> void:
	assert_not_null(sd.weapon_scene, str(sd.id) + ": weapon_scene must not be null")
	var w = add_child_autofree(sd.weapon_scene.instantiate())
	assert_true(w is Weapon3D, str(sd.id) + ": weapon_scene must instantiate as Weapon3D")

func test_ido_toxic_cloud_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/ido_toxic_cloud.tres")
	_check_weapon_scene(sd)

func test_ido_venom_orbs_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/ido_venom_orbs.tres")
	_check_weapon_scene(sd)

func test_ido_miasma_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/ido_miasma.tres")
	_check_weapon_scene(sd)

func test_ido_corrosion_weapon_scene() -> void:
	var sd: SkillData = load("res://characters/skills/ido_corrosion.tres")
	_check_weapon_scene(sd)

# ═════════════════════════════════════════════════════════════════════════════
# Bespoke fire() — IdoToxicCloud3D DoT tick behavior
# ═════════════════════════════════════════════════════════════════════════════

func test_toxic_cloud_initial_params() -> void:
	var w := _make_toxic_cloud()
	assert_almost_eq(w.damage, 8.0, 0.001, "Toxic Cloud damage must start at 8.0")
	assert_almost_eq(w.radius, 6.0, 0.001, "Toxic Cloud radius must start at 6.0")
	assert_almost_eq(w.base_cooldown, 1.0, 0.001, "Toxic Cloud base_cooldown must be 1.0")

func test_toxic_cloud_fire_damages_enemy_in_radius() -> void:
	var w := _make_toxic_cloud()
	# Enemy within radius=6, placed at distance 3
	var e := _make_stub_enemy(3.0, 0.0)
	w.fire()
	assert_gt(e.hit_count, 0, "Enemy within radius must be hit by Toxic Cloud fire()")

func test_toxic_cloud_fire_does_not_hit_enemy_outside_radius() -> void:
	var w := _make_toxic_cloud()
	# Enemy at distance 10 > radius=6
	var e := _make_stub_enemy(10.0, 0.0)
	w.fire()
	assert_eq(e.hit_count, 0, "Enemy outside radius must not be hit by Toxic Cloud fire()")

func test_toxic_cloud_fire_applies_correct_damage() -> void:
	var w := _make_toxic_cloud()
	var e := _make_stub_enemy(2.0, 0.0)
	w.fire()
	# damage=8.0, damage_mult=1.0 → expected 8.0
	assert_almost_eq(e.damage_received, 8.0, 0.001,
		"Toxic Cloud must deal damage * damage_mult per fire tick")

func test_toxic_cloud_fire_ticks_repeatedly() -> void:
	# fire() is a simple tick — calling it twice doubles the total damage
	var w := _make_toxic_cloud()
	var e := _make_stub_enemy(2.0, 0.0)
	w.fire()
	w.fire()
	assert_almost_eq(e.damage_received, 16.0, 0.001,
		"Two fire() ticks must deal 2x damage (DoT behavior)")

func test_toxic_cloud_fire_hits_multiple_enemies() -> void:
	var w := _make_toxic_cloud()
	var e1 := _make_stub_enemy(1.0, 0.0)
	var e2 := _make_stub_enemy(0.0, 4.0)
	w.fire()
	assert_gt(e1.hit_count, 0, "First enemy in radius must be hit")
	assert_gt(e2.hit_count, 0, "Second enemy in radius must be hit")

func test_toxic_cloud_fire_scales_with_damage_mult() -> void:
	assert_not_null(_ToxicCloudScene, "ido_toxic_cloud_3d.tscn must exist")
	var w: IdoToxicCloud3D = add_child_autofree(_ToxicCloudScene.instantiate()) as IdoToxicCloud3D
	var player: Node3D = add_child_autofree(Node3D.new()) as Node3D
	var s := StatBlock.new()
	s.damage_mult = 2.0
	s.fire_rate_mult = 1.0
	w.setup(player, s)
	var e := _make_stub_enemy(2.0, 0.0)
	w.fire()
	# damage=8 * mult=2 = 16
	assert_almost_eq(e.damage_received, 16.0, 0.001,
		"Toxic Cloud damage must scale with stats.damage_mult")

func test_toxic_cloud_no_charm() -> void:
	var w := _make_toxic_cloud()
	assert_almost_eq(w.charm_duration, 0.0, 0.001,
		"Toxic Cloud must not have charm_duration (poison, not charm)")

func test_toxic_cloud_affected_enemies_helper_pure() -> void:
	# Test the inherited affected_enemies() helper — nodes must be in tree for global_position.
	var w := _make_toxic_cloud()
	var close: StubEnemy = add_child_autofree(StubEnemy.new()) as StubEnemy
	close.global_position = Vector3(3.0, 0.0, 0.0)
	var far: StubEnemy = add_child_autofree(StubEnemy.new()) as StubEnemy
	far.global_position = Vector3(20.0, 0.0, 0.0)
	var result := w.affected_enemies([close, far], Vector3.ZERO)
	assert_eq(result.size(), 1, "affected_enemies must only return enemies within radius")
	assert_true(result.has(close), "Only the close enemy must be in the result")
