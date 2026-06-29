# See docs/notes/enemy-attacks.md
extends GutTest
## Wiring tests for Enemy3D's attack-strategy delegation.
var Scene: PackedScene = null
class StubTarget extends Node3D:
	pass

func before_all() -> void:
	Scene = load("res://enemies/enemy_3d.tscn")

func _enemy_with(kind: int, is_ranged: bool = false) -> Enemy3D:
	var e: Enemy3D = add_child_autofree(Scene.instantiate())
	var d := EnemyData.new()
	d.max_hp = 10.0; d.move_speed = 5.0; d.contact_damage = 4.0
	d.attack_kind = kind; d.is_ranged = is_ranged
	var tgt: StubTarget = add_child_autofree(StubTarget.new())
	tgt.global_position = Vector3(10, 0, 0)
	e.setup(d, tgt)
	return e

func test_melee_has_no_attack_object() -> void:
	var e := _enemy_with(EnemyData.AttackKind.MELEE)
	assert_null(e._attack, "MELEE uses inline default — no strategy object")

func test_ranged_kind_gets_ranged_attack() -> void:
	var e := _enemy_with(EnemyData.AttackKind.RANGED)
	assert_true(e._attack is RangedAttack, "RANGED kind → RangedAttack")

func test_dasher_kind_gets_dash_attack() -> void:
	var e := _enemy_with(EnemyData.AttackKind.DASHER)
	assert_true(e._attack is DashAttack, "DASHER kind → DashAttack")

func test_is_ranged_backcompat_maps_to_ranged() -> void:
	var e := _enemy_with(EnemyData.AttackKind.MELEE, true)
	assert_true(e._attack is RangedAttack, "legacy is_ranged=true → RangedAttack")
