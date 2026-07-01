extends GutTest

func test_enet_host_returns_multiplayer_peer():
	var peer = NetTransport.create_peer("enet_host", {"port": 47591})
	assert_true(peer is ENetMultiplayerPeer)
	if peer:
		peer.close()

func test_unknown_mode_returns_null():
	var peer = NetTransport.create_peer("bogus_mode", {})
	assert_null(peer)
	assert_push_error("unknown transport mode: bogus_mode")
