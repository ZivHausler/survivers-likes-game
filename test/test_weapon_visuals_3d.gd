## Tests verifying that 3D weapon and skill-FX visuals are clearly coloured and emissive.
## Covers: OrbitWeapon3D orbiter mesh, NovaWeapon3D telegraph, Bubble3D sphere,
## ZivStunningLooks3D beam visual, and SkillCastFx3D / SkillHitFx3D emissive material.
extends GutTest

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _make_stats(dmg: float = 1.0, rate: float = 1.0) -> StatBlock:
	var s := StatBlock.new()
	s.damage_mult    = dmg
	s.fire_rate_mult = rate
	return s

## Return the first MeshInstance3D found under `node` (depth-first), or null.
func _find_mesh(node: Node) -> MeshInstance3D:
	if node is MeshInstance3D:
		return node as MeshInstance3D
	for child in node.get_children():
		var found := _find_mesh(child)
		if found != null:
			return found
	return null

# ═════════════════════════════════════════════════════════════════════════════
# OrbitWeapon3D — each orbiter must have a visible emissive mesh
# ═════════════════════════════════════════════════════════════════════════════

func test_orbiter_has_mesh_instance_child() -> void:
	var w: OrbitWeapon3D = add_child_autofree(OrbitWeapon3D.new())
	var player: Node3D = add_child_autofree(Node3D.new())
	w.setup(player, _make_stats())
	assert_true(w._orbiters.size() > 0, "must have at least one orbiter to test")
	var orbiter: Area3D = w._orbiters[0]
	var mi := _find_mesh(orbiter)
	assert_not_null(mi, "each OrbitWeapon3D orbiter must contain a MeshInstance3D")

func test_orbiter_mesh_has_emissive_material() -> void:
	var w: OrbitWeapon3D = add_child_autofree(OrbitWeapon3D.new())
	var player: Node3D = add_child_autofree(Node3D.new())
	w.setup(player, _make_stats())
	var orbiter: Area3D = w._orbiters[0]
	var mi := _find_mesh(orbiter)
	assert_not_null(mi, "orbiter must have a MeshInstance3D")
	var mat := mi.material_override as StandardMaterial3D
	assert_not_null(mat, "orbiter MeshInstance3D must have a StandardMaterial3D material_override")
	assert_true(mat.emission_enabled, "orbiter material must have emission_enabled = true")

func test_orbiter_emissive_color_matches_vfx_color() -> void:
	var w: OrbitWeapon3D = add_child_autofree(OrbitWeapon3D.new())
	var player: Node3D = add_child_autofree(Node3D.new())
	w.setup(player, _make_stats())
	var orbiter: Area3D = w._orbiters[0]
	var mi := _find_mesh(orbiter)
	assert_not_null(mi, "orbiter must have a MeshInstance3D")
	var mat := mi.material_override as StandardMaterial3D
	assert_not_null(mat, "orbiter must have a StandardMaterial3D material_override")
	assert_eq(mat.emission, w.vfx_color,
		"orbiter emission color must match weapon vfx_color (gold for Orbit)")

func test_orbiter_materials_are_not_shared() -> void:
	var w: OrbitWeapon3D = add_child_autofree(OrbitWeapon3D.new())
	var player: Node3D = add_child_autofree(Node3D.new())
	w.setup(player, _make_stats())
	w.level_up()  # now 4 orbiters
	assert_true(w._orbiters.size() >= 2, "need at least 2 orbiters for this test")
	var mi0 := _find_mesh(w._orbiters[0])
	var mi1 := _find_mesh(w._orbiters[1])
	assert_not_null(mi0)
	assert_not_null(mi1)
	assert_ne(mi0.material_override, mi1.material_override,
		"each orbiter must have its own material instance (no shared resource)")

# ═════════════════════════════════════════════════════════════════════════════
# NovaWeapon3D — fire() must spawn a telegraph that auto-frees
# ═════════════════════════════════════════════════════════════════════════════

class StubEnemy3D extends Node3D:
	func _init() -> void:
		add_to_group("enemies")
	func take_damage(_amount: float) -> void:
		pass

func test_nova_fire_spawns_telegraph_node() -> void:
	var w: NovaWeapon3D = add_child_autofree(NovaWeapon3D.new())
	var player: Node3D = add_child_autofree(Node3D.new())
	w.setup(player, _make_stats())
	w.radius = 0.5  # small radius so no stub enemies needed for damage

	var parent: Node = get_tree().current_scene if get_tree().current_scene != null \
		else get_tree().root
	var before: int = parent.get_child_count()
	w.fire()
	var after: int = parent.get_child_count()
	assert_gt(after, before, "nova fire() must add a telegraph node to the scene tree")

