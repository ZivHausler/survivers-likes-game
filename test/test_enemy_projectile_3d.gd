# test/test_enemy_projectile_3d.gd
extends GutTest
var Scene: PackedScene = null

class PlayerStub extends Area3D:
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
