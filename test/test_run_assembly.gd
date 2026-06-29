extends GutTest
## Verifies GameManager3D assembles a run's skill list as
## [ultimate] + type-filtered shared pool, ultimate first.

func _stub(id: StringName, type: StringName, signature := false) -> SkillData:
	var sd := SkillData.new()
	sd.id = id
	sd.type = type
	sd.is_signature = signature
	return sd

func _ids(arr: Array) -> Array:
	var out := []
	for sd in arr:
		out.append(sd.id)
	return out

func test_assemble_puts_ultimate_first_then_filtered_pool() -> void:
	var ult := _stub(&"ziv_ult", &"charm", true)
	var pool := [_stub(&"n", &"natural"), _stub(&"c", &"charm"), _stub(&"h", &"holy")]
	var got := GameManager3D.assemble_run_skills(ult, pool, [&"charm"])
	assert_eq(_ids(got), [&"ziv_ult", &"n", &"c"], "ultimate first, then natural + charm")

func test_assemble_null_ultimate_omitted() -> void:
	var pool := [_stub(&"n", &"natural")]
	var got := GameManager3D.assemble_run_skills(null, pool, [])
	assert_eq(_ids(got), [&"n"], "null ultimate is skipped")
