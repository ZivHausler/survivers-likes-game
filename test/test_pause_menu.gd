# See docs/notes/pause-menu.md
extends GutTest
## Unit tests for PauseMenu and GameManager3D pause-menu integration.

# ---------------------------------------------------------------------------
# Stub PauseMenu — for GameManager3D integration tests that don't need a full
# scene. Exposes the same open()/close()/is_open() surface as PauseMenu.
# ---------------------------------------------------------------------------
class StubPauseMenu extends Node:
	var _open: bool = false
	var open_calls: int = 0
	var close_calls: int = 0

	func open() -> void:
		_open = true
		open_calls += 1
		get_tree().paused = true

	func close() -> void:
		_open = false
		close_calls += 1
		get_tree().paused = false

	func is_open() -> bool:
		return _open


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

## Build a minimal GameManager3D scene wired to a StubPauseMenu.
## Returns [manager, stub_pause_menu].
func _make_gm_with_pause_menu() -> Array:
	var root := Node3D.new()
	add_child_autofree(root)

	# StubSpawner so start() doesn't crash on missing Spawner3D.
	var spawner := Node3D.new()
	spawner.name = "Spawner3D"
	spawner.set_script(null)
	root.add_child(spawner)

	var pm := StubPauseMenu.new()
	pm.name = "PauseMenu"
	root.add_child(pm)

	var manager := GameManager3D.new()
	manager.name = "GameManager3D"
	root.add_child(manager)  # triggers _ready → start(); resolves PauseMenu sibling

	return [manager, pm]


## Build an InputEventAction set to pressed state for the given action name.
func _make_action_event(action: StringName, pressed: bool = true) -> InputEventAction:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = pressed
	return ev


# ---------------------------------------------------------------------------
# PauseMenu unit tests (instantiated from scene so @onready nodes resolve)
# ---------------------------------------------------------------------------

const PAUSE_MENU_SCENE := "res://ui/pause_menu.tscn"

func _make_pause_menu() -> PauseMenu:
	var packed := load(PAUSE_MENU_SCENE) as PackedScene
	if packed == null:
		return null
	var pm := packed.instantiate() as PauseMenu
	add_child_autofree(pm)
	return pm


func test_pause_menu_open_pauses_tree() -> void:
	var pm := _make_pause_menu()
	if pm == null:
		fail_test("pause_menu.tscn could not be loaded"); return
	pm.open()
	assert_true(get_tree().paused, "open() must pause the scene tree")
	get_tree().paused = false


func test_pause_menu_open_shows_menu() -> void:
	var pm := _make_pause_menu()
	if pm == null:
		fail_test("pause_menu.tscn could not be loaded"); return
	pm.open()
	assert_true(pm.visible, "open() must make the menu visible")
	get_tree().paused = false


func test_pause_menu_close_unpauses_tree() -> void:
	var pm := _make_pause_menu()
	if pm == null:
		fail_test("pause_menu.tscn could not be loaded"); return
	pm.open()
	pm.close()
	assert_false(get_tree().paused, "close() must unpause the scene tree")


func test_pause_menu_close_hides_menu() -> void:
	var pm := _make_pause_menu()
	if pm == null:
		fail_test("pause_menu.tscn could not be loaded"); return
	pm.open()
	pm.close()
	assert_false(pm.visible, "close() must hide the menu")


func test_pause_menu_is_open_false_initially() -> void:
	var pm := _make_pause_menu()
	if pm == null:
		fail_test("pause_menu.tscn could not be loaded"); return
	assert_false(pm.is_open(), "is_open() must return false before open() is called")


func test_pause_menu_is_open_true_after_open() -> void:
	var pm := _make_pause_menu()
	if pm == null:
		fail_test("pause_menu.tscn could not be loaded"); return
	pm.open()
	assert_true(pm.is_open(), "is_open() must return true after open()")
	get_tree().paused = false


func test_pause_menu_is_open_false_after_close() -> void:
	var pm := _make_pause_menu()
	if pm == null:
		fail_test("pause_menu.tscn could not be loaded"); return
	pm.open()
	pm.close()
	assert_false(pm.is_open(), "is_open() must return false after close()")


# ---------------------------------------------------------------------------
# PauseMenu scene path constants
# ---------------------------------------------------------------------------

func test_pause_menu_arena_scene_path() -> void:
	assert_eq(PauseMenu.ARENA_SCENE, "res://game/main_3d.tscn",
		"ARENA_SCENE must point to main_3d.tscn")


func test_pause_menu_select_scene_path() -> void:
	assert_eq(PauseMenu.SELECT_SCENE, "res://ui/character_select_3d.tscn",
		"SELECT_SCENE must point to character_select_3d.tscn")


# ---------------------------------------------------------------------------
# GameManager3D: ui_cancel opens pause menu
# ---------------------------------------------------------------------------

func test_gm_ui_cancel_opens_pause_menu() -> void:
	var arr := _make_gm_with_pause_menu()
	var manager := arr[0] as GameManager3D
	var pm      := arr[1] as StubPauseMenu

	# Simulate Escape press via _unhandled_input.
	var ev := _make_action_event("ui_cancel", true)
	manager._unhandled_input(ev)

	assert_true(pm.is_open(), "ui_cancel must open the pause menu when it is closed")
	get_tree().paused = false


func test_gm_ui_cancel_closes_open_pause_menu() -> void:
	var arr := _make_gm_with_pause_menu()
	var manager := arr[0] as GameManager3D
	var pm      := arr[1] as StubPauseMenu

	pm.open()  # manually open first
	get_tree().paused = false  # don't let the tree stay paused in test

	# Restore open state without tree pause for the stub.
	pm._open = true

	var ev := _make_action_event("ui_cancel", true)
	manager._unhandled_input(ev)

	assert_false(pm.is_open(), "ui_cancel must close the pause menu when it is open")
	get_tree().paused = false


func test_gm_ui_cancel_does_not_open_while_choosing() -> void:
	var arr := _make_gm_with_pause_menu()
	var manager := arr[0] as GameManager3D
	var pm      := arr[1] as StubPauseMenu

	# Simulate the level-up card flow being active.
	manager._choosing = true

	var ev := _make_action_event("ui_cancel", true)
	manager._unhandled_input(ev)

	assert_false(pm.is_open(),
		"ui_cancel must NOT open the pause menu while the level-up card flow is active")

	manager._choosing = false  # cleanup
	get_tree().paused = false


func test_gm_ui_cancel_ignored_when_not_pressed() -> void:
	var arr := _make_gm_with_pause_menu()
	var manager := arr[0] as GameManager3D
	var pm      := arr[1] as StubPauseMenu

	# A release event (pressed=false) must not toggle the menu.
	var ev := _make_action_event("ui_cancel", false)
	manager._unhandled_input(ev)

	assert_false(pm.is_open(),
		"ui_cancel release event must not open the pause menu")
	get_tree().paused = false
