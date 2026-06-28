extends GutTest
## Headless tests for the UpgradeUI card picker.
## Tests verify: correct card count, card content (name/desc/stat), level labels,
## EVOLUTION golden/EVOLVE treatment, and that _pick() emits chosen(upgrade).
## Pixel rendering is NOT asserted — manual playtest required for visual polish.

var _scene: PackedScene = null


func before_all() -> void:
	_scene = load("res://upgrades/upgrade_ui.tscn")


# ── helpers ──────────────────────────────────────────────────────────────────

func _make_generic(id: StringName, name: String,
		desc := "A description.", stat := "+1 Stat", max_lv := 5) -> Upgrade:
	var u := Upgrade.new()
	u.id           = id
	u.display_name = name
	u.kind         = Upgrade.Kind.GENERIC
	u.description  = desc
	u.stat_text    = stat
	u.max_level    = max_lv
	return u


## Build a UpgradeUI with a controlled generic pool.
## Signature and passive are auto-maxed so only pool entries appear in build_choices.
## Returns [ui, sys].
func _make_ui(pool: Array, levels: Dictionary = {}) -> Array:
	var ch := CharacterData.new()
	ch.id = &"tc"; ch.max_signature_level = 1
	ch.passive_id = &"xpas"; ch.evolution_id = &"xevo"

	var sig := Upgrade.new(); sig.id = &"xsig"; sig.kind = Upgrade.Kind.SIGNATURE; sig.max_level = 1
	var pas := Upgrade.new(); pas.id = &"xpas"; pas.kind = Upgrade.Kind.PASSIVE;   pas.max_level = 1
	var evo := Upgrade.new(); evo.id = &"xevo"; evo.kind = Upgrade.Kind.EVOLUTION; evo.max_level = 1

	var sys := UpgradeSystem.new(ch, pool, sig, pas, evo)
	sys.levels[&"xsig"] = 1  # max out so they don't pollute choices
	sys.levels[&"xpas"] = 1
	sys.evolved = true        # suppress evolution so only pool entries appear
	for k in levels:
		sys.levels[k] = levels[k]

	var ui: UpgradeUI = add_child_autofree(_scene.instantiate())
	ui.present(sys, null)
	return [ui, sys]


func _card(ui: UpgradeUI, i: int) -> Control:
	return ui.get_node("Panel/PanelVBox/CardRow/Card%d" % i)

func _label(ui: UpgradeUI, i: int, name: String) -> Label:
	return ui.get_node("Panel/PanelVBox/CardRow/Card%d/CardContent/%s" % [i, name])


# ── card count ────────────────────────────────────────────────────────────────

func test_one_choice_shows_one_card_hides_two() -> void:
	var u    := _make_generic(&"g1", "Swift Feet")
	var arr  := _make_ui([u])
	var ui   := arr[0] as UpgradeUI
	assert_true(_card(ui, 0).visible,  "Card0 must be visible for 1 choice")
	assert_false(_card(ui, 1).visible, "Card1 must be hidden")
	assert_false(_card(ui, 2).visible, "Card2 must be hidden")


func test_three_choices_show_three_cards() -> void:
	var pool := [
		_make_generic(&"g1", "Swift Feet"),
		_make_generic(&"g2", "Vitality Boost"),
		_make_generic(&"g3", "Thick Skin"),
	]
	var arr := _make_ui(pool)
	var ui  := arr[0] as UpgradeUI
	for i in 3:
		assert_true(_card(ui, i).visible, "Card%d must be visible for 3 choices" % i)


# ── card content ─────────────────────────────────────────────────────────────

func test_card_shows_correct_name_desc_stat() -> void:
	var u   := _make_generic(&"g1", "Swift Feet", "Run fast.", "+12 Move Speed")
	var arr := _make_ui([u])
	var ui  := arr[0] as UpgradeUI

	assert_eq(_label(ui, 0, "NameLabel").text, "Swift Feet",    "Name label wrong")
	assert_eq(_label(ui, 0, "DescLabel").text, "Run fast.",     "Desc label wrong")
	assert_eq(_label(ui, 0, "StatLabel").text, "+12 Move Speed","Stat label wrong")


