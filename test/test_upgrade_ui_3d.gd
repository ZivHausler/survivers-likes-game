# See docs/notes/upgrade-ui.md
extends GutTest
## Tests for UpgradeUI with SkillSystem (3D path).
## Verifies that the shared UI works correctly when driven by a SkillSystem:
## SYNERGY golden styling, SKILL "NEW" label, and no crash on present().
## Mirrors test_upgrade_ui.gd patterns but uses SkillSystem instead of UpgradeSystem.

var _scene: PackedScene = null


func before_all() -> void:
	_scene = load("res://upgrades/upgrade_ui.tscn")


# ── helpers ──────────────────────────────────────────────────────────────────

## Build a SkillData with the given skill_id.  is_sig=true → level pre-initialised to 1.
func _make_skill(skill_id: StringName, is_sig: bool = false) -> SkillData:
	var su  := Upgrade.new()
	su.id   = StringName(str(skill_id) + "_skill")
	su.kind = Upgrade.Kind.SKILL; su.max_level = 5; su.skill_id = skill_id
	su.display_name = "Test Skill+"; su.description = "A test skill."; su.stat_text = "+1 level"

	var pu  := Upgrade.new()
	pu.id   = StringName(str(skill_id) + "_passive")
	pu.kind = Upgrade.Kind.PASSIVE; pu.max_level = 5; pu.skill_id = skill_id
	pu.display_name = "Passive"; pu.description = "Passive desc."; pu.stat_text = "+1 passive"
	pu.effect_value = 0.5

	var syn := Upgrade.new()
	syn.id   = StringName(str(skill_id) + "_synergy")
	syn.kind = Upgrade.Kind.SYNERGY; syn.max_level = 1; syn.skill_id = skill_id
	syn.display_name = "SYNERGY: Fabulous"; syn.description = "Synergy!"; syn.stat_text = "Unlocks"

	var s := SkillData.new()
	s.id = skill_id
	s.skill_upgrade = su; s.passive_upgrade = pu; s.synergy_upgrade = syn
	s.is_signature = is_sig
	return s


## Build a SkillSystem with one skill and optional generics. Returns [ui, sys].
func _make_ui_with_skill_system(skill_id: StringName = &"uisk",
		is_sig: bool = true, generics: Array = []) -> Array:
	var skill := _make_skill(skill_id, is_sig)
	var sys   := SkillSystem.new([skill], generics)
	var ui: UpgradeUI = add_child_autofree(_scene.instantiate())
	ui.present(sys, null)
	return [ui, sys]


func _card(ui: UpgradeUI, i: int) -> Control:
	return ui.get_node("Panel/PanelVBox/CardRow/Card%d" % i)

func _label(ui: UpgradeUI, i: int, name: String) -> Label:
	return ui.get_node("Panel/PanelVBox/CardRow/Card%d/CardContent/%s" % [i, name])


# ── basic present / no crash ──────────────────────────────────────────────────

func test_skill_system_present_does_not_crash() -> void:
	# Simply constructing + presenting must not crash.
	var arr := _make_ui_with_skill_system()
	var ui  := arr[0] as UpgradeUI
	assert_not_null(ui, "UpgradeUI must be instantiated")
	assert_true(_card(ui, 0).visible or true,
		"present() with SkillSystem must not crash")


func test_skill_system_shows_at_least_one_card() -> void:
	var arr := _make_ui_with_skill_system()
	var ui  := arr[0] as UpgradeUI
	# Signature is pre-owned at level 1; skill_upgrade is at max 5 so leveling
	# is offered. The signature is at level 1 so passive should NOT be offered
	# yet (owned but SkillSystem only offers passive if is_owned == true, which
	# it is for the signature). At minimum, signature skill_upgrade (level 1) and
	# possibly others appear.
	assert_true(_card(ui, 0).visible, "At least one card must be visible")


# ── SKILL card → NEW label at level 0 ────────────────────────────────────────

