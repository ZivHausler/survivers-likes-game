extends GutTest
## Unit tests for AvihayChatSpam weapon and its Bubble projectile.
##
## Physics-overlap (bubble physically colliding with enemies in-world) is
## manual-only because get_overlapping_bodies() requires live physics frames.
## Everything here is pure state / scalar logic driven via _advance() and
## _on_hit() — the same code paths the overlap handler uses.

# ─────────────────────────────────────────────────────────────────────────────
# Stub enemy — inline inner class so no extra scene file is needed.
# Added to the "enemies" group and exposes take_damage() call recording.
# ─────────────────────────────────────────────────────────────────────────────
class StubEnemy extends Node2D:
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
	_BubbleScene = load("res://weapons/bubble.tscn")
	_WeaponScene = load("res://weapons/avihay_chat_spam.tscn")

# ─────────────────────────────────────────────────────────────────────────────
# Helpers
# ─────────────────────────────────────────────────────────────────────────────

func _make_stats(dmg: float = 1.0, rate: float = 1.0) -> StatBlock:
	var s := StatBlock.new()
	s.damage_mult    = dmg
	s.fire_rate_mult = rate
	return s

func _make_bubble(direction: Vector2 = Vector2.RIGHT,
		damage: float = 10.0,
		pierce: int = 1,
		homing: bool = false) -> Bubble:
	assert_not_null(_BubbleScene, "bubble.tscn must exist")
	var b: Bubble = add_child_autofree(_BubbleScene.instantiate()) as Bubble
	b.setup(direction, damage, pierce, homing)
	return b

func _make_enemy(xpos: float = 0.0) -> StubEnemy:
	var e := StubEnemy.new()
	add_child_autofree(e)
	e.add_to_group("enemies")
	e.global_position = Vector2(xpos, 0.0)
	return e

func _make_weapon() -> AvihayChatSpam:
	assert_not_null(_WeaponScene, "avihay_chat_spam.tscn must exist")
	var w: AvihayChatSpam = add_child_autofree(_WeaponScene.instantiate()) as AvihayChatSpam
	var player: Node2D = add_child_autofree(Node2D.new()) as Node2D
	w.setup(player, _make_stats())
	return w

# ═════════════════════════════════════════════════════════════════════════════
# Bubble — setup & travel
# ═════════════════════════════════════════════════════════════════════════════

func test_bubble_setup_direction_stored() -> void:
	var b := _make_bubble(Vector2(1.0, 0.0))
	assert_almost_eq(b._direction.x, 1.0, 0.001, "direction.x should be 1 after setup")
	assert_almost_eq(b._direction.y, 0.0, 0.001, "direction.y should be 0 after setup")

func test_bubble_advance_moves_along_direction() -> void:
	var b := _make_bubble(Vector2.RIGHT)
	var before := b.position
	b._advance(0.1)
	assert_gt(b.position.x, before.x, "bubble must move rightward after _advance")
	assert_almost_eq(b.position.y, before.y, 0.001, "bubble must not drift vertically")

func test_bubble_advance_distance_matches_speed_times_dt() -> void:
	var b := _make_bubble(Vector2.RIGHT)
	b._advance(0.5)
	var expected := Bubble.SPEED * 0.5
	assert_almost_eq(b.position.x, expected, 0.5, "bubble x should be ~SPEED*dt after advance")

func test_bubble_lifetime_expires_and_queues_free() -> void:
	var b := _make_bubble()
	# Advance past MAX_LIFETIME in one big step
	b._advance(Bubble.MAX_LIFETIME + 0.1)
	assert_true(b.is_queued_for_deletion(),
		"bubble should be queued for deletion after lifetime expires")

func test_bubble_direction_normalised_on_setup() -> void:
	var b := _make_bubble(Vector2(3.0, 4.0))  # length 5 — should normalise to length 1
	assert_almost_eq(b._direction.length(), 1.0, 0.001, "direction must be unit-length")

# ═════════════════════════════════════════════════════════════════════════════
# Bubble — pierce & hit logic (_on_hit)
# ═════════════════════════════════════════════════════════════════════════════

func test_bubble_hit_calls_take_damage() -> void:
	var b := _make_bubble(Vector2.RIGHT, 10.0, 1)
	var e := _make_enemy()
	b._on_hit(e)
	assert_almost_eq(e.damage_received, 10.0, 0.001,
		"take_damage(10) must be called on enemy after _on_hit")

func test_bubble_hit_decrements_pierce() -> void:
	var b := _make_bubble(Vector2.RIGHT, 10.0, 2)
	var e := _make_enemy()
	b._on_hit(e)
	assert_eq(b._pierce, 1, "pierce should be 1 after one hit on pierce=2 bubble")

