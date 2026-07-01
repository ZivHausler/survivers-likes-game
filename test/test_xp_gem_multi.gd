extends GutTest

func _n(pos: Vector3) -> Node3D:
	var n := Node3D.new(); add_child_autofree(n); n.global_position = pos; return n

func test_nearest_player_picks_closest():
	var a := _n(Vector3(9, 0, 0))
	var b := _n(Vector3(1, 0, 0))
	assert_eq(XPGem3D.nearest_player(Vector3.ZERO, [a, b]), b)

func test_nearest_player_ignores_invalid():
	var a := _n(Vector3(2, 0, 0))
	assert_eq(XPGem3D.nearest_player(Vector3.ZERO, [null, a]), a)

func test_nearest_player_none_returns_null():
	assert_null(XPGem3D.nearest_player(Vector3.ZERO, []))
