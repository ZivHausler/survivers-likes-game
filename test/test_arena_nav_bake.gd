extends GutTest
## Verifies the arena's navigation mesh is BAKED with obstacle footprints carved out
## (instead of a flat quad), so enemy NavigationAgent3D pathfinding routes AROUND
## terrain. Tests the pure static bake helper directly — deterministic, no live server.

## True when world-XZ point `p` lies inside any polygon of the baked navmesh
## (i.e. it is walkable). Carved holes have no covering polygon.
func _walkable(navmesh: NavigationMesh, p: Vector2) -> bool:
	var verts := navmesh.get_vertices()
	for i in navmesh.get_polygon_count():
		var poly := navmesh.get_polygon(i)
		var pts := PackedVector2Array()
		for idx in poly:
			var v := verts[idx]
			pts.append(Vector2(v.x, v.z))
		if Geometry2D.is_point_in_polygon(p, pts):
			return true
	return false

func test_flat_bake_produces_walkable_floor() -> void:
	var navmesh := GardenScatter.build_carved_navmesh(20.0, 0.5, [])
	assert_true(navmesh.get_polygon_count() > 0, "bake must produce navmesh polygons")
	assert_true(_walkable(navmesh, Vector2.ZERO), "open floor origin must be walkable")

func test_obstacle_footprint_is_carved_out() -> void:
	var footprints := [{"pos": Vector3(8, 0, 0), "radius": 2.0}]
	var navmesh := GardenScatter.build_carved_navmesh(20.0, 0.5, footprints)
	assert_false(_walkable(navmesh, Vector2(8, 0)),
		"the obstacle footprint center must be carved out of the navmesh")
	assert_true(_walkable(navmesh, Vector2.ZERO),
		"floor away from the obstacle must remain walkable")

func test_agent_radius_recorded_on_navmesh() -> void:
	# Radius kept an exact multiple of the bake cell_size (0.5) so it is not voxel-ceiled.
	var navmesh := GardenScatter.build_carved_navmesh(20.0, 1.0, [])
	assert_almost_eq(navmesh.agent_radius, 1.0, 0.001,
		"navmesh must carry the enemy agent radius so paths keep clearance")
