extends GutTest
## Structural tests for Enemy sprite/fallback visual switching (Task B2).
## Verifies Sprite2D presence and ColorRect/Sprite visibility rules.
## On-screen wobble and boss tint require manual playtest — see task-B2-report.md.

var EnemyScene = null

func before_all() -> void:
	EnemyScene = load("res://enemies/enemy.tscn")

func _make_data_no_texture(max_hp: float = 20.0, xp: int = 3) -> EnemyData:
	var d := EnemyData.new()
	d.id = &"test_no_tex"
	d.color = Color.WHITE
	d.max_hp = max_hp
	d.move_speed = 80.0
	d.contact_damage = 5.0
	d.xp_value = xp
	d.is_ranged = false
	d.radius = 8.0
	# texture intentionally left null
	return d

func _make_data_with_texture(max_hp: float = 20.0, xp: int = 3) -> EnemyData:
	var d := _make_data_no_texture(max_hp, xp)
	d.id = &"test_with_tex"
	# Create a minimal 4x4 ImageTexture so we don't depend on disk assets in tests.
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	d.texture = ImageTexture.create_from_image(img)
	return d

func _make_enemy_no_texture(max_hp: float = 20.0, xp: int = 3) -> Enemy:
	assert_not_null(EnemyScene, "enemy.tscn must exist")
	var e: Enemy = add_child_autofree(EnemyScene.instantiate()) as Enemy
	var dummy: Node2D = add_child_autofree(Node2D.new()) as Node2D
	e.setup(_make_data_no_texture(max_hp, xp), dummy)
	return e

func _make_enemy_with_texture(max_hp: float = 20.0, xp: int = 3) -> Enemy:
	assert_not_null(EnemyScene, "enemy.tscn must exist")
	var e: Enemy = add_child_autofree(EnemyScene.instantiate()) as Enemy
	var dummy: Node2D = add_child_autofree(Node2D.new()) as Node2D
	e.setup(_make_data_with_texture(max_hp, xp), dummy)
	return e

# ── Structure ──────────────────────────────────────────────────────────────────

func test_enemy_has_sprite2d_named_sprite() -> void:
	var e: Enemy = add_child_autofree(EnemyScene.instantiate()) as Enemy
	var sprite := e.get_node_or_null("Sprite")
	assert_not_null(sprite, "Enemy must have a child node named 'Sprite'")
	assert_true(sprite is Sprite2D, "Sprite node must be Sprite2D")

func test_sprite_hidden_by_default_before_setup() -> void:
	var e: Enemy = add_child_autofree(EnemyScene.instantiate()) as Enemy
	var sprite := e.get_node("Sprite") as Sprite2D
	assert_false(sprite.visible, "Sprite should be hidden before setup() is called")

# ── With texture ───────────────────────────────────────────────────────────────

func test_setup_with_texture_shows_sprite() -> void:
	var e: Enemy = _make_enemy_with_texture()
	var sprite := e.get_node("Sprite") as Sprite2D
	assert_true(sprite.visible, "Sprite must be visible when EnemyData has a texture")

func test_setup_with_texture_assigns_texture() -> void:
	var data := _make_data_with_texture()
	var e: Enemy = add_child_autofree(EnemyScene.instantiate()) as Enemy
	var dummy: Node2D = add_child_autofree(Node2D.new()) as Node2D
	e.setup(data, dummy)
	var sprite := e.get_node("Sprite") as Sprite2D
	assert_eq(sprite.texture, data.texture, "Sprite.texture must match EnemyData.texture")

func test_setup_with_texture_hides_body() -> void:
	var e: Enemy = _make_enemy_with_texture()
	var body := e.get_node("Body") as ColorRect
	assert_false(body.visible, "Body ColorRect must be hidden when texture is set")

# ── Without texture (fallback) ────────────────────────────────────────────────

func test_setup_without_texture_hides_sprite() -> void:
	var e: Enemy = _make_enemy_no_texture()
	var sprite := e.get_node("Sprite") as Sprite2D
	assert_false(sprite.visible, "Sprite must stay hidden when texture is null")

func test_setup_without_texture_keeps_body_visible() -> void:
	var e: Enemy = _make_enemy_no_texture()
	var body := e.get_node("Body") as ColorRect
	assert_true(body.visible, "Body ColorRect must remain visible when texture is null")

# ── Enemy contract still intact ────────────────────────────────────────────────

func test_take_damage_reduces_hp_with_texture() -> void:
	var e: Enemy = _make_enemy_with_texture(20.0)
	e.take_damage(5.0)
	assert_almost_eq(e.hp, 15.0, 0.001, "hp should be 15 after 5 damage on 20hp enemy")

func test_nonlethal_damage_does_not_emit_enemy_killed_with_texture() -> void:
	var e: Enemy = _make_enemy_with_texture(20.0, 3)
	watch_signals(GameEvents)
	e.take_damage(10.0)
	assert_signal_not_emitted(GameEvents, "enemy_killed")

func test_lethal_damage_emits_enemy_killed_with_texture() -> void:
	var e: Enemy = _make_enemy_with_texture(20.0, 3)
	watch_signals(GameEvents)
	e.take_damage(20.0)
	assert_signal_emitted(GameEvents, "enemy_killed")

func test_lethal_damage_frees_node_with_texture() -> void:
	var e: Enemy = _make_enemy_with_texture(20.0)
	e.take_damage(20.0)
	await get_tree().process_frame
	assert_false(is_instance_valid(e), "enemy should be freed after lethal damage")
