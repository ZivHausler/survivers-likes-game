# test/test_enemy_projectile_3d.gd
extends GutTest
var Scene: PackedScene = null

class PlayerStub extends Area3D:
	var taken := 0.0
	func _init() -> void: add_to_group("player")
	func take_damage(a: float) -> void: taken += a

## Mirrors the real game tree: Player3D (in group "player", has take_damage) with a
## child Hurtbox Area3D (NOT in group "player") on collision layer 2.
## This exercises the elif-parent branch of _on_area_entered, which the original
## PlayerStub test did NOT reach.
class HurtboxParent extends Node3D:
	var taken := 0.0
	func _init() -> void: add_to_group("player")
	func take_damage(a: float) -> void: taken += a

func before_all() -> void:
	Scene = load("res://enemies/enemy_projectile_3d.tscn")

func test_scene_loads_and_is_area() -> void:
	var p: EnemyProjectile3D = Scene.instantiate()
	assert_true(p is Area3D, "projectile is an Area3D")
	# mask must include player-hurtbox (2) and terrain (16), exclude enemies (8)
	assert_true((p.collision_mask & 2) == 2, "masks player hurtbox layer 2")
	assert_true((p.collision_mask & 16) == 16, "masks terrain layer 16")
	assert_true((p.collision_mask & 8) == 0, "must NOT mask enemy layer 8")
	p.free()

func test_projectile_has_visible_mesh() -> void:
	var p: EnemyProjectile3D = Scene.instantiate()
	var mi := p.get_node_or_null("MeshInstance3D") as MeshInstance3D
	assert_not_null(mi, "projectile has a MeshInstance3D")
	assert_not_null(mi.mesh, "MeshInstance3D has a mesh assigned (projectile is visible, not invisible)")
	p.free()

func test_setup_applies_glowing_color_material() -> void:
	var p: EnemyProjectile3D = add_child_autofree(Scene.instantiate())
	p.setup(Vector3(1, 0, 0), 10.0, 5.0, Color(0.2, 0.8, 0.3))
	var mi := p.get_node("MeshInstance3D") as MeshInstance3D
	var mat := mi.material_override as StandardMaterial3D
	assert_not_null(mat, "setup applies a color material override")
	if mat:
		assert_true(mat.emission_enabled, "projectile material glows (emission on)")
		assert_almost_eq(mat.albedo_color.g, 0.8, 0.001, "albedo tinted by the passed enemy color")

func test_advance_moves_along_direction() -> void:
	var p: EnemyProjectile3D = add_child_autofree(Scene.instantiate())
	p.setup(Vector3(1, 0, 0), 10.0, 5.0)
	p.global_position = Vector3.ZERO
	p._advance(0.5)
	assert_almost_eq(p.global_position.x, 5.0, 0.001, "moved speed*dt along +X")
	assert_almost_eq(p.global_position.y, 0.0, 0.001, "stays on travel plane (no Y drift)")

func test_hits_player_and_frees() -> void:
	var p: EnemyProjectile3D = add_child_autofree(Scene.instantiate())
	p.setup(Vector3(1, 0, 0), 10.0, 7.0)
	var stub := PlayerStub.new()
	add_child_autofree(stub)
	p._on_area_entered(stub)
	assert_almost_eq(stub.taken, 7.0, 0.001, "player takes projectile_damage on hurtbox hit")
	assert_true(p.is_queued_for_deletion(), "projectile frees after hitting the player")

## Covers the real hurtbox path: a non-grouped Area3D child whose PARENT is in group
## "player" with take_damage.  This is the elif branch in _on_area_entered that was
## previously untested.
func test_hits_via_hurtbox_parent_path() -> void:
	var p: EnemyProjectile3D = add_child_autofree(Scene.instantiate())
	p.setup(Vector3(1, 0, 0), 10.0, 9.0)

	var player_node := HurtboxParent.new()
	add_child_autofree(player_node)
	var hurtbox := Area3D.new()          # NOT in group "player" — just a child Area3D
	player_node.add_child(hurtbox)

	p._on_area_entered(hurtbox)

	assert_almost_eq(player_node.taken, 9.0, 0.001,
		"parent player node takes damage via the hurtbox-parent branch")
	assert_true(p.is_queued_for_deletion(),
		"projectile frees after hurtbox-parent hit")
