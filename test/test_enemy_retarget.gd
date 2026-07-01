# test/test_enemy_retarget.gd
extends GutTest

func _n(pos: Vector3) -> Node3D:
	var n := Node3D.new()
	add_child_autofree(n)
	n.global_position = pos
	return n

func test_nearest_picks_closest():
	var a := _n(Vector3(10, 0, 0))
	var b := _n(Vector3(2, 0, 0))
	var c := _n(Vector3(5, 0, 0))
	assert_eq(Enemy3D.nearest_target(Vector3.ZERO, [a, b, c]), b)

func test_nearest_ignores_null_and_invalid():
	var a := _n(Vector3(3, 0, 0))
	assert_eq(Enemy3D.nearest_target(Vector3.ZERO, [null, a]), a)

func test_nearest_empty_returns_null():
	assert_null(Enemy3D.nearest_target(Vector3.ZERO, []))
