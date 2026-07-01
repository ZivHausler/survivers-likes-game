extends GutTest

func _reg() -> LobbyRegistry:
	return LobbyRegistry.new()

func test_add_player_defaults_not_ready_no_fighter():
	var r := _reg()
	r.add_player(7, "Ziv")
	assert_eq(r.count(), 1)
	var p := r.get_player(7)
	assert_eq(p["name"], "Ziv")
	assert_eq(p["fighter_id"], "")
	assert_false(p["ready"])

func test_all_ready_false_when_empty():
	assert_false(_reg().all_ready())

func test_all_ready_true_only_when_every_player_ready():
	var r := _reg()
	r.add_player(1, "A"); r.add_player(2, "B")
	r.set_ready(1, true)
	assert_false(r.all_ready())
	r.set_ready(2, true)
	assert_true(r.all_ready())

func test_duplicate_fighters_allowed():
	var r := _reg()
	r.add_player(1, "A"); r.add_player(2, "B")
	r.set_fighter(1, "ziv_3d"); r.set_fighter(2, "ziv_3d")
	assert_eq(r.get_player(1)["fighter_id"], "ziv_3d")
	assert_eq(r.get_player(2)["fighter_id"], "ziv_3d")

func test_remove_player():
	var r := _reg()
	r.add_player(1, "A"); r.add_player(2, "B")
	r.remove_player(1)
	assert_eq(r.count(), 1)
	assert_eq(r.peer_ids(), [2])

func test_roundtrip_to_from_dict():
	var r := _reg()
	r.add_player(1, "A"); r.set_fighter(1, "ido_3d"); r.set_ready(1, true)
	var r2 := _reg()
	r2.from_dict(r.to_dict())
	assert_eq(r2.get_player(1), r.get_player(1))
