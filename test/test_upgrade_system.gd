extends GutTest

func _make_sys(max_sig := 3) -> UpgradeSystem:
    var ch := CharacterData.new(); ch.id = &"ziv"; ch.max_signature_level = max_sig
    ch.passive_id = &"vanity"; ch.evolution_id = &"fabulous"
    var sig := Upgrade.new(); sig.id = &"sig"; sig.kind = Upgrade.Kind.SIGNATURE; sig.max_level = max_sig
    var pas := Upgrade.new(); pas.id = &"vanity"; pas.kind = Upgrade.Kind.PASSIVE; pas.max_level = 5
    var evo := Upgrade.new(); evo.id = &"fabulous"; evo.kind = Upgrade.Kind.EVOLUTION; evo.max_level = 1
    var gens: Array = []
    for i in 5:
        var g := Upgrade.new(); g.id = StringName("g%d" % i); g.kind = Upgrade.Kind.GENERIC; g.max_level = 5
        gens.append(g)
    return UpgradeSystem.new(ch, gens, sig, pas, evo)

func test_evolution_not_available_initially():
    assert_false(_make_sys().evolution_available())

func test_evolution_available_when_sig_max_and_passive_owned():
    var s := _make_sys(3)
    s.levels[&"sig"] = 3
    s.levels[&"vanity"] = 1
    assert_true(s.evolution_available())

func test_evolution_blocked_without_passive():
    var s := _make_sys(3)
    s.levels[&"sig"] = 3
    assert_false(s.evolution_available())

func test_build_choices_offers_evolution_when_available():
    var s := _make_sys(3)
    s.levels[&"sig"] = 3; s.levels[&"vanity"] = 1
    var rng := RandomNumberGenerator.new(); rng.seed = 1
    var choices := s.build_choices(rng, 3)
    var has_evo := choices.any(func(u): return u.kind == Upgrade.Kind.EVOLUTION)
    assert_true(has_evo)

func test_maxed_upgrades_not_offered():
    var s := _make_sys(3)
    s.levels[&"g0"] = 5  # generic maxed
    var rng := RandomNumberGenerator.new(); rng.seed = 2
    for _i in 10:
        var choices := s.build_choices(rng, 3)
        assert_false(choices.any(func(u): return u.id == &"g0"))

func test_apply_increments_level():
    var s := _make_sys(3)
    var sig := Upgrade.new(); sig.id = &"sig"; sig.kind = Upgrade.Kind.SIGNATURE; sig.max_level = 3
    s.apply(sig)
    assert_eq(s.levels[&"sig"], 1)
    s.apply(sig)
    assert_eq(s.levels[&"sig"], 2)

func test_apply_evolution_sets_evolved_and_emits():
    var s := _make_sys(3)
    var evo := Upgrade.new(); evo.id = &"fabulous"; evo.kind = Upgrade.Kind.EVOLUTION; evo.max_level = 1
    watch_signals(GameEvents)
    s.apply(evo)
    assert_true(s.evolved)
    assert_signal_emitted(GameEvents, "evolution_unlocked")
    assert_signal_emitted_with_parameters(GameEvents, "evolution_unlocked", [&"fabulous"])

func test_evolution_blocked_when_already_evolved():
    var s := _make_sys(3)
    s.levels[&"sig"] = 3
    s.levels[&"vanity"] = 1
    s.evolved = true
    assert_false(s.evolution_available())

func test_is_maxed():
    var s := _make_sys(3)
    var g := Upgrade.new(); g.id = &"g0"; g.kind = Upgrade.Kind.GENERIC; g.max_level = 5
    assert_false(s.is_maxed(g))
    s.levels[&"g0"] = 5
    assert_true(s.is_maxed(g))
