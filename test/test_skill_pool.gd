extends GutTest
## Tests the pure type-filter used to build each run's offer pool.

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

func test_filter_includes_natural_always() -> void:
	var pool := [_stub(&"n", &"natural"), _stub(&"c", &"charm"), _stub(&"h", &"holy")]
	var got := _ids(SkillPool.filter(pool, []))
	assert_eq(got, [&"n"], "empty types → natural only")

func test_filter_includes_matching_type() -> void:
	var pool := [_stub(&"n", &"natural"), _stub(&"c", &"charm"), _stub(&"h", &"holy")]
	var got := _ids(SkillPool.filter(pool, [&"charm"]))
	assert_eq(got, [&"n", &"c"], "natural + charm, not holy")

func test_filter_dual_type() -> void:
	var pool := [_stub(&"n", &"natural"), _stub(&"c", &"charm"), _stub(&"h", &"holy")]
	var got := _ids(SkillPool.filter(pool, [&"charm", &"holy"]))
	assert_eq(got, [&"n", &"c", &"h"], "natural + both matching types")

func test_all_is_empty_until_content_added() -> void:
	# Registry is intentionally empty in the foundation; content plans append to it.
	assert_eq(SkillPool.all().size(), 0)

func test_for_types_composes_all_and_filter() -> void:
	# With an empty registry, for_types is empty regardless of types.
	assert_eq(SkillPool.for_types([&"charm"]).size(), 0)
