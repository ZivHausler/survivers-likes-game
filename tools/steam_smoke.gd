extends SceneTree
## DEV HARNESS ONLY — live Steam connection smoke test (Task C2). NOT part of the game.
##
## Requires Steam.exe running + logged in and the GodotSteam extension installed.
## Run with:
##   godot47 --headless --path . --script tools/steam_smoke.gd
##
## Inits Steam, creates a FRIENDS_ONLY lobby, pumps callbacks until lobby_created
## fires (or ~10 s timeout), then creates a host SteamMultiplayerPeer and prints its
## Error + connection status. quit(0) on success, quit(1) on timeout.

var _steam: Object
var _elapsed: float = 0.0
var _done: bool = false

func _initialize() -> void:
	if not Engine.has_singleton("Steam"):
		print("SMOKE steam: FAIL — Steam singleton not present (extension missing)")
		quit(1)
		return
	_steam = Engine.get_singleton("Steam")

	var init_res: Variant = _steam.call("steamInitEx") if _steam.has_method("steamInitEx") else _steam.call("steamInit")
	print("SMOKE steam: steamInitEx result = %s" % [init_res])

	_steam.connect("lobby_created", _on_lobby_created)
	print("SMOKE steam: createLobby(1, 4) ...")
	_steam.call("createLobby", 1, 4)

func _process(delta: float) -> bool:
	if _done:
		return true
	_steam.call("run_callbacks")
	_elapsed += delta
	if _elapsed >= 10.0:
		print("SMOKE steam: TIMEOUT — lobby_created did not fire within 10s")
		quit(1)
		return true
	return false

func _on_lobby_created(connect_result: int, lobby_id: int) -> void:
	print("SMOKE steam: lobby_created connect_result=%d lobby_id=%d" % [connect_result, lobby_id])
	print("SMOKE steam: getSteamID = %s" % [_steam.call("getSteamID")])
	if connect_result != 1:
		print("SMOKE steam: FAIL — connect_result != k_EResultOK(1)")
		_done = true
		quit(1)
		return
	if not ClassDB.can_instantiate("SteamMultiplayerPeer"):
		print("SMOKE steam: FAIL — SteamMultiplayerPeer cannot instantiate")
		_done = true
		quit(1)
		return
	var peer := ClassDB.instantiate("SteamMultiplayerPeer") as MultiplayerPeer
	var err: int = peer.call("create_host", 0)
	print("SMOKE steam: create_host(0) err=%d connection_status=%d" % [err, peer.get_connection_status()])
	print("SMOKE steam: OK" if err == OK else "SMOKE steam: FAIL — create_host err")
	_done = true
	quit(0 if err == OK else 1)
