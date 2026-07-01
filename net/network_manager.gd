extends Node

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal registry_changed()
signal all_ready()
signal host_aborted()
signal steam_lobby_ready(lobby_id: int)

# GodotSteam LobbyType: PRIVATE=0, FRIENDS_ONLY=1, PUBLIC=2, INVISIBLE=3.
const LOBBY_TYPE_FRIENDS_ONLY := 1
const MAX_MEMBERS := 4

var registry: LobbyRegistry = LobbyRegistry.new()
var local_name: String = "Player"
var _lobby_id: int = 0
var _steam_signals_connected: bool = false
# The GodotSteam addon may be present before Steam is actually initialized (Task C2).
# Only pump Steam callbacks once C2 has called steamInit and set this true, so ordinary
# ENet/solo runs never invoke the Steam API.
var _steam_ready: bool = false

func _ready() -> void:
	# CRITICAL: never let pause stop the Steam pump, or P2P silently stalls.
	process_mode = Node.PROCESS_MODE_ALWAYS
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.server_disconnected.connect(_on_server_disconnected)

func _process(_dt: float) -> void:
	# Pump Steam callbacks every frame (no-op until Steam is initialized in Task C2).
	# NOTE: called via Engine.get_singleton(...).call(...) rather than the bare
	# `Steam` identifier so the code parses whether or not GodotSteam is installed
	# (an undeclared global identifier is a parse error, not a runtime no-op).
	# Gated on _steam_ready so the pump stays inert until C2 initializes Steam,
	# even now that the addon binaries are present in the project.
	if _steam_ready and Engine.has_singleton("Steam"):
		Engine.get_singleton("Steam").call("run_callbacks")

func host_enet(port: int = NetTransport.DEFAULT_PORT) -> int:
	var peer := NetTransport.create_peer("enet_host", {"port": port})
	if peer == null:
		return ERR_CANT_CREATE
	multiplayer.multiplayer_peer = peer
	_apply_register(1, local_name)   # host is peer 1
	return OK

func join_enet(address: String, port: int = NetTransport.DEFAULT_PORT) -> int:
	var peer := NetTransport.create_peer("enet_client", {"address": address, "port": port})
	if peer == null:
		return ERR_CANT_CREATE
	multiplayer.multiplayer_peer = peer
	return OK

func is_host() -> bool:
	return multiplayer.multiplayer_peer != null and multiplayer.is_server()

# ---- Steam lobby lifecycle (Task C2) ----
# All Steam access goes through the guarded singleton so this file parses/boots
# with the GodotSteam extension absent (it is gitignored / missing in CI).
func _steam() -> Object:
	return Engine.get_singleton("Steam") if Engine.has_singleton("Steam") else null

func steam_init() -> bool:
	var s := _steam()
	if s == null:
		return false
	# GodotSteam init returns a status Dictionary/int; status 0 == OK.
	var status: int
	if s.has_method("steamInitEx"):
		status = _init_status(s.call("steamInitEx"))
	elif s.has_method("steamInit"):
		status = _init_status(s.call("steamInit"))
	else:
		return false
	if status != 0:
		return false
	_steam_ready = true
	if not _steam_signals_connected:
		s.connect("lobby_created", _on_lobby_created)
		s.connect("lobby_joined", _on_lobby_joined)
		s.connect("lobby_join_requested", _on_lobby_join_requested)
		_steam_signals_connected = true
	return true

func _init_status(res: Variant) -> int:
	# steamInitEx returns a Dictionary {status, verbal}; steamInit returns an int.
	if res is Dictionary:
		return int(res.get("status", -1))
	return int(res)

func host_steam() -> int:
	if not steam_init():
		return ERR_UNAVAILABLE
	# Peer creation is deferred to the lobby_created signal handler.
	_steam().call("createLobby", LOBBY_TYPE_FRIENDS_ONLY, MAX_MEMBERS)
	return OK

func join_steam(lobby_id: int) -> void:
	if _steam() == null:
		return
	if not _steam_ready:
		steam_init()  # ensure signals are connected before joining
	_steam().call("joinLobby", lobby_id)

