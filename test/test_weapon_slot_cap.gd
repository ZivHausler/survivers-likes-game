extends GutTest
## Verifies the weapon-slot cap: at cap, no new weapons are offered, but
## level-ups of owned weapons and generics still are. Signature is exempt.

func _skill_upgrade(sid: StringName) -> Upgrade:
	var u := Upgrade.new()
	u.id = sid
	u.kind = Upgrade.Kind.SKILL
	u.max_level = 5
	u.skill_id = sid
	return u

func _passive_upgrade(sid: StringName) -> Upgrade:
	var u := Upgrade.new()
	u.id = StringName(str(sid) + "_p")
	u.kind = Upgrade.Kind.PASSIVE
	u.max_level = 5
	u.skill_id = sid
	return u

func _synergy_upgrade(sid: StringName) -> Upgrade:
	var u := Upgrade.new()
	u.id = StringName(str(sid) + "_s")
	u.kind = Upgrade.Kind.SYNERGY
	u.max_level = 1
	u.skill_id = sid
	return u

func _skill(sid: StringName, signature: bool) -> SkillData:
	var sd := SkillData.new()
	sd.id = sid
	sd.is_signature = signature
	sd.skill_upgrade = _skill_upgrade(sid)
	sd.passive_upgrade = _passive_upgrade(sid)
	sd.synergy_upgrade = _synergy_upgrade(sid)
	return sd

func _pool_ids(sys: SkillSystem) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var out := []
	# Pull a generous count so we see the whole eligible pool.
	for u in sys.build_choices(rng, 99):
		out.append(u.id)
	return out

func test_owned_weapon_count_excludes_signature() -> void:
	var ult := _skill(&"ult", true)
	var w1 := _skill(&"w1", false)
	var sys := SkillSystem.new([ult, w1], [], 6)
	# Only the signature is owned at start → 0 non-signature weapons.
	assert_eq(sys.owned_weapon_count(), 0)
	sys.apply(w1.skill_upgrade)  # acquire w1 (0→1)
	assert_eq(sys.owned_weapon_count(), 1)

func test_new_weapon_blocked_at_cap() -> void:
	var ult := _skill(&"ult", true)
	var w1 := _skill(&"w1", false)
	var w2 := _skill(&"w2", false)
	var sys := SkillSystem.new([ult, w1, w2], [], 1)  # cap = 1
	sys.apply(w1.skill_upgrade)  # own 1 weapon → at cap
	var ids := _pool_ids(sys)
	assert_does_not_have(ids, &"w2", "new weapon must not be offered at cap")
	assert_has(ids, &"w1", "owned weapon level-up must still be offered")

func test_under_cap_offers_new_weapon() -> void:
	var ult := _skill(&"ult", true)
	var w1 := _skill(&"w1", false)
	var w2 := _skill(&"w2", false)
	var sys := SkillSystem.new([ult, w1, w2], [], 6)
	sys.apply(w1.skill_upgrade)
	var ids := _pool_ids(sys)
	assert_has(ids, &"w2", "below cap, new weapon is offered")

func test_cap_zero_means_unlimited() -> void:
	var ult := _skill(&"ult", true)
	var w1 := _skill(&"w1", false)
	var w2 := _skill(&"w2", false)
	var sys := SkillSystem.new([ult, w1, w2], [], 0)  # unlimited
	sys.apply(w1.skill_upgrade)
	var ids := _pool_ids(sys)
	assert_has(ids, &"w2", "cap<=0 disables the limit")
