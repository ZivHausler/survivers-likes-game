extends GutTest

# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

## Build a SkillData with correct Upgrade kinds/skill_ids for the given skill id.
## max_sig_level defaults to 5 (game canon).
func _make_skill(skill_id: StringName, is_sig: bool = false, max_skill_level: int = 5) -> SkillData:
	var skill_up := Upgrade.new()
	skill_up.id = StringName(str(skill_id) + "_skill")
	skill_up.kind = Upgrade.Kind.SKILL
	skill_up.max_level = max_skill_level
	skill_up.skill_id = skill_id

	var passive_up := Upgrade.new()
	passive_up.id = StringName(str(skill_id) + "_passive")
	passive_up.kind = Upgrade.Kind.PASSIVE
	passive_up.max_level = 5
	passive_up.skill_id = skill_id

	var synergy_up := Upgrade.new()
	synergy_up.id = StringName(str(skill_id) + "_synergy")
	synergy_up.kind = Upgrade.Kind.SYNERGY
	synergy_up.max_level = 1
	synergy_up.skill_id = skill_id

	var sd := SkillData.new()
	sd.id = skill_id
	sd.display_name = str(skill_id)
	sd.is_signature = is_sig
	sd.skill_upgrade = skill_up
	sd.passive_upgrade = passive_up
	sd.synergy_upgrade = synergy_up
	return sd


## Build a generic Upgrade.
func _make_generic(gid: StringName) -> Upgrade:
	var g := Upgrade.new()
	g.id = gid
	g.kind = Upgrade.Kind.GENERIC
	g.max_level = 5
	return g


## Build a SkillSystem with:
##   skills: [sig_skill, skill_a, skill_b, skill_c]
##   generics: [gen_x, gen_y]
func _make_sys() -> SkillSystem:
	var sig  := _make_skill(&"sig_skill", true)
	var sk_a := _make_skill(&"skill_a", false)
	var sk_b := _make_skill(&"skill_b", false)
	var sk_c := _make_skill(&"skill_c", false)
	var gen_x := _make_generic(&"gen_x")
	var gen_y := _make_generic(&"gen_y")
	return SkillSystem.new([sig, sk_a, sk_b, sk_c], [gen_x, gen_y])


## Convenience: retrieve SkillData from a fresh sys by id.
func _skill_of(sys: SkillSystem, skill_id: StringName) -> SkillData:
	for s in sys._skills:
		if s.id == skill_id:
			return s
	return null


func _rng(seed_val: int = 42) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r


# ---------------------------------------------------------------------------
# Init tests
# ---------------------------------------------------------------------------

func test_init_signature_owned():
	var sys := _make_sys()
	assert_true(sys.is_owned(_skill_of(sys, &"sig_skill")))


func test_init_signature_level_1():
	var sys := _make_sys()
	assert_eq(sys.skill_level(&"sig_skill"), 1)


func test_init_other_skills_not_owned():
	var sys := _make_sys()
	assert_false(sys.is_owned(_skill_of(sys, &"skill_a")))
	assert_false(sys.is_owned(_skill_of(sys, &"skill_b")))
	assert_false(sys.is_owned(_skill_of(sys, &"skill_c")))


func test_init_other_skill_levels_zero():
	var sys := _make_sys()
	assert_eq(sys.skill_level(&"skill_a"), 0)
	assert_eq(sys.skill_level(&"skill_b"), 0)
	assert_eq(sys.skill_level(&"skill_c"), 0)


# ---------------------------------------------------------------------------
# build_choices — initial state
# ---------------------------------------------------------------------------

func test_build_choices_no_passive_for_unowned_skills():
	var sys := _make_sys()
	var choices := sys.build_choices(_rng(), 10)  # ask for many to expose all options
	for u in choices:
		if u.kind == Upgrade.Kind.PASSIVE:
			# Should only be offered for owned skills
			var sid := u.skill_id
			assert_true(sys.skill_level(sid) >= 1,
				"Passive offered for unowned skill: " + str(sid))


func test_build_choices_no_synergy_at_start():
	var sys := _make_sys()
	var choices := sys.build_choices(_rng(), 10)
	for u in choices:
		assert_true(u.kind != Upgrade.Kind.SYNERGY,
			"Synergy should not appear at start")


func test_build_choices_at_start_contains_acquirable_skills():
	var sys := _make_sys()
	var choices := sys.build_choices(_rng(), 10)
	# The 3 acquirable skill_upgrades should be in the pool
	var ids := choices.map(func(u): return u.id)
	assert_true(ids.has(&"skill_a_skill") or ids.has(&"skill_b_skill") or ids.has(&"skill_c_skill"))


