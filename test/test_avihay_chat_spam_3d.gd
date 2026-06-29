# See docs/notes/weapon-avihay-3d.md
extends GutTest
## Unit tests for AvihayChatSpam3D weapon and its Bubble3D projectile.
## Mirrors test_avihay_chat_spam.gd coverage against the 3D classes.
##
## Physics-overlap (bubble physically colliding with enemies) is manual-only.
## Everything here is pure state / scalar logic driven via _advance() and
## _on_hit() — the same code paths the overlap handler uses.

# ─────────────────────────────────────────────────────────────────────────────
# Stub enemy — inline inner class.
# Added to the "enemies" group and exposes take_damage() call recording.
# ─────────────────────────────────────────────────────────────────────────────
class StubEnemy3D extends Node3D:
	var damage_received: float = 0.0
	var hit_count: int = 0

	func take_damage(amount: float) -> void:
		damage_received += amount
		hit_count += 1

# ─────────────────────────────────────────────────────────────────────────────
# Scene / resource caches
# ─────────────────────────────────────────────────────────────────────────────
var _BubbleScene: PackedScene = null
var _WeaponScene: PackedScene = null

func before_all() -> void:
	_BubbleScene = load("res://weapons/bubble_3d.tscn")
	_WeaponScene = load("res://weapons/avihay_chat_spam_3d.tscn")

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _make_stats(dmg: float = 1.0, rate: float = 1.0) -> StatBlock:
	var s := StatBlock.new()
	s.damage_mult    = dmg
	s.fire_rate_mult = rate
	return s

func _make_bubble(direction: Vector3 = Vector3(1, 0, 0),
		damage: float = 10.0,
		pierce: int = 1,
		homing: bool = false) -> Bubble3D:
	assert_not_null(_BubbleScene, "bubble_3d.tscn must exist")
	var b: Bubble3D = add_child_autofree(_BubbleScene.instantiate()) as Bubble3D
	b.setup(direction, damage, pierce, homing)
	return b

func _make_enemy(xpos: float = 0.0, zpos: float = 0.0) -> StubEnemy3D:
	var e := StubEnemy3D.new()
	add_child_autofree(e)
	e.add_to_group("enemies")
	e.global_position = Vector3(xpos, 0.0, zpos)
	return e

func _make_weapon() -> AvihayChatSpam3D:
	assert_not_null(_WeaponScene, "avihay_chat_spam_3d.tscn must exist")
	var w: AvihayChatSpam3D = add_child_autofree(_WeaponScene.instantiate()) as AvihayChatSpam3D
	var player: Node3D = add_child_autofree(Node3D.new()) as Node3D
	w.setup(player, _make_stats())
	return w

# ═════════════════════════════════════════════════════════════════════════════
# Bubble3D — setup & travel
# ═════════════════════════════════════════════════════════════════════════════

func test_bubble_setup_direction_stored() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0))
	assert_almost_eq(b._direction.x, 1.0, 0.001, "direction.x should be 1 after setup")
	assert_almost_eq(b._direction.y, 0.0, 0.001, "direction.y should be 0 (XZ plane)")
	assert_almost_eq(b._direction.z, 0.0, 0.001, "direction.z should be 0 after setup")

func test_bubble_advance_moves_along_x() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0))
	var before := b.global_position
	b._advance(0.1)
	assert_gt(b.global_position.x, before.x, "bubble must move in +X direction")
	assert_almost_eq(b.global_position.y, before.y, 0.001, "bubble y must stay constant")
	assert_almost_eq(b.global_position.z, before.z, 0.001, "bubble z must not drift when moving along X")

func test_bubble_advance_distance_matches_speed_times_dt() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0))
	b._advance(0.5)
	var expected := Bubble3D.SPEED * 0.5
	assert_almost_eq(b.global_position.x, expected, 0.01,
		"bubble x should be ~SPEED*dt after advance")

