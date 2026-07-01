class_name LobbyRegistry
extends RefCounted

# peer_id:int -> { "name": String, "fighter_id": String, "ready": bool }
var players: Dictionary = {}

func add_player(peer_id: int, name: String) -> void:
	if players.has(peer_id):
		return
	players[peer_id] = {"name": name, "fighter_id": "", "ready": false}

func remove_player(peer_id: int) -> void:
	players.erase(peer_id)

func set_fighter(peer_id: int, fighter_id: String) -> void:
	if players.has(peer_id):
		players[peer_id]["fighter_id"] = fighter_id

func set_ready(peer_id: int, ready: bool) -> void:
	if players.has(peer_id):
		players[peer_id]["ready"] = ready

func all_ready() -> bool:
	if players.is_empty():
		return false
	for pid in players:
		if not players[pid]["ready"]:
			return false
	return true

func peer_ids() -> Array:
	var ids := players.keys()
	ids.sort()
	return ids

func count() -> int:
	return players.size()

func get_player(peer_id: int) -> Dictionary:
	return players.get(peer_id, {})

func to_dict() -> Dictionary:
	return players.duplicate(true)

func from_dict(d: Dictionary) -> void:
	players = d.duplicate(true)
