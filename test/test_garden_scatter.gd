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
	# Dense art-directed budget (superseded the old sparse 1/3-6/10-25, which itself
	# tripped the "props are sparse" visual auto-fail). Upper bound raised to 38 after
	# adding arena-ring props inside the gameplay frustum (the combat view was empty of
	# props at the real camera framing). Ranges stay bounded to catch runaway/empty scatter.
	var land := props.get_node("Landmarks").get_child_count()
	var med := props.get_node("MediumProps").get_child_count()
	var small := props.get_node("SmallDetails").get_child_count()
	assert_true(land >= 1 and land <= 3, "1-3 landmarks, got %d" % land)
	assert_true(med >= 8 and med <= 38, "8-38 medium props, got %d" % med)
	assert_true(small >= 40 and small <= 130, "40-130 small props, got %d" % small)

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