func test_bubble_y_stays_zero_after_advance() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0))
	b._advance(1.0)
	assert_almost_eq(b.global_position.y, 0.0, 0.001,
		"bubble must stay on XZ plane (y=0)")

func test_bubble_lifetime_expires_and_queues_free() -> void:
	var b := _make_bubble()
	b._advance(Bubble3D.MAX_LIFETIME + 0.1)
	assert_true(b.is_queued_for_deletion(),
		"bubble should be queued for deletion after lifetime expires")

func test_bubble_direction_normalised_on_setup() -> void:
	var b := _make_bubble(Vector3(3.0, 0.0, 4.0))  # length 5 — should normalise to 1
	assert_almost_eq(b._direction.length(), 1.0, 0.001, "direction must be unit-length")

func test_bubble_direction_y_is_zero_after_normalise() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0))
	assert_almost_eq(b._direction.y, 0.0, 0.001,
		"direction y must remain 0 on XZ plane")

# ═════════════════════════════════════════════════════════════════════════════
# Bubble3D — pierce & hit logic (_on_hit)
# ═════════════════════════════════════════════════════════════════════════════

func test_bubble_hit_calls_take_damage() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0), 10.0, 1)
	var e := _make_enemy()
	b._on_hit(e)
	assert_almost_eq(e.damage_received, 10.0, 0.001,
		"take_damage(10) must be called on enemy after _on_hit")

func test_bubble_hit_decrements_pierce() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0), 10.0, 2)
	var e := _make_enemy()
	b._on_hit(e)
	assert_eq(b._pierce, 1, "pierce should be 1 after one hit on pierce=2 bubble")

func test_bubble_pierce_1_frees_after_first_hit() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0), 10.0, 1)
	var e := _make_enemy()
	b._on_hit(e)
	assert_true(b.is_queued_for_deletion(),
		"pierce=1 bubble must be queued for deletion after first hit")

func test_bubble_pierce_2_survives_first_hit() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0), 10.0, 2)
	var e := _make_enemy()
	b._on_hit(e)
	assert_false(b.is_queued_for_deletion(),
		"pierce=2 bubble must survive the first hit")

func test_bubble_pierce_2_damages_two_enemies() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0), 10.0, 2)
	var e1 := _make_enemy(10.0)
	var e2 := _make_enemy(20.0)
	b._on_hit(e1)
	b._on_hit(e2)
	assert_almost_eq(e1.damage_received, 10.0, 0.001, "enemy 1 must take damage")
	assert_almost_eq(e2.damage_received, 10.0, 0.001, "enemy 2 must take damage")

func test_bubble_pierce_2_frees_after_second_hit() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0), 10.0, 2)
	var e1 := _make_enemy(10.0)
	var e2 := _make_enemy(20.0)
	b._on_hit(e1)
	b._on_hit(e2)
	assert_true(b.is_queued_for_deletion(),
		"pierce=2 bubble must be queued for deletion after second hit")

func test_bubble_no_double_hit_same_enemy() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0), 10.0, 5)
	var e := _make_enemy()
	b._on_hit(e)
	b._on_hit(e)   # second call on the same enemy must be ignored
	assert_eq(e.hit_count, 1, "same enemy must only be hit once per bubble")
	assert_almost_eq(e.damage_received, 10.0, 0.001, "damage should not double")

func test_bubble_ignores_non_enemy_node() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0), 10.0, 1)
	var non_enemy: Node3D = add_child_autofree(Node3D.new()) as Node3D
	b._on_hit(non_enemy)
	assert_false(b.is_queued_for_deletion(),
		"bubble must not be consumed by a non-enemy node")

func test_bubble_damage_uses_setup_damage() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0), 25.0, 2)
	var e := _make_enemy()
	b._on_hit(e)
	assert_almost_eq(e.damage_received, 25.0, 0.001,
		"bubble must deal exactly the damage given to setup()")

# ═════════════════════════════════════════════════════════════════════════════
# Bubble3D — homing bends toward nearest enemy
# ═════════════════════════════════════════════════════════════════════════════

