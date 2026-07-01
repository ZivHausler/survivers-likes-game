extends GutTest
## Pure tests for cluster prop placement (reuses ArenaScatter.compute_positions).

const PropLayout := preload("res://arena/floor/prop_layout.gd")

func _clusters() -> Array:
	return [
		{ "role": &"landmark", "center": Vector2(0, 40), "ext": 1.0, "seed": 1, "sep": 1.0,
			"items": [["hero", 1, true, 1.0]] },
		{ "role": &"medium", "center": Vector2(-30, 20), "ext": 10.0, "seed": 10, "sep": 6.0,
			"items": [["bench", 3, true, 1.0]] },
		{ "role": &"small", "center": Vector2(20, -20), "ext": 10.0, "seed": 20, "sep": 3.0,
			"items": [["bush", 8, false, 1.0], ["flower", 6, false, 1.0]] },
	]

func test_deterministic() -> void:
	var a := PropLayout.resolve(_clusters(), 10.0)
	var b := PropLayout.resolve(_clusters(), 10.0)
	assert_eq(a.size(), b.size(), "same input → same count")
	for i in a.size():
		assert_true(a[i]["pos"].is_equal_approx(b[i]["pos"]), "placement %d identical" % i)

func test_entries_carry_key_role_collide_scale_and_xz_pos() -> void:
	var out := PropLayout.resolve(_clusters(), 10.0)
	assert_true(out.size() > 0)
	for e in out:
		assert_true(e.has("key") and e.has("pos") and e.has("collide") and e.has("scale") and e.has("role"))
		assert_almost_eq(e["pos"].y, 0.0, 0.001, "props sit on the y=0 plane")

func test_spawn_disc_kept_clear() -> void:
	# Force a cluster over the origin; nothing should be placed inside clear_radius.
	var clusters := [{ "role": &"small", "center": Vector2(0, 0), "ext": 30.0, "seed": 5, "sep": 4.0,
		"items": [["bush", 20, false, 1.0]] }]
	for e in PropLayout.resolve(clusters, 12.0):
		var d := Vector2(e["pos"].x, e["pos"].z).length()
		assert_true(d >= 12.0, "prop at radius %.1f violates the 12u spawn disc" % d)

func test_role_counts_match_budget_ranges() -> void:
	# Using the real Garden recipe, the resolved counts must hit the spec's budget.
	var recipe: Dictionary = load("res://arena/maps/garden_map.gd").RECIPE
	var out := PropLayout.resolve(recipe["prop_clusters"], 12.0)
	var by_role := { &"landmark": 0, &"medium": 0, &"small": 0 }
	for e in out:
		by_role[e["role"]] += 1
	assert_true(by_role[&"landmark"] >= 1 and by_role[&"landmark"] <= 3, "1–3 landmarks, got %d" % by_role[&"landmark"])
	assert_true(by_role[&"medium"] >= 8 and by_role[&"medium"] <= 30, "8–30 medium, got %d" % by_role[&"medium"])
	assert_true(by_role[&"small"] >= 40 and by_role[&"small"] <= 130, "40–130 small, got %d" % by_role[&"small"])
