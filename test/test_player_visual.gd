extends GutTest
## Structural tests for Player sprite/fallback visual switching (Task B1).
## Verifies AnimatedSprite2D presence and ColorRect/Sprite visibility rules.
## On-screen look and bob feel require manual playtest — see task-B1-report.md.

var PlayerScene = null

func before_all() -> void:
	PlayerScene = load("res://player/player.tscn")

func _make_stats(max_hp: float = 100.0) -> StatBlock:
	var sb := StatBlock.new()
	sb.max_hp = max_hp
	sb.armor = 0.0
	sb.pickup_range = 48.0
	sb.move_speed = 120.0
	return sb

func _make_data_with_sprite_frames() -> CharacterData:
	var sf := SpriteFrames.new()
	sf.add_animation("idle")
	var cd := CharacterData.new()
	cd.base_stats = _make_stats()
	cd.sprite_frames = sf
	return cd

func _make_data_without_sprite_frames() -> CharacterData:
	var cd := CharacterData.new()
	cd.base_stats = _make_stats()
	# sprite_frames intentionally null — player.setup() falls back to ColorRect
	return cd

# ── Structure ──────────────────────────────────────────────────────────────────

func test_player_has_animated_sprite2d_named_sprite() -> void:
	var player = add_child_autofree(PlayerScene.instantiate())
	var sprite = player.get_node_or_null("Sprite")
	assert_not_null(sprite, "Player must have a child node named 'Sprite'")
	assert_true(sprite is AnimatedSprite2D, "Sprite node must be AnimatedSprite2D")

func test_sprite_hidden_by_default_in_scene() -> void:
	var player = add_child_autofree(PlayerScene.instantiate())
	var sprite := player.get_node("Sprite") as AnimatedSprite2D
	assert_false(sprite.visible, "Sprite should be hidden before setup() is called")

# ── With sprite_frames ─────────────────────────────────────────────────────────

func test_setup_with_sprite_frames_shows_sprite() -> void:
	var player = add_child_autofree(PlayerScene.instantiate())
	player.setup(_make_data_with_sprite_frames())
	var sprite := player.get_node("Sprite") as AnimatedSprite2D
	assert_true(sprite.visible, "Sprite must be visible when CharacterData has sprite_frames")

func test_setup_with_sprite_frames_hides_color_rect() -> void:
	var player = add_child_autofree(PlayerScene.instantiate())
	player.setup(_make_data_with_sprite_frames())
	var color_rect := player.get_node("ColorRect") as ColorRect
	assert_false(color_rect.visible, "ColorRect must be hidden when sprite_frames is set")

# ── Without sprite_frames (fallback) ─────────────────────────────────────────

func test_setup_without_sprite_frames_hides_sprite() -> void:
	var player = add_child_autofree(PlayerScene.instantiate())
	player.setup(_make_data_without_sprite_frames())
	var sprite := player.get_node("Sprite") as AnimatedSprite2D
	assert_false(sprite.visible, "Sprite must stay hidden when sprite_frames is null")

func test_setup_without_sprite_frames_keeps_color_rect_visible() -> void:
	var player = add_child_autofree(PlayerScene.instantiate())
	player.setup(_make_data_without_sprite_frames())
	var color_rect := player.get_node("ColorRect") as ColorRect
	assert_true(color_rect.visible, "ColorRect must remain visible when sprite_frames is null")