func test_homing_bubble_bends_toward_enemy() -> void:
	# Bubble travels along +X; enemy is at +Z. After one advance step,
	# direction should have gained a +Z component.
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0), 10.0, 1, true)
	b.global_position = Vector3(0.0, 0.0, 0.0)
	var e := _make_enemy(0.0, 5.0)   # enemy at +Z
	# Need enemy in group for _nearest_enemy() to find it
	var z_before := b._direction.z
	b._advance(0.2)
	assert_gt(b._direction.z, z_before,
		"homing bubble direction must bend toward enemy (+Z component increases)")

func test_homing_bubble_direction_stays_unit_length() -> void:
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0), 10.0, 1, true)
	b.global_position = Vector3(0.0, 0.0, 0.0)
	var _e := _make_enemy(0.0, 5.0)
	b._advance(0.1)
	assert_almost_eq(b._direction.length(), 1.0, 0.001,
		"homing direction must remain a unit vector after steering")

func test_homing_bubble_direction_y_stays_zero_when_enemy_at_different_y() -> void:
	# Guard for fix #1: enemy has a non-zero Y position.
	# After a homing _advance step the bubble's _direction.y must stay ≈ 0
	# because homing projects onto the XZ plane before normalising.
	var b := _make_bubble(Vector3(1.0, 0.0, 0.0), 10.0, 1, true)
	b.global_position = Vector3(0.0, 0.0, 0.0)
	var e := _make_enemy(0.0, 5.0)
	e.global_position = Vector3(0.0, 10.0, 5.0)  # Y differs from bubble's Y=0
	b._advance(0.1)
	assert_lt(abs(b._direction.y), 1e-5,
		"homing must not introduce Y drift when enemy is at a different Y")

# ═════════════════════════════════════════════════════════════════════════════
# AvihayChatSpam3D — level_up() scaling
# ═════════════════════════════════════════════════════════════════════════════

func test_weapon_starts_at_level_1() -> void:
	var w := _make_weapon()
	assert_eq(w.level, 1, "weapon must start at level 1")

func test_level_up_increments_level() -> void:
	var w := _make_weapon()
	w.level_up()
	assert_eq(w.level, 2, "level must be 2 after one level_up")

func test_level_up_increases_bubble_count() -> void:
	var w := _make_weapon()
	var before := w.bubble_count
	w.level_up()
	assert_gt(w.bubble_count, before, "bubble_count must grow after level_up")

func test_level_up_bubble_count_delta_is_1() -> void:
	var w := _make_weapon()
	var before := w.bubble_count
	w.level_up()
	assert_eq(w.bubble_count - before, 1, "bubble_count must increase by exactly 1")

func test_level_up_increases_bubble_pierce() -> void:
	var w := _make_weapon()
	var before := w.bubble_pierce
	w.level_up()
	assert_gt(w.bubble_pierce, before, "bubble_pierce must grow after level_up")

func test_level_up_bubble_pierce_delta_is_1() -> void:
	var w := _make_weapon()
	var before := w.bubble_pierce
	w.level_up()
	assert_eq(w.bubble_pierce - before, 1, "bubble_pierce must increase by exactly 1")

func test_level_up_increases_bubble_damage() -> void:
	var w := _make_weapon()
	var before := w.bubble_damage
	w.level_up()
	assert_gt(w.bubble_damage, before, "bubble_damage must grow after level_up")

func test_level_up_bubble_damage_delta_is_5() -> void:
	var w := _make_weapon()
	var before := w.bubble_damage
	w.level_up()
	assert_almost_eq(w.bubble_damage - before, 5.0, 0.001,
		"bubble_damage must increase by exactly 5 per level")

func test_is_not_max_at_start() -> void:
	var w := _make_weapon()
	assert_false(w.is_max_level(AvihayChatSpam3D.MAX_LEVEL),
		"should not be max level at level 1")

