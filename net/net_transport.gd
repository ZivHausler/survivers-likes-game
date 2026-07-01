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
		"steam_host", "steam_client":
			# Implemented in Task C2 once GodotSteam is installed.
			push_error("Steam transport not available yet")
			return null
	push_error("unknown transport mode: %s" % mode)
	return null
