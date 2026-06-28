extends GutTest
## Structural tests for arena background + XP gem visual (Task B3).
## Uses SceneState introspection — no full instantiation — so autoloads and
## physics bodies are never entered; tests are safe in headless mode.

var ArenaScene: PackedScene = null
var GemScene: PackedScene = null

func before_all() -> void:
	ArenaScene = load("res://game/arena.tscn")
	GemScene   = load("res://pickups/xp_gem.tscn")

# ── Arena background ──────────────────────────────────────────────────────────

func test_arena_scene_loads() -> void:
	assert_not_null(ArenaScene, "arena.tscn must load without errors")

func test_arena_has_background_node() -> void:
	assert_not_null(ArenaScene)
	var state := ArenaScene.get_state()
	var found := false
	for i in range(state.get_node_count()):
		if state.get_node_name(i) == &"Background":
			found = true
			break
	assert_true(found, "Arena must have a child node named 'Background'")

func test_background_is_ordered_before_player() -> void:
	var state := ArenaScene.get_state()
	var bg_idx     := -1
	var player_idx := -1
	for i in range(state.get_node_count()):
		match state.get_node_name(i):
			&"Background": bg_idx     = i
			&"Player":     player_idx = i
	assert_true(bg_idx     > 0, "Background must exist in scene")
	assert_true(player_idx > 0, "Player must exist in scene")
	assert_true(bg_idx < player_idx,
		"Background node must appear before Player in scene tree (lower draw order)")

func test_arena_has_vignette_canvas_layer() -> void:
	var state := ArenaScene.get_state()
	var found := false
	for i in range(state.get_node_count()):
		if state.get_node_name(i) == &"Vignette":
			found = true
			break
	assert_true(found, "Arena must have a Vignette CanvasLayer")

# ── XP gem visual ─────────────────────────────────────────────────────────────

func test_xp_gem_scene_loads() -> void:
	assert_not_null(GemScene, "xp_gem.tscn must load without errors")

func test_xp_gem_has_body_visual() -> void:
	assert_not_null(GemScene)
	var state := GemScene.get_state()
	var found := false
	for i in range(state.get_node_count()):
		if state.get_node_name(i) == &"Body":
			found = true
			break
	assert_true(found, "XPGem scene must have a visual node named 'Body' (ColorRect or Sprite2D)")