func test_bubble_pierce_1_frees_after_first_hit() -> void:
	var b := _make_bubble(Vector2.RIGHT, 10.0, 1)
	var e := _make_enemy()
	b._on_hit(e)
	assert_true(b.is_queued_for_deletion(),
		"pierce=1 bubble must be queued for deletion after first hit")

func test_bubble_pierce_2_survives_first_hit() -> void:
	var b := _make_bubble(Vector2.RIGHT, 10.0, 2)
	var e := _make_enemy()
	b._on_hit(e)
	assert_false(b.is_queued_for_deletion(),
		"pierce=2 bubble must survive the first hit")

func test_bubble_pierce_2_damages_two_enemies() -> void:
	var b := _make_bubble(Vector2.RIGHT, 10.0, 2)
	var e1 := _make_enemy(10.0)
	var e2 := _make_enemy(20.0)
	b._on_hit(e1)
	b._on_hit(e2)
	assert_almost_eq(e1.damage_received, 10.0, 0.001, "enemy 1 must take damage")
	assert_almost_eq(e2.damage_received, 10.0, 0.001, "enemy 2 must take damage")

func test_bubble_pierce_2_frees_after_second_hit() -> void:
	var b := _make_bubble(Vector2.RIGHT, 10.0, 2)
	var e1 := _make_enemy(10.0)
	var e2 := _make_enemy(20.0)
	b._on_hit(e1)
	b._on_hit(e2)
	assert_true(b.is_queued_for_deletion(),
		"pierce=2 bubble must be queued for deletion after second hit")

func test_bubble_no_double_hit_same_enemy() -> void:
	var b := _make_bubble(Vector2.RIGHT, 10.0, 5)
	var e := _make_enemy()
	b._on_hit(e)
	b._on_hit(e)   # second call on the same enemy must be ignored
	assert_eq(e.hit_count, 1, "same enemy must only be hit once per bubble")
	assert_almost_eq(e.damage_received, 10.0, 0.001, "damage should not double")

func test_bubble_ignores_non_enemy_node() -> void:
	var b := _make_bubble(Vector2.RIGHT, 10.0, 1)
	var non_enemy := add_child_autofree(Node2D.new()) as Node2D
	# not in "enemies" group — _on_hit must be a no-op
	b._on_hit(non_enemy)
	assert_false(b.is_queued_for_deletion(),
		"bubble must not be consumed by a non-enemy node")

func test_bubble_damage_uses_setup_damage() -> void:
	var b := _make_bubble(Vector2.RIGHT, 25.0, 2)
	var e := _make_enemy()
	b._on_hit(e)
	assert_almost_eq(e.damage_received, 25.0, 0.001,
		"bubble must deal exactly the damage given to setup()")

# ═════════════════════════════════════════════════════════════════════════════
# AvihayChatSpam — level_up() scaling
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

func test_level_up_increases_bubble_pierce() -> void:
	var w := _make_weapon()
	var before := w.bubble_pierce
	w.level_up()
	assert_gt(w.bubble_pierce, before, "bubble_pierce must grow after level_up")

func test_level_up_increases_bubble_damage() -> void:
	var w := _make_weapon()
	var before := w.bubble_damage
	w.level_up()
	assert_gt(w.bubble_damage, before, "bubble_damage must grow after level_up")

func test_is_not_max_at_start() -> void:
	var w := _make_weapon()
	assert_false(w.is_max_level(AvihayChatSpam.MAX_LEVEL),
		"should not be max level at level 1")

func test_is_max_after_enough_level_ups() -> void:
	var w := _make_weapon()
	for _i in range(AvihayChatSpam.MAX_LEVEL - 1):
		w.level_up()
	assert_true(w.is_max_level(AvihayChatSpam.MAX_LEVEL),
		"should be max level after MAX_LEVEL-1 level_ups from level 1")

# ═════════════════════════════════════════════════════════════════════════════
# AvihayChatSpam — evolve()
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
# AvihayChatSpam — _get_fire_directions() (state logic, no physics required)
# ═════════════════════════════════════════════════════════════════════════════

func test_fire_directions_normal_count_matches_bubble_count() -> void:
	var w := _make_weapon()
	# Call without enemy in tree — falls back to Vector2.RIGHT, which is fine.
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
			"all fire directions must be unit vectors")

func test_fire_directions_normal_are_unit_vectors() -> void:
	var w := _make_weapon()
	for dir in w._get_fire_directions():
		assert_almost_eq(dir.length(), 1.0, 0.001,
			"all non-evolved fire directions must be unit vectors")

func test_fire_directions_grow_after_level_up() -> void:
	var w := _make_weapon()
	var count_before := w._get_fire_directions().size()
	w.level_up()
	var count_after := w._get_fire_directions().size()
	assert_gt(count_after, count_before,
		"_get_fire_directions must return more directions after level_up")
