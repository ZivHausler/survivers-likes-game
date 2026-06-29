# See docs/notes/enemy-attacks.md
extends GutTest

func test_approach_advances_when_far() -> void:
	# enemy far beyond attack_range → move toward target
	var v := RangedAttack.approach_velocity(Vector3.ZERO, Vector3(30, 0, 0), 12.0, 5.0)
	assert_true(v.x > 0.0, "far enemy moves toward target (+X)")

func test_approach_holds_when_too_close() -> void:
	# enemy well inside attack_range → hold position (no retreat)
	var v := RangedAttack.approach_velocity(Vector3(2, 0, 0), Vector3(0, 0, 0), 12.0, 5.0)
	assert_true(v.length() < 0.01, "too-close enemy holds position (no kite retreat)")

func test_approach_holds_within_range() -> void:
	# at roughly attack_range → hold (zero velocity)
	var v := RangedAttack.approach_velocity(Vector3(12, 0, 0), Vector3(0, 0, 0), 12.0, 5.0)
	assert_true(v.length() < 0.01, "enemy holds position when within attack_range")

func test_should_fire_requires_range_los_and_cooldown() -> void:
	var ra := RangedAttack.new()
	# in range + LOS clear + cooldown ready → can fire
	assert_true(ra._can_fire(10.0, true, 12.0), "fires when in range, LOS clear, cd ready")
	# out of range
	assert_false(ra._can_fire(40.0, true, 12.0), "no fire out of attack_range")
	# blocked LOS
	assert_false(ra._can_fire(10.0, false, 12.0), "no fire when LOS blocked (terrain cover)")

func test_cooldown_blocks_refire() -> void:
	var ra := RangedAttack.new()
	ra._cooldown_left = 1.0
	assert_false(ra._ready_to_fire(), "cooldown blocks immediate refire")
	ra._cooldown_left = 0.0
	assert_true(ra._ready_to_fire(), "fires once cooldown elapsed")

func test_holding_enemy_fires_within_range() -> void:
	# Confirm approach threshold and fire threshold are consistent:
	# an enemy at exactly attack_range holds (zero velocity) and can fire.
	var attack_range := 12.0
	var speed := 5.0
	var enemy_pos := Vector3(attack_range, 0, 0)
	var target_pos := Vector3.ZERO
	var v := RangedAttack.approach_velocity(enemy_pos, target_pos, attack_range, speed)
	assert_true(v.length() < 0.01, "at attack_range: hold (zero velocity)")
	var ra := RangedAttack.new()
	assert_true(ra._can_fire(attack_range, true, attack_range), "at attack_range: can fire")

## Regression: projectile must spawn at the enemy, not at world origin.
## With the old code (global_position before call_deferred add_child), the node
## was not in the tree when global_position was set, so Godot discarded the value
## and the projectile landed at (0,0,0).  The fix (add_child sync, then set
## global_position) ensures the node is in the tree before the transform is applied.
func test_projectile_spawns_at_enemy_not_world_origin() -> void:
	var spawn_parent := Node3D.new()
	add_child_autofree(spawn_parent)

	var EnemyScene: PackedScene = load("res://enemies/enemy_3d.tscn")
	var enemy: Enemy3D = EnemyScene.instantiate()
	spawn_parent.add_child(enemy)

	var data := EnemyData.new()
	# defaults cover attack_cooldown (2.0); only speed + damage matter for _launch
	data.projectile_speed = 10.0
	data.projectile_damage = 5.0
	enemy.data = data
	enemy.global_position = Vector3(5.0, 0.0, 5.0)

	var target := Node3D.new()
	add_child_autofree(target)
	target.global_position = Vector3.ZERO

	var ra := RangedAttack.new()
	ra._launch(enemy, target)

	var proj: EnemyProjectile3D = null
	for child in spawn_parent.get_children():
		if child is EnemyProjectile3D:
			proj = child
			break

	assert_not_null(proj, "a projectile was added under the spawn_parent")
	if proj == null:
		return

	# Old code: projectile ends up at (0,0,0); new code: near the enemy.
	var dist_from_origin: float = proj.global_position.length()
	assert_true(dist_from_origin > 1.0,
		"projectile is NOT at world origin (dist=%.3f)" % dist_from_origin)

	var dist_from_enemy: float = proj.global_position.distance_to(enemy.global_position)
	assert_true(dist_from_enemy < 2.0,
		"projectile spawns within 2 units of the enemy (dist=%.3f)" % dist_from_enemy)