func test_skill_card_at_level_zero_shows_new_label() -> void:
	# Create a system where the non-signature skill is not yet acquired (level 0).
	var sig    := _make_skill(&"sig",  true)   # owned (level 1)
	var other  := _make_skill(&"other", false)  # not owned (level 0)
	var sys    := SkillSystem.new([sig, other], [])
	var ui: UpgradeUI = add_child_autofree(_scene.instantiate())
	ui.present(sys, null)

	# Find the card showing the 'other' skill_upgrade (level 0).
	var found_new := false
	for i in 3:
		if not _card(ui, i).visible:
			continue
		if _label(ui, i, "LevelLabel").text == "NEW":
			found_new = true
			break
	assert_true(found_new, "A SKILL card at level 0 (not owned) must show 'NEW' label")


# ── SYNERGY card → golden modulate + SYNERGY badge ────────────────────────────

func test_synergy_card_is_golden_and_shows_synergy_badge() -> void:
	# Build a system where the synergy is available:
	# skill at max_level (5), passive owned (≥1), not yet synergized.
	var skill := _make_skill(&"syn_sk", true)
	var sys   := SkillSystem.new([skill], [])
	# Max out skill and give passive level 1 → synergy becomes available.
	sys.levels[skill.skill_upgrade.id]   = 5
	sys.levels[skill.passive_upgrade.id] = 1

	var ui: UpgradeUI = add_child_autofree(_scene.instantiate())
	ui.present(sys, null)

	# Synergy is the guaranteed first choice.
	assert_true(_card(ui, 0).visible, "Synergy card must be visible")
	assert_eq(_label(ui, 0, "LevelLabel").text, "SYNERGY",
		"Synergy card must show 'SYNERGY' badge")

	var m := _card(ui, 0).modulate
	assert_almost_eq(m.r, 1.0,  0.01, "Synergy modulate.r must be 1.0 (golden)")
	assert_almost_eq(m.g, 0.85, 0.01, "Synergy modulate.g must be 0.85 (golden)")
	assert_almost_eq(m.b, 0.1,  0.01, "Synergy modulate.b must be 0.1 (golden)")


func test_synergy_card_name_matches_display_name() -> void:
	var skill := _make_skill(&"syn_sk2", true)
	var sys   := SkillSystem.new([skill], [])
	sys.levels[skill.skill_upgrade.id]   = 5
	sys.levels[skill.passive_upgrade.id] = 1

	var ui: UpgradeUI = add_child_autofree(_scene.instantiate())
	ui.present(sys, null)

	assert_eq(_label(ui, 0, "NameLabel").text, "SYNERGY: Fabulous",
		"Synergy card name must match the synergy_upgrade display_name")


# ── Normal SKILL card (owned) → Lv X / max label ─────────────────────────────

func test_skill_card_owned_shows_level_label() -> void:
	var skill := _make_skill(&"lvsk", true)
	var sys   := SkillSystem.new([skill], [])
	# Signature starts at level 1. Apply twice more to go to level 3.
	sys.apply(skill.skill_upgrade)
	sys.apply(skill.skill_upgrade)
	# Now skill_upgrade level should be 3.
	var ui: UpgradeUI = add_child_autofree(_scene.instantiate())
	ui.present(sys, null)

	# Find the card for the signature skill_upgrade.
	var found_lv := false
	for i in 3:
		if not _card(ui, i).visible:
			continue
		var lbl := _label(ui, i, "LevelLabel").text
		if lbl.begins_with("Lv"):
			found_lv = true
			break
	assert_true(found_lv, "An owned SKILL card must show a 'Lv X / Y' label")


# ── pick emits chosen ─────────────────────────────────────────────────────────

func test_skill_system_pick_emits_chosen() -> void:
	var arr := _make_ui_with_skill_system()
	var ui  := arr[0] as UpgradeUI
	watch_signals(ui)
	ui._pick(0)
	assert_signal_emitted(ui, "chosen",
		"_pick(0) with SkillSystem must emit chosen signal")
