class_name SessionRoot
extends Node
## Persistent session root (Task D1). Holds the lobby and, later, the arena as swapped
## children of Slot — never freed for the life of the session. Swapping children here
## (instead of get_tree().change_scene_to_file) avoids dropping RPC packets against a
## freed tree mid-session. See docs/superpowers/plans/2026-07-01-coop-foundation.md.

const LOBBY_SCENE := preload("res://ui/lobby_3d.tscn")
const ARENA_SCENE := preload("res://game/main_3d.tscn")

@onready var _slot: Node = $Slot   # the child container we swap

func _ready() -> void:
	# DEV-ONLY: flag-gated co-op self-test harness. Zero effect on normal launches —
	# only runs when the process is started with `-- --coop-selftest=host|join`.
	# Used to reproduce/verify the co-op arena-spawn race over ENet-loopback headlessly.
	var mode := _selftest_mode()
	if mode == "host":
		_run_selftest_host()
		return
	elif mode == "join":
		_run_selftest_join()
		return
	_show_lobby()

# ── DEV-ONLY co-op self-test (strictly flag-gated; no effect without the flag) ──
const _SELFTEST_FIGHTER := "res://characters/ziv_3d.tres"

func _selftest_mode() -> String:
	for a in (OS.get_cmdline_args() + OS.get_cmdline_user_args()):
		if a.begins_with("--coop-selftest="):
			return a.substr(16)
	return ""

func _run_selftest_host() -> void:
	print("[selftest host] hosting ENet…")
	NetworkManager.host_enet()
	var client_id: int = await multiplayer.peer_connected
	print("[selftest host] client connected: peer ", client_id)
	# Mimic "lobby established, then Start pressed": let the link settle, then enter arena.
	await get_tree().create_timer(1.0).timeout
	var party := {1: _SELFTEST_FIGHTER, client_id: _SELFTEST_FIGHTER}
	print("[selftest host] enter_arena party=", party)
	enter_arena.rpc(party)   # call_local + replicated
	await get_tree().create_timer(3.0).timeout
	_selftest_report("HOST")

func _run_selftest_join() -> void:
	print("[selftest join] joining 127.0.0.1…")
	NetworkManager.join_enet("127.0.0.1")
	await multiplayer.connected_to_server
	print("[selftest join] connected to server")
	await get_tree().create_timer(4.0).timeout
	_selftest_report("CLIENT")

func _selftest_report(who: String) -> void:
	var arena := _slot.get_node_or_null("Arena")
	if arena == null:
		print("[selftest %s] RESULT: NO ARENA" % who)
	else:
		var players := arena.get_node_or_null("Players")
		var names: Array = []
		if players:
			for c in players.get_children():
				names.append("%s(auth=%d)" % [c.name, c.get_multiplayer_authority()])
		names.sort()
		print("[selftest %s] RESULT Players children: %s" % [who, names])
		var gm := arena.get_node_or_null("GameManager3D")
		if gm != null:
			print("[selftest %s] RESULT GameManager3D._players.size()=%d" % [who, gm._players.size()])
	await get_tree().create_timer(0.5).timeout
	get_tree().quit()

func _show_lobby() -> void:
	_clear_slot()
	_slot.add_child(LOBBY_SCENE.instantiate(), true)

# Host calls this; call_local runs it on the host too. Replicates to all CURRENT peers.
@rpc("authority", "call_local", "reliable")
func enter_arena(party: Dictionary) -> void:
	RunState.party = party
	_clear_slot()
	var arena := ARENA_SCENE.instantiate()
	arena.name = "Arena"
	_slot.add_child(arena, true)   # force-readable, deterministic name across peers

func _clear_slot() -> void:
	for c in _slot.get_children():
		c.queue_free()