# ── level labels ──────────────────────────────────────────────────────────────

func test_level_label_shows_new_when_never_picked() -> void:
	var u   := _make_generic(&"g1", "Swift Feet")
	var arr := _make_ui([u])  # levels empty → level 0
	var ui  := arr[0] as UpgradeUI
	assert_eq(_label(ui, 0, "LevelLabel").text, "NEW",
		"Unpicked upgrade must show NEW")


func test_level_label_shows_lv_x_when_owned() -> void:
	var u   := _make_generic(&"g1", "Swift Feet")
	u.max_level = 5
	var arr := _make_ui([u], {&"g1": 2})
	var ui  := arr[0] as UpgradeUI
	assert_eq(_label(ui, 0, "LevelLabel").text, "Lv 2 / 5",
		"Owned upgrade must show Lv X / max")


# ── evolution card ────────────────────────────────────────────────────────────

func test_evolution_card_shows_evolve_badge_and_golden_modulate() -> void:
	# Build a system where evolution is available (sig maxed, passive owned).
	var ch := CharacterData.new()
	ch.id = &"tc2"; ch.max_signature_level = 1
	ch.passive_id = &"xpas2"; ch.evolution_id = &"xevo2"

	var sig := Upgrade.new(); sig.id = &"xsig2"; sig.kind = Upgrade.Kind.SIGNATURE; sig.max_level = 1
	var pas := Upgrade.new(); pas.id = &"xpas2"; pas.kind = Upgrade.Kind.PASSIVE;   pas.max_level = 1
	var evo := Upgrade.new()
	evo.id = &"xevo2"; evo.kind = Upgrade.Kind.EVOLUTION; evo.max_level = 1
	evo.display_name = "EVOLVE: Fabulous"
	evo.description  = "Ultimate form."
	evo.stat_text    = "Transforms everything."

	var sys := UpgradeSystem.new(ch, [], sig, pas, evo)
	sys.levels[&"xsig2"] = 1  # maxed → evolution_available() = true
	sys.levels[&"xpas2"] = 1

	var ui: UpgradeUI = add_child_autofree(_scene.instantiate())
	ui.present(sys, null)

	# Evolution is always first choice
	assert_true(_card(ui, 0).visible, "Evolution card must be visible")
	assert_eq(_label(ui, 0, "LevelLabel").text, "EVOLVE",
		"Evolution card must show EVOLVE badge")

	var m := _card(ui, 0).modulate
	assert_almost_eq(m.r, 1.0,  0.01, "Evolution modulate.r must be 1.0")
	assert_almost_eq(m.g, 0.85, 0.01, "Evolution modulate.g must be 0.85")
	assert_almost_eq(m.b, 0.1,  0.01, "Evolution modulate.b must be 0.1")

	assert_eq(_label(ui, 0, "NameLabel").text, "EVOLVE: Fabulous",
		"Evolution card name must match display_name")


# ── click → chosen signal ─────────────────────────────────────────────────────

func test_pick_emits_chosen_with_correct_upgrade() -> void:
	var u   := _make_generic(&"g1", "Swift Feet")
	var arr := _make_ui([u])
	var ui  := arr[0] as UpgradeUI

	watch_signals(ui)
	ui._pick(0)
	assert_signal_emitted(ui, "chosen")
	assert_signal_emitted_with_parameters(ui, "chosen", [u])


func test_pick_out_of_range_does_not_emit() -> void:
	var u   := _make_generic(&"g1", "Swift Feet")
	var arr := _make_ui([u])
	var ui  := arr[0] as UpgradeUI

	watch_signals(ui)
	ui._pick(5)  # only 1 choice available
	assert_signal_not_emitted(ui, "chosen")
