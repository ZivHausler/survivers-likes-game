extends GutTest
## Visual smoke tests for Task D2 assembly sweep.
## Uses SceneState introspection — no full instantiation — so autoloads and
## physics bodies are never entered; safe in headless mode.
## Also verifies Juice autoload is live and HUD bars have fill StyleBoxes.
##
## Scenes are loaded once in before_all() to avoid repeated UID warnings from
## the player.tscn ext_resource reference, which GUT would count as unexpected
## errors if triggered on every test.

var _main_scene: PackedScene = null
var _arena_scene: PackedScene = null

func before_all() -> void:
	_main_scene  = load("res://game/main.tscn")
	_arena_scene = load("res://game/arena.tscn")

# ── Scene loading ─────────────────────────────────────────────────────────────

func test_main_scene_loads() -> void:
	assert_not_null(_main_scene, "main.tscn must load without error")

func test_arena_scene_loads() -> void:
	assert_not_null(_arena_scene, "arena.tscn must load without error")

# ── Arena structure ───────────────────────────────────────────────────────────

func test_arena_has_background_node() -> void:
	assert_not_null(_arena_scene)
	var state := _arena_scene.get_state()
	var found := false
	for i in range(state.get_node_count()):
		if state.get_node_name(i) == &"Background":
			found = true
			break
	assert_true(found, "Arena must have a child node named 'Background'")

func test_arena_background_below_player() -> void:
	assert_not_null(_arena_scene)
	var state := _arena_scene.get_state()
	var bg_idx     := -1
	var player_idx := -1
	for i in range(state.get_node_count()):
		match state.get_node_name(i):
			&"Background": bg_idx     = i
			&"Player":     player_idx = i
	assert_true(bg_idx > 0, "Background must exist in arena scene")
	assert_true(player_idx > 0, "Player must exist in arena scene")
	assert_true(bg_idx < player_idx,
		"Background must appear before Player in scene tree (renders below gameplay)")

func test_arena_has_vignette() -> void:
	assert_not_null(_arena_scene)
	var state := _arena_scene.get_state()
	var found := false
	for i in range(state.get_node_count()):
		if state.get_node_name(i) == &"Vignette":
			found = true
			break
	assert_true(found, "Arena must have a Vignette CanvasLayer for edge darkening")

func test_arena_has_hud() -> void:
	assert_not_null(_arena_scene)
	var state := _arena_scene.get_state()
	var found := false
	for i in range(state.get_node_count()):
		if state.get_node_name(i) == &"HUD":
			found = true
			break
	assert_true(found, "Arena must have a HUD node")

# ── Juice autoload ────────────────────────────────────────────────────────────

func test_juice_autoload_is_live() -> void:
	# Juice is registered as an autoload in project.godot; it must always be
	# accessible as a global singleton (including headless mode).
	assert_not_null(Juice, "Juice autoload must be present")

func test_juice_has_register_camera() -> void:
	assert_true(Juice.has_method("register_camera"),
		"Juice must expose register_camera(Camera2D)")

func test_juice_has_register_player() -> void:
	assert_true(Juice.has_method("register_player"),
		"Juice must expose register_player(Node2D)")

# ── HUD fill StyleBoxes ───────────────────────────────────────────────────────

func test_hp_bar_has_fill_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var hp_bar: ProgressBar = hud.get_node("VBox/HPBar")
	assert_not_null(hp_bar, "HUD must have VBox/HPBar")
	assert_true(hp_bar.has_theme_stylebox_override("fill"),
		"HPBar must have a red fill StyleBox (clearly readable)")

func test_xp_bar_has_fill_stylebox() -> void:
	var hud: Node = add_child_autofree(load("res://ui/hud.tscn").instantiate())
	var xp_bar: ProgressBar = hud.get_node("VBox/XPBar")
	assert_not_null(xp_bar, "HUD must have VBox/XPBar")
	assert_true(xp_bar.has_theme_stylebox_override("fill"),
		"XPBar must have a cyan fill StyleBox (clearly readable)")
