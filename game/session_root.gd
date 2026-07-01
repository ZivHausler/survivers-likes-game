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
	_show_lobby()

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
