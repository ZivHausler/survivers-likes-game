extends GutTest
## Structural + configure() tests for the reusable collidable map prop.

const OBSTACLE_BIT := 16
var Scene: PackedScene = null

func before_all() -> void:
	Scene = load("res://obstacles/obstacle_3d.tscn")

func test_scene_loads() -> void:
	assert_not_null(Scene, "obstacle_3d.tscn must load")

func test_is_staticbody_on_obstacle_layer() -> void:
	var o: Obstacle3D = Scene.instantiate()
	assert_true(o is StaticBody3D, "Obstacle3D must be a StaticBody3D")
	assert_true((o.collision_layer & OBSTACLE_BIT) == OBSTACLE_BIT,
		"Obstacle3D must be ON the Obstacles layer (16)")
	o.free()

func test_has_required_children() -> void:
	var o: Obstacle3D = Scene.instantiate()
	assert_not_null(o.get_node_or_null("MeshInstance3D"), "needs a MeshInstance3D")
	assert_not_null(o.get_node_or_null("CollisionShape3D"), "needs a CollisionShape3D")
	assert_not_null(o.get_node_or_null("NavigationObstacle3D"), "needs a NavigationObstacle3D")
	o.free()

func test_configure_sets_footprint_and_nav_radius() -> void:
	var o: Obstacle3D = add_child_autofree(Scene.instantiate())
	var mesh := BoxMesh.new()
	o.configure(mesh, 2.5, 6.0)
	var mi: MeshInstance3D = o.get_node("MeshInstance3D")
	assert_eq(mi.mesh, mesh, "configure must assign the visual mesh")
	var shape: CylinderShape3D = (o.get_node("CollisionShape3D") as CollisionShape3D).shape
	assert_almost_eq(shape.radius, 2.5, 0.001, "collision radius must match footprint")
	assert_almost_eq(shape.height, 6.0, 0.001, "collision height must match")
	var nav: NavigationObstacle3D = o.get_node("NavigationObstacle3D")
	assert_almost_eq(nav.radius, 2.5, 0.001, "nav obstacle radius must match footprint")