func open_invite_overlay() -> void:
	if _lobby_id == 0 or _steam() == null:
		return
	_steam().call("activateGameOverlayInviteDialog", _lobby_id)

func _on_lobby_created(connect_result: int, lobby_id: int) -> void:
	if connect_result != 1:  # k_EResultOK
		push_error("Steam createLobby failed: %d" % connect_result)
		return
	_lobby_id = lobby_id
	var peer := NetTransport.create_peer("steam_host", {})
	if peer == null:
		return
	multiplayer.multiplayer_peer = peer
	_apply_register(1, local_name)   # host is peer 1
	steam_lobby_ready.emit(lobby_id)

func _on_lobby_joined(lobby_id: int, _permissions: int, _locked: bool, _response: int) -> void:
	_lobby_id = lobby_id
	var s := _steam()
	if s == null:
		return
	var owner: int = int(s.call("getLobbyOwner", lobby_id))
	if owner == int(s.call("getSteamID")):
		return  # we are the host; already set up in _on_lobby_created
	var peer := NetTransport.create_peer("steam_client", {"host_steam_id": owner})
	if peer == null:
		return
	multiplayer.multiplayer_peer = peer

func _on_lobby_join_requested(lobby_id: int, _friend_id: int) -> void:
	# Fired when the user accepts an invite from the Steam overlay.
	join_steam(lobby_id)

# ---- connection lifecycle ----
func _on_peer_connected(peer_id: int) -> void:
	# Host learns of a new client; ask them to register their name.
	if is_host():
		rpc_id(peer_id, "_rpc_request_register")

func _on_peer_disconnected(peer_id: int) -> void:
	if is_host():
		_apply_unregister(peer_id)
		_broadcast_registry()

func _on_connected_to_server() -> void:
	pass  # wait for _rpc_request_register from host

func _on_server_disconnected() -> void:
	host_aborted.emit()

# ---- RPCs ----
@rpc("authority", "call_remote", "reliable")
func _rpc_request_register() -> void:
	# client -> tell host our name
	rpc_id(1, "_rpc_register", local_name)

@rpc("any_peer", "call_remote", "reliable")
func _rpc_register(name: String) -> void:
	if not is_host():
		return
	var pid := multiplayer.get_remote_sender_id()
	_apply_register(pid, name)
	_broadcast_registry()

@rpc("authority", "call_remote", "reliable")
func _rpc_sync_registry(dict: Dictionary) -> void:
	registry.from_dict(dict)
	registry_changed.emit()
	if registry.all_ready():
		all_ready.emit()

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_fighter(peer_id: int, fighter_id: String) -> void:
	if not is_host():
		return
	if peer_id != multiplayer.get_remote_sender_id():
		return
	_apply_set_fighter(peer_id, fighter_id)
	_broadcast_registry()

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_ready(peer_id: int, ready: bool) -> void:
	if not is_host():
		return
	if peer_id != multiplayer.get_remote_sender_id():
		return
	_apply_set_ready(peer_id, ready)
	_broadcast_registry()

# client-facing helpers
func request_set_fighter(fighter_id: String) -> void:
	rpc_id(1, "_rpc_set_fighter", multiplayer.get_unique_id(), fighter_id)

func request_set_ready(ready: bool) -> void:
	rpc_id(1, "_rpc_set_ready", multiplayer.get_unique_id(), ready)

func _broadcast_registry() -> void:
	rpc("_rpc_sync_registry", registry.to_dict())
	registry_changed.emit()
	if registry.all_ready():
		all_ready.emit()

# ---- pure mutation handlers (unit-tested) ----
func _apply_register(peer_id: int, name: String) -> void:
	registry.add_player(peer_id, name)
	player_joined.emit(peer_id)
	registry_changed.emit()

func _apply_unregister(peer_id: int) -> void:
	registry.remove_player(peer_id)
	player_left.emit(peer_id)
	registry_changed.emit()

func _apply_set_fighter(peer_id: int, fighter_id: String) -> void:
	registry.set_fighter(peer_id, fighter_id)

func _apply_set_ready(peer_id: int, ready: bool) -> void:
	registry.set_ready(peer_id, ready)