func test_nova_telegraph_has_mesh_instance() -> void:
	var w: NovaWeapon3D = add_child_autofree(NovaWeapon3D.new())
	var player: Node3D = add_child_autofree(Node3D.new())
	w.setup(player, _make_stats())
	w.radius = 0.5

	var parent: Node = get_tree().current_scene if get_tree().current_scene != null \
		else get_tree().root
	var before: int = parent.get_child_count()
	w.fire()
	# The telegraph should be the last child added.
	var after_count: int = parent.get_child_count()
	assert_gt(after_count, before, "telegraph must be spawned")
	var telegraph: Node = null
	for i in range(parent.get_child_count() - 1, -1, -1):
		var child := parent.get_child(i)
		if child is Node3D and _find_mesh(child) != null:
			telegraph = child
			break
	assert_not_null(telegraph, "telegraph node must contain a MeshInstance3D")

func test_nova_telegraph_emissive_color_matches_vfx_color() -> void:
	var w: NovaWeapon3D = add_child_autofree(NovaWeapon3D.new())
	var player: Node3D = add_child_autofree(Node3D.new())
	w.setup(player, _make_stats())
	w.radius = 0.5

	var parent: Node = get_tree().current_scene if get_tree().current_scene != null \
		else get_tree().root
	w.fire()
	var telegraph: Node = null
	for i in range(parent.get_child_count() - 1, -1, -1):
		var child := parent.get_child(i)
		if child is Node3D and _find_mesh(child) != null:
			telegraph = child
			break
	assert_not_null(telegraph, "telegraph must be in scene tree")
	var mi := _find_mesh(telegraph)
	assert_not_null(mi)
	var mat := mi.material_override as StandardMaterial3D
	assert_not_null(mat, "telegraph mesh must have a StandardMaterial3D material_override")
	assert_true(mat.emission_enabled, "telegraph material must have emission_enabled")
	assert_eq(mat.emission, w.vfx_color, "telegraph emission must match weapon vfx_color")

func test_nova_telegraph_auto_frees() -> void:
	var w: NovaWeapon3D = add_child_autofree(NovaWeapon3D.new())
	var player: Node3D = add_child_autofree(Node3D.new())
	w.setup(player, _make_stats())
	w.radius = 0.5

	var parent: Node = get_tree().current_scene if get_tree().current_scene != null \
		else get_tree().root
	w.fire()
	var telegraph: Node3D = null
	for i in range(parent.get_child_count() - 1, -1, -1):
		var child := parent.get_child(i)
		if child is Node3D and _find_mesh(child) != null:
			telegraph = child as Node3D
			break
	assert_not_null(telegraph, "telegraph must exist right after fire()")
	var ref: WeakRef = weakref(telegraph)
	# Telegraph animates over 0.25 s; wait 0.6 s for tween to finish + queue_free to run.
	await get_tree().create_timer(0.6).timeout
	assert_null(ref.get_ref(),
		"nova telegraph must auto-free after the tween completes (~0.25 s)")

# ═════════════════════════════════════════════════════════════════════════════
# Bubble3D — must have a visible emissive sphere mesh
# ═════════════════════════════════════════════════════════════════════════════

func test_bubble_3d_has_mesh_instance() -> void:
	var bubble: Bubble3D = add_child_autofree(Bubble3D.new())
	var mi := _find_mesh(bubble)
	assert_not_null(mi, "Bubble3D must contain a MeshInstance3D after _ready()")

func test_bubble_3d_mesh_has_emissive_material() -> void:
	var bubble: Bubble3D = add_child_autofree(Bubble3D.new())
	var mi := _find_mesh(bubble)
	assert_not_null(mi, "Bubble3D must have a MeshInstance3D")
	var mat := mi.material_override as StandardMaterial3D
	assert_not_null(mat, "Bubble3D mesh must have a StandardMaterial3D material_override")
	assert_true(mat.emission_enabled,
		"Bubble3D mesh material must have emission_enabled = true")

