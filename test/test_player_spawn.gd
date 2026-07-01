extends GutTest
## Unit tests for PlayerSpawn.spawn_point — deterministic party spawn positions.

func test_single_player_spawns_at_center():
	assert_eq(PlayerSpawn.spawn_point(0, 1, 3.0), Vector3.ZERO)

func test_four_players_are_distinct_and_on_radius():
	var pts := []
	for i in range(4):
		pts.append(PlayerSpawn.spawn_point(i, 4, 3.0))
	# distinct
	assert_eq(pts.size(), 4)
	for i in range(4):
		for j in range(i + 1, 4):
			assert_true(pts[i].distance_to(pts[j]) > 0.1)
	# on the ring (y=0, radius 3)
	for p in pts:
		assert_almost_eq(Vector2(p.x, p.z).length(), 3.0, 0.001)
		assert_eq(p.y, 0.0)
