extends Node

signal player_joined(peer_id: int)
signal player_left(peer_id: int)
signal registry_changed()
signal all_ready()
signal host_aborted()

var registry: LobbyRegistry = LobbyRegistry.new()
var local_name: String = "Player"

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
	# `Steam` identifier because GodotSteam is not installed yet; referencing an
	# undeclared global identifier is a GDScript parse error, not just a runtime
	# no-op, and would break autoload boot entirely.
	if Engine.has_singleton("Steam"):
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
	_apply_set_fighter(peer_id, fighter_id)
	_broadcast_registry()

@rpc("any_peer", "call_local", "reliable")
func _rpc_set_ready(peer_id: int, ready: bool) -> void:
	if not is_host():
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
