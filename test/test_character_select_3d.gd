# See docs/notes/character-select-3d.md
extends GutTest
## Combined sanity test for all 10 CharacterData resources and the data-driven selector.
## Tests: 4-skill arrays, correct upgrade Kinds, model_scene set, unique skill_ids,
## and that CharacterSelect3D generates exactly 10 buttons.

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

const CHARACTER_PATHS: Array[String] = [
	"res://characters/ziv_3d.tres",
	"res://characters/avihay_3d.tres",
	"res://characters/avinoam_3d.tres",
	"res://characters/matan_3d.tres",
	"res://characters/ido_3d.tres",
	"res://characters/yuval_3d.tres",
	"res://characters/natali_3d.tres",
	"res://characters/barak_3d.tres",
	"res://characters/yinon_3d.tres",
	"res://characters/yoav_3d.tres",
]

func _load_char(path: String) -> CharacterData:
	var cd: CharacterData = load(path) as CharacterData
	assert_not_null(cd, "CharacterData must load from %s" % path)
	return cd

func _check_skill_upgrades(sd: SkillData) -> void:
	var sid: StringName = sd.id
	assert_not_null(sd.skill_upgrade,   str(sid) + ": skill_upgrade must not be null")
	assert_not_null(sd.passive_upgrade, str(sid) + ": passive_upgrade must not be null")
	assert_not_null(sd.synergy_upgrade, str(sid) + ": synergy_upgrade must not be null")
	assert_eq(sd.skill_upgrade.kind,   Upgrade.Kind.SKILL,   str(sid) + ": skill_upgrade.kind must be SKILL (4)")
	assert_eq(sd.passive_upgrade.kind, Upgrade.Kind.PASSIVE, str(sid) + ": passive_upgrade.kind must be PASSIVE (1)")
	assert_eq(sd.synergy_upgrade.kind, Upgrade.Kind.SYNERGY, str(sid) + ": synergy_upgrade.kind must be SYNERGY (5)")
	assert_eq(sd.skill_upgrade.skill_id,   sid, str(sid) + ": skill_upgrade.skill_id must match")
	assert_eq(sd.passive_upgrade.skill_id, sid, str(sid) + ": passive_upgrade.skill_id must match")
	assert_eq(sd.synergy_upgrade.skill_id, sid, str(sid) + ": synergy_upgrade.skill_id must match")

# ─────────────────────────────────────────────────────────────────────────────
# All 10 CharacterData: load, 4 skills, signature, upgrade kinds, unique ids
# ─────────────────────────────────────────────────────────────────────────────

func test_all_ten_characters_load() -> void:
	for path in CHARACTER_PATHS:
		var cd: CharacterData = load(path) as CharacterData
		assert_not_null(cd, "CharacterData must load from %s" % path)

func test_all_ten_characters_have_4_skills() -> void:
	for path in CHARACTER_PATHS:
		var cd: CharacterData = _load_char(path)
		if cd == null:
			continue
		assert_eq(cd.skills.size(), 4,
			"%s must have exactly 4 skills (got %d)" % [path, cd.skills.size()])

func test_all_ten_characters_skills0_is_signature() -> void:
	for path in CHARACTER_PATHS:
		var cd: CharacterData = _load_char(path)
		if cd == null or cd.skills.size() == 0:
			continue
		var sd: SkillData = cd.skills[0] as SkillData
		assert_not_null(sd, "%s: skills[0] must be a SkillData" % path)
		if sd:
			assert_true(sd.is_signature, "%s: skills[0].is_signature must be true" % path)

func test_all_ten_characters_upgrade_kinds() -> void:
	for path in CHARACTER_PATHS:
		var cd: CharacterData = _load_char(path)
		if cd == null:
			continue
		for i in cd.skills.size():
			var sd: SkillData = cd.skills[i] as SkillData
			assert_not_null(sd, "%s: skills[%d] must be SkillData" % [path, i])
			if sd:
				_check_skill_upgrades(sd)

func test_all_ten_characters_model_scene_set() -> void:
	for path in CHARACTER_PATHS:
		var cd: CharacterData = _load_char(path)
		if cd == null:
			continue
		assert_not_null(cd.model_scene,
			"%s: model_scene must not be null" % path)

func test_all_ten_characters_skill_ids_unique() -> void:
	for path in CHARACTER_PATHS:
		var cd: CharacterData = _load_char(path)
		if cd == null:
			continue
		var seen: Dictionary = {}
		for i in cd.skills.size():
			var sd: SkillData = cd.skills[i] as SkillData
			if sd == null:
				continue
			var sid: StringName = sd.id
			assert_false(seen.has(sid),
				"%s: duplicate skill_id '%s' at index %d" % [path, sid, i])
			seen[sid] = true

# ─────────────────────────────────────────────────────────────────────────────
# Selector scene generates exactly 10 buttons
# ─────────────────────────────────────────────────────────────────────────────

func test_selector_generates_10_buttons() -> void:
	var scene: PackedScene = load("res://ui/character_select_3d.tscn")
	assert_not_null(scene, "character_select_3d.tscn must load")
	if scene == null:
		return

	var root: CharacterSelect3D = add_child_autofree(scene.instantiate()) as CharacterSelect3D
	assert_not_null(root, "scene must instantiate as CharacterSelect3D")
	if root == null:
		return

	# Wait one frame for _ready() to fire
	await get_tree().process_frame

	var grid: GridContainer = root.get_node_or_null("VBox/Scroll/Grid") as GridContainer
	assert_not_null(grid, "VBox/Scroll/Grid must exist in the scene")
	if grid == null:
		return

	var btn_count: int = 0
	for child in grid.get_children():
		if child is Button:
			btn_count += 1

	assert_eq(btn_count, 10, "Selector must generate exactly 10 buttons (got %d)" % btn_count)