func test_build_choices_contains_sig_skill_upgrade_at_start():
	# Signature starts at level 1; max is 5 so it should still be levelable
	var sys := _make_sys()
	var choices := sys.build_choices(_rng(), 10)
	var ids := choices.map(func(u): return u.id)
	assert_true(ids.has(&"sig_skill_skill"))


# ---------------------------------------------------------------------------
# Acquire flow
# ---------------------------------------------------------------------------

func test_acquire_sets_level_to_1():
	var sys := _make_sys()
	var sk_a := _skill_of(sys, &"skill_a")
	sys.apply(sk_a.skill_upgrade)
	assert_eq(sys.skill_level(&"skill_a"), 1)


func test_acquire_makes_is_owned_true():
	var sys := _make_sys()
	var sk_a := _skill_of(sys, &"skill_a")
	sys.apply(sk_a.skill_upgrade)
	assert_true(sys.is_owned(sk_a))


func test_passive_offered_after_acquire():
	var sys := _make_sys()
	var sk_a := _skill_of(sys, &"skill_a")
	sys.apply(sk_a.skill_upgrade)
	var choices := sys.build_choices(_rng(), 10)
	var ids := choices.map(func(u): return u.id)
	assert_true(ids.has(&"skill_a_passive"))


func test_passive_not_offered_before_acquire():
	var sys := _make_sys()
	var choices := sys.build_choices(_rng(), 10)
	for u in choices:
		assert_true(u.id != &"skill_a_passive",
			"skill_a passive must not appear before acquire")


# ---------------------------------------------------------------------------
# acquisition-detection contract (GameManager pattern)
# ---------------------------------------------------------------------------

func test_acquisition_detected_via_skill_level_equals_1():
	var sys := _make_sys()
	var sk_b := _skill_of(sys, &"skill_b")
	sys.apply(sk_b.skill_upgrade)
	# GameManager checks skill_level(skill_id_of(u)) == 1 after apply
	var detected := sys.skill_level(sys.skill_id_of(sk_b.skill_upgrade)) == 1
	assert_true(detected)


func test_skill_id_of_skill_upgrade():
	var sys := _make_sys()
	var sk_a := _skill_of(sys, &"skill_a")
	assert_eq(sys.skill_id_of(sk_a.skill_upgrade), &"skill_a")


func test_skill_id_of_passive_upgrade():
	var sys := _make_sys()
	var sk_a := _skill_of(sys, &"skill_a")
	assert_eq(sys.skill_id_of(sk_a.passive_upgrade), &"skill_a")


func test_skill_id_of_synergy_upgrade():
	var sys := _make_sys()
	var sk_a := _skill_of(sys, &"skill_a")
	assert_eq(sys.skill_id_of(sk_a.synergy_upgrade), &"skill_a")


func test_skill_id_of_generic_is_empty():
	var sys := _make_sys()
	var g := _make_generic(&"gen_x")
	assert_eq(sys.skill_id_of(g), &"")


# ---------------------------------------------------------------------------
# Level cap
# ---------------------------------------------------------------------------

func test_skill_maxes_at_5():
	var sys := _make_sys()
	var sig := _skill_of(sys, &"sig_skill")
	for _i in 4:
		sys.apply(sig.skill_upgrade)
	assert_eq(sys.skill_level(&"sig_skill"), 5)
	assert_true(sys.is_maxed(sig.skill_upgrade))


func test_maxed_skill_not_in_build_choices():
	var sys := _make_sys()
	var sig := _skill_of(sys, &"sig_skill")
	# sig starts at 1; need 4 more to hit max 5
	for _i in 4:
		sys.apply(sig.skill_upgrade)
	assert_true(sys.is_maxed(sig.skill_upgrade))
	# Now build_choices should not offer it
	var choices := sys.build_choices(_rng(), 10)
	for u in choices:
		assert_true(u.id != &"sig_skill_skill",
			"Maxed skill_upgrade must not appear in choices")


# ---------------------------------------------------------------------------
# Passive gating
# ---------------------------------------------------------------------------

func test_passive_offered_when_skill_owned_not_maxed():
	var sys := _make_sys()
	var sk_c := _skill_of(sys, &"skill_c")
	sys.apply(sk_c.skill_upgrade)
	var choices := sys.build_choices(_rng(), 10)
	var ids := choices.map(func(u): return u.id)
	assert_true(ids.has(&"skill_c_passive"))


func test_passive_not_offered_when_maxed():
	var sys := _make_sys()
	var sk_a := _skill_of(sys, &"skill_a")
	# Own the skill first
	sys.apply(sk_a.skill_upgrade)
	# Max the passive
	for _i in 5:
		sys.apply(sk_a.passive_upgrade)
	assert_true(sys.is_maxed(sk_a.passive_upgrade))
	var choices := sys.build_choices(_rng(), 10)
	for u in choices:
		assert_true(u.id != &"skill_a_passive",
			"Maxed passive must not appear in choices")


