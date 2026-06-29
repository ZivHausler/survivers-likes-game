extends GutTest
## Verifies the additive type-system fields on SkillData and CharacterData,
## including backward-compatibility with existing .tres resources.

func test_skilldata_type_defaults_to_natural() -> void:
	var sd := SkillData.new()
	assert_eq(sd.type, &"natural", "SkillData.type must default to &\"natural\"")

func test_skilldata_type_is_assignable() -> void:
	var sd := SkillData.new()
	sd.type = &"charm"
	assert_eq(sd.type, &"charm")

func test_characterdata_types_defaults_empty() -> void:
	var cd := CharacterData.new()
	assert_eq(cd.types.size(), 0, "CharacterData.types must default to []")
	assert_null(cd.ultimate, "CharacterData.ultimate must default to null")

func test_existing_skill_resource_still_loads_with_default_type() -> void:
	# Back-compat: a .tres authored before the field existed loads with the default.
	var sd: SkillData = load("res://characters/skills/ziv_mirror_shards.tres")
	assert_not_null(sd, "existing skill resource must still load")
	assert_eq(sd.type, &"natural", "legacy resource must read the default type")
