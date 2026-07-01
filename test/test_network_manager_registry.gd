extends GutTest

var nm

func before_each():
	nm = load("res://net/network_manager.gd").new()
	add_child_autofree(nm)
	nm.registry = LobbyRegistry.new()

func test_apply_register_adds_player_and_signals():
	watch_signals(nm)
	nm._apply_register(5, "Ido")
	assert_eq(nm.registry.count(), 1)
	assert_signal_emitted(nm, "registry_changed")

func test_apply_set_fighter_and_ready():
	nm._apply_register(5, "Ido")
	nm._apply_set_fighter(5, "ido_3d")
	nm._apply_set_ready(5, true)
	assert_eq(nm.registry.get_player(5)["fighter_id"], "ido_3d")
	assert_true(nm.registry.all_ready())

func test_apply_unregister_removes():
	nm._apply_register(5, "Ido")
	nm._apply_unregister(5)
	assert_eq(nm.registry.count(), 0)
