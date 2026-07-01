# See docs/notes/spawner-3d.md
extends GutTest
## Unit tests for Spawner3D party targeting (Task B2).

func _n(pos: Vector3) -> Node3D:
	var n := Node3D.new(); add_child_autofree(n); n.global_position = pos; return n

func test_party_center_averages_positions():
	var a := _n(Vector3(0, 0, 0))
	var b := _n(Vector3(4, 0, 0))
	assert_eq(Spawner3D.party_center([a, b]), Vector3(2, 0, 0))

func test_party_center_ignores_invalid():
	var a := _n(Vector3(6, 0, 0))
	assert_eq(Spawner3D.party_center([null, a]), Vector3(6, 0, 0))

func test_party_center_empty_is_zero():
	assert_eq(Spawner3D.party_center([]), Vector3.ZERO)

func test_setup_wraps_single_target_into_party():
	var sp := Spawner3D.new()
	var root := Node3D.new(); add_child_autofree(root)
	root.add_child(sp)
	var t := _n(Vector3(1, 0, 0))
	sp.setup(t)
	assert_eq(sp.get_targets(), [t])
