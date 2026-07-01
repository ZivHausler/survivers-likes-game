extends GutTest
## Real physics-overlap tests for OrbitWeapon3D — the continuous-grind damage path
## and the per-hit knockback. Complements test_orbit_weapon_3d.gd (which is pure/scalar
## and explicitly skips real Area3D overlaps).

class ProbeEnemy extends CharacterBody3D:
	var damage_received: float = 0.0
	var hits: int = 0
	func _init() -> void:
		add_to_group("enemies")
		collision_layer = 8   # matches enemies/enemy_3d.tscn
		collision_mask = 16
		var col := CollisionShape3D.new()
		var sph := SphereShape3D.new()
		sph.radius = 0.5
		col.shape = sph
		add_child(col)
	func take_damage(amount: float) -> void:
		damage_received += amount
		hits += 1

func _make_group_call() -> Node3D:
	var player := add_child_autofree(Node3D.new()) as Node3D
	var scene: PackedScene = load("res://weapons/avihay_group_call_3d.tscn")
	var w = scene.instantiate()
	player.add_child(w)
	var stats := StatBlock.new()
	stats.damage_mult = 1.0
	stats.fire_rate_mult = 1.0
	w.setup(player, stats)
	return w

func test_overlapping_enemy_takes_damage_every_frame_scan() -> void:
	var w := _make_group_call()
	var enemy := ProbeEnemy.new()
	add_child_autofree(enemy)
	# Sit on orbiter 0 at phase 0.
	enemy.global_position = Vector3(w.orbit_radius, 0.0, 0.0)
	# Freeze the ring so the orbiter stays on the enemy across frames.
	w.orbit_speed = 0.0
	for i in range(6):
		await get_tree().physics_frame
	assert_gt(enemy.damage_received, 0.0, "continuous scan must damage a persistently-overlapping enemy")

func test_hits_throttled_by_hit_cd() -> void:
	var w := _make_group_call()
	var enemy := ProbeEnemy.new()
	add_child_autofree(enemy)
	enemy.global_position = Vector3(w.orbit_radius, 0.0, 0.0)
	w.orbit_speed = 0.0
	# Many physics frames within one HIT_CD_MS window → at most a couple of hits,
	# NOT one-per-frame spam. (500ms window; ~10 frames ≈ 0.16s.)
	for i in range(10):
		await get_tree().physics_frame
	assert_lt(enemy.hits, 5, "HIT_CD_MS must throttle repeat hits within its window")

func test_orb_knocks_enemy_outward_from_character() -> void:
	var w := _make_group_call()
	var enemy := ProbeEnemy.new()
	add_child_autofree(enemy)
	enemy.global_position = Vector3(w.orbit_radius, 0.0, 0.0)
	w.orbit_speed = 0.0
	# The weapon's origin sits on the character (ring centre).
	var before: float = enemy.global_position.distance_to(w.global_position)
	for i in range(4):
		await get_tree().physics_frame
	var after: float = enemy.global_position.distance_to(w.global_position)
	assert_gt(after, before, "an orb touching an enemy must push it radially outward from the character")
	# Pushed straight out along +X (no sideways drift in the orb's travel direction).
	assert_almost_eq(enemy.global_position.z, 0.0, 0.001, "knockback must be radial, not tangential")