func test_is_max_after_enough_level_ups() -> void:
	var w := _make_weapon()
	for _i in range(AvihayChatSpam3D.MAX_LEVEL - 1):
		w.level_up()
	assert_true(w.is_max_level(AvihayChatSpam3D.MAX_LEVEL),
		"should be max level after MAX_LEVEL-1 level_ups from level 1")

# ═════════════════════════════════════════════════════════════════════════════
# AvihayChatSpam3D — evolve()
# ═════════════════════════════════════════════════════════════════════════════

func test_evolved_is_false_initially() -> void:
	var w := _make_weapon()
	assert_false(w.evolved, "evolved must start false")

func test_homing_mode_is_false_initially() -> void:
	var w := _make_weapon()
	assert_false(w._homing_mode, "_homing_mode must start false")

func test_evolve_sets_evolved_flag() -> void:
	var w := _make_weapon()
	w.evolve()
	assert_true(w.evolved, "evolved must be true after evolve()")

func test_evolve_enables_homing_mode() -> void:
	var w := _make_weapon()
	w.evolve()
	assert_true(w._homing_mode, "_homing_mode must be true after evolve()")

# ═════════════════════════════════════════════════════════════════════════════
# AvihayChatSpam3D — _get_fire_directions() (state logic, no physics required)
# ═════════════════════════════════════════════════════════════════════════════

func test_fire_directions_normal_count_matches_bubble_count() -> void:
	var w := _make_weapon()
	var dirs := w._get_fire_directions()
	assert_eq(dirs.size(), w.bubble_count,
		"non-evolved fire must produce exactly bubble_count directions")

func test_fire_directions_evolved_count_is_doubled() -> void:
	var w := _make_weapon()
	w.evolve()
	var dirs := w._get_fire_directions()
	assert_eq(dirs.size(), w.bubble_count * 2,
		"evolved 360° fire must produce bubble_count*2 directions")

func test_fire_directions_evolved_are_unit_vectors() -> void:
	var w := _make_weapon()
	w.evolve()
	for dir in w._get_fire_directions():
		assert_almost_eq(dir.length(), 1.0, 0.001,
			"all evolved fire directions must be unit vectors")

func test_fire_directions_normal_are_unit_vectors() -> void:
	var w := _make_weapon()
	for dir in w._get_fire_directions():
		assert_almost_eq(dir.length(), 1.0, 0.001,
			"all non-evolved fire directions must be unit vectors")

func test_fire_directions_are_xz_vectors() -> void:
	var w := _make_weapon()
	for dir in w._get_fire_directions():
		assert_almost_eq(dir.y, 0.0, 0.001,
			"all fire directions must have y=0 (XZ plane)")

func test_fire_directions_evolved_are_xz_vectors() -> void:
	var w := _make_weapon()
	w.evolve()
	for dir in w._get_fire_directions():
		assert_almost_eq(dir.y, 0.0, 0.001,
			"all evolved fire directions must have y=0 (XZ plane)")

func test_fire_directions_grow_after_level_up() -> void:
	var w := _make_weapon()
	var count_before := w._get_fire_directions().size()
	w.level_up()
	var count_after := w._get_fire_directions().size()
	assert_gt(count_after, count_before,
		"_get_fire_directions must return more directions after level_up")

func test_fire_directions_span_spread_cone() -> void:
	# With an enemy at +X, the spread should fan around +X within ±SPREAD_HALF_ANGLE.
	var w := _make_weapon()
	var e := _make_enemy(10.0, 0.0)  # at +X
	e.add_to_group("enemies")
	var dirs := w._get_fire_directions()
	# All directions should be within the spread cone:
	# angle from +X in XZ plane should be within ±SPREAD_HALF_ANGLE + small epsilon
	for dir in dirs:
		var angle_from_x: float = abs(atan2(dir.z, dir.x))
		assert_true(angle_from_x <= AvihayChatSpam3D.SPREAD_HALF_ANGLE + 0.01,
			"all non-evolved directions must be within ±SPREAD_HALF_ANGLE of target")

