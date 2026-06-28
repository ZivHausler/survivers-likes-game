extends GutTest
## Unit tests for ZivStunningLooks weapon and the Enemy.charm() method it depends on.
##
## Physics-overlap (beam actually hitting enemies) is manual-only because
## get_overlapping_bodies() requires live physics frames.
## Everything tested here is pure state / scalar logic.

var WeaponScene = null
var EnemyScene  = null

func before_all() -> void:
	WeaponScene = load("res://weapons/ziv_stunning_looks.tscn")
	EnemyScene  = load("res://enemies/enemy.tscn")

# ── helpers ──────────────────────────────────────────────────────────────────

func _make_stats(dmg: float = 1.0, rate: float = 1.0) -> StatBlock:
	var s := StatBlock.new()
	s.damage_mult    = dmg
	s.fire_rate_mult = rate
	return s

func _make_weapon() -> ZivStunningLooks:
	assert_not_null(WeaponScene, "ziv_stunning_looks.tscn must exist")
	var w: ZivStunningLooks = add_child_autofree(WeaponScene.instantiate()) as ZivStunningLooks
	var player: Node2D = add_child_autofree(Node2D.new()) as Node2D
	w.setup(player, _make_stats())
	return w

func _make_enemy_data(hp: float = 20.0) -> EnemyData:
	var d := EnemyData.new()
	d.id             = &"test_ziv"
	d.color          = Color.WHITE
	d.max_hp         = hp
	d.move_speed     = 80.0
	d.contact_damage = 5.0
	d.xp_value       = 1
	d.is_ranged      = false
	d.radius         = 8.0
	return d

func _make_enemy() -> Enemy:
	assert_not_null(EnemyScene, "enemy.tscn must exist")
	var e: Enemy = add_child_autofree(EnemyScene.instantiate()) as Enemy
	var dummy: Node2D = add_child_autofree(Node2D.new()) as Node2D
	dummy.global_position = Vector2(500.0, 0.0)   # far so velocity is non-zero normally
	e.setup(_make_enemy_data(), dummy)
	return e

# ── level_up() scales numbers ────────────────────────────────────────────────

func test_level_up_increases_beam_damage() -> void:
	var w := _make_weapon()
	var before := w.beam_damage
	w.level_up()
	assert_gt(w.beam_damage, before, "beam_damage must grow after level_up")

func test_level_up_increases_charm_count() -> void:
	var w := _make_weapon()
	var before := w.charm_count
	w.level_up()
	assert_gt(w.charm_count, before, "charm_count must grow after level_up")

func test_level_up_increases_charm_duration() -> void:
	var w := _make_weapon()
	var before := w.charm_duration
	w.level_up()
	assert_gt(w.charm_duration, before, "charm_duration must grow after level_up")

func test_level_up_increases_charm_radius() -> void:
	var w := _make_weapon()
	var before := w.charm_radius
	w.level_up()
	assert_gt(w.charm_radius, before, "charm_radius must grow after level_up")

func test_level_increments_with_level_up() -> void:
	var w := _make_weapon()
	assert_eq(w.level, 1, "weapon starts at level 1")
	w.level_up()
	assert_eq(w.level, 2, "level should be 2 after one level_up")

# ── is_max_level / evolve() ──────────────────────────────────────────────────

func test_is_not_max_at_start() -> void:
	var w := _make_weapon()
	assert_false(w.is_max_level(ZivStunningLooks.MAX_LEVEL),
		"should not be max level at level 1")

func test_is_max_after_enough_level_ups() -> void:
	var w := _make_weapon()
	for _i in range(ZivStunningLooks.MAX_LEVEL - 1):
		w.level_up()
	assert_true(w.is_max_level(ZivStunningLooks.MAX_LEVEL),
		"should be max level after MAX_LEVEL - 1 level_ups from level 1")

func test_evolved_is_false_initially() -> void:
	var w := _make_weapon()
	assert_false(w.evolved, "evolved must start false")

func test_evolve_sets_evolved_flag() -> void:
	var w := _make_weapon()
	w.evolve()
	assert_true(w.evolved, "evolved must be true after evolve()")

func test_evolve_enables_charm_field_monitoring() -> void:
	var w := _make_weapon()
	assert_false(w._charm_field.monitoring,
		"CharmField should be off before evolve")
	w.evolve()
	assert_true(w._charm_field.monitoring,
		"CharmField must be monitoring after evolve")

func test_evolve_beam_remains_monitoring() -> void:
	var w := _make_weapon()
	w.evolve()
	assert_true(w._beam.monitoring,
		"Beam must still be monitoring after evolve")

# ── Enemy.charm() suppresses movement ────────────────────────────────────────

func test_charm_sets_velocity_to_zero() -> void:
	var e := _make_enemy()
	e.charm(5.0)
	# _physics_process should detect active charm and zero velocity
	e._physics_process(0.016)
	assert_eq(e.velocity, Vector2.ZERO,
		"enemy velocity must be zero while charmed")

func test_charm_stacks_to_max_duration() -> void:
	var e := _make_enemy()
	e.charm(2.0)
	e.charm(5.0)   # longer — should win
	assert_almost_eq(e._charm_timer, 5.0, 0.001,
		"charm timer should be max of stacked durations")

func test_charm_timer_counts_down() -> void:
	var e := _make_enemy()
	e.charm(1.0)
	e._physics_process(0.25)
	assert_almost_eq(e._charm_timer, 0.75, 0.001,
		"charm timer should decrement by dt")

func test_charm_expires_and_enemy_moves() -> void:
	var e := _make_enemy()
	e.charm(0.016)                  # one tiny frame worth
	e._physics_process(0.1)        # expires charm (0.016 - 0.1 → 0) then steers
	# After expiry the steering code runs; target is 500 px away so velocity ≠ 0
	assert_gt(e.velocity.length(), 0.0,
		"enemy should move again after charm expires")

func test_no_charm_enemy_moves() -> void:
	var e := _make_enemy()
	e._physics_process(0.016)
	assert_gt(e.velocity.length(), 0.0,
		"uncharmed enemy with valid target must have non-zero velocity")
