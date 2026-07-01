extends GutTest
## Structural tests for the Garden prop builder.

func _build() -> Node3D:
	var root := Node3D.new()
	add_child_autofree(root)
	var gs := GardenScatter.new()
	gs.recipe_path = "res://arena/maps/garden_map.gd"
	gs.clear_radius = 12.0
	# Do NOT add gs to root -- that fires gs._ready(), which deferred-builds Props + a nav
	# region that never land under -gexit, orphaning nodes. Build synchronously instead.
	gs.build_props(root)
	gs.free()
	return root

func test_props_tree_structure() -> void:
	var root := _build()
	var props := root.get_node_or_null("Props")
	assert_not_null(props, "GardenScatter must build a Props node")
	for c in ["Landmarks", "MediumProps", "SmallDetails"]:
		assert_not_null(props.get_node_or_null(c), "Props must contain %s" % c)

func test_budget_counts() -> void:
	var root := _build()
	var props := root.get_node("Props")
	assert_eq(props.get_node("Landmarks").get_child_count(), 1, "exactly 1 landmark")
	var med := props.get_node("MediumProps").get_child_count()
	var small := props.get_node("SmallDetails").get_child_count()
	assert_true(med >= 3 and med <= 6, "3-6 medium props, got %d" % med)
	assert_true(small >= 10 and small <= 25, "10-25 small props, got %d" % small)

func test_spawn_disc_clear() -> void:
	var root := _build()
	var props := root.get_node("Props")
	for group in ["Landmarks", "MediumProps", "SmallDetails"]:
		for p in props.get_node(group).get_children():
			var n := p as Node3D
			var d := Vector2(n.position.x, n.position.z).length()
			assert_true(d >= 12.0, "prop '%s' at radius %.1f violates spawn disc" % [n.name, d])

func test_collider_props_wrapped_in_obstacle3d() -> void:
	var root := _build()
	var landmark := root.get_node("Props/Landmarks").get_child(0)
	assert_true(landmark is Obstacle3D, "colliding landmark must be an Obstacle3D wrapper")
