class_name NetTransport
extends RefCounted

const DEFAULT_PORT := 7777

static func create_peer(mode: String, opts: Dictionary) -> MultiplayerPeer:
	match mode:
		"enet_host":
			var p := ENetMultiplayerPeer.new()
			p.create_server(int(opts.get("port", DEFAULT_PORT)), 4)
			return p
		"enet_client":
			var p := ENetMultiplayerPeer.new()
			p.create_client(String(opts.get("address", "127.0.0.1")), int(opts.get("port", DEFAULT_PORT)))
			return p
		"steam_host":
			if not ClassDB.can_instantiate("SteamMultiplayerPeer"):
				push_error("SteamMultiplayerPeer not available")
				return null
			var p := ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
			var err: int = p.call("create_host", 0)
			if err != OK:
				push_error("SteamMultiplayerPeer.create_host failed: %d" % err)
				return null
			return p
		"steam_client":
			if not ClassDB.can_instantiate("SteamMultiplayerPeer"):
				push_error("SteamMultiplayerPeer not available")
				return null
			var host_steam_id := int(opts.get("host_steam_id", 0))
			var p := ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
			var err: int = p.call("create_client", host_steam_id, 0)
			if err != OK:
				push_error("SteamMultiplayerPeer.create_client failed: %d" % err)
				return null
			return p
	push_error("unknown transport mode: %s" % mode)
	return null
