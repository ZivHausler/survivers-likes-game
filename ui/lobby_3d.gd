class_name Lobby3D
extends Control
## Networked lobby / character-select screen (Task D1). Host or join an ENet session,
## pick a fighter, ready up; the host starts the run once everyone is ready. Solo skips
## networking entirely and jumps straight into the arena with a single-entry party.

const CHARACTER_PATHS: Array[String] = preload("res://ui/character_select_3d.gd").CHARACTER_PATHS

@onready var _host_btn: Button = $VBox/NetRow/HostButton
@onready var _join_btn: Button = $VBox/NetRow/JoinButton
@onready var _steam_host_btn: Button = $VBox/NetRow/SteamHostButton
@onready var _invite_btn: Button = $VBox/NetRow/InviteButton
@onready var _fighter_grid: GridContainer = $VBox/Scroll/FighterGrid
@onready var _player_list: VBoxContainer = $VBox/PlayerList
@onready var _ready_toggle: CheckButton = $VBox/ReadyToggle
@onready var _start_btn: Button = $VBox/StartButton
@onready var _solo_btn: Button = $VBox/SoloButton

var _local_fighter_path: String = ""

# Dev join-by-ID controls (built in code): the Steam overlay can't render over an
# engine-launched Vulkan build, so invites can't be accepted the usual way. Instead the
# host reads its numeric lobby id off-screen and a client joins by typing it in.
var _lobby_id_row: HBoxContainer
var _lobby_id_field: LineEdit
var _join_id_edit: LineEdit

func _ready() -> void:
	NetworkManager.registry_changed.connect(_refresh)
	NetworkManager.host_aborted.connect(_on_host_aborted)
	NetworkManager.steam_lobby_ready.connect(_on_steam_lobby_ready)
	NetworkManager.steam_init()  # Task C2: connect Steam signals + start pump so a cold
	# joiner who accepts an overlay invite from the lobby screen actually gets routed.
	_build_fighter_grid()
	_host_btn.pressed.connect(_on_host_pressed)
	_join_btn.pressed.connect(_on_join_pressed.bind("127.0.0.1"))
	_steam_host_btn.pressed.connect(_on_steam_host_pressed)
	_invite_btn.pressed.connect(NetworkManager.open_invite_overlay)
	_ready_toggle.toggled.connect(_on_ready_toggled)
	_start_btn.pressed.connect(_on_start_pressed)
	_solo_btn.pressed.connect(_on_solo_pressed)
	_build_join_by_id()
	_refresh()

## Add a "lobby id" field + Join button to the net row, and a host-side id readout label.
func _build_join_by_id() -> void:
	var net_row := _host_btn.get_parent()
	_join_id_edit = LineEdit.new()
	_join_id_edit.placeholder_text = "lobby id"
	_join_id_edit.custom_minimum_size = Vector2(200, 0)
	net_row.add_child(_join_id_edit)
	var join_id_btn := Button.new()
	join_id_btn.text = "Join by ID"
	join_id_btn.pressed.connect(_on_join_by_id_pressed)
	net_row.add_child(join_id_btn)
	# Host lobby-id readout: a selectable read-only field + one-click Copy button.
	_lobby_id_row = HBoxContainer.new()
	_lobby_id_row.visible = false
	var lbl := Label.new()
	lbl.text = "Lobby ID:"
	_lobby_id_row.add_child(lbl)
	_lobby_id_field = LineEdit.new()
	_lobby_id_field.editable = false
	_lobby_id_field.custom_minimum_size = Vector2(230, 0)
	_lobby_id_row.add_child(_lobby_id_field)
	var copy_btn := Button.new()
	copy_btn.text = "Copy"
	copy_btn.pressed.connect(_on_copy_id_pressed)
	_lobby_id_row.add_child(copy_btn)
	net_row.get_parent().add_child(_lobby_id_row)
	net_row.get_parent().move_child(_lobby_id_row, net_row.get_index() + 1)

func _on_copy_id_pressed() -> void:
	DisplayServer.clipboard_set(_lobby_id_field.text)

func _on_join_by_id_pressed() -> void:
	var id := _join_id_edit.text.strip_edges().to_int()
	if id != 0:
		NetworkManager.join_steam(id)

func _on_host_pressed() -> void:
	NetworkManager.host_enet()   # or host_steam() when Steam selected
	_refresh()

func _on_join_pressed(address: String) -> void:
	NetworkManager.join_enet(address)

func _on_steam_host_pressed() -> void:
	NetworkManager.host_steam()
	_refresh()

func _on_steam_lobby_ready(lobby_id: int) -> void:
	_invite_btn.disabled = false
	_lobby_id_field.text = "%d" % lobby_id
	_lobby_id_row.visible = true
	print("[lobby] Steam lobby created — id=", lobby_id)

func _on_fighter_picked(path: String) -> void:
	_local_fighter_path = path
	if NetworkManager.multiplayer.multiplayer_peer != null:
		NetworkManager.request_set_fighter(path)
	_refresh()

func _on_ready_toggled(on: bool) -> void:
	if NetworkManager.multiplayer.multiplayer_peer != null:
		NetworkManager.request_set_ready(on)

func _on_start_pressed() -> void:
	if not NetworkManager.is_host():
		return
	if not NetworkManager.registry.all_ready():
		return
	var party := {}
	for pid in NetworkManager.registry.peer_ids():
		party[pid] = NetworkManager.registry.get_player(pid)["fighter_id"]
	# No change_scene_to_file: ask the persistent root to swap in the arena on all peers.
	var root := get_tree().current_scene as SessionRoot
	root.enter_arena.rpc(party)

func _on_solo_pressed() -> void:
	var chosen := _local_fighter_path if _local_fighter_path != "" else CHARACTER_PATHS[0]
	var party := {1: chosen}
	RunState.party = party
	var root := get_tree().current_scene as SessionRoot
	root.enter_arena(party)

func _refresh() -> void:
	for child in _player_list.get_children():
		child.queue_free()
	for pid in NetworkManager.registry.peer_ids():
		var p := NetworkManager.registry.get_player(pid)
		var label := Label.new()
		label.text = "%s — %s — %s" % [p["name"], p["fighter_id"], "Ready" if p["ready"] else "Not ready"]
		_player_list.add_child(label)
	_start_btn.disabled = not (NetworkManager.is_host() and NetworkManager.registry.all_ready())

func _build_fighter_grid() -> void:
	for path in CHARACTER_PATHS:
		var data: CharacterData = load(path) as CharacterData
		if data == null:
			continue
		var btn := Button.new()
		btn.text = data.display_name
		btn.modulate = data.color
		btn.custom_minimum_size = Vector2(160, 50)
		btn.pressed.connect(_on_fighter_picked.bind(path))
		_fighter_grid.add_child(btn)

func _on_host_aborted() -> void:
	var root := get_tree().current_scene as SessionRoot
	root._show_lobby()