func test_passive_level_increments():
	var sys := _make_sys()
	var sk_a := _skill_of(sys, &"skill_a")
	sys.apply(sk_a.skill_upgrade)
	sys.apply(sk_a.passive_upgrade)
	assert_eq(sys.passive_level(&"skill_a"), 1)
	sys.apply(sk_a.passive_upgrade)
	assert_eq(sys.passive_level(&"skill_a"), 2)


# ---------------------------------------------------------------------------
# Synergy gating (item 5 core)
# ---------------------------------------------------------------------------

func test_synergy_not_available_initially():
	var sys := _make_sys()
	var sig := _skill_of(sys, &"sig_skill")
	assert_false(sys.synergy_available(sig))


func test_synergy_not_available_without_passive():
	var sys := _make_sys()
	var sig := _skill_of(sys, &"sig_skill")
	# Max the skill (sig already at 1, needs 4 more)
	for _i in 4:
		sys.apply(sig.skill_upgrade)
	assert_false(sys.synergy_available(sig), "No synergy without passive")


func test_synergy_not_available_without_skill_maxed():
	var sys := _make_sys()
	var sig := _skill_of(sys, &"sig_skill")
	# Give passive but don't max skill
	sys.apply(sig.passive_upgrade)
	assert_false(sys.synergy_available(sig), "No synergy when skill not maxed")


func test_synergy_available_when_maxed_and_passive_owned():
	var sys := _make_sys()
	var sig := _skill_of(sys, &"sig_skill")
	for _i in 4:
		sys.apply(sig.skill_upgrade)   # 1→5
	sys.apply(sig.passive_upgrade)     # passive ≥ 1
	assert_true(sys.synergy_available(sig))


func test_build_choices_guarantees_synergy_when_available():
	var sys := _make_sys()
	var sig := _skill_of(sys, &"sig_skill")
	for _i in 4:
		sys.apply(sig.skill_upgrade)
	sys.apply(sig.passive_upgrade)
	assert_true(sys.synergy_available(sig))
	var choices := sys.build_choices(_rng(), 3)
	var has_synergy := false
	for u in choices:
		if u.kind == Upgrade.Kind.SYNERGY and u.skill_id == &"sig_skill":
			has_synergy = true
	assert_true(has_synergy, "Synergy must be a guaranteed slot in build_choices")


func test_synergy_is_first_in_choices():
	var sys := _make_sys()
	var sig := _skill_of(sys, &"sig_skill")
	for _i in 4:
		sys.apply(sig.skill_upgrade)
	sys.apply(sig.passive_upgrade)
	var choices := sys.build_choices(_rng(), 3)
	assert_eq(choices[0].kind, Upgrade.Kind.SYNERGY)


func test_apply_synergy_marks_synergized():
	var sys := _make_sys()
	var sig := _skill_of(sys, &"sig_skill")
	for _i in 4:
		sys.apply(sig.skill_upgrade)
	sys.apply(sig.passive_upgrade)
	sys.apply(sig.synergy_upgrade)
	assert_true(sys.synergized.has(&"sig_skill"))


func test_apply_synergy_emits_evolution_unlocked():
	var sys := _make_sys()
	var sig := _skill_of(sys, &"sig_skill")
	watch_signals(GameEvents)
	for _i in 4:
		sys.apply(sig.skill_upgrade)
	sys.apply(sig.passive_upgrade)
	sys.apply(sig.synergy_upgrade)
	assert_signal_emitted(GameEvents, "evolution_unlocked")
	assert_signal_emitted_with_parameters(GameEvents, "evolution_unlocked", [&"sig_skill"])


func test_synergy_not_available_after_applied():
	var sys := _make_sys()
	var sig := _skill_of(sys, &"sig_skill")
	for _i in 4:
		sys.apply(sig.skill_upgrade)
	sys.apply(sig.passive_upgrade)
	sys.apply(sig.synergy_upgrade)
	assert_false(sys.synergy_available(sig))


func test_synergy_not_in_choices_after_applied():
	var sys := _make_sys()
	var sig := _skill_of(sys, &"sig_skill")
	for _i in 4:
		sys.apply(sig.skill_upgrade)
	sys.apply(sig.passive_upgrade)
	sys.apply(sig.synergy_upgrade)
	var choices := sys.build_choices(_rng(), 10)
	for u in choices:
		assert_true(u.kind != Upgrade.Kind.SYNERGY,
			"Synergy must not appear after it has been applied")