func test_nearest_enemy_direction_returns_xz_unit_vector() -> void:
	var w := _make_weapon()
	var _e := _make_enemy(5.0, 3.0)
	var dir := w._nearest_enemy_direction()
	assert_almost_eq(dir.length(), 1.0, 0.001,
		"_nearest_enemy_direction must return a unit vector")
	assert_almost_eq(dir.y, 0.0, 0.001,
		"_nearest_enemy_direction y must be 0 (XZ only)")

func test_nearest_enemy_direction_fallback_when_no_enemies() -> void:
	var w := _make_weapon()
	# No enemies in the tree — should return default (1,0,0)
	var dir := w._nearest_enemy_direction()
	assert_almost_eq(dir.x, 1.0, 0.001, "fallback direction x should be 1")
	assert_almost_eq(dir.y, 0.0, 0.001, "fallback direction y should be 0")
	assert_almost_eq(dir.z, 0.0, 0.001, "fallback direction z should be 0")

func test_nearest_enemy_direction_points_toward_enemy() -> void:
	var w := _make_weapon()
	# Enemy at +Z relative to player (at origin)
	var _e := _make_enemy(0.0, 5.0)
	var dir := w._nearest_enemy_direction()
	# Direction should point toward +Z
	assert_almost_eq(dir.z, 1.0, 0.01,
		"direction should point toward enemy along +Z")
	assert_almost_eq(dir.x, 0.0, 0.01,
		"direction x should be 0 when enemy is straight ahead in Z")

# ═════════════════════════════════════════════════════════════════════════════
# AvihayChatSpam3D — fire() add_child ordering (Bug 2 regression tests)
# Bubbles must be added to tree before global_position is set; otherwise
# Node3D raises "!is_inside_tree()" and the bubble ends up at origin.
# ═════════════════════════════════════════════════════════════════════════════

## _make_weapon() adds the player via add_child_autofree, so player IS in the
## scene tree. spawn_parent = player.get_parent() = the GutTest root.
## fire() must add bubbles under spawn_parent without errors.

func test_fire_adds_bubbles_to_spawn_parent() -> void:
	var w := _make_weapon()
	var player := w._player_ref as Node3D
	var spawn_parent := player.get_parent()
	assert_not_null(spawn_parent, "player must have a parent (spawn_parent) for fire() to work")
	var before_count := spawn_parent.get_child_count()
	w.fire()
	var after_count := spawn_parent.get_child_count()
	assert_gt(after_count, before_count,
		"fire() must add at least one bubble child under spawn_parent")

func test_fire_bubble_is_inside_tree_after_fire() -> void:
	var w := _make_weapon()
	var spawn_parent := (w._player_ref as Node3D).get_parent()
	w.fire()
	var found := false
	for child in spawn_parent.get_children():
		if child is Bubble3D:
			found = true
			assert_true(child.is_inside_tree(),
				"Bubble3D must be inside tree after fire() — add_child must precede global_position")
			break
	assert_true(found, "fire() must spawn at least one Bubble3D")

func test_fire_bubble_position_matches_player_position() -> void:
	# Build a proper Node3D scene root so global_position inherits correctly.
	var scene_root := Node3D.new()
	add_child_autofree(scene_root)
	var player := Node3D.new()
	scene_root.add_child(player)
	player.global_position = Vector3(4.0, 0.0, 7.0)

	var w: AvihayChatSpam3D = _WeaponScene.instantiate() as AvihayChatSpam3D
	scene_root.add_child(w)
	w.setup(player, _make_stats())

	w.fire()

	var found := false
	for child in scene_root.get_children():
		if child is Bubble3D:
			found = true
			assert_almost_eq(child.global_position.x, player.global_position.x, 0.01,
				"bubble x must match player x after fire()")
			assert_almost_eq(child.global_position.z, player.global_position.z, 0.01,
				"bubble z must match player z after fire()")
			break
	assert_true(found, "fire() must spawn at least one Bubble3D when player is in a Node3D tree")
