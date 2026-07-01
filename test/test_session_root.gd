extends GutTest
## Task D1: SessionRoot smoke test.
## Verifies the persistent session root shows the lobby under Slot after _ready, then
## swaps Slot's child for the arena (named "Arena") when enter_arena() runs — all
## WITHOUT change_scene_to_file, so RunState.party is the only session hand-off.

const A_CHARACTER_PATH := "res://characters/ziv_3d.tres"

func test_lobby_shows_then_enter_arena_swaps_to_arena() -> void:
	var root: SessionRoot = add_child_autofree(load("res://game/session_root.tscn").instantiate()) as SessionRoot
	assert_not_null(root, "session_root.tscn must instantiate as SessionRoot")
	if root == null:
		return

	await get_tree().process_frame

	var slot: Node = root.get_node("Slot")
	assert_eq(slot.get_child_count(), 1, "Slot should have exactly one child (the lobby) after _ready")
	var lobby: Node = slot.get_child(0)
	assert_true(lobby is Control, "lobby child under Slot should be a Control (Lobby3D)")

	root.enter_arena({1: A_CHARACTER_PATH})

	# queue_free() from _clear_slot() is deferred; give it a couple of frames to land.
	await get_tree().process_frame
	await get_tree().process_frame

	assert_false(is_instance_valid(lobby), "lobby child should be freed/gone from Slot after enter_arena")
	assert_true(slot.has_node("Arena"), "a node named 'Arena' must be under Slot after enter_arena")
	assert_eq(slot.get_child_count(), 1, "Slot should hold only the arena after the swap")
	assert_eq(RunState.party, {1: A_CHARACTER_PATH}, "RunState.party must be set by enter_arena")
