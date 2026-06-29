extends GutTest
## Water body must be visible AND block movement (Obstacles layer + nav obstacle).

const OBSTACLE_BIT := 16
var Scene: PackedScene = null

func before_all() -> void:
	Scene = load("res://obstacles/water_3d.tscn")

func test_scene_loads() -> void:
	assert_not_null(Scene, "water_3d.tscn must load")

func test_is_blocking_and_has_visual_and_nav() -> void:
	var w: Water3D = Scene.instantiate()
	assert_true(w is StaticBody3D, "Water3D is a StaticBody3D")
	assert_true((w.collision_layer & OBSTACLE_BIT) == OBSTACLE_BIT, "water blocks on layer 16")
	assert_not_null(w.get_node_or_null("MeshInstance3D"), "water has a visible surface")
	assert_not_null(w.get_node_or_null("CollisionShape3D"), "water has blocking collision")
	assert_not_null(w.get_node_or_null("NavigationObstacle3D"), "water has a nav obstacle")
	w.free()