# ---------------------------------------------------------------------------
# has_available_choices
# ---------------------------------------------------------------------------

func test_has_available_choices_true_at_start():
	var sys := _make_sys()
	assert_true(sys.has_available_choices())


func test_has_available_choices_false_when_exhausted():
	# Build a minimal system: 1 skill + no generics, so we can exhaust everything.
	var sig := _make_skill(&"only", true)
	var sys := SkillSystem.new([sig], [])
	# Max skill: sig starts at 1, needs 4 more
	for _i in 4:
		sys.apply(sig.skill_upgrade)
	# Max passive
	for _i in 5:
		sys.apply(sig.passive_upgrade)
	# Apply synergy
	sys.apply(sig.synergy_upgrade)
	assert_false(sys.has_available_choices())


func test_has_available_choices_true_when_synergy_available():
	var sys := _make_sys()
	# Max sig and give it a passive
	var sig := _skill_of(sys, &"sig_skill")
	for _i in 4:
		sys.apply(sig.skill_upgrade)
	sys.apply(sig.passive_upgrade)
	assert_true(sys.has_available_choices())


# ---------------------------------------------------------------------------
# No duplicate ids in build_choices
# ---------------------------------------------------------------------------

func test_no_duplicate_ids_in_build_choices():
	var sys := _make_sys()
	var rng := _rng(99)
	for _trial in 20:
		var choices := sys.build_choices(rng, 3)
		var ids: Dictionary = {}
		for u in choices:
			assert_false(ids.has(u.id),
				"Duplicate id in choices: " + str(u.id))
			ids[u.id] = true


func test_build_choices_returns_at_most_count():
	var sys := _make_sys()
	for count in [1, 2, 3]:
		var choices := sys.build_choices(_rng(), count)
		assert_true(choices.size() <= count)


# ---------------------------------------------------------------------------
# Generic upgrades
# ---------------------------------------------------------------------------

func test_generic_in_choices_when_not_maxed():
	var sys := _make_sys()
	var choices := sys.build_choices(_rng(), 10)
	var ids := choices.map(func(u): return u.id)
	assert_true(ids.has(&"gen_x") or ids.has(&"gen_y"))


func test_maxed_generic_not_in_choices():
	var sys := _make_sys()
	# Manually max gen_x via apply
	var g := _make_generic(&"gen_x")
	for _i in 5:
		sys.apply(g)
	assert_true(sys.is_maxed(g))
	var choices := sys.build_choices(_rng(), 10)
	for u in choices:
		assert_true(u.id != &"gen_x", "Maxed generic must not appear in choices")


# ---------------------------------------------------------------------------
# is_maxed
# ---------------------------------------------------------------------------

func test_is_maxed_false_initially():
	var sys := _make_sys()
	var sk_a := _skill_of(sys, &"skill_a")
	assert_false(sys.is_maxed(sk_a.skill_upgrade))


func test_is_maxed_true_at_max_level():
	var sys := _make_sys()
	var sk_a := _skill_of(sys, &"skill_a")
	for _i in 5:
		sys.apply(sk_a.skill_upgrade)
	assert_true(sys.is_maxed(sk_a.skill_upgrade))


# ---------------------------------------------------------------------------
# CharacterData.skills field (additive, non-breaking)
# ---------------------------------------------------------------------------

func test_character_data_skills_field_exists():
	var cd := CharacterData.new()
	assert_true(cd.get("skills") != null or "skills" in cd,
		"CharacterData should have a skills field")


func test_character_data_skills_empty_by_default():
	var cd := CharacterData.new()
	assert_eq(cd.skills.size(), 0)


func test_character_data_skills_accepts_skill_data():
	var cd := CharacterData.new()
	var skill := _make_skill(&"test_skill", false)
	cd.skills.append(skill)
	assert_eq(cd.skills.size(), 1)
	assert_eq(cd.skills[0].id, &"test_skill")


# ---------------------------------------------------------------------------
# Upgrade.Kind enum additions (additive, non-breaking)
# ---------------------------------------------------------------------------

func test_upgrade_kind_skill_value():
	assert_eq(Upgrade.Kind.SKILL, 4)


func test_upgrade_kind_synergy_value():
	assert_eq(Upgrade.Kind.SYNERGY, 5)


func test_upgrade_existing_kind_values_unchanged():
	assert_eq(Upgrade.Kind.SIGNATURE, 0)
	assert_eq(Upgrade.Kind.PASSIVE, 1)
	assert_eq(Upgrade.Kind.GENERIC, 2)
	assert_eq(Upgrade.Kind.EVOLUTION, 3)


func test_upgrade_skill_id_field_exists():
	var u := Upgrade.new()
	assert_eq(u.skill_id, &"")
