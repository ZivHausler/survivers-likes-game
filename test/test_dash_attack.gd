# See docs/notes/enemy-attacks.md
extends GutTest
class StubEnemy extends Node3D:
	var data: EnemyData
class StubTarget extends Node3D:
	pass

func _setup() -> Array:
	var e: StubEnemy = add_child_autofree(StubEnemy.new())
	var d := EnemyData.new()
	d.move_speed = 5.0; d.dash_trigger_range = 14.0; d.dash_windup = 0.5
	d.dash_speed = 30.0; d.dash_duration = 0.35; d.dash_cooldown = 2.5; d.contact_damage = 6.0
	e.data = d
	var t: StubTarget = add_child_autofree(StubTarget.new())
	return [e, t, d]

func test_starts_in_approach() -> void:
	var da := DashAttack.new()
	assert_eq(da._phase, DashAttack.Phase.APPROACH, "begins approaching")

func test_enters_windup_when_in_trigger_range() -> void:
	var arr := _setup()
	var e: StubEnemy = arr[0]; var t: StubTarget = arr[1]
	e.global_position = Vector3.ZERO
	t.global_position = Vector3(10, 0, 0)  # within dash_trigger_range 14
	var da := DashAttack.new()
	da.attack_tick(e, t, 0.016)
	assert_eq(da._phase, DashAttack.Phase.WINDUP, "in range → windup")

func test_windup_then_dash_then_cooldown() -> void:
	var arr := _setup()
	var e: StubEnemy = arr[0]; var t: StubTarget = arr[1]
	e.global_position = Vector3.ZERO; t.global_position = Vector3(10, 0, 0)
	var da := DashAttack.new()
	da.attack_tick(e, t, 0.016)          # → WINDUP
	da.attack_tick(e, t, 1.0)            # windup (0.5) elapses → DASH
	assert_eq(da._phase, DashAttack.Phase.DASH, "after windup → dash")
	da.attack_tick(e, t, 1.0)            # dash (0.35) elapses → COOLDOWN
	assert_eq(da._phase, DashAttack.Phase.COOLDOWN, "after dash → cooldown")

func test_dash_velocity_points_at_locked_target() -> void:
	var v := DashAttack.dash_velocity(Vector3.ZERO, Vector3(0, 0, 8), 30.0)
	assert_almost_eq(v.z, 30.0, 0.001, "dash moves at dash_speed toward locked target (+Z)")
	assert_almost_eq(v.x, 0.0, 0.001)