func test_bubble_3d_emissive_color_matches_vfx_color() -> void:
	var bubble: Bubble3D = add_child_autofree(Bubble3D.new())
	var mi := _find_mesh(bubble)
	assert_not_null(mi)
	var mat := mi.material_override as StandardMaterial3D
	assert_not_null(mat)
	assert_eq(mat.emission, bubble.vfx_color,
		"Bubble3D emission color must match its vfx_color")

func test_bubble_3d_instances_have_separate_materials() -> void:
	var b1: Bubble3D = add_child_autofree(Bubble3D.new())
	var b2: Bubble3D = add_child_autofree(Bubble3D.new())
	var mi1 := _find_mesh(b1)
	var mi2 := _find_mesh(b2)
	assert_not_null(mi1)
	assert_not_null(mi2)
	assert_ne(mi1.material_override, mi2.material_override,
		"each Bubble3D instance must own its own material (no shared resource)")

# ═════════════════════════════════════════════════════════════════════════════
# SkillCastFx3D — play_at() must apply emissive color via material_override
# ═════════════════════════════════════════════════════════════════════════════

func test_skill_cast_fx_play_at_sets_material_override() -> void:
	var fx: SkillCastFx3D = add_child_autofree(
		load("res://vfx/skill_cast_fx_3d.tscn").instantiate())
	fx.play_at(Vector3.ZERO, Color(1.0, 0.5, 0.0))
	assert_not_null(fx.material_override,
		"SkillCastFx3D.play_at() must set material_override")

func test_skill_cast_fx_play_at_emission_matches_color() -> void:
	var fx: SkillCastFx3D = add_child_autofree(
		load("res://vfx/skill_cast_fx_3d.tscn").instantiate())
	var color := Color(0.0, 0.8, 1.0)
	fx.play_at(Vector3.ZERO, color)
	var mat := fx.material_override as StandardMaterial3D
	assert_not_null(mat, "material_override must be a StandardMaterial3D")
	assert_true(mat.emission_enabled, "cast FX material must have emission_enabled")
	assert_eq(mat.emission, color, "cast FX emission must match the passed color")

func test_skill_cast_fx_instances_do_not_share_material() -> void:
	var fx1: SkillCastFx3D = add_child_autofree(
		load("res://vfx/skill_cast_fx_3d.tscn").instantiate())
	var fx2: SkillCastFx3D = add_child_autofree(
		load("res://vfx/skill_cast_fx_3d.tscn").instantiate())
	fx1.play_at(Vector3.ZERO, Color(1.0, 0.0, 0.0))
	fx2.play_at(Vector3.ZERO, Color(0.0, 1.0, 0.0))
	assert_ne(fx1.material_override, fx2.material_override,
		"each SkillCastFx3D instance must own its own material_override")

# ═════════════════════════════════════════════════════════════════════════════
# SkillHitFx3D — play_at() must apply emissive color via material_override
# ═════════════════════════════════════════════════════════════════════════════

func test_skill_hit_fx_play_at_sets_material_override() -> void:
	var fx: SkillHitFx3D = add_child_autofree(
		load("res://vfx/skill_hit_fx_3d.tscn").instantiate())
	fx.play_at(Vector3.ZERO, Color(0.3, 0.6, 1.0))
	assert_not_null(fx.material_override,
		"SkillHitFx3D.play_at() must set material_override")

func test_skill_hit_fx_play_at_emission_matches_color() -> void:
	var fx: SkillHitFx3D = add_child_autofree(
		load("res://vfx/skill_hit_fx_3d.tscn").instantiate())
	var color := Color(1.0, 0.4, 0.8)
	fx.play_at(Vector3.ZERO, color)
	var mat := fx.material_override as StandardMaterial3D
	assert_not_null(mat, "material_override must be a StandardMaterial3D")
	assert_true(mat.emission_enabled, "hit FX material must have emission_enabled")
	assert_eq(mat.emission, color, "hit FX emission must match the passed color")

func test_skill_hit_fx_instances_do_not_share_material() -> void:
	var fx1: SkillHitFx3D = add_child_autofree(
		load("res://vfx/skill_hit_fx_3d.tscn").instantiate())
	var fx2: SkillHitFx3D = add_child_autofree(
		load("res://vfx/skill_hit_fx_3d.tscn").instantiate())
	fx1.play_at(Vector3.ZERO, Color(1.0, 0.0, 0.0))
	fx2.play_at(Vector3.ZERO, Color(0.0, 0.0, 1.0))
	assert_ne(fx1.material_override, fx2.material_override,
		"each SkillHitFx3D instance must own its own material_override")
