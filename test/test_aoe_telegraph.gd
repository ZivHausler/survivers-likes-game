# See docs/notes/aoe-telegraph.md
extends GutTest
## Tests for AoeTelegraph3D — flat additive ring decal (Task 1.6).

const _Scene: PackedScene = preload("res://vfx/aoe_telegraph_3d.tscn")

# ── Scene loading ─────────────────────────────────────────────────────────────

func test_aoe_telegraph_scene_loads() -> void:
	var packed: PackedScene = load("res://vfx/aoe_telegraph_3d.tscn")
	assert_not_null(packed, "aoe_telegraph_3d.tscn must load successfully")

# ── play_at contract ──────────────────────────────────────────────────────────

func test_aoe_telegraph_in_tree_after_play_at() -> void:
	var fx: AoeTelegraph3D = _Scene.instantiate()
	add_child(fx)
	fx.play_at(Vector3.ZERO, 6.0, Color.CYAN)
	await get_tree().process_frame
	assert_true(fx.is_inside_tree(),
		"AoeTelegraph3D must remain in the scene tree immediately after play_at")

func test_aoe_telegraph_positioned_at_given_pos() -> void:
	var fx: AoeTelegraph3D = _Scene.instantiate()
	add_child(fx)
	var target := Vector3(3.0, 0.0, -2.0)
	fx.play_at(target, 4.0, Color.RED)
	await get_tree().process_frame
	# XZ position must match; Y may be lifted slightly to avoid z-fighting.
	assert_almost_eq(fx.global_position.x, target.x, 0.01,
		"AoeTelegraph3D X must match the requested position")
	assert_almost_eq(fx.global_position.z, target.z, 0.01,
		"AoeTelegraph3D Z must match the requested position")

# ── Auto-free (lifetime) ──────────────────────────────────────────────────────

func test_aoe_telegraph_auto_frees_after_lifetime() -> void:
	var fx: AoeTelegraph3D = _Scene.instantiate()
	add_child(fx)
	fx.play_at(Vector3.ZERO, 6.0, Color.CYAN)
	var ref: WeakRef = weakref(fx)
	# Lifetime = 0.8 s + 0.1 s guard; wait 1.5 s to be safe.
	await get_tree().create_timer(1.5).timeout
	assert_null(ref.get_ref(),
		"AoeTelegraph3D must auto-free after its lifetime expires")

# ── SkillVFX dispatch ─────────────────────────────────────────────────────────

func test_skill_vfx_spawns_telegraph_on_skill_cast() -> void:
	var tree: SceneTree = get_tree()
	var parent: Node = tree.current_scene if tree.current_scene != null else tree.root
	var before: int = parent.get_children().filter(
		func(c: Node) -> bool: return c is AoeTelegraph3D).size()
	GameEvents.skill_cast.emit(&"test_nova", Color.CYAN, Vector3(1, 0, 2))
	await get_tree().process_frame
	var after: int = parent.get_children().filter(
		func(c: Node) -> bool: return c is AoeTelegraph3D).size()
	assert_gt(after, before,
		"SkillVFX must spawn an AoeTelegraph3D when skill_cast is emitted")
