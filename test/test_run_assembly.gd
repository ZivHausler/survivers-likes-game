extends GutTest
## Verifies GameManager3D.assemble_run_skills returns ONLY the type-filtered pool
## with NO ultimate entry — the ultimate is granted into the manual SPACE slot
## separately and must never appear in the upgrade pool.

func _stub(id: StringName, type: StringName) -> SkillData:
	var sd := SkillData.new()
	sd.id = id
	sd.type = type
	return sd

func _ids(arr: Array) -> Array:
	var out := []
	for sd in arr:
		out.append(sd.id)
	return out

func test_assembled_skills_equal_type_filtered_pool() -> void:
	var pool := [_stub(&"n", &"natural"), _stub(&"c", &"charm"), _stub(&"h", &"holy")]
	var got := GameManager3D.assemble_run_skills(pool, [&"charm"])
	assert_eq(_ids(got), [&"n", &"c"], "result is natural + charm-typed only")

func test_assembled_skills_empty_types_gives_only_natural() -> void:
	var pool := [_stub(&"n", &"natural"), _stub(&"c", &"charm")]
	var got := GameManager3D.assemble_run_skills(pool, [])
	assert_eq(_ids(got), [&"n"], "empty types yields natural-only")

func test_ultimate_not_in_assembled_skills() -> void:
	# Even though the ultimate shares the character's type, it is granted
	# separately into the SPACE slot — assemble_run_skills has no ultimate param.
	var ult_id := &"ziv_ult"
	var pool := [_stub(&"n", &"natural"), _stub(&"c", &"charm")]
	var got := GameManager3D.assemble_run_skills(pool, [&"charm"])
	assert_false(_ids(got).has(ult_id), "ultimate id must not appear in run-skill pool")
